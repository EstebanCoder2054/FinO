# FinoAI Finance Agent

Native iOS hackathon MVP for recording personal expenses through a system-level iPhone experience powered by an OpenAI-backed backend agent.

## Core Flow

```text
iOS Control / native app
  -> voice or text expense
  -> POST /api/expenses
  -> authenticated backend
  -> OpenAI expense agent
  -> categorize_expense
  -> save_expense
  -> Supabase PostgreSQL
  -> native confirmation and history
```

## Repository Layout

```text
backend/   TypeScript API, auth, agent, tools, validation, Supabase access
ios/       Native SwiftUI app and WidgetKit/App Intents system experience
supabase/  Database migrations and demo seed data
docs/      Architecture, API, database, team specs, and decisions
```

## Current Status

This repo is bootstrapped for collaborative GitHub development. It includes:

- shared architecture and team ownership docs
- API and database contracts
- Supabase initial migration and demo seed
- TypeScript backend foundation with health endpoint, validation, domain types, and tests
- native iOS 18+ project with a WidgetKit Control, shared App Intent, and voice-capture foundation

The authenticated expense endpoint, OpenAI agent, and persistence remain the next backend steps, following the implementation order in `AGENTS.md`.

## Backend Setup

```bash
cd backend
npm install
npm run dev
```

For backend type checking:

```bash
cd backend
npm run typecheck
```

Copy `.env.example` to `.env` at the repo root or backend runtime environment and fill in the real values.

Required backend secrets:

- `OPENAI_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`

Never commit real secret values.

## Supabase Setup

Apply migrations in `supabase/migrations/` using the Supabase CLI or dashboard SQL editor for local/demo environments.

```bash
supabase db reset
```

Seed data in `supabase/seed.sql` is fake demo data only.

## GitHub Collaboration

The folder already contains Git metadata. If starting fresh elsewhere:

```bash
git init
git add .
git commit -m "chore: bootstrap finance agent monorepo"
```

Suggested branches:

- `develop`
- `feature/backend-agent`
- `feature/ios-control`
- `feature/ios-dashboard`

Before merging, run relevant tests, verify no secrets are present, and update docs for contract changes.
