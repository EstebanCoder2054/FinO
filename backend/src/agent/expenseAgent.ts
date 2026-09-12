import { z } from "zod";
import { ApiError } from "../api/errors.js";
import { getOptionalEnv } from "../config/env.js";
import { categorizeExpense } from "../tools/categorizeExpense.js";
import { extractGroupedDigitAmount } from "../services/expenseParser.js";
import { expenseCategories, supportedCurrencies, type CreateExpenseInput } from "../types/expense.js";
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
  required: ["status", "amount", "currency", "description", "merchant", "category", "confidence", "message"],
  properties: {
    status: {
      type: "string",
      enum: ["ok", "needs_clarification"]
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
          "You are an expense extraction agent for a Colombian personal finance MVP. Extract only real expense data from the user text. Do not invent amounts, currency, merchant, or description. If the amount is missing or ambiguous, return needs_clarification. Use only COP, USD, or EUR. If currency is omitted but the phrase is Colombian Spanish and the amount is clear, use COP. Use only the supported categories. Do not provide investment advice."
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
    parsed.category === null
      ? categorizeExpense({ description: parsed.description, merchant: parsed.merchant, amount: parsed.amount })
      : { category: parsed.category, confidence: parsed.confidence };

  // Cross-check against an unambiguous grouped-digit amount in the raw text
  // ("50.000", "50,000"): the model has been seen reading the separator as
  // a decimal point and returning e.g. "50" for "50,000 pesos".
  const groupedDigitAmount = extractGroupedDigitAmount(input);
  const amount = groupedDigitAmount ?? parsed.amount;

  return {
    status: "ok",
    expense: {
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
