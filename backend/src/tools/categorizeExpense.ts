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
