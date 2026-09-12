import { z } from "zod";
import { expenseCategories, supportedCurrencies } from "../types/expense.js";

export const maxExpenseInputLength = 500;

export const createExpenseRequestSchema = z.object({
  input: z
    .string({
      required_error: "input is required",
      invalid_type_error: "input must be a string"
    })
    .trim()
    .min(1, "input cannot be empty")
    .max(maxExpenseInputLength, `input must be ${maxExpenseInputLength} characters or fewer`)
});

export type CreateExpenseRequest = z.infer<typeof createExpenseRequestSchema>;

export function validateCreateExpenseRequest(body: unknown): CreateExpenseRequest {
  return createExpenseRequestSchema.parse(body);
}

export const expenseIdSchema = z.string().uuid("id must be a valid UUID");

export function validateExpenseId(id: string): string {
  return expenseIdSchema.parse(id);
}

export const updateExpenseRequestSchema = z
  .object({
    amount: z.coerce
      .number({ invalid_type_error: "amount must be a number" })
      .positive("amount must be greater than 0")
      .transform((value) => value.toString())
      .optional(),
    currency: z.enum(supportedCurrencies).optional(),
    category: z.enum(expenseCategories).optional(),
    description: z
      .string({ invalid_type_error: "description must be a string" })
      .trim()
      .min(1, "description cannot be empty")
      .max(200, "description must be 200 characters or fewer")
      .optional(),
    merchant: z
      .string()
      .trim()
      .max(120, "merchant must be 120 characters or fewer")
      .nullable()
      .optional()
  })
  .refine((body) => Object.keys(body).length > 0, {
    message: "at least one field must be provided"
  });

export type UpdateExpenseRequest = z.infer<typeof updateExpenseRequestSchema>;

export function validateUpdateExpenseRequest(body: unknown): UpdateExpenseRequest {
  return updateExpenseRequestSchema.parse(body);
}
