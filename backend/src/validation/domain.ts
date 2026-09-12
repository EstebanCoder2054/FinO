import { z } from "zod";
import { expenseCategories, expenseSources, supportedCurrencies } from "../types/expense.js";

export const expenseCategorySchema = z.enum(expenseCategories);
export const supportedCurrencySchema = z.enum(supportedCurrencies);
export const expenseSourceSchema = z.enum(expenseSources);

export const confidenceSchema = z.number().min(0).max(1).nullable();

export const amountStringSchema = z
  .string()
  .regex(/^\d+(\.\d{1,2})?$/, "amount must be a positive decimal string")
  .refine((value) => Number(value) > 0, "amount must be greater than zero");
