import { categorizeExpense } from "../tools/categorizeExpense.js";
import type { CreateExpenseInput } from "../types/expense.js";
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

  const merchant = extractMerchant(input);
  const description = extractDescription(input, merchant);
  const categoryResult = categorizeExpense({
    description,
    merchant,
    amount
  });

  return {
    status: "ok",
    expense: {
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

  const normalized = numericMatch[0].replace(/\./g, "").replace(",", ".");
  const value = Number(normalized);
  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }

  return value.toFixed(Number.isInteger(value) ? 0 : 2);
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
