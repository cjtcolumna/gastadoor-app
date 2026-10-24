-- Sub-account bubbles: each pocket can have its own icon and a savings goal.
--
--   icon        a name like 'flight' or 'savings' (the app turns it into a
--               picture). Empty = the default piggy bank.
--   goal_cents  how much you want to save, in cents. Empty = no goal.
--               Must be above zero when set.

alter table public.accounts
  add column icon text
    check (icon is null or char_length(icon) between 1 and 40),
  add column goal_cents bigint
    check (goal_cents is null or goal_cents > 0);
