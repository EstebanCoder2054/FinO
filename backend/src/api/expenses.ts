import { Router } from "express";
import { requireAuth } from "../auth/authContext.js";
import { saveExpenseForUser } from "../services/expenseRepository.js";
import { processExpenseInput } from "../services/expenseProcessor.js";
import { validateCreateExpenseRequest } from "../validation/expenseRequest.js";

export const expensesRouter = Router();

expensesRouter.post("/api/expenses", requireAuth, async (req, res, next) => {
  try {
    const body = validateCreateExpenseRequest(req.body);
    const parsed = await processExpenseInput(body.input);

    if (parsed.status === "needs_clarification") {
      res.status(400).json({
        success: false,
        code: "needs_clarification",
        message: parsed.message
      });
      return;
    }

    const expense = await saveExpenseForUser(req.auth!.userId, parsed.expense, req.header("idempotency-key") ?? undefined);

    res.status(201).json({
      success: true,
      expense: {
        id: expense.id,
        amount: expense.amount,
        currency: expense.currency,
        category: expense.category,
        description: expense.description,
        merchant: expense.merchant,
        source: expense.source,
        createdAt: expense.createdAt
      }
    });
  } catch (error) {
    next(error);
  }
});
