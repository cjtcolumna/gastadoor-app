-- DEV ONLY: checks for the subscription schedule and the nightly job.
-- This is NOT a migration. Run each part by hand in the Supabase SQL Editor.
-- (Select just one part, then click Run, so only that part runs.)


-- ===========================================================================
-- PART 1: the date rules. Needs no account. Every row should say ok = true.
-- ===========================================================================
select what, got, expected, got = expected as ok
from (values
  ('Jan 31 monthly, 1 month later',
     public.subscription_charge_date('2026-01-31', 'monthly', 1), date '2026-02-28'),
  ('Jan 31 monthly, 2 months later (back on the 31st)',
     public.subscription_charge_date('2026-01-31', 'monthly', 2), date '2026-03-31'),
  ('Jan 31 monthly, 3 months later (April has 30 days)',
     public.subscription_charge_date('2026-01-31', 'monthly', 3), date '2026-04-30'),
  ('Feb 29 2024 yearly, 1 year later (2025 has no Feb 29)',
     public.subscription_charge_date('2024-02-29', 'yearly', 1), date '2025-02-28'),
  ('Feb 29 2024 yearly, 4 years later (2028 is a leap year)',
     public.subscription_charge_date('2024-02-29', 'yearly', 4), date '2028-02-29'),
  ('Nov 4 monthly, next on or after Nov 4 is Nov 4 itself',
     public.subscription_next_on_or_after('2026-11-04', 'monthly', '2026-11-04'), date '2026-11-04'),
  ('Nov 4 monthly, next on or after Nov 5',
     public.subscription_next_on_or_after('2026-11-04', 'monthly', '2026-11-05'), date '2026-12-04'),
  ('Jan 31 monthly, next on or after Feb 1',
     public.subscription_next_on_or_after('2026-01-31', 'monthly', '2026-02-01'), date '2026-02-28'),
  ('Dec 4 yearly, next on or after Dec 5',
     public.subscription_next_on_or_after('2026-12-04', 'yearly', '2026-12-05'), date '2027-12-04')
) as t(what, got, expected);


-- ===========================================================================
-- PART 2: run the nightly job on a test subscription that is 3 months late.
--
-- 1. Replace you@example.com below with the email you sign in with.
-- 2. Make sure you have opened the app once, so your "Cash" account exists.
-- Run 2a, then 2b, then 2c, 2d. Then look at History in the app.
-- ===========================================================================

-- 2a. Make the test subscription.
do $$
declare
  me uuid := (select id from auth.users where email = 'you@example.com');
  acct uuid;
  sub uuid;
  local_today date := (now() at time zone 'Asia/Manila')::date;
begin
  if me is null then
    raise exception 'No user with that email. Check the email at the top of this script.';
  end if;

  select id into acct from public.accounts
  where user_id = me and not archived
  order by created_at limit 1;
  if acct is null then
    raise exception 'No account found. Open the app once so Cash is created.';
  end if;

  insert into public.subscriptions
    (user_id, name, amount_cents, frequency, first_charge_on, account_id)
  values
    (me, 'Sample: Spotify', 14900, 'monthly',
     (local_today - interval '3 months')::date, acct)
  returning id into sub;

  -- The trigger moved next_charge_on to today or later. Move it back, so the
  -- job sees a subscription that has not been charged for 3 months.
  update public.subscriptions set next_charge_on = first_charge_on where id = sub;
end $$;

-- 2b. Run the job by hand. It returns how many expenses it added.
--     Expected: 4 (three months ago, two, one, and today).
select public.process_due_subscriptions();

-- 2c. Look at what it made. Four 'Sample: Spotify' expenses on four different
--     days, and next_charge_on one month from today.
select occurred_on, amount_cents, note
from public.transactions
where note = 'Sample: Spotify'
order by occurred_on;

select name, next_charge_on from public.subscriptions where name = 'Sample: Spotify';

-- 2d. Run the job again. Expected: 0 (nothing is due, nothing is added twice).
select public.process_due_subscriptions();


-- ===========================================================================
-- CLEAN UP: removes the test subscription and its expenses.
-- (Expenses first, because deleting a subscription keeps its expenses.)
-- ===========================================================================
-- delete from public.transactions where note = 'Sample: Spotify';
-- delete from public.subscriptions where name = 'Sample: Spotify';
