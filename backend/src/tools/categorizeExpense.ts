import type { ExpenseCategory } from "../types/expense.js";

type CategorizeExpenseInput = {
  description: string;
  merchant: string | null;
  amount: string;
};

type CategorizeExpenseResult = {
  category: ExpenseCategory;
  confidence: number;
};

const keywordCategoryMap: Array<{ keywords: string[]; category: ExpenseCategory }> = [
  { keywords: ["mercado", "supermercado", "super", "tienda", "comida para la casa"], category: "groceries" },
  { keywords: ["restaurante", "almuerzo", "cena", "cafe", "comida"], category: "restaurants" },
  { keywords: ["uber", "taxi", "bus", "metro", "gasolina", "transporte"], category: "transportation" },
  { keywords: ["camisa", "zapatos", "ropa", "compré", "compre"], category: "shopping" },
  { keywords: ["cine", "netflix", "juego", "concierto"], category: "entertainment" },
  { keywords: ["luz", "agua", "internet", "servicio"], category: "utilities" },
  { keywords: ["medicina", "doctor", "farmacia", "salud"], category: "health" },
  { keywords: ["suscripcion", "suscripción", "spotify", "icloud"], category: "subscriptions" },
  { keywords: ["hotel", "vuelo", "viaje"], category: "travel" }
];

export function categorizeExpense(input: CategorizeExpenseInput): CategorizeExpenseResult {
  const searchText = `${input.description} ${input.merchant ?? ""}`.toLowerCase();
  const match = keywordCategoryMap.find(({ keywords }) => keywords.some((keyword) => searchText.includes(keyword)));

  return {
    category: match?.category ?? "other",
    confidence: match ? 0.9 : 0.5
  };
}

type CategorizeIncomeInput = {
  description: string;
  merchant: string | null;
};

const incomeKeywordCategoryMap: Array<{ keywords: string[]; category: ExpenseCategory }> = [
  { keywords: ["sueldo", "salario", "n[oó]mina", "pago mensual", "me pagaron", "me pag[oó]"], category: "salary" },
  { keywords: ["pr[eé]stamo", "me prestaron"], category: "loan" },
  { keywords: ["regalo", "me regalaron"], category: "gift" },
  { keywords: ["reembolso", "devoluci[oó]n", "me devolvieron"], category: "refund" }
];

export function categorizeIncome(input: CategorizeIncomeInput): CategorizeExpenseResult {
  const searchText = `${input.description} ${input.merchant ?? ""}`.toLowerCase();
  const match = incomeKeywordCategoryMap.find(({ keywords }) =>
    keywords.some((keyword) => new RegExp(keyword).test(searchText))
  );

  return {
    category: match?.category ?? "other_income",
    confidence: match ? 0.9 : 0.5
  };
}
