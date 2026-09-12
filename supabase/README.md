# Supabase

This directory contains reproducible database schema and demo data.

## Apply Locally

```bash
supabase db reset
```

or apply the files in `migrations/` in order.

## Security Boundary

iOS may use Supabase Auth for login/session management, but must not directly read or write application tables. Application data access goes through the backend.
