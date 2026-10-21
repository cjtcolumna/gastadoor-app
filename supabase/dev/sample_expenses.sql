-- DEV ONLY: adds 45 sample expenses so you can see History's pagination.
-- This is NOT a migration. Run it by hand in the Supabase SQL Editor.
--
-- 1. Replace you@example.com below with the email you sign in with.
-- 2. Make sure you have opened the app once, so your "Cash" account exists.
-- 3. Click Run.
-- To remove them later:  delete from public.transactions where note like 'Sample:%';

do $$
declare
  me uuid := (select id from auth.users where email = 'you@example.com');
  acct uuid;
  cat_ids uuid[];
  names text[] := array['Food', 'Transport', 'Bills', 'Shopping', 'Coffee'];
  icons text[] := array['restaurant', 'bus', 'receipt', 'shopping', 'cafe'];
  colors text[] := array['orange', 'blue', 'amber', 'pink', 'brown'];
  notes text[] := array['Jollibee', 'Grab', 'Meralco', 'Shopee', 'Starbucks'];
  i int;
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

  -- A few expense categories (skipped if they already exist).
  insert into public.categories (user_id, name, kind, icon, color)
  select me, n, 'expense', i, col from unnest(names, icons, colors) as t(n, i, col)
  on conflict (user_id, kind, name) do nothing;

  select array_agg(id order by name) into cat_ids
  from public.categories
  where user_id = me and kind = 'expense' and name = any(names);

  for i in 1..45 loop
    insert into public.transactions (user_id, account_id, category_id, kind, amount_cents, occurred_on, note)
    values (
      me,
      acct,
      cat_ids[1 + (i % array_length(cat_ids, 1))],
      'expense',
      (50 + (i * 37) % 950) * 100 + (i * 13) % 100,   -- between ₱50 and ₱1,000
      current_date - (i / 2),                          -- spread over ~3 weeks
      'Sample: ' || notes[1 + (i % 5)]
    );
  end loop;
end $$;
