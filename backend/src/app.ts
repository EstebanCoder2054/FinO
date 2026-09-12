import cors from "cors";
import express from "express";
import helmet from "helmet";
import { sendError } from "./api/errors.js";
import { expensesRouter } from "./api/expenses.js";
import { healthRouter } from "./api/health.js";
import { requestIdMiddleware } from "./api/requestId.js";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: "16kb" }));
  app.use(requestIdMiddleware);

  app.use(healthRouter);
  app.use(expensesRouter);

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    sendError(res, error);
  });

  return app;
}
