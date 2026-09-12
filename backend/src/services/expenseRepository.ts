import { ApiError } from "../api/errors.js";
import { supabaseAdmin } from "../db/supabase.js";
import type { CreateExpenseInput, Expense, ExpenseCategory, UpdateExpenseInput } from "../types/expense.js";

const expenseColumns = "id, amount, currency, category, description, merchant, source, raw_input, confidence, created_at";

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

/**
 * The `expenses` table doesn't have a `kind` column or the income-side
 * category enum values yet (needs a migration that hasn't been run against
 * the live database). Until then, this maps anything the schema can't
 * store to a value it can, so voice capture can classify income today
 * without every insert/update failing against the live enum. The caller
 * (app.ts) still returns the true kind/category in the API response from
 * what it already computed — this only affects what gets persisted.
 */
const liveCategories = new Set<ExpenseCategory>([
  "groceries",
  "restaurants",
  "transportation",
  "shopping",
  "entertainment",
  "utilities",
  "health",
  "subscriptions",
  "travel",
  "other"
]);

function toLiveCategory(category: ExpenseCategory): ExpenseCategory {
  return liveCategories.has(category) ? category : "other";
}

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
      category: toLiveCategory(input.category),
      description: input.description,
      merchant: input.merchant,
      source: input.source,
      raw_input: input.rawInput,
      confidence: input.confidence,
      idempotency_key: idempotencyKey ?? null
    })
    .select(expenseColumns)
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

export async function listExpensesForUser(userId: string, limit = 100): Promise<Expense[]> {
  const { data, error } = await supabaseAdmin
    .from("expenses")
    .select(expenseColumns)
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit)
    .returns<ExpenseRow[]>();

  if (error) {
    console.error("Supabase expense list failed", {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });

    throw new ApiError(503, "upstream_failure", "Could not load expenses right now.");
  }

  return data.map(mapExpenseRow);
}

export async function updateExpenseForUser(
  userId: string,
  id: string,
  patch: UpdateExpenseInput
): Promise<Expense> {
  const row: Record<string, unknown> = {};
  if (patch.amount !== undefined) row.amount = patch.amount;
  if (patch.currency !== undefined) row.currency = patch.currency;
  if (patch.category !== undefined) row.category = toLiveCategory(patch.category);
  if (patch.description !== undefined) row.description = patch.description;
  if (patch.merchant !== undefined) row.merchant = patch.merchant;

  const { data, error } = await supabaseAdmin
    .from("expenses")
    .update(row)
    .eq("id", id)
    .eq("user_id", userId)
    .select(expenseColumns)
    .single<ExpenseRow>();

  if (error) {
    if (error.code === "PGRST116") {
      throw new ApiError(404, "not_found", "Expense not found.");
    }

    console.error("Supabase expense update failed", {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });

    throw new ApiError(503, "upstream_failure", "Could not update the expense right now.");
  }

  return mapExpenseRow(data);
}

export async function deleteExpenseForUser(userId: string, id: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("expenses")
    .delete()
    .eq("id", id)
    .eq("user_id", userId)
    .select("id")
    .single<{ id: string }>();

  if (error) {
    if (error.code === "PGRST116") {
      throw new ApiError(404, "not_found", "Expense not found.");
    }

    console.error("Supabase expense delete failed", {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });

    throw new ApiError(503, "upstream_failure", "Could not delete the expense right now.");
  }
}

function mapExpenseRow(row: ExpenseRow): Expense {
  return {
    id: row.id,
    // The live schema has no `kind` column yet — see the note above
    // `liveCategories`. Rows read back from the database can't say whether
    // they were income, so this defaults to "expense" the same way the iOS
    // client already does when the field is missing.
    kind: "expense",
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
