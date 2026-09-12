import { describe, expect, it } from "vitest";
import { categorizeExpense } from "../src/tools/categorizeExpense.js";

describe("categorizeExpense", () => {
  it("categorizes mercado as groceries", () => {
    expect(categorizeExpense({ description: "mercado", merchant: null, amount: "1000000" }).category).toBe("groceries");
  });

  it("categorizes Uber as transportation", () => {
    expect(categorizeExpense({ description: "Uber", merchant: "Uber", amount: "45000" }).category).toBe("transportation");
  });

  it("falls back to other", () => {
    expect(categorizeExpense({ description: "algo raro", merchant: null, amount: "10000" }).category).toBe("other");
  });
});
