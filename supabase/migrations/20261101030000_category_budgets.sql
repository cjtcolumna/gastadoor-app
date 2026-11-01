-- Budgets move onto categories.
--
-- Until now a budget was its own row in `budgets`, pointing at a category.
-- A category can have at most one budget, so the limit becomes a property of
-- the category itself: `categories.budget_cents`.
--
-- This file is SAFE: it only ADDS a column and COPIES the amounts across.
-- The `budgets` table is left exactly as it is, so nothing is lost. A later
-- migration drops `budgets` once the app has been checked against the new
-- column.
--
-- Run this once. If you run it again, the copy step puts the old budget
-- amounts back over any limit you have changed since, so don't re-run it
-- after you start using the new Budget page.

-- ---------------------------------------------------------------------------
-- 1. The new column
-- ---------------------------------------------------------------------------
-- The limit for one budget period, in cents. Null means "no limit".
alter table public.categories
  add column budget_cents bigint
    check (budget_cents is null or budget_cents > 0);

-- Only expense categories can have a limit. Income has no budgets.
alter table public.categories
  add constraint categories_budget_is_expense
    check (budget_cents is null or kind = 'expense');

-- ---------------------------------------------------------------------------
-- 2. Copy the existing budgets across
-- ---------------------------------------------------------------------------
-- Only monthly budgets for expense categories are copied: that is all the
-- app could create. (The budgets table is not changed, so a budget that is
-- not copied is still there.)
update public.categories c
set budget_cents = b.amount_cents
from public.budgets b
where b.category_id = c.id
  and b.user_id = c.user_id
  and b.period = 'monthly'
  and c.kind = 'expense';

-- Say what was left behind (shown as a notice in the Supabase SQL editor):
-- an "all spending" budget has no category, so it has nowhere to go, and a
-- weekly or yearly budget is not a monthly limit.
do $$
declare
  skipped integer;
begin
  select count(*) into skipped
  from public.budgets b
  where b.category_id is null or b.period <> 'monthly';

  if skipped > 0 then
    raise notice '% budget(s) were not copied (all-spending or not monthly). They stay in public.budgets.', skipped;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Check it by hand afterwards (these two numbers should match, unless the
--    notice above said some budgets were left behind):
--
--   select count(*) from public.budgets where category_id is not null and period = 'monthly';
--   select count(*) from public.categories where budget_cents is not null;
--
-- To undo this file (the old budgets are untouched):
--
--   alter table public.categories drop column budget_cents;
--   -- (this also drops the check constraints that use it)
-- ---------------------------------------------------------------------------
