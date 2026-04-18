-- ============================================================
-- Migration: Admin-Controlled Chat Rate Limits with Realtime
-- Date: 2026-04-18
-- Description: Creates chat_settings (singleton) and chat_usage
--              tables, RLS policies, Realtime subscription, and
--              atomic increment function.
-- ============================================================

-- ─── 1. chat_settings — singleton admin-controlled config ───
create table if not exists public.chat_settings (
  id integer primary key default 1,
  chats_per_day integer not null default 5,
  messages_per_chat integer not null default 20,
  rate_limiting_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  constraint singleton check (id = 1)
);

-- Seed default values
insert into public.chat_settings (id, chats_per_day, messages_per_chat)
  values (1, 5, 20)
  on conflict (id) do nothing;

-- RLS: anyone authenticated can READ settings
alter table public.chat_settings enable row level security;

create policy "Authenticated users can read chat settings"
  on public.chat_settings for select
  to authenticated
  using (true);

-- Only admins can UPDATE settings
-- Uses site_settings allowed_emails as admin check
create policy "Admins can update chat settings"
  on public.chat_settings for update
  using (
    exists (
      select 1 from public.site_settings
      where key = 'admin_access'
        and auth.jwt() ->> 'email' = any(allowed_emails)
    )
  );

-- Enable Realtime on this table
alter publication supabase_realtime add table public.chat_settings;


-- ─── 2. chat_usage — per-user daily usage tracking ───
create table if not exists public.chat_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  chat_count integer not null default 0,
  message_count integer not null default 0,
  unique (user_id, date)
);

alter table public.chat_usage enable row level security;

create policy "Users can read own usage"
  on public.chat_usage for select
  using (auth.uid() = user_id);

create policy "Users can insert own usage"
  on public.chat_usage for insert
  with check (auth.uid() = user_id);

create policy "Users can update own usage"
  on public.chat_usage for update
  using (auth.uid() = user_id);


-- ─── 3. Atomic increment function ───
create or replace function increment_chat_usage(
  p_user_id uuid,
  p_field text
)
returns void language plpgsql security definer as $$
begin
  insert into public.chat_usage (user_id, date, chat_count, message_count)
    values (p_user_id, current_date, 0, 0)
    on conflict (user_id, date) do nothing;

  if p_field = 'chat_count' then
    update public.chat_usage
      set chat_count = chat_count + 1
      where user_id = p_user_id and date = current_date;
  elsif p_field = 'message_count' then
    update public.chat_usage
      set message_count = message_count + 1
      where user_id = p_user_id and date = current_date;
  end if;
end;
$$;


-- ─── 4. chat_memory — persistent conversation history per user ───
create table if not exists public.chat_memory (
  user_id uuid primary key references auth.users(id) on delete cascade,
  messages jsonb not null default '[]'::jsonb,
  personality text not null default 'caring',
  language text not null default 'hinglish',
  avatar_index integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.chat_memory enable row level security;

create policy "Users can read own memory"
  on public.chat_memory for select
  using (auth.uid() = user_id);

create policy "Users can insert own memory"
  on public.chat_memory for insert
  with check (auth.uid() = user_id);

create policy "Users can update own memory"
  on public.chat_memory for update
  using (auth.uid() = user_id);
