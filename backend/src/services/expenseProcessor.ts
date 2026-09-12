import { runExpenseAgent, type ExpenseAgentResult } from "../agent/expenseAgent.js";
import { parseExpenseInput } from "./expenseParser.js";

export async function processExpenseInput(input: string): Promise<ExpenseAgentResult> {
  if (!process.env.OPENAI_API_KEY) {
    return parseExpenseInput(input);
  }

  try {
    return await runExpenseAgent(input);
  } catch (error) {
    if (process.env.EXPENSE_AGENT_DEBUG === "true") {
      console.warn("OpenAI expense agent failed; falling back to deterministic parser.", {
        message: error instanceof Error ? error.message : "Unknown error"
      });
    }

    return parseExpenseInput(input);
  }
}
