-- Persist My List folders and their anime assignments in Supabase.
-- The original public schema migrations did not create the non-profile
-- category tables, so create them here before adding nested-folder columns.
create table if not exists public.list_categories (
  id uuid primary key default gen_random_uuid(),
  user_key text not null,
  name text not null,
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.mylist_categories (
  user_key text not null,
  source_id text not null,
  item_id text not null,
  category_id uuid not null,
  primary key (user_key, source_id, item_id, category_id)
);

alter table public.list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';
alter table public.profile_list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';

create unique index if not exists list_categories_user_id_unique
  on public.list_categories(user_key, id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'list_categories_parent_fk'
      and conrelid = 'public.list_categories'::regclass
  ) then
    alter table public.list_categories
      add constraint list_categories_parent_fk
      foreign key (user_key, parent_id)
      references public.list_categories(user_key, id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'mylist_categories_category_fk'
      and conrelid = 'public.mylist_categories'::regclass
  ) then
    alter table public.mylist_categories
      add constraint mylist_categories_category_fk
      foreign key (user_key, category_id)
      references public.list_categories(user_key, id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profile_list_categories_parent_fk'
      and conrelid = 'public.profile_list_categories'::regclass
  ) then
    alter table public.profile_list_categories
      add constraint profile_list_categories_parent_fk
      foreign key (user_key, profile_id, parent_id)
      references public.profile_list_categories(user_key, profile_id, id)
      on delete cascade;
  end if;
end $$;

alter table public.list_categories
  drop constraint if exists list_categories_user_key_name_key;
create unique index if not exists list_categories_sibling_name_unique
  on public.list_categories(
    user_key,
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(name)
  );
create unique index if not exists profile_list_categories_sibling_name_unique
  on public.profile_list_categories(
    user_key,
    profile_id,
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(name)
  );

alter table public.list_categories enable row level security;
alter table public.mylist_categories enable row level security;
drop policy if exists list_categories_own on public.list_categories;
create policy list_categories_own on public.list_categories
  for all using (user_key = auth.uid()::text)
  with check (user_key = auth.uid()::text);
drop policy if exists mylist_categories_own on public.mylist_categories;
create policy mylist_categories_own on public.mylist_categories
  for all using (user_key = auth.uid()::text)
  with check (user_key = auth.uid()::text);
grant select, insert, update, delete on
  public.list_categories, public.mylist_categories to authenticated;

notify pgrst, 'reload schema';
