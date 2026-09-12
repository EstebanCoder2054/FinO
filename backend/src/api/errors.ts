import type { Response } from "express";
import { ZodError } from "zod";

export type ApiErrorCode =
  | "bad_request"
  | "unauthorized"
  | "forbidden"
  | "not_found"
  | "conflict"
  | "rate_limited"
  | "needs_clarification"
  | "upstream_failure"
  | "internal_error";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: ApiErrorCode,
    message: string
  ) {
    super(message);
  }
}

export function sendError(res: Response, error: unknown): void {
  if (error instanceof ApiError) {
    res.status(error.status).json({ success: false, code: error.code, message: error.message });
    return;
  }

  if (error instanceof ZodError) {
    res.status(400).json({
      success: false,
      code: "bad_request",
      message: error.issues[0]?.message ?? "Invalid request."
    });
    return;
  }

  res.status(500).json({
    success: false,
    code: "internal_error",
    message: "Unexpected server error."
  });
}
