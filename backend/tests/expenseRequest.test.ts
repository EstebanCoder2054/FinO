import { describe, expect, it } from "vitest";
import { validateCreateExpenseRequest } from "../src/validation/expenseRequest.js";

describe("validateCreateExpenseRequest", () => {
  it("accepts a valid natural language input", () => {
    expect(validateCreateExpenseRequest({ input: "Me gasté un millón de pesos en el mercado." })).toEqual({
      input: "Me gasté un millón de pesos en el mercado."
    });
  });

  it("trims input", () => {
    expect(validateCreateExpenseRequest({ input: "  Gasté 45 mil en Uber.  " })).toEqual({
      input: "Gasté 45 mil en Uber."
    });
  });

  it("rejects empty input", () => {
    expect(() => validateCreateExpenseRequest({ input: "   " })).toThrow();
  });

  it("rejects input over 500 characters", () => {
    expect(() => validateCreateExpenseRequest({ input: "x".repeat(501) })).toThrow();
  });
});
