# Team Model

The repository is owned by three engineers working in one monorepo.

## PERSON 1

Backend, OpenAI agent, API contract, Supabase schema, migrations, tools, backend tests.

## PERSON 2

iOS system-level entry point, WidgetKit Control, App Intents, Speech framework, voice capture flow.

## PERSON 3

Native iOS app shell, auth UI, home screen, expense history, confirmations, integration QA, demo flow.

## Coordination Rules

- API contract changes start in `docs/API.md`.
- Database changes require a migration.
- Category changes must be reflected across docs, backend types, tests, database enum, and iOS models.
- No one commits secrets.
