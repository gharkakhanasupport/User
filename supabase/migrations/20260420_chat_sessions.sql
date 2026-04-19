-- ============================================================
-- Migration: Chat Sessions Table
-- Date: 2026-04-20
-- Description: Creates chat_sessions table for multi-chat
--              management with persistent message history.
--              Also resets stale chat_usage records since
--              prior sessions were never actually persisted.
-- ============================================================

-- ─── 1. chat_sessions — per-user multi-chat storage ───
create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'New Chat',
  messages jsonb not null default '[]'::jsonb,
  personality text not null default 'caring',
  language text not null default 'hinglish',
  avatar_index integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for fast user+date queries
create index if not exists idx_chat_sessions_user_created
  on public.chat_sessions (user_id, created_at desc);

-- ─── 2. RLS Policies ───
alter table public.chat_sessions enable row level security;

create policy "Users can read own sessions"
  on public.chat_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert own sessions"
  on public.chat_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own sessions"
  on public.chat_sessions for update
  using (auth.uid() = user_id);

create policy "Users can delete own sessions"
  on public.chat_sessions for delete
  using (auth.uid() = user_id);


-- ─── 3. Reset stale chat_usage counters ───
-- Previous sessions were never persisted (table didn't exist),
-- so usage counters are inflated. Reset today's records.
update public.chat_usage
  set chat_count = 0, message_count = 0
  where date = current_date;
