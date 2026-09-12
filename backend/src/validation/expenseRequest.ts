import { z } from "zod";

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
