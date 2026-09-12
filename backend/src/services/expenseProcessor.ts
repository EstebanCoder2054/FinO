import { runExpenseAgent, type ExpenseAgentResult } from "../agent/expenseAgent.js";
import { parseExpenseInput } from "./expenseParser.js";

export async function processExpenseInput(input: string): Promise<ExpenseAgentResult> {
  if (!process.env.OPENAI_API_KEY) {
    return parseExpenseInput(input);
  }

  try {
    return await runExpenseAgent(input);
  } catch (error) {
    console.warn("OpenAI expense agent failed; falling back to deterministic parser.");
    return parseExpenseInput(input);
  }
}
