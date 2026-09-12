# PERSON 1 - Backend / Agent / API / Supabase

## Responsibility

Own the backend vertical slice: API, auth verification, OpenAI agent, tools, Supabase migrations, persistence, and backend tests.

## Primary Files

- `backend/`
- `supabase/`
- `docs/API.md`
- `docs/DATABASE.md`

## Dependencies

- Supabase project credentials
- OpenAI API key
- Confirmed iOS API needs from PERSON 2 and PERSON 3

## Tasks

1. Initialize and maintain backend runtime.
2. Implement Supabase auth token verification.
3. Apply and validate database migrations.
4. Implement `POST /api/expenses`.
5. Add `categorize_expense`.
6. Add `save_expense`.
7. Add OpenAI agent integration using the current official SDK/API.
8. Add request IDs, error handling, and useful safe logs.
9. Write backend unit and API tests.
10. Keep `docs/API.md` current.

## Acceptance Criteria

An authenticated request:

```text
Me gasté un millón de pesos en el mercado.
```

persists a `1000000 COP` `groceries` expense for the authenticated user and returns a safe confirmation response.

## Integration Points

- PERSON 2 consumes the endpoint from voice/control flows.
- PERSON 3 consumes the endpoint from native app screens and auth/session flows.

## Do Not Modify Without Coordination

- iOS user-facing flows
- category contract
- API response shape
- database fields used by iOS
