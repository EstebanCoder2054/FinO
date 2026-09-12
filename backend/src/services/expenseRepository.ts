import { ApiError } from "../api/errors.js";
import { supabaseAdmin } from "../db/supabase.js";
import type { CreateExpenseInput, Expense } from "../types/expense.js";

type ExpenseRow = {
  id: string;
  amount: number | string;
  currency: Expense["currency"];
  category: Expense["category"];
  description: string;
  merchant: string | null;
  source: Expense["source"];
  raw_input: string;
  confidence: number | null;
  created_at: string;
};

export async function saveExpenseForUser(
  userId: string,
  input: CreateExpenseInput,
  idempotencyKey?: string
): Promise<Expense> {
  const { data, error } = await supabaseAdmin
    .from("expenses")
    .insert({
      user_id: userId,
      amount: input.amount,
      currency: input.currency,
      category: input.category,
      description: input.description,
      merchant: input.merchant,
      source: input.source,
      raw_input: input.rawInput,
      confidence: input.confidence,
      idempotency_key: idempotencyKey ?? null
    })
    .select("id, amount, currency, category, description, merchant, source, raw_input, confidence, created_at")
    .single<ExpenseRow>();

  if (error) {
    console.error("Supabase expense insert failed", {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });

    if (error.code === "23505") {
      throw new ApiError(409, "conflict", "This expense request was already processed.");
    }

    throw new ApiError(503, "upstream_failure", "Could not save the expense right now.");
  }

  return mapExpenseRow(data);
}

function mapExpenseRow(row: ExpenseRow): Expense {
  return {
    id: row.id,
    amount: String(row.amount),
    currency: row.currency,
    category: row.category,
    description: row.description,
    merchant: row.merchant,
    source: row.source,
    rawInput: row.raw_input,
    confidence: row.confidence,
    createdAt: row.created_at
  };
}
