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
  "other"
] as const;

export type ExpenseCategory = (typeof expenseCategories)[number];

export const supportedCurrencies = ["COP", "USD", "EUR"] as const;

export type SupportedCurrency = (typeof supportedCurrencies)[number];

export const expenseSources = ["ios_voice", "ios_text", "ios_control"] as const;

export type ExpenseSource = (typeof expenseSources)[number];

export type Expense = {
  id: string;
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
  amount: string;
  currency: SupportedCurrency;
  category: ExpenseCategory;
  description: string;
  merchant: string | null;
  source: ExpenseSource;
  rawInput: string;
  confidence: number | null;
};
