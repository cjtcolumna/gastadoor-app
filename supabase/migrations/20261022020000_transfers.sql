-- Transfers: moving money between your own accounts (e.g. Cash -> GCash).
--
-- A transfer is a row in `transactions` with kind = 'transfer':
--   account_id     = the account the money leaves (From)
--   to_account_id  = the account the money arrives in (To)
-- It is not income or spending, so net worth does not change.

-- 1. Allow the new kind.
alter table public.transactions
  drop constraint transactions_kind_check;
alter table public.transactions
  add constraint transactions_kind_check
  check (kind in ('expense', 'income', 'transfer'));

-- 2. The "To" account. The composite key (to_account_id, user_id) makes sure
--    you can only transfer into one of your own accounts.
alter table public.transactions
  add column to_account_id uuid;
alter table public.transactions
  add constraint transactions_to_account_id_user_id_fkey
  foreign key (to_account_id, user_id)
  references public.accounts (id, user_id)
  on delete cascade;

-- 3. Shape rules: a transfer has a To account (different from From) and no
--    category; expenses and income have no To account.
alter table public.transactions
  add constraint transactions_transfer_shape check (
    (kind = 'transfer') = (to_account_id is not null)
    and (to_account_id is null or to_account_id <> account_id)
    and (kind <> 'transfer' or category_id is null)
  );

create index transactions_to_account_idx on public.transactions (to_account_id);

-- 4. Balances now include transfers:
--    opening + income - expenses - transfers out + transfers in.
--    security_invoker keeps Row Level Security working through the view.
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
  )::bigint as balance_cents
from public.accounts a;
