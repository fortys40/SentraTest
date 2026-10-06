begin;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function private.can_read_avatar(object_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id::text = split_part(object_name, '/', 1)
    and private.can_read_profile(id))
$$;
revoke all on function private.can_read_avatar(text) from public, anon, authenticated, service_role;
grant execute on function private.can_read_avatar(text) to authenticated;

create policy sentra_avatar_read on storage.objects for select to authenticated
using (bucket_id = 'avatars' and private.can_read_avatar(name));
create policy sentra_avatar_insert on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text and split_part(name, '/', 2) <> '');
create policy sentra_avatar_update on storage.objects for update to authenticated
using (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text)
with check (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text and split_part(name, '/', 2) <> '');
create policy sentra_avatar_delete on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text);

do $$
declare table_name text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach table_name in array array['matches', 'rsvps', 'payments', 'mvp_results', 'player_badges'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = table_name) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('sentra-maintenance', '* * * * *', 'select private.run_maintenance();');
  else
    raise notice 'pg_cron unavailable: run the migrations on Supabase to register sentra-maintenance. Portable tests invoke maintenance directly.';
  end if;
end;
$$;

commit;