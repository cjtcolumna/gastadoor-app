-- Budget cycle + the protected Salary category.
--
-- 1. budget_settings: when a budget period starts (monthly, or twice a month).
-- 2. categories.is_salary: marks the one Salary category every user has.
--    It is needed for the "reset when I log salary" cycle, so it can't be
--    archived, deleted, or turned into something else.

-- ---------------------------------------------------------------------------
-- 1. budget_settings: one row per user
-- ---------------------------------------------------------------------------
create table public.budget_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  cycle text not null default 'monthly'
    check (cycle in ('monthly', 'twice_monthly')),
  -- The day a new period starts. 31 means "the last day of the month"
  -- (the app uses the real last day in shorter months).
  first_day smallint not null default 1 check (first_day between 1 and 31),
  -- Only for twice_monthly: the second day a period starts.
  second_day smallint check (second_day between 1 and 31),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint budget_settings_days_check check (
    (cycle = 'monthly' and second_day is null)
    or (cycle = 'twice_monthly' and second_day is not null and second_day <> first_day)
  )
);

create trigger budget_settings_set_updated_at before update on public.budget_settings
  for each row execute function public.set_updated_at();

alter table public.budget_settings enable row level security;

create policy "Users manage their own budget settings" on public.budget_settings
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 2. categories.is_salary
-- ---------------------------------------------------------------------------
alter table public.categories
  add column is_salary boolean not null default false;

-- Only income can be the salary category, and a user has at most one.
alter table public.categories
  add constraint categories_salary_is_income check (not is_salary or kind = 'income');
create unique index categories_one_salary_per_user
  on public.categories (user_id) where is_salary;

-- Existing users: flag the income category called "Salary" (and bring it back
-- if it was archived).
update public.categories
set is_salary = true, archived = false
where kind = 'income' and name = 'Salary';

-- Existing users who don't have one (it was renamed): give them a new one.
insert into public.categories (user_id, name, kind, icon, color, is_salary)
select distinct c.user_id, 'Salary', 'income', 'work', 'green', true
from public.categories c
where not exists (
  select 1 from public.categories s where s.user_id = c.user_id and s.is_salary
)
on conflict do nothing;

-- The Salary category can be renamed, recolored, and given another icon,
-- but not archived, deleted, or changed into something else.
-- (security definer: it needs to look in auth.users, which normal users
-- can't read. It lets a delete through when the whole account is removed.)
create or replace function public.protect_salary_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_salary
       and exists (select 1 from auth.users u where u.id = old.user_id) then
      raise exception 'The Salary category is needed and cannot be deleted.';
    end if;
    return old;
  end if;

  if old.is_salary then
    if new.archived then
      raise exception 'The Salary category is needed and cannot be archived.';
    end if;
    if not new.is_salary or new.kind <> old.kind then
      raise exception 'The Salary category cannot be changed into something else.';
    end if;
  end if;
  return new;
end;
$$;

create trigger categories_protect_salary
  before update or delete on public.categories
  for each row execute function public.protect_salary_category();
