import { Hono } from "hono";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";
import { randomUUID } from "node:crypto";
import { ApiError, toErrorResponse } from "./api/errors.js";
import { getOptionalEnv, getRequiredEnv } from "./config/env.js";
import { saveExpenseForUser } from "./services/expenseRepository.js";
import { processExpenseInput } from "./services/expenseProcessor.js";
import { validateCreateExpenseRequest } from "./validation/expenseRequest.js";

type AppBindings = {
  Variables: {
    requestId: string;
    userId: string;
  };
};

export function createApp() {
  const app = new Hono<AppBindings>();

  app.use("*", secureHeaders());
  app.use("*", cors());
  app.use("*", async (c, next) => {
    const incomingRequestId = c.req.header("x-request-id");
    const requestId = incomingRequestId && incomingRequestId.length <= 100 ? incomingRequestId : randomUUID();
    c.set("requestId", requestId);
    c.header("x-request-id", requestId);
    await next();
  });

  app.get("/", (c) => {
    return c.json({
      success: true,
      service: "FinoAI backend",
      status: "ok"
    });
  });

  app.get("/health", (c) => {
    return c.json({
      success: true,
      status: "ok"
    });
  });

  app.post("/api/expenses", async (c) => {
    const userId = resolveUserId();
    const body = validateCreateExpenseRequest(await c.req.json());
    const parsed = await processExpenseInput(body.input);

    if (parsed.status === "needs_clarification") {
      return c.json(
        {
          success: false,
          code: "needs_clarification",
          message: parsed.message
        },
        400
      );
    }

    const expense = await saveExpenseForUser(userId, parsed.expense, c.req.header("idempotency-key"));

    return c.json(
      {
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
      },
      201
    );
  });

  app.onError((error, c) => {
    const response = toErrorResponse(error);
    return c.json(response.body, response.status);
  });

  return app;
}

function resolveUserId(): string {
  if (getOptionalEnv("AUTH_MODE", "required") === "disabled") {
    return getRequiredEnv("DEV_USER_ID");
  }

  throw new ApiError(401, "unauthorized", "Authentication is required.");
}
