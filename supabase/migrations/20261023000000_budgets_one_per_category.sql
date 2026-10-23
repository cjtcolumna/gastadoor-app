-- Budgets: at most one budget per category for each user,
-- and at most one "all spending" budget (category_id is null).
--
-- "nulls not distinct" makes two NULL category_ids count as the same value,
-- so a second "all spending" budget is refused too.

create unique index budgets_one_per_category
  on public.budgets (user_id, category_id) nulls not distinct;
