# 0001 Backend Runtime

## Decision

Use a small TypeScript HTTP API for the backend.

## Reasoning

The MVP needs API validation, auth verification, OpenAI agent orchestration, tool execution, and Supabase access. A standalone TypeScript service keeps those responsibilities clear without introducing a web frontend framework.

## Consequences

- No Next.js dashboard.
- Native iOS remains the product UI.
- Backend can be deployed to a Node-compatible platform.
