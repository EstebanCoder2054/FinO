import { Router } from "express";
import { ApiError } from "./errors.js";
import { requireAuth } from "../auth/authContext.js";
import { validateCreateExpenseRequest } from "../validation/expenseRequest.js";

export const expensesRouter = Router();

expensesRouter.post("/api/expenses", requireAuth, (req, res, next) => {
  try {
    validateCreateExpenseRequest(req.body);
    throw new ApiError(501, "internal_error", "Expense creation is not implemented yet.");
  } catch (error) {
    next(error);
  }
});
