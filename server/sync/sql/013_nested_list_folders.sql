-- Keep VPS library schema aligned with the Supabase library bridge.
alter table sync_api.list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';
alter table sync_api.profile_list_categories
  add column if not exists parent_id uuid,
  add column if not exists description text not null default '';

create unique index if not exists list_categories_user_id_unique
  on sync_api.list_categories(user_key, id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'list_categories_parent_fk') then
    alter table sync_api.list_categories add constraint list_categories_parent_fk
      foreign key (user_key, parent_id) references sync_api.list_categories(user_key, id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profile_list_categories_parent_fk') then
    alter table sync_api.profile_list_categories add constraint profile_list_categories_parent_fk
      foreign key (user_key, profile_id, parent_id)
      references sync_api.profile_list_categories(user_key, profile_id, id)
      on delete cascade;
  end if;
end $$;

alter table sync_api.list_categories drop constraint if exists list_categories_user_key_name_key;
create unique index if not exists list_categories_sibling_name_unique
  on sync_api.list_categories(user_key, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
create unique index if not exists profile_list_categories_sibling_name_unique
  on sync_api.profile_list_categories(user_key, profile_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
