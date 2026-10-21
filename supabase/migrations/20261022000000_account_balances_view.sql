-- account_balances: each account's current balance, worked out by the database.
-- balance = opening balance + income - expenses.
--
-- security_invoker = true makes the view run as the person asking, so the
-- Row Level Security rules on accounts and transactions still apply:
-- each user only ever sees their own balances.

create view public.account_balances
with (security_invoker = true)
as
select
  a.id as account_id,
  a.user_id,
  (
    a.opening_balance_cents
    + coalesce(
        sum(case when t.kind = 'income' then t.amount_cents else -t.amount_cents end),
        0
      )
  )::bigint as balance_cents
from public.accounts a
left join public.transactions t
  on t.account_id = a.id
 and t.user_id = a.user_id
group by a.id;

revoke all on public.account_balances from anon;
grant select on public.account_balances to authenticated;
