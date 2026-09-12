import { ZodError } from "zod";

export type ApiStatusCode = 400 | 401 | 403 | 404 | 409 | 429 | 500 | 502 | 503;

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
    public readonly status: ApiStatusCode,
    public readonly code: ApiErrorCode,
    message: string
  ) {
    super(message);
  }
}

export function toErrorResponse(error: unknown): {
  status: ApiStatusCode;
  body: {
    success: false;
    code: ApiErrorCode;
    message: string;
  };
} {
  if (error instanceof ApiError) {
    return {
      status: error.status,
      body: { success: false, code: error.code, message: error.message }
    };
  }

  if (error instanceof ZodError) {
    return {
      status: 400,
      body: {
        success: false,
        code: "bad_request",
        message: error.issues[0]?.message ?? "Invalid request."
      }
    };
  }

  return {
    status: 500,
    body: {
      success: false,
      code: "internal_error",
      message: "Unexpected server error."
    }
  };
}
