import { z } from "zod";
import { ApiError } from "../api/errors.js";
import { getOptionalEnv } from "../config/env.js";
import { categorizeExpense, categorizeIncome } from "../tools/categorizeExpense.js";
import { extractDigitMagnitudeAmount, extractGroupedDigitAmount } from "../services/expenseParser.js";
import { expenseCategories, expenseKinds, supportedCurrencies, type CreateExpenseInput } from "../types/expense.js";
import { getOpenAIClient } from "./openaiClient.js";

export type ExpenseAgentResult =
  | {
      status: "ok";
      expense: CreateExpenseInput;
    }
  | {
      status: "needs_clarification";
      message: string;
    };

const agentOutputSchema = z.discriminatedUnion("status", [
  z.object({
    status: z.literal("ok"),
    kind: z.enum(expenseKinds),
    amount: z.string().regex(/^\d+(\.\d{1,2})?$/),
    currency: z.enum(supportedCurrencies),
    description: z.string().trim().min(1).max(200),
    merchant: z.string().trim().min(1).max(120).nullable(),
    category: z.enum(expenseCategories).nullable(),
    confidence: z.number().min(0).max(1)
  }),
  z.object({
    status: z.literal("needs_clarification"),
    message: z.string().trim().min(1).max(200)
  })
]);

const responseJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["status", "kind", "amount", "currency", "description", "merchant", "category", "confidence", "message"],
  properties: {
    status: {
      type: "string",
      enum: ["ok", "needs_clarification"]
    },
    kind: {
      type: ["string", "null"],
      enum: [...expenseKinds, null],
      description: "'expense' for money going out, 'income' for money coming in."
    },
    amount: {
      type: ["string", "null"],
      description: "Positive decimal amount as a string, without currency symbols."
    },
    currency: {
      type: ["string", "null"],
      enum: [...supportedCurrencies, null]
    },
    description: {
      type: ["string", "null"]
    },
    merchant: {
      type: ["string", "null"]
    },
    category: {
      type: ["string", "null"],
      enum: [...expenseCategories, null]
    },
    confidence: {
      type: ["number", "null"],
      minimum: 0,
      maximum: 1
    },
    message: {
      type: ["string", "null"]
    }
  }
};

export async function runExpenseAgent(input: string): Promise<ExpenseAgentResult> {
  const response = await getOpenAIClient().responses.create({
    model: getOptionalEnv("OPENAI_MODEL", "gpt-4.1-mini"),
    input: [
      {
        role: "system",
        content:
          "You are an expense/income extraction agent for a Colombian personal finance MVP. Extract only real transaction data from the user text. Do not invent amounts, currency, merchant, or description. If the amount is missing or ambiguous, return needs_clarification. Use only COP, USD, or EUR. If currency is omitted but the phrase is Colombian Spanish and the amount is clear, use COP. Use only the supported categories. Do not provide investment advice. " +
          "Colombian Spanish amounts use 'mil' for thousands and 'millón'/'millones' for millions — always expand these to the FULL numeric value, never the bare digits before the word. Examples: '200 mil pesos' -> amount \"200000\" (not \"200\"); 'cuarenta y cinco mil' -> \"45000\"; '2.5 millones' -> \"2500000\"; 'un millón doscientos mil' -> \"1200000\". " +
          "Classify 'kind' as 'income' for money coming IN, 'expense' for money going OUT. Common Colombian Spanish income phrases: 'me pagaron', 'me pagó', 'me ingresó'/'me depositaron', 'me dieron', 'me prestaron', 'recibí', 'gané', 'me regalaron', 'reembolso'/'me devolvieron'. 'adquirí' is ambiguous by itself — treat it as income only when paired with receiving money/a loan/a payment (e.g. 'adquirí un préstamo'), otherwise as an expense (e.g. 'adquirí una camisa' is a purchase). For income, pick category from: salary (sueldo/nómina), loan (préstamo recibido), gift (regalo), refund (reembolso/devolución), other_income (anything else). For expenses, use the original expense categories (groceries, restaurants, transportation, shopping, entertainment, utilities, health, subscriptions, travel, other)."
      },
      {
        role: "user",
        content: input
      }
    ],
    text: {
      format: {
        type: "json_schema",
        name: "expense_extraction",
        strict: true,
        schema: responseJsonSchema
      }
    }
  });

  const outputText = response.output_text;
  if (!outputText) {
    throw new ApiError(502, "upstream_failure", "OpenAI did not return a usable response.");
  }

  const parsedJson = JSON.parse(outputText) as unknown;
  const parsed = agentOutputSchema.parse(normalizeAgentOutput(parsedJson));

  if (parsed.status === "needs_clarification") {
    return parsed;
  }

  const categoryResult =
    parsed.category !== null
      ? { category: parsed.category, confidence: parsed.confidence }
      : parsed.kind === "income"
        ? categorizeIncome({ description: parsed.description, merchant: parsed.merchant })
        : categorizeExpense({ description: parsed.description, merchant: parsed.merchant, amount: parsed.amount });

  // Cross-check against deterministic patterns the model has been seen
  // getting wrong: digit-led magnitude words ("200 mil" -> "200" instead of
  // "200000") and grouped-digit thousands separators ("50,000" -> "50"
  // instead of "50000"). Both are unambiguous by construction, so either one
  // (they don't overlap) wins over the model's own extraction.
  const amount = extractDigitMagnitudeAmount(input) ?? extractGroupedDigitAmount(input) ?? parsed.amount;

  return {
    status: "ok",
    expense: {
      kind: parsed.kind,
      amount,
      currency: parsed.currency,
      category: categoryResult.category,
      description: parsed.description,
      merchant: parsed.merchant,
      source: "ios_voice",
      rawInput: input,
      confidence: Math.min(parsed.confidence, categoryResult.confidence)
    }
  };
}

function normalizeAgentOutput(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    return value;
  }

  const candidate = value as Record<string, unknown>;
  if (candidate.status === "needs_clarification") {
    return {
      status: "needs_clarification",
      message: candidate.message ?? "Necesito más información para guardar este gasto."
    };
  }

  return candidate;
}
