-- GastaDoor initial schema.
-- Money is stored as integer cents (bigint) to avoid floating point errors.
-- Every table has Row Level Security: a user can only see and change their own rows.

create extension if not exists "pgcrypto";

-- Keeps updated_at current on every update.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- accounts: where money lives (cash, bank, card, e-wallet like GCash/Maya)
-- ---------------------------------------------------------------------------
create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  type text not null default 'cash'
    check (type in ('cash', 'bank', 'credit_card', 'e_wallet', 'other')),
  currency char(3) not null default 'PHP',
  opening_balance_cents bigint not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Lets child tables check that referenced rows belong to the same user.
  unique (id, user_id)
);

-- ---------------------------------------------------------------------------
-- categories: what money is spent on / comes from
-- ---------------------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  kind text not null check (kind in ('expense', 'income')),
  icon text,
  color text,
  parent_id uuid,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, kind, name),
  foreign key (parent_id, user_id) references public.categories (id, user_id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- transactions: individual expenses and income
-- ---------------------------------------------------------------------------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  account_id uuid not null,
  category_id uuid,
  kind text not null check (kind in ('expense', 'income')),
  amount_cents bigint not null check (amount_cents > 0),
  occurred_on date not null default current_date,
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Composite keys stop a user from pointing at someone else's account/category.
  foreign key (account_id, user_id) references public.accounts (id, user_id) on delete cascade,
  foreign key (category_id, user_id) references public.categories (id, user_id) on delete set null (category_id)
);

create index transactions_user_date_idx on public.transactions (user_id, occurred_on desc);
create index transactions_category_idx on public.transactions (category_id);
create index transactions_account_idx on public.transactions (account_id);

-- ---------------------------------------------------------------------------
-- budgets: spending limits per period, overall (category_id null) or per category
-- ---------------------------------------------------------------------------
create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id uuid,
  name text not null check (char_length(name) between 1 and 80),
  period text not null default 'monthly' check (period in ('weekly', 'monthly', 'yearly')),
  amount_cents bigint not null check (amount_cents > 0),
  starts_on date not null default date_trunc('month', current_date)::date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (category_id, user_id) references public.categories (id, user_id) on delete cascade
);

create index budgets_user_idx on public.budgets (user_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create trigger accounts_set_updated_at before update on public.accounts
  for each row execute function public.set_updated_at();
create trigger categories_set_updated_at before update on public.categories
  for each row execute function public.set_updated_at();
create trigger transactions_set_updated_at before update on public.transactions
  for each row execute function public.set_updated_at();
create trigger budgets_set_updated_at before update on public.budgets
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;

-- (select auth.uid()) is evaluated once per query instead of once per row.
create policy "Users manage their own accounts" on public.accounts
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users manage their own categories" on public.categories
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users manage their own transactions" on public.transactions
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users manage their own budgets" on public.budgets
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
