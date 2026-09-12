import { describe, expect, it } from "vitest";
import { parseExpenseInput } from "../src/services/expenseParser.js";

describe("parseExpenseInput", () => {
  it("parses one million pesos in mercado", () => {
    const result = parseExpenseInput("Me gasté un millón de pesos en el mercado.");

    expect(result).toMatchObject({
      status: "ok",
      expense: {
        amount: "1000000",
        currency: "COP",
        category: "groceries",
        description: "mercado"
      }
    });
  });

  it("parses 45 mil in Uber", () => {
    const result = parseExpenseInput("Gasté 45 mil en Uber.");

    expect(result).toMatchObject({
      status: "ok",
      expense: {
        amount: "45000",
        currency: "COP",
        category: "transportation",
        merchant: "Uber"
      }
    });
  });

  it("does not invent missing amounts", () => {
    expect(parseExpenseInput("Me gasté mucho en comida.")).toEqual({
      status: "needs_clarification",
      message: "Necesito el monto exacto para guardar este gasto."
    });
  });
});
