-- The nightly job that turns due subscriptions into real expenses.
--
-- Every night at 00:05 Philippine time, `process_due_subscriptions()` looks at
-- every active subscription whose `next_charge_on` has arrived and adds one
-- expense per missed charge date, dated on the day it was really due. So if
-- the job ever misses a night (for example the project was paused), the next
-- run catches up with the right dates.
--
-- Turn on pg_cron first: Supabase dashboard > Database > Extensions > pg_cron.
-- (The line below does the same and is harmless if it is already on.)

create extension if not exists pg_cron;

create or replace function public.process_due_subscriptions()
returns integer -- how many expenses were added
language plpgsql
set search_path = ''
as $$
declare
  local_today date := (now() at time zone 'Asia/Manila')::date;
  sub record;
  n int;
  due_on date;
  rows_added int;
  total_added int := 0;
begin
  -- `for update skip locked` makes this safe to run twice at the same moment:
  -- the second run skips rows the first one is working on.
  for sub in
    select *
    from public.subscriptions
    where active and next_charge_on <= local_today
    order by next_charge_on
    for update skip locked
  loop
    -- Walk the charge dates from the very first one. Add an expense for each
    -- date from `next_charge_on` up to today. The first date after today
    -- becomes the new `next_charge_on`.
    n := 0;
    due_on := sub.first_charge_on;
    while due_on <= local_today loop
      if due_on >= sub.next_charge_on then
        -- The job has no signed-in user, so `user_id` is copied from the
        -- subscription instead of the usual auth.uid() default.
        insert into public.transactions (
          user_id, account_id, category_id, kind,
          amount_cents, occurred_on, note, subscription_id
        )
        values (
          sub.user_id, sub.account_id, sub.category_id, 'expense',
          sub.amount_cents, due_on, sub.name, sub.id
        )
        on conflict (subscription_id, occurred_on)
          where subscription_id is not null
          do nothing;
        get diagnostics rows_added = row_count;
        total_added := total_added + rows_added;
      end if;
      n := n + 1;
      due_on := public.subscription_charge_date(
        sub.first_charge_on, sub.frequency, n
      );
    end loop;

    update public.subscriptions
    set next_charge_on = due_on
    where id = sub.id;
  end loop;

  return total_added;
end;
$$;

-- Functions in `public` can be called by anyone through the Supabase API.
-- This one is for the nightly job only, so take that permission away.
revoke all on function public.process_due_subscriptions()
  from public, anon, authenticated;

-- Run it every night. pg_cron uses UTC, so 16:05 UTC is 00:05 in Manila.
-- Using the same name again replaces the job instead of making a second one.
select cron.schedule(
  'process-due-subscriptions',
  '5 16 * * *',
  $$select public.process_due_subscriptions();$$
);

-- To stop it:   select cron.unschedule('process-due-subscriptions');
-- To see runs:  select * from cron.job_run_details order by start_time desc limit 10;
