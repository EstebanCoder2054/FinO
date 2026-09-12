export const expenseCategories = [
  "groceries",
  "restaurants",
  "transportation",
  "shopping",
  "entertainment",
  "utilities",
  "health",
  "subscriptions",
  "travel",
  "other",
  // Income-side categories (kind === "income")
  "salary",
  "loan",
  "gift",
  "refund",
  "other_income"
] as const;

export type ExpenseCategory = (typeof expenseCategories)[number];

export const expenseKinds = ["expense", "income"] as const;

export type ExpenseKind = (typeof expenseKinds)[number];

export const supportedCurrencies = ["COP", "USD", "EUR"] as const;

export type SupportedCurrency = (typeof supportedCurrencies)[number];

export const expenseSources = ["ios_voice", "ios_text", "ios_control"] as const;

export type ExpenseSource = (typeof expenseSources)[number];

export type Expense = {
  id: string;
  kind: ExpenseKind;
  amount: string;
  currency: SupportedCurrency;
  category: ExpenseCategory;
  description: string;
  merchant: string | null;
  source: ExpenseSource;
  rawInput: string;
  confidence: number | null;
  createdAt: string;
};

export type CreateExpenseInput = {
  kind: ExpenseKind;
  amount: string;
  currency: SupportedCurrency;
  category: ExpenseCategory;
  description: string;
  merchant: string | null;
  source: ExpenseSource;
  rawInput: string;
  confidence: number | null;
};

export type UpdateExpenseInput = {
  amount?: string;
  currency?: SupportedCurrency;
  category?: ExpenseCategory;
  description?: string;
  merchant?: string | null;
};
