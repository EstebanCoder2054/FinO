# Architecture

## System Boundary

The iOS app communicates with Supabase Auth for authentication and with the backend for application data. All expense persistence and reads go through the backend.

```text
iOS
  | authenticate
  v
Supabase Auth
  | access token
  v
iOS
  | Authorization: Bearer <token>
  v
Backend
  | service role, scoped by authenticated user
  v
Supabase PostgreSQL
```

## Runtime Components

- Native iOS app: SwiftUI screens, auth state, expense capture, expense history, totals.
- Widget extension: WidgetKit Control and App Intent entry point.
- Backend API: validation, auth verification, request IDs, error handling, OpenAI agent orchestration.
- Agent tools: `categorize_expense` and `save_expense`.
- Database: `expenses` table with RLS and user ownership constraints.

## Initial Backend Choice

The backend is a small TypeScript HTTP API. It is independent from UI and does not use Next.js, GraphQL, LangChain, LangGraph, or MCP runtime infrastructure.

## Currency Rule

The initial supported currencies are `COP`, `USD`, and `EUR`. For the hackathon demo, when currency is omitted after structured extraction and no user profile default exists, the backend may use `DEFAULT_CURRENCY`, defaulting to `COP`. Ambiguous amounts must not be invented.

## Idempotency

The first implementation should accept an optional `Idempotency-Key` header from iOS and persist or check it before creating an expense. Until implemented, clients should avoid automatic blind retries for `POST /api/expenses`.
