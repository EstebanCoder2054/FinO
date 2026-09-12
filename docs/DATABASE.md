# Database

Supabase PostgreSQL is the application database.

## Application Tables

### expenses

Fields:

- `id uuid primary key`
- `user_id uuid not null`
- `amount numeric(14,2) not null`
- `currency text not null`
- `category expense_category not null`
- `description text not null`
- `merchant text null`
- `source expense_source not null`
- `raw_input text not null`
- `confidence numeric(4,3) null`
- `idempotency_key text null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

## Money Representation

Amounts use PostgreSQL `numeric(14,2)` instead of floating point to preserve exact money values.

## Security

RLS is enabled. Users can only read or mutate rows where `auth.uid() = user_id`. The backend also scopes every query by the authenticated user ID and does not rely on frontend filtering.

The backend uses the Supabase service role only on the server. iOS never receives this credential.
