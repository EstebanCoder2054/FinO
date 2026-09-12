import type { NextFunction, Request, Response } from "express";
import { ApiError } from "../api/errors.js";
import { getOptionalEnv, getRequiredEnv } from "../config/env.js";
import { supabaseAdmin } from "../db/supabase.js";
import { getAuthenticatedUserId } from "./supabaseAuth.js";

declare global {
  namespace Express {
    interface Request {
      auth?: {
        userId: string;
      };
    }
  }
}

export async function requireAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  if (getOptionalEnv("AUTH_MODE", "required") === "disabled") {
    req.auth = {
      userId: getRequiredEnv("DEV_USER_ID")
    };
    next();
    return;
  }

  const authorization = req.header("authorization");

  if (!authorization?.startsWith("Bearer ")) {
    next(new ApiError(401, "unauthorized", "Authentication is required."));
    return;
  }

  try {
    const token = authorization.slice("Bearer ".length).trim();
    req.auth = {
      userId: await getAuthenticatedUserId(token, supabaseAdmin)
    };
    next();
  } catch (error) {
    next(error);
  }
}
