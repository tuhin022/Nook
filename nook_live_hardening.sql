-- Nook live hardening migration
-- Non-destructive: adds compatibility columns/functions and tightens callable-function access.
-- Run this AFTER the base backend schema exists.

alter table public.conversation_members add column if not exists status text not null default 'active';
alter table public.conversation_members add column if not exists disappearing boolean not null default false;
alter table public.messages add column if not exists expires_at timestamptz;
alter table public.notifications add column if not exists conversation_id uuid references public.conversations(id) on delete cascade;
alter table public.reports add column if not exists reported_user_id uuid references public.profiles(id) on delete set null;
alter table public.reports add column if not exists post_id uuid references public.posts(id) on delete set null;
alter table public.reports add column if not exists message_id uuid references public.messages(id) on delete set null;
alter table public.reports add column if not exists conversation_id uuid references public.conversations(id) on delete set null;
alter table public.reports add column if not exists details text not null default '';
alter table public.reports add column if not exists status text not null default 'open';

create or replace function public.can_call_conversation(c uuid,u uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select u=auth.uid()
    and public.in_conversation(c,u)
    and not exists (select 1 from public.conversation_members cm join public.blocks b on ((b.blocker_id=cm.user_id and b.blocked_id=u) or (b.blocker_id=u and b.blocked_id=cm.user_id)) where cm.conversation_id=c and cm.user_id<>u)
    and not exists (select 1 from public.conversation_members cm join public.profiles p on p.id=cm.user_id where cm.conversation_id=c and cm.user_id<>u and (p.who_call='nobody' or (p.who_call='following' and not public.is_following(cm.user_id,u))));
$$;

revoke execute on function public.can_call_conversation(uuid,uuid) from public,anon;
grant execute on function public.can_call_conversation(uuid,uuid) to authenticated;

revoke execute on function public.handle_new_user() from public,anon,authenticated;

-- Security-definer count RPC is not needed by Nook and must not be exposed.
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='follow_counts' and pg_get_function_identity_arguments(p.oid)='target uuid') then
    revoke execute on function public.follow_counts(uuid) from public,anon,authenticated;
    execute 'drop function public.follow_counts(uuid)';
  end if;
end $$;


-- Auth -> profile bootstrap. Keep the privileged function outside the public schema/API.
create schema if not exists private;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  requested_handle text;
  base_handle text;
  candidate text;
  suffix int := 0;
  display_name text;
begin
  display_name := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(coalesce(new.email,''),'@',1), 'user');
  requested_handle := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'handle',''), '[^a-zA-Z0-9._]', '', 'g'));
  base_handle := left(coalesce(nullif(requested_handle,''), lower(regexp_replace(coalesce(split_part(coalesce(new.email,''),'@',1),'user'), '[^a-zA-Z0-9._]', '', 'g'))), 20);
  if length(base_handle) < 3 then base_handle := 'user' || substr(replace(new.id::text,'-',''),1,8); end if;
  candidate := base_handle;
  while exists (select 1 from public.profiles where handle = candidate) loop
    suffix := suffix + 1;
    candidate := left(base_handle, greatest(3, 20 - length(suffix::text) - 1)) || '_' || suffix::text;
  end loop;

  insert into public.profiles (id, handle, name)
  values (new.id, candidate, left(display_name, 120))
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

-- Realtime publication entries required by Nook.
do $$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then alter publication supabase_realtime add table public.messages; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then alter publication supabase_realtime add table public.notifications; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='conversation_members') then alter publication supabase_realtime add table public.conversation_members; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='message_reactions') then alter publication supabase_realtime add table public.message_reactions; end if;
end $$;
