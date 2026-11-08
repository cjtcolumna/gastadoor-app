-- Subscriptions: charges that repeat, like Spotify every month or a domain
-- name every year.
--
-- A subscription is a SCHEDULE, not money. Every time one is due, a nightly
-- job (see the next migration) adds a normal expense to `transactions`. That is
-- why History, budgets, insights and account balances include subscriptions
-- without any extra work.
--
-- Dates are worked out in the Philippines time zone (Asia/Manila), because
-- the database clock is in UTC and "today" would otherwise be wrong for 8
-- hours every day. The Philippines has no daylight saving, so this is safe.

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  amount_cents bigint not null check (amount_cents > 0),
  frequency text not null default 'monthly' check (frequency in ('monthly', 'yearly')),
  -- The date the schedule is counted from: the "Next charge" date picked in
  -- the form. (It is not the day you first signed up. It is the day the
  -- schedule starts counting from.) Monthly = same day every month, yearly =
  -- same day and month every year.
  first_charge_on date not null,
  -- When the next expense will be added. A trigger below keeps it right, so
  -- the app never has to send it.
  next_charge_on date not null,
  -- Which account pays for it, and what kind of spending it is.
  account_id uuid not null,
  category_id uuid,
  -- False = paused: no charges are added until you resume.
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Lets `transactions` check that a charge belongs to the same user.
  unique (id, user_id),
  foreign key (account_id, user_id) references public.accounts (id, user_id)
    on delete cascade,
  foreign key (category_id, user_id) references public.categories (id, user_id)
    on delete set null (category_id)
);

create index subscriptions_user_idx on public.subscriptions (user_id);
create index subscriptions_account_idx on public.subscriptions (account_id);
create index subscriptions_category_idx on public.subscriptions (category_id);
-- The nightly job only looks at active subscriptions that are due.
create index subscriptions_due_idx on public.subscriptions (next_charge_on)
  where active;

create trigger subscriptions_set_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Date helpers. All the schedule maths lives here, in one place.
-- ---------------------------------------------------------------------------

-- The date of charge number `n` (0 is the first), counted from `anchor`
-- (the subscription's first_charge_on).
-- Postgres moves a date that does not exist to the end of the month:
--   Jan 31 + 1 month = Feb 28,   Feb 29 2024 + 1 year = Feb 28 2025.
-- It always counts from `anchor`, never from the previous charge, so a charge
-- that landed on Feb 28 goes back to Mar 31 (not Mar 28).
create or replace function public.subscription_charge_date(
  anchor date,
  freq text,
  n int
)
returns date
language sql
immutable
set search_path = ''
as $$
  select (
    anchor + case
      when freq = 'yearly' then make_interval(years => n)
      else make_interval(months => n)
    end
  )::date;
$$;

-- The first charge date that is `from_day` or later.
create or replace function public.subscription_next_on_or_after(
  anchor date,
  freq text,
  from_day date
)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := 0;
  d date := anchor;
begin
  while d < from_day loop
    n := n + 1;
    d := public.subscription_charge_date(anchor, freq, n);
  end loop;
  return d;
end;
$$;

-- ---------------------------------------------------------------------------
-- Keeps next_charge_on right. It is worked out again when:
--   - the subscription is created,
--   - you change the "Next charge" date or monthly/yearly,
--   - you resume a paused subscription (so the months it was paused do not
--     all get charged at once).
-- ---------------------------------------------------------------------------
create or replace function public.subscriptions_set_next_charge()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  local_today date := (now() at time zone 'Asia/Manila')::date;
  recalculate boolean;
begin
  if tg_op = 'INSERT' then
    recalculate := true;
  else
    recalculate :=
      new.first_charge_on is distinct from old.first_charge_on
      or new.frequency is distinct from old.frequency
      or (new.active and not old.active);
  end if;

  if recalculate then
    new.next_charge_on := public.subscription_next_on_or_after(
      new.first_charge_on, new.frequency, local_today
    );
  end if;
  return new;
end;
$$;

create trigger subscriptions_next_charge
  before insert or update on public.subscriptions
  for each row execute function public.subscriptions_set_next_charge();

-- ---------------------------------------------------------------------------
-- Row Level Security: you only see and change your own subscriptions
-- ---------------------------------------------------------------------------
alter table public.subscriptions enable row level security;

create policy "Users manage their own subscriptions" on public.subscriptions
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Link each charge back to the subscription that made it.
-- Deleting a subscription keeps its past charges: they were real spending.
-- ---------------------------------------------------------------------------
alter table public.transactions add column subscription_id uuid;

alter table public.transactions
  add constraint transactions_subscription_id_user_id_fkey
  foreign key (subscription_id, user_id)
  references public.subscriptions (id, user_id)
  on delete set null (subscription_id);

-- One charge per subscription per day. The nightly job is built so this never
-- happens; the index is the safety net that stops a double charge if it did.
create unique index transactions_subscription_day_key
  on public.transactions (subscription_id, occurred_on)
  where subscription_id is not null;
