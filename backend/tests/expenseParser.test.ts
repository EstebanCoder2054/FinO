import { describe, expect, it } from "vitest";
import { extractDigitMagnitudeAmount, parseExpenseInput } from "../src/services/expenseParser.js";

describe("parseExpenseInput", () => {
  it("parses 200 mil pesos en el mercado", () => {
    const result = parseExpenseInput("Me gasté 200 mil pesos en el mercado.");

    expect(result).toMatchObject({
      status: "ok",
      expense: {
        amount: "200000",
        currency: "COP",
        category: "groceries",
        description: "mercado"
      }
    });
  });

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

  it("classifies 'me pagaron' as income with a salary category", () => {
    const result = parseExpenseInput("Me pagaron 200 mil pesos del trabajo.");

    expect(result).toMatchObject({
      status: "ok",
      expense: {
        kind: "income",
        amount: "200000",
        category: "salary"
      }
    });
  });

  it("classifies 'me prestaron' as income with a loan category", () => {
    const result = parseExpenseInput("Me prestaron 500 mil pesos.");

    expect(result).toMatchObject({
      status: "ok",
      expense: {
        kind: "income",
        amount: "500000",
        category: "loan"
      }
    });
  });

  it("keeps ordinary purchases classified as expenses", () => {
    const result = parseExpenseInput("Gasté 45 mil en Uber.");

    expect(result).toMatchObject({
      status: "ok",
      expense: { kind: "expense" }
    });
  });
});

describe("extractDigitMagnitudeAmount", () => {
  it("expands digit-led 'mil' amounts, guarding against the LLM agent dropping the magnitude", () => {
    expect(extractDigitMagnitudeAmount("Me gasté 200 mil pesos en el mercado.")).toBe("200000");
    expect(extractDigitMagnitudeAmount("2.5 millones en arriendo")).toBe("2500000");
  });

  it("returns null when there's no digit-led magnitude word to disambiguate", () => {
    expect(extractDigitMagnitudeAmount("Gasté cuarenta y cinco mil en Uber.")).toBeNull();
    expect(extractDigitMagnitudeAmount("Gasté 20000 en Uber.")).toBeNull();
  });
});
