-- Sub-accounts: pockets inside an account, e.g. GoTyme -> Travel.
--
-- A sub-account is a normal account with a parent_id. It has its own
-- balance and its own transactions. The parent's total (parent + its
-- sub-accounts) is added up in the app.
--
-- Rules:
--   * The parent must be one of your own accounts.
--   * An account can't be its own parent.
--   * One level only: a sub-account can't have sub-accounts.

-- 1. The link to the parent. The composite key (parent_id, user_id) makes
--    sure the parent belongs to the same user. "on delete restrict" stops
--    a parent from being deleted while it still has sub-accounts.
alter table public.accounts
  add column parent_id uuid;

alter table public.accounts
  add constraint accounts_parent_id_user_id_fkey
  foreign key (parent_id, user_id)
  references public.accounts (id, user_id)
  on delete restrict;

alter table public.accounts
  add constraint accounts_not_own_parent
  check (parent_id is null or parent_id <> id);

create index accounts_parent_idx on public.accounts (parent_id);

-- 2. One level only. A check constraint can only look at its own row,
--    so this rule needs a trigger that looks at the other rows.
create function public.accounts_one_level_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.parent_id is not null then
    if exists (
      select 1 from public.accounts
      where id = new.parent_id and parent_id is not null
    ) then
      raise exception 'A sub-account can''t have its own sub-accounts.'
        using errcode = 'check_violation';
    end if;
    if exists (
      select 1 from public.accounts where parent_id = new.id
    ) then
      raise exception 'An account with sub-accounts can''t become a sub-account.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger accounts_one_level_only
  before insert or update of parent_id on public.accounts
  for each row execute function public.accounts_one_level_only();
