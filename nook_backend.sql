-- Nook production backend
-- Run this file in the Supabase SQL editor/migration system for the Nook project.
-- Safe to re-run: tables/policies are recreated only where needed.

create extension if not exists pgcrypto;

-- ---------- profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text not null,
  name text not null default 'Nook user',
  bio text not null default '',
  color text not null default 'iris',
  avatar_url text,
  banner_url text,
  banner_style text not null default 'shapes',
  status_emoji text not null default '',
  status_text text not null default '',
  interests text[] not null default '{}',
  link text not null default '',
  adult_confirmed boolean not null default false,
  private_account boolean not null default false,
  post_audience text not null default 'public' check (post_audience in ('public','followers','me')),
  last_seen_pref text not null default 'everyone' check (last_seen_pref in ('everyone','following','nobody')),
  online_visible boolean not null default true,
  discoverable boolean not null default true,
  who_message text not null default 'everyone' check (who_message in ('everyone','following','nobody')),
  who_call text not null default 'everyone' check (who_call in ('everyone','following','nobody')),
  who_groups text not null default 'everyone' check (who_groups in ('everyone','following','nobody')),
  requests_filter boolean not null default false,
  read_receipts boolean not null default true,
  typing_enabled boolean not null default true,
  sensitive_blur boolean not null default false,
  comments_from text not null default 'everyone' check (comments_from in ('everyone','following','nobody')),
  hidden_words text[] not null default '{}',
  two_step_pref boolean not null default false,
  login_alerts_pref boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_handle_format check (handle ~ '^[a-z0-9._]{3,20}$'),
  constraint profiles_handle_unique unique (handle)
);

-- ---------- follows / blocks ----------
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'accepted' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint follows_no_self check (follower_id <> followee_id)
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self check (blocker_id <> blocked_id)
);

-- ---------- posts ----------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'poster' check (kind in ('poster','art','photo','video')),
  text text not null default '',
  media_url text,
  audience text not null default 'public' check (audience in ('public','followers','me')),
  sensitive boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint posts_has_content check (length(trim(text)) > 0 or media_url is not null)
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now(),
  constraint post_comments_nonempty check (length(trim(text)) between 1 and 2000)
);

create table if not exists public.saved_posts (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- ---------- conversations ----------
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('dm','group')),
  name text,
  color text not null default 'iris',
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  muted boolean not null default false,
  pinned boolean not null default false,
  disappearing boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'text' check (type in ('text','image','video','voice','call')),
  text text,
  media_url text,
  duration integer,
  call_video boolean not null default false,
  call_missed boolean not null default false,
  call_declined boolean not null default false,
  reply_to uuid references public.messages(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  constraint messages_payload check (
    type <> 'text' or length(trim(coalesce(text,''))) between 1 and 10000
  )
);

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

-- ---------- notifications ----------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  post_id uuid references public.posts(id) on delete cascade,
  conversation_id uuid references public.conversations(id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- moments ----------
create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('text','photo','video')),
  text text not null default '',
  media_url text,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now(),
  constraint moments_has_content check (length(trim(text)) > 0 or media_url is not null)
);

create table if not exists public.moment_views (
  moment_id uuid not null references public.moments(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (moment_id, viewer_id)
);

-- ---------- reports ----------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  reason text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

-- Backward-compatible columns for existing Nook deployments.
alter table public.conversation_members add column if not exists disappearing boolean not null default false;
alter table public.conversation_members add column if not exists status text not null default 'active';
alter table public.messages add column if not exists expires_at timestamptz;
alter table public.reports add column if not exists conversation_id uuid references public.conversations(id) on delete set null;


do $$
begin
  if not exists (
    select 1 from pg_constraint where conname='conversation_members_status_check'
  ) then
    alter table public.conversation_members add constraint conversation_members_status_check check (status in ('active','pending'));
  end if;
end $$;

-- ---------- indexes ----------
create index if not exists profiles_created_idx on public.profiles(created_at);
create index if not exists follows_followee_idx on public.follows(followee_id,status);
create index if not exists follows_follower_idx on public.follows(follower_id,status);
create index if not exists posts_author_created_idx on public.posts(author_id,created_at desc);
create index if not exists posts_created_idx on public.posts(created_at desc);
create index if not exists comments_post_created_idx on public.post_comments(post_id,created_at);
create index if not exists conv_members_user_idx on public.conversation_members(user_id);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id,created_at);
create index if not exists messages_expires_idx on public.messages(expires_at) where expires_at is not null;
create index if not exists notifications_user_created_idx on public.notifications(user_id,created_at desc);
create index if not exists moments_author_created_idx on public.moments(author_id,created_at desc);
create index if not exists reports_created_idx on public.reports(created_at desc);
create index if not exists moments_expires_idx on public.moments(expires_at);

-- ---------- common helpers ----------
create or replace function public.is_following(viewer uuid, target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.follows
    where follower_id = viewer and followee_id = target and status = 'accepted'
  );
$$;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

create or replace function public.in_conversation(c uuid, u uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = c and user_id = u
  );
$$;


-- Call authorization helper. Keep this in public only because Realtime policies need it; execution is restricted below.
create or replace function public.can_call_conversation(c uuid,u uuid)
returns boolean
language sql stable security definer set search_path=public
as $$
  select
    u = auth.uid()
    and public.in_conversation(c,u)
    and not exists (
      select 1 from public.conversation_members cm
      join public.blocks b on ((b.blocker_id=cm.user_id and b.blocked_id=u) or (b.blocker_id=u and b.blocked_id=cm.user_id))
      where cm.conversation_id=c and cm.user_id<>u and cm.status='active'
    )
    and not exists (
      select 1 from public.conversation_members cm
      join public.profiles p on p.id=cm.user_id
      where cm.conversation_id=c and cm.user_id<>u and cm.status='active'
        and (p.who_call='nobody' or (p.who_call='following' and not public.is_following(cm.user_id,u)))
    );
$$;

create or replace view public.profile_counts with (security_invoker=true) as
select p.id,
       coalesce((select count(*) from public.follows f where f.followee_id=p.id and f.status='accepted'),0)::integer as followers,
       coalesce((select count(*) from public.follows f where f.follower_id=p.id and f.status='accepted'),0)::integer as following
from public.profiles p;

grant select on public.profile_counts to authenticated;

-- ---------- timestamps ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
drop trigger if exists follows_touch on public.follows;
create trigger follows_touch before update on public.follows for each row execute function public.touch_updated_at();
drop trigger if exists posts_touch on public.posts;
create trigger posts_touch before update on public.posts for each row execute function public.touch_updated_at();
drop trigger if exists conversations_touch on public.conversations;
create trigger conversations_touch before update on public.conversations for each row execute function public.touch_updated_at();

-- ---------- auth -> profile ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  base_handle text;
  candidate text;
begin
  base_handle := lower(regexp_replace(
    coalesce(new.raw_user_meta_data->>'handle', split_part(coalesce(new.email,''),'@',1), 'user'),
    '[^a-z0-9._]', '', 'g'
  ));
  base_handle := left(base_handle, 18);
  if length(base_handle) < 3 then
    base_handle := 'user' || left(replace(new.id::text,'-',''), 6);
  end if;
  candidate := base_handle;
  if exists(select 1 from public.profiles where handle = candidate) then
    candidate := left(base_handle, 14) || '_' || left(replace(new.id::text,'-',''), 5);
  end if;

  insert into public.profiles(id,handle,name,adult_confirmed)
  values (
    new.id,
    candidate,
    coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''), candidate),
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------- notification helpers ----------
create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.follower_id <> new.followee_id then
    insert into public.notifications(user_id,actor_id,type)
    values (new.followee_id,new.follower_id,
      case when new.status='pending' then 'follow_request' else 'follow' end);
  end if;
  return new;
end;
$$;
drop trigger if exists follows_notify on public.follows;
create trigger follows_notify after insert on public.follows
for each row execute function public.notify_follow();

create or replace function public.notify_post_interaction()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  select author_id into owner from public.posts where id = new.post_id;
  if owner is not null and owner <> new.user_id then
    insert into public.notifications(user_id,actor_id,type,post_id)
    values (owner,new.user_id,
      case when tg_table_name='post_likes' then 'like' else 'comment' end,
      new.post_id);
  end if;
  return new;
end;
$$;
drop trigger if exists post_like_notify on public.post_likes;
create trigger post_like_notify after insert on public.post_likes for each row execute function public.notify_post_interaction();
drop trigger if exists post_comment_notify on public.post_comments;
create trigger post_comment_notify after insert on public.post_comments for each row execute function public.notify_post_interaction();



-- Message-request state: pending members can read the request but cannot send until accepted.
alter table public.conversation_members
  add column if not exists status text not null default 'active'
  check (status in ('active','pending'));

create or replace function public.validate_conversation_member()
returns trigger
language plpgsql
security definer set search_path=public
as $$
declare
  c public.conversations;
  target public.profiles;
begin
  select * into c from public.conversations where id=new.conversation_id;
  if c.id is null then raise exception 'Conversation not found'; end if;

  if new.user_id = c.created_by then
    new.status := 'active';
    return new;
  end if;

  if public.is_blocked(c.created_by,new.user_id) then
    raise exception 'This conversation is not allowed';
  end if;

  select * into target from public.profiles where id=new.user_id;
  if target.id is null then raise exception 'User not found'; end if;

  if c.type='dm' then
    if target.who_message='nobody' then
      raise exception 'This user does not accept messages';
    elsif target.who_message='following' and not public.is_following(target.id,c.created_by) then
      if target.requests_filter then new.status := 'pending';
      else raise exception 'This user only accepts messages from people they follow'; end if;
    end if;
  elsif c.type='group' then
    if target.who_groups='nobody' then
      raise exception 'This user does not accept group invites';
    elsif target.who_groups='following' and not public.is_following(target.id,c.created_by) then
      if target.requests_filter then new.status := 'pending';
      else raise exception 'This user only accepts group invites from people they follow'; end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_conversation_member on public.conversation_members;
create trigger validate_conversation_member
before insert on public.conversation_members
for each row execute function public.validate_conversation_member();


create or replace function public.notify_message_request()
returns trigger language plpgsql security definer set search_path=public as $$
declare creator uuid;
begin
  if new.status='pending' then
    select created_by into creator from public.conversations where id=new.conversation_id;
    insert into public.notifications(user_id,actor_id,type,conversation_id)
    values(new.user_id,creator,'message_request',new.conversation_id);
  end if;
  return new;
end;
$$;
drop trigger if exists conversation_request_notify on public.conversation_members;
create trigger conversation_request_notify after insert on public.conversation_members
for each row execute function public.notify_message_request();

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.saved_posts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.notifications enable row level security;
alter table public.moments enable row level security;
alter table public.moment_views enable row level security;
alter table public.reports enable row level security;

-- Re-runnable policy helper is awkward in SQL, so explicitly drop the policies below.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname='public'
      and tablename in ('profiles','follows','blocks','posts','post_likes','post_comments','saved_posts',
                        'conversations','conversation_members','messages','message_reactions',
                        'notifications','moments','moment_views','reports')
  loop
    execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end $$;

-- Profiles: authenticated users can discover profiles; owners can edit.
create policy profiles_select on public.profiles for select to authenticated
using (
  id = auth.uid()
  or (not public.is_blocked(auth.uid(),id) and discoverable)
  or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followee_id=id and f.status='accepted')
);
create policy profiles_insert on public.profiles for insert to authenticated
with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- Follows.
create policy follows_select on public.follows for select to authenticated
using (follower_id=auth.uid() or followee_id=auth.uid());
create policy follows_insert on public.follows for insert to authenticated
with check (
  follower_id=auth.uid()
  and follower_id <> followee_id
  and not public.is_blocked(auth.uid(),followee_id)
);
create policy follows_update_recipient on public.follows for update to authenticated
using (followee_id=auth.uid())
with check (followee_id=auth.uid() and status='accepted');
create policy follows_delete on public.follows for delete to authenticated
using (follower_id=auth.uid() or followee_id=auth.uid());

-- Blocks.
create policy blocks_select on public.blocks for select to authenticated
using (blocker_id=auth.uid() or blocked_id=auth.uid());
create policy blocks_insert on public.blocks for insert to authenticated
with check (blocker_id=auth.uid() and blocker_id<>blocked_id);
create policy blocks_delete on public.blocks for delete to authenticated
using (blocker_id=auth.uid());

-- Posts. RLS enforces public/follower/private visibility and blocks.
create policy posts_select on public.posts for select to authenticated
using (
  not public.is_blocked(auth.uid(),author_id)
  and (
    author_id=auth.uid()
    or audience='public'
    or (audience='followers' and public.is_following(auth.uid(),author_id))
  )
  and not exists (
    select 1 from public.profiles p
    where p.id=author_id and p.private_account and author_id<>auth.uid()
      and not public.is_following(auth.uid(),author_id)
  )
);
create policy posts_insert on public.posts for insert to authenticated
with check (
  author_id=auth.uid()
  and (
    audience='public'
    or audience='followers'
    or audience='me'
  )
);
create policy posts_update on public.posts for update to authenticated
using (author_id=auth.uid()) with check (author_id=auth.uid());
create policy posts_delete on public.posts for delete to authenticated
using (author_id=auth.uid());

-- Likes/comments/saves inherit post visibility.
create policy post_likes_select on public.post_likes for select to authenticated
using (exists(select 1 from public.posts p where p.id=post_id));
create policy post_likes_insert on public.post_likes for insert to authenticated
with check (user_id=auth.uid() and exists(select 1 from public.posts p where p.id=post_id));
create policy post_likes_delete on public.post_likes for delete to authenticated
using (user_id=auth.uid());

create policy post_comments_select on public.post_comments for select to authenticated
using (exists(select 1 from public.posts p where p.id=post_id));
create policy post_comments_insert on public.post_comments for insert to authenticated
with check (
  author_id=auth.uid()
  and exists(select 1 from public.posts p where p.id=post_id)
  and (
    select case
      when p.author_id=auth.uid() then true
      when p.author_id is not null then
        coalesce((select comments_from from public.profiles where id=p.author_id),'everyone')='everyone'
        or (select comments_from from public.profiles where id=p.author_id)='followers' and public.is_following(auth.uid(),p.author_id)
      else false end
    from public.posts p where p.id=post_id
  )
);
create policy post_comments_delete on public.post_comments for delete to authenticated
using (author_id=auth.uid() or exists(select 1 from public.posts p where p.id=post_id and p.author_id=auth.uid()));

create policy saved_posts_select on public.saved_posts for select to authenticated
using (user_id=auth.uid());
create policy saved_posts_insert on public.saved_posts for insert to authenticated
with check (user_id=auth.uid() and exists(select 1 from public.posts p where p.id=post_id));
create policy saved_posts_delete on public.saved_posts for delete to authenticated
using (user_id=auth.uid());

-- Conversations and membership.
create policy conversations_select on public.conversations for select to authenticated
using (public.in_conversation(id,auth.uid()));
create policy conversations_insert on public.conversations for insert to authenticated
with check (created_by=auth.uid());
create policy conversations_update on public.conversations for update to authenticated
using (created_by=auth.uid() or public.in_conversation(id,auth.uid()))
with check (created_by=auth.uid() or public.in_conversation(id,auth.uid()));
create policy conversations_delete on public.conversations for delete to authenticated
using (created_by=auth.uid());

create policy conversation_members_select on public.conversation_members for select to authenticated
using (public.in_conversation(conversation_id,auth.uid()));
create policy conversation_members_insert on public.conversation_members for insert to authenticated
with check (exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=auth.uid()));
create policy conversation_members_update on public.conversation_members for update to authenticated
using (user_id=auth.uid() or exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=auth.uid()))
with check (
  (user_id=auth.uid() or exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=auth.uid()))
  and status in ('active','pending')
);
create policy conversation_members_delete on public.conversation_members for delete to authenticated
using (user_id=auth.uid() or exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=auth.uid()));

-- Messages only inside conversations the current user belongs to; sender must be current user.
create policy messages_select on public.messages for select to authenticated
using (public.in_conversation(conversation_id,auth.uid()));
create policy messages_insert on public.messages for insert to authenticated
with check (
  sender_id=auth.uid()
  and exists(select 1 from public.conversation_members cm where cm.conversation_id=messages.conversation_id and cm.user_id=auth.uid() and cm.status='active')
  and not exists (
    select 1 from public.conversation_members cm
    join public.blocks b on (b.blocker_id=cm.user_id and b.blocked_id=auth.uid())
                           or (b.blocker_id=auth.uid() and b.blocked_id=cm.user_id)
    where cm.conversation_id=messages.conversation_id and cm.user_id<>auth.uid()
  )
);
create policy messages_update on public.messages for update to authenticated
using (sender_id=auth.uid()) with check (sender_id=auth.uid());
create policy messages_delete on public.messages for delete to authenticated
using (sender_id=auth.uid());

create policy message_reactions_select on public.message_reactions for select to authenticated
using (public.in_conversation((select conversation_id from public.messages m where m.id=message_id),auth.uid()));
create policy message_reactions_insert on public.message_reactions for insert to authenticated
with check (
  user_id=auth.uid()
  and public.in_conversation((select conversation_id from public.messages m where m.id=message_id),auth.uid())
);
create policy message_reactions_delete on public.message_reactions for delete to authenticated
using (user_id=auth.uid());

-- Notifications are private to recipient; actors can be visible only as joined profile data.
create policy notifications_select on public.notifications for select to authenticated
using (user_id=auth.uid());
create policy notifications_update on public.notifications for update to authenticated
using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated
using (user_id=auth.uid());

-- Moments.
create policy moments_select on public.moments for select to authenticated
using (
  expires_at > now()
  and not public.is_blocked(auth.uid(),author_id)
  and (
    author_id=auth.uid()
    or (select not private_account from public.profiles where id=author_id)
    or public.is_following(auth.uid(),author_id)
  )
);
create policy moments_insert on public.moments for insert to authenticated
with check (author_id=auth.uid());
create policy moments_update on public.moments for update to authenticated
using (author_id=auth.uid()) with check (author_id=auth.uid());
create policy moments_delete on public.moments for delete to authenticated
using (author_id=auth.uid());

create policy moment_views_select on public.moment_views for select to authenticated
using (viewer_id=auth.uid() or exists(select 1 from public.moments m where m.id=moment_id and m.author_id=auth.uid()));
create policy moment_views_insert on public.moment_views for insert to authenticated
with check (viewer_id=auth.uid());

-- Reports: users can submit and view only their own reports.
create policy reports_insert on public.reports for insert to authenticated
with check (reporter_id=auth.uid());
create policy reports_select on public.reports for select to authenticated
using (reporter_id=auth.uid());

-- ---------- storage ----------
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'nook-media','nook-media',false,83886080,
  array[
    'image/jpeg','image/png','image/webp','image/gif',
    'video/mp4','video/webm','video/quicktime',
    'audio/webm','audio/ogg','audio/mp4','audio/mpeg'
  ]
)
on conflict (id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists nook_media_select on storage.objects;
drop policy if exists nook_media_insert on storage.objects;
drop policy if exists nook_media_update on storage.objects;
drop policy if exists nook_media_delete on storage.objects;

create policy nook_media_select on storage.objects for select to authenticated
using (
  bucket_id='nook-media'
  and (
    owner_id = auth.uid()::text
    or (
      (name like 'messages/%')
      and exists (
        select 1
        from public.messages m
        where m.media_url = name
          and public.in_conversation(m.conversation_id,auth.uid())
      )
    )
    or (
      name like 'posts/%'
      and exists (
        select 1
        from public.posts p
        where p.media_url = name
          and (
            p.author_id=auth.uid()
            or p.audience='public'
            or (p.audience='followers' and public.is_following(auth.uid(),p.author_id))
          )
      )
    )
    or (
      name like 'profile/%'
      and exists (
        select 1 from public.profiles p
        where (p.avatar_url=name or p.banner_url=name)
          and (
            p.id=auth.uid()
            or p.discoverable
            or public.is_following(auth.uid(),p.id)
          )
      )
    )
    or (
      name like 'moments/%'
      and exists (
        select 1 from public.moments m
        where m.media_url=name and m.expires_at>now()
          and (m.author_id=auth.uid() or public.is_following(auth.uid(),m.author_id))
      )
    )
  )
);
create policy nook_media_insert on storage.objects for insert to authenticated
with check (
  bucket_id='nook-media'
  and (storage.foldername(name))[2] = auth.uid()::text
);
create policy nook_media_update on storage.objects for update to authenticated
using (bucket_id='nook-media' and owner_id=auth.uid()::text)
with check (bucket_id='nook-media' and owner_id=auth.uid()::text);
create policy nook_media_delete on storage.objects for delete to authenticated
using (bucket_id='nook-media' and owner_id=auth.uid()::text);

alter table public.message_reactions replica identity full;
alter table public.conversation_members replica identity full;

-- Function execution hardening: helper functions are callable only by signed-in users; trigger functions are not RPC endpoints.
revoke execute on function public.is_following(uuid,uuid) from public, anon;
revoke execute on function public.is_blocked(uuid,uuid) from public, anon;
revoke execute on function public.in_conversation(uuid,uuid) from public, anon;
revoke execute on function public.can_call_conversation(uuid,uuid) from public, anon;
grant execute on function public.is_following(uuid,uuid) to authenticated;
grant execute on function public.is_blocked(uuid,uuid) to authenticated;
grant execute on function public.in_conversation(uuid,uuid) to authenticated;
grant execute on function public.can_call_conversation(uuid,uuid) to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.notify_follow() from public, anon, authenticated;
revoke execute on function public.notify_post_interaction() from public, anon, authenticated;
revoke execute on function public.validate_conversation_member() from public, anon, authenticated;
revoke execute on function public.notify_message_request() from public, anon, authenticated;

-- Remove the legacy security-definer count RPC if it exists.
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='follow_counts' and pg_get_function_identity_arguments(p.oid)='target uuid') then
    revoke execute on function public.follow_counts(uuid) from public, anon, authenticated;
    execute 'drop function public.follow_counts(uuid)';
  end if;
end $$;

-- ---------- Realtime ----------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='messages'
  ) then alter publication supabase_realtime add table public.messages; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='notifications'
  ) then alter publication supabase_realtime add table public.notifications; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='conversation_members'
  ) then alter publication supabase_realtime add table public.conversation_members; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='message_reactions'
  ) then alter publication supabase_realtime add table public.message_reactions; end if;
end $$;

-- Private Realtime channels used for presence/call signaling.
drop policy if exists "nook realtime members" on realtime.messages;
create policy "nook realtime members"
on realtime.messages
for all to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and (
    (
      realtime.messages.topic like 'nook-call-%'
      and public.can_call_conversation(split_part(realtime.messages.topic,'nook-call-',2)::uuid,auth.uid())
    )
    or (
      realtime.messages.topic like 'nook-presence-%'
      and split_part(realtime.messages.topic,'nook-presence-',2)=auth.uid()::text
    )
  )
)
with check (
  realtime.messages.extension = 'broadcast'
  and (
    (
      realtime.messages.topic like 'nook-call-%'
      and public.can_call_conversation(split_part(realtime.messages.topic,'nook-call-',2)::uuid,auth.uid())
    )
    or (
      realtime.messages.topic like 'nook-presence-%'
      and split_part(realtime.messages.topic,'nook-presence-',2)=auth.uid()::text
    )
  )
);

-- Cleanup expired moments periodically when pg_cron is available.
do $$
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    if exists(select 1 from cron.job where jobname='nook-expire-moments') then
      perform cron.unschedule('nook-expire-moments');
    end if;
    perform cron.schedule('nook-expire-moments','*/15 * * * *',
      $cron$delete from public.messages where expires_at is not null and expires_at < now(); delete from public.moments where expires_at < now() - interval '2 days'$cron$);
  end if;
exception when others then
  raise notice 'pg_cron cleanup not installed; expired moments remain until queried/deleted.';
end $$;
