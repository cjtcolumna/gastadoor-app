-- A third budget cycle: 'salary'. A new period starts every time the user
-- logs income in their Salary category (categories.is_salary). It has no
-- fixed days, so it uses neither a second day nor a particular first day.

alter table public.budget_settings
  drop constraint budget_settings_cycle_check;
alter table public.budget_settings
  add constraint budget_settings_cycle_check
  check (cycle in ('monthly', 'twice_monthly', 'salary'));

alter table public.budget_settings
  drop constraint budget_settings_days_check;
alter table public.budget_settings
  add constraint budget_settings_days_check check (
    (cycle in ('monthly', 'salary') and second_day is null)
    or (cycle = 'twice_monthly' and second_day is not null and second_day <> first_day)
  );
