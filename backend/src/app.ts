import { Context, Hono } from "hono";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";
import { randomUUID } from "node:crypto";
import { ApiError, toErrorResponse } from "./api/errors.js";
import { getOptionalEnv, getRequiredEnv } from "./config/env.js";
import {
  deleteExpenseForUser,
  listExpensesForUser,
  saveExpenseForUser,
  updateExpenseForUser
} from "./services/expenseRepository.js";
import { processExpenseInput } from "./services/expenseProcessor.js";
import {
  validateCreateExpenseRequest,
  validateExpenseId,
  validateUpdateExpenseRequest
} from "./validation/expenseRequest.js";

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

  const statusResponse = {
    success: true,
    service: "FinoAI backend",
    status: "ok"
  };

  app.get("/", (c) => {
    return c.json(statusResponse);
  });

  app.get("/api", (c) => {
    return c.json(statusResponse);
  });

  app.get("/api/index", (c) => {
    return c.json({
      success: true,
      service: "FinoAI backend",
      status: "ok",
      routedBy: "vercel-function"
    });
  });

  const healthResponse = {
    success: true,
    status: "ok"
  };

  app.get("/health", (c) => {
    return c.json(healthResponse);
  });

  app.get("/api/health", (c) => {
    return c.json(healthResponse);
  });

  app.get("/api/index/health", (c) => {
    return c.json({
      ...healthResponse,
      routedBy: "vercel-function"
    });
  });

  app.get("/debug/runtime", async (c) => {
    return c.json(getRuntimeDiagnostics());
  });

  app.get("/api/debug/runtime", async (c) => {
    return c.json(getRuntimeDiagnostics());
  });

  app.get("/api/index/debug/runtime", async (c) => {
    return c.json(getRuntimeDiagnostics());
  });

  app.get("/expenses", async (c) => {
    return listExpenses(c);
  });

  app.get("/api/expenses", async (c) => {
    return listExpenses(c);
  });

  app.get("/api/index/expenses", async (c) => {
    return listExpenses(c);
  });

  app.post("/expenses", async (c) => {
    return createExpense(c);
  });

  app.post("/api/expenses", async (c) => {
    return createExpense(c);
  });

  app.post("/api/index/expenses", async (c) => {
    return createExpense(c);
  });

  app.patch("/expenses/:id", async (c) => {
    return updateExpense(c);
  });

  app.patch("/api/expenses/:id", async (c) => {
    return updateExpense(c);
  });

  app.patch("/api/index/expenses/:id", async (c) => {
    return updateExpense(c);
  });

  app.delete("/expenses/:id", async (c) => {
    return deleteExpense(c);
  });

  app.delete("/api/expenses/:id", async (c) => {
    return deleteExpense(c);
  });

  app.delete("/api/index/expenses/:id", async (c) => {
    return deleteExpense(c);
  });

  app.onError((error, c) => {
    const response = toErrorResponse(error);
    return c.json(response.body, response.status);
  });

  return app;
}

async function listExpenses(c: Context<AppBindings>) {
  const userId = resolveUserId();
  const expenses = await listExpensesForUser(userId);

  return c.json({
    success: true,
    expenses: expenses.map((expense) => ({
      id: expense.id,
      amount: expense.amount,
      currency: expense.currency,
      category: expense.category,
      description: expense.description,
      merchant: expense.merchant,
      source: expense.source,
      createdAt: expense.createdAt
    }))
  });
}

async function createExpense(c: Context<AppBindings>) {
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
}

async function updateExpense(c: Context<AppBindings>) {
  const userId = resolveUserId();
  const id = validateExpenseId(c.req.param("id") ?? "");
  const patch = validateUpdateExpenseRequest(await c.req.json());
  const expense = await updateExpenseForUser(userId, id, patch);

  return c.json({
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
}

async function deleteExpense(c: Context<AppBindings>) {
  const userId = resolveUserId();
  const id = validateExpenseId(c.req.param("id") ?? "");
  await deleteExpenseForUser(userId, id);

  return c.json({ success: true, id });
}

function resolveUserId(): string {
  if (getOptionalEnv("AUTH_MODE", "required") === "disabled") {
    return getRequiredEnv("DEV_USER_ID");
  }

  throw new ApiError(401, "unauthorized", "Authentication is required.");
}

function decodeJwtPayload(token: string | undefined): Record<string, unknown> | null {
  if (!token) {
    return null;
  }

  try {
    const payload = token.split(".")[1];
    if (!payload) {
      return null;
    }

    return JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function maskValue(value: string | undefined): string | null {
  if (!value) {
    return null;
  }

  if (value.length <= 8) {
    return "***";
  }

  return `${value.slice(0, 4)}...${value.slice(-4)}`;
}

function getRuntimeDiagnostics() {
  const serviceRolePayload = decodeJwtPayload(process.env.SUPABASE_SERVICE_ROLE_KEY);

  return {
    success: true,
    env: {
      nodeEnv: process.env.NODE_ENV ?? null,
      authMode: process.env.AUTH_MODE ?? null,
      hasDevUserId: Boolean(process.env.DEV_USER_ID),
      devUserId: maskValue(process.env.DEV_USER_ID),
      hasOpenAIKey: Boolean(process.env.OPENAI_API_KEY),
      openAIModel: process.env.OPENAI_MODEL ?? null,
      hasSupabaseUrl: Boolean(process.env.SUPABASE_URL),
      supabaseUrlHost: process.env.SUPABASE_URL ? new URL(process.env.SUPABASE_URL).host : null,
      hasSupabaseServiceRoleKey: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
      supabaseServiceRoleRole: serviceRolePayload?.role ?? null,
      supabaseServiceRoleRef: serviceRolePayload?.ref ?? null,
      supabaseServiceRoleIssuer: serviceRolePayload?.iss ?? null,
      hasGladiaKey: Boolean(process.env.GLADIA_API_KEY)
    }
  };
}
