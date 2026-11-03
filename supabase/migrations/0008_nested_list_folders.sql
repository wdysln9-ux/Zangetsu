-- Add cloud-persisted nested folders and Markdown descriptions without
-- rewriting existing folder ids or title assignments.
alter table public.list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';
alter table public.profile_list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'list_categories_parent_fk') then
    alter table public.list_categories add constraint list_categories_parent_fk
      foreign key (parent_id) references public.list_categories(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profile_list_categories_parent_fk') then
    alter table public.profile_list_categories add constraint profile_list_categories_parent_fk
      foreign key (user_key, profile_id, parent_id)
      references public.profile_list_categories(user_key, profile_id, id)
      on delete cascade;
  end if;
end $$;

alter table public.list_categories drop constraint if exists list_categories_user_key_name_key;
create unique index if not exists list_categories_sibling_name_unique
  on public.list_categories(user_key, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
create unique index if not exists profile_list_categories_sibling_name_unique
  on public.profile_list_categories(user_key, profile_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

notify pgrst, 'reload schema';
