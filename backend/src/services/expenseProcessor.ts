import { runExpenseAgent, type ExpenseAgentResult } from "../agent/expenseAgent.js";
import { parseExpenseInput } from "./expenseParser.js";

export async function processExpenseInput(input: string): Promise<ExpenseAgentResult> {
  if (!process.env.OPENAI_API_KEY) {
    console.warn("OpenAI expense agent skipped; OPENAI_API_KEY is missing.");
    return parseExpenseInput(input);
  }

  try {
    return await runExpenseAgent(input);
  } catch (error) {
    console.warn("OpenAI expense agent failed; falling back to deterministic parser.", serializeAgentError(error));
    return parseExpenseInput(input);
  }
}

function serializeAgentError(error: unknown): Record<string, unknown> {
  if (!error || typeof error !== "object") {
    return {
      type: typeof error,
      message: String(error)
    };
  }

  const record = error as Record<string, unknown>;

  return {
    name: error instanceof Error ? error.name : record.name,
    message: error instanceof Error ? error.message : record.message,
    status: record.status,
    code: record.code,
    type: record.type,
    requestId: record.request_id ?? record.requestID,
    param: record.param,
    cause: serializeCause(record.cause)
  };
}

function serializeCause(cause: unknown): Record<string, unknown> | undefined {
  if (!cause || typeof cause !== "object") {
    return undefined;
  }

  const record = cause as Record<string, unknown>;

  return {
    name: cause instanceof Error ? cause.name : record.name,
    message: cause instanceof Error ? cause.message : record.message,
    code: record.code
  };
}
