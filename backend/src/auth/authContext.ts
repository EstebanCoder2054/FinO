import type { NextFunction, Request, Response } from "express";
import { ApiError } from "../api/errors.js";

declare global {
  namespace Express {
    interface Request {
      auth?: {
        userId: string;
      };
    }
  }
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const authorization = req.header("authorization");

  if (!authorization?.startsWith("Bearer ")) {
    next(new ApiError(401, "unauthorized", "Authentication is required."));
    return;
  }

  // Step 3 placeholder: verify Supabase JWT and derive user ID from token claims.
  next(new ApiError(501, "internal_error", "Authentication verification is not implemented yet."));
}
