import { categorizeExpense, categorizeIncome } from "../tools/categorizeExpense.js";
import type { CreateExpenseInput, ExpenseKind } from "../types/expense.js";
import { getOptionalEnv } from "../config/env.js";

type ParseExpenseResult =
  | {
      status: "ok";
      expense: CreateExpenseInput;
    }
  | {
      status: "needs_clarification";
      message: string;
    };

const numberWords: Record<string, number> = {
  un: 1,
  una: 1,
  uno: 1,
  dos: 2,
  tres: 3,
  cuatro: 4,
  cinco: 5,
  seis: 6,
  siete: 7,
  ocho: 8,
  nueve: 9,
  diez: 10
};

/// Digits-only magnitude pattern ("200 mil", "2.5 millones"). Unambiguous
/// by construction — unlike word-spelled numbers ("cuarenta y cinco mil"),
/// there's no risk of only catching the last word before "mil" — so the
/// LLM-backed agent (`expenseAgent.ts`) uses this as a cross-check/override
/// on its own amount extraction, which has been seen dropping the magnitude
/// word and returning e.g. "200" for "200 mil pesos".
export function extractDigitMagnitudeAmount(input: string): string | null {
  const lower = input.toLowerCase();

  const millionMatch = lower.match(/\b(\d+(?:[.,]\d+)?)\s+mill[oó]n(?:es)?\b/);
  if (millionMatch) {
    const value = Number(millionMatch[1].replace(",", "."));
    return Number.isFinite(value) && value > 0 ? String(value * 1_000_000) : null;
  }

  const milMatch = lower.match(/\b(\d+(?:[.,]\d+)?)\s+mil\b/);
  if (milMatch) {
    const value = Number(milMatch[1].replace(",", "."));
    return Number.isFinite(value) && value > 0 ? String(value * 1000) : null;
  }

  return null;
}

/// Matches the Colombian Spanish phrases this feature was asked to
/// recognize (money coming in, not going out). Used only by this
/// deterministic fallback — the LLM-backed agent gets the same guidance as
/// prompt instructions, which handle ambiguous cases (like "adquirí") with
/// more judgment than a regex can.
const incomePattern =
  /\b(me pagaron|me pag[oó]|me ingres(?:aron|[oó])|me deposit(?:aron|[oó])|me dieron|me prestaron|me regalaron|me devolvieron|recib[ií]|gan[eé]|adquir[ií])\b/;

function extractKind(input: string): ExpenseKind {
  return incomePattern.test(input) ? "income" : "expense";
}

export function parseExpenseInput(rawInput: string): ParseExpenseResult {
  const input = rawInput.trim();
  const lower = input.toLowerCase();
  const amount = extractAmount(lower);

  if (!amount) {
    return {
      status: "needs_clarification",
      message: "Necesito el monto exacto para guardar este gasto."
    };
  }

  const kind = extractKind(lower);
  const merchant = extractMerchant(input);
  const description = extractDescription(input, merchant);
  const categoryResult =
    kind === "income" ? categorizeIncome({ description, merchant }) : categorizeExpense({ description, merchant, amount });

  return {
    status: "ok",
    expense: {
      kind,
      amount,
      currency: extractCurrency(lower),
      category: categoryResult.category,
      description,
      merchant,
      source: "ios_voice",
      rawInput: input,
      confidence: categoryResult.confidence
    }
  };
}

function extractAmount(input: string): string | null {
  const millionWordMatch = input.match(/\b(un|una|uno|\d+(?:[.,]\d+)?)\s+mill[oó]n(?:es)?\b/);
  if (millionWordMatch) {
    const value = parseNumberToken(millionWordMatch[1]);
    return value ? String(value * 1000000) : null;
  }

  const milMatch = input.match(/\b(\d+(?:[.,]\d+)?|un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez)\s+mil\b/);
  if (milMatch) {
    const value = parseNumberToken(milMatch[1]);
    return value ? String(value * 1000) : null;
  }

  const numericMatch = input.match(/\b\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?\b|\b\d+(?:[.,]\d{1,2})?\b/);
  if (!numericMatch) {
    return null;
  }

  const value = Number(normalizeGroupedNumber(numericMatch[0]));
  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }

  return value.toFixed(Number.isInteger(value) ? 0 : 2);
}

/**
 * Normalizes a number that may use "." or "," as either a thousands
 * separator or a decimal point (locale-ambiguous). Amounts here are pesos —
 * no cents in practice — so any separator immediately followed by exactly
 * three digits is a thousands group and gets stripped, regardless of which
 * character it is; a separator left over after that (followed by 1-2
 * digits) is a genuine decimal point. Blindly assuming "," is always
 * decimal previously turned "50,000" into 50 instead of 50000.
 */
function normalizeGroupedNumber(raw: string): string {
  return raw.replace(/[.,](\d{3})(?!\d)/g, "$1").replace(",", ".");
}

/**
 * Cross-check for an unambiguous grouped-digit amount ("50.000", "50,000",
 * "1.234.567") anywhere in free text. Exists because both the LLM agent and
 * plain parsing here have been seen misreading the separator as a decimal
 * point — this regex only matches when there's no such ambiguity (a full
 * three-digit group), so it's safe to use as an override.
 */
export function extractGroupedDigitAmount(input: string): string | null {
  const match = input.match(/\b\d{1,3}(?:[.,]\d{3})+\b/);
  if (!match) {
    return null;
  }

  const value = Number(normalizeGroupedNumber(match[0]));
  return Number.isFinite(value) && value > 0 ? String(value) : null;
}

function parseNumberToken(token: string): number | null {
  if (token in numberWords) {
    return numberWords[token];
  }

  const value = Number(token.replace(",", "."));
  return Number.isFinite(value) ? value : null;
}

function extractCurrency(input: string): "COP" | "USD" | "EUR" {
  if (/\b(usd|d[oó]lares?|dollars?)\b/.test(input)) {
    return "USD";
  }

  if (/\b(eur|euros?)\b/.test(input)) {
    return "EUR";
  }

  return getOptionalEnv("DEFAULT_CURRENCY", "COP") as "COP" | "USD" | "EUR";
}

function extractMerchant(input: string): string | null {
  const knownMerchants = ["Uber", "Netflix", "Spotify", "iCloud"];
  return knownMerchants.find((merchant) => input.toLowerCase().includes(merchant.toLowerCase())) ?? null;
}

function extractDescription(input: string, merchant: string | null): string {
  if (merchant) {
    return merchant;
  }

  const lower = input.toLowerCase();
  if (lower.includes("mercado")) return "mercado";
  if (lower.includes("camisa")) return "camisa";
  if (lower.includes("comida")) return "comida";

  return input.replace(/[.。]$/, "").slice(0, 120);
}
