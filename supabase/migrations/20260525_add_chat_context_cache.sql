-- Per-user cache of Gemini cachedContents used by chat-transactions
-- The cache stores the user's financial context (system prompt + summary + recent transactions).
-- Cache invalidation is signature-based: when the user's data changes, the signature changes
-- and the next request transparently creates a fresh Gemini cache.

create table if not exists public.chat_user_context_cache (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cache_name text not null,
  signature text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.chat_user_context_cache enable row level security;

create policy "Users manage their own chat cache"
  on public.chat_user_context_cache
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists chat_user_context_cache_expires_at_idx
  on public.chat_user_context_cache (expires_at);
