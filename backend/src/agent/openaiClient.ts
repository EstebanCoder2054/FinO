import OpenAI from "openai";
import { getRequiredEnv } from "../config/env.js";

let client: OpenAI | null = null;

export function getOpenAIClient(): OpenAI {
  if (!client) {
    client = new OpenAI({
      apiKey: getRequiredEnv("OPENAI_API_KEY")
    });
  }

  return client;
}
