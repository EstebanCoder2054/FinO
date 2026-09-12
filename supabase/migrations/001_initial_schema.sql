create extension if not exists "pgcrypto";

create type public.expense_category as enum (
  'groceries',
  'restaurants',
  'transportation',
  'shopping',
  'entertainment',
  'utilities',
  'health',
  'subscriptions',
  'travel',
  'other'
);

create type public.expense_source as enum (
  'ios_voice',
  'ios_text',
  'ios_control',
  'seed'
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  currency text not null check (currency in ('COP', 'USD', 'EUR')),
  category public.expense_category not null,
  description text not null check (char_length(description) between 1 and 200),
  merchant text null check (merchant is null or char_length(merchant) <= 120),
  source public.expense_source not null,
  raw_input text not null check (char_length(raw_input) between 1 and 500),
  confidence numeric(4,3) null check (confidence is null or (confidence >= 0 and confidence <= 1)),
  idempotency_key text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create index expenses_user_created_at_idx on public.expenses (user_id, created_at desc);
create index expenses_user_category_idx on public.expenses (user_id, category);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger expenses_set_updated_at
before update on public.expenses
for each row
execute function public.set_updated_at();

alter table public.expenses enable row level security;

create policy "Users can read own expenses"
on public.expenses
for select
using (auth.uid() = user_id);

create policy "Users can insert own expenses"
on public.expenses
for insert
with check (auth.uid() = user_id);

create policy "Users can update own expenses"
on public.expenses
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own expenses"
on public.expenses
for delete
using (auth.uid() = user_id);
