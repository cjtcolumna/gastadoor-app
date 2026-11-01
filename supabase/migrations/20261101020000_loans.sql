-- Lending: money you lent to someone, and the repayments you get back.
--
-- A loan is NOT spending and a repayment is NOT income, so neither is a row in
-- `transactions`. They live in their own tables.
--
-- Each loan and each repayment can name an account (`account_id`):
--   - a loan with an account: the money leaves that account.
--   - a repayment with an account: the money goes into that account.
--   - no account (null): the account balance is left alone. Use this for a
--     loan you made before you started tracking, when the starting balance
--     already left it out.

-- ---------------------------------------------------------------------------
-- loans
-- ---------------------------------------------------------------------------
create table public.loans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Only 'lent' for now. Borrowing can be added later by widening this check.
  direction text not null default 'lent' check (direction in ('lent')),
  person text not null check (char_length(person) between 1 and 80),
  amount_cents bigint not null check (amount_cents > 0),
  lent_on date not null default current_date,
  due_on date,
  note text check (char_length(note) <= 500),
  -- Where the money came from. Null = don't change any account.
  account_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint loans_due_after_lent check (due_on is null or due_on >= lent_on),
  -- Lets loan_payments check that a payment belongs to the same user.
  unique (id, user_id),
  foreign key (account_id, user_id) references public.accounts (id, user_id)
    on delete set null (account_id)
);

create index loans_user_idx on public.loans (user_id);
create index loans_account_idx on public.loans (account_id);

-- ---------------------------------------------------------------------------
-- loan_payments: money paid back toward a loan
-- ---------------------------------------------------------------------------
create table public.loan_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  loan_id uuid not null,
  amount_cents bigint not null check (amount_cents > 0),
  paid_on date not null default current_date,
  note text check (char_length(note) <= 500),
  -- Where the money went. Null = don't change any account.
  account_id uuid,
  created_at timestamptz not null default now(),
  foreign key (loan_id, user_id) references public.loans (id, user_id)
    on delete cascade,
  foreign key (account_id, user_id) references public.accounts (id, user_id)
    on delete set null (account_id)
);

create index loan_payments_loan_idx on public.loan_payments (loan_id);
create index loan_payments_account_idx on public.loan_payments (account_id);

-- Nobody can pay back more than they borrowed. (The app checks this too, but
-- the database is the last line of defence.)
create or replace function public.check_loan_not_overpaid()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  loan_total bigint;
  paid_total bigint;
begin
  select amount_cents into loan_total
  from public.loans where id = new.loan_id;

  select coalesce(sum(amount_cents), 0) into paid_total
  from public.loan_payments
  where loan_id = new.loan_id and id <> new.id;

  if paid_total + new.amount_cents > loan_total then
    raise exception 'That is more than what is still owed on this loan.';
  end if;
  return new;
end;
$$;

create trigger loan_payments_check_total
  before insert or update on public.loan_payments
  for each row execute function public.check_loan_not_overpaid();

create trigger loans_set_updated_at before update on public.loans
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security: you only see and change your own loans
-- ---------------------------------------------------------------------------
alter table public.loans enable row level security;
alter table public.loan_payments enable row level security;

create policy "Users manage their own loans" on public.loans
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users manage their own loan payments" on public.loan_payments
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Balances now include loans:
--   opening + income - expenses - transfers out + transfers in
--   - loans lent from this account + repayments into this account.
-- security_invoker keeps Row Level Security working through the view.
-- ---------------------------------------------------------------------------
create or replace view public.account_balances
with (security_invoker = true)
as
select
  a.id as account_id,
  a.user_id,
  (
    a.opening_balance_cents
    + coalesce((
        select sum(case when t.kind = 'income' then t.amount_cents else -t.amount_cents end)
        from public.transactions t
        where t.account_id = a.id and t.user_id = a.user_id
      ), 0)
    + coalesce((
        select sum(t.amount_cents)
        from public.transactions t
        where t.to_account_id = a.id and t.user_id = a.user_id
      ), 0)
    - coalesce((
        select sum(l.amount_cents)
        from public.loans l
        where l.account_id = a.id and l.user_id = a.user_id
      ), 0)
    + coalesce((
        select sum(p.amount_cents)
        from public.loan_payments p
        where p.account_id = a.id and p.user_id = a.user_id
      ), 0)
  )::bigint as balance_cents
from public.accounts a;
