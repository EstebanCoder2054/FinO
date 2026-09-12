import dotenv from "dotenv";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const envPaths = [resolve(process.cwd(), ".env"), resolve(process.cwd(), "../.env")];

for (const envPath of envPaths) {
  if (existsSync(envPath)) {
    dotenv.config({ path: envPath });
  }
}

export function getRequiredEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export function getOptionalEnv(name: string, fallback: string): string {
  return process.env[name] || fallback;
}
