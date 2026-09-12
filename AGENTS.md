# AI Finance Agent Repository Instructions

This repository is a native iOS and TypeScript backend monorepo for an AI-powered expense capture MVP.

## Product Boundary

The core demo is:

```text
iPhone system surface -> voice -> natural language -> backend -> OpenAI agent -> tools -> Supabase -> native iOS confirmation
```

Do not turn this into a web dashboard, generic chatbot, banking integration, LangChain demo, or MCP runtime.

## Architecture

Primary areas:

- `ios/`: native Swift, SwiftUI, WidgetKit, App Intents, Speech framework.
- `backend/`: TypeScript API, auth verification, validation, OpenAI agent, tools, Supabase access.
- `supabase/`: SQL migrations, seed data, database documentation.
- `docs/`: API, architecture, team ownership, database, and decisions.

## Security Rules

- iOS must not access application data tables directly.
- iOS must not contain the Supabase service-role key, database passwords, OpenAI keys, or backend secrets.
- The backend must derive `user_id` from a verified bearer token.
- Never trust a `user_id` provided by the client or model.
- Do not expose stack traces, SQL details, secrets, internal prompts, or tool traces to the client.

## Implementation Order

1. Bootstrap repository and team specs.
2. Define contracts, domain model, auth expectations, database schema, and error model.
3. Build Supabase migration and seed.
4. Build backend foundation: health, auth middleware, validation, Supabase client, logging, errors.
5. Implement API without AI.
6. Add OpenAI integration and tools.
7. Validate full backend vertical slice.
8. Build iOS foundation and system experience in parallel using documented contracts.

## Team Ownership

- PERSON 1 owns `backend/`, `supabase/`, and `docs/API.md`.
- PERSON 2 owns `ios/FinanceAgentWidget/` and `ios/FinanceAgent/Features/Voice/`.
- PERSON 3 owns native app product UI, auth integration, QA, and demo flow in `ios/FinanceAgent/`.

Coordinate before changing another person's owned API, schema, or shared model contract.
