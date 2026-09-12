import type { NextFunction, Request, Response } from "express";
import { randomUUID } from "node:crypto";

declare global {
  namespace Express {
    interface Request {
      requestId: string;
    }
  }
}

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const incomingRequestId = req.header("x-request-id");
  req.requestId = incomingRequestId && incomingRequestId.length <= 100 ? incomingRequestId : randomUUID();
  res.setHeader("x-request-id", req.requestId);
  next();
}
