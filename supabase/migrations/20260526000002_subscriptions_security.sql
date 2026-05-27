-- ─────────────────────────────────────────────────────────────────────────────
-- Subscriptions Security Lockdown
-- ─────────────────────────────────────────────────────────────────────────────
-- Lock down the subscriptions table so clients can no longer write directly.
-- All mutations go through SECURITY DEFINER RPCs.
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop all write policies (covers various legacy names that may exist).
drop policy if exists "Users can insert their subscription"   on public.subscriptions;
drop policy if exists "Users can update their subscription"   on public.subscriptions;
drop policy if exists "Users can upsert their subscription"   on public.subscriptions;
drop policy if exists "Users insert own subscription"         on public.subscriptions;
drop policy if exists "Users update own subscription"         on public.subscriptions;

-- Ensure a read-only policy exists.
drop policy if exists "Users can view their subscription" on public.subscriptions;
create policy "Users can view their subscription"
  on public.subscriptions
  for select
  using ((select auth.uid()) = user_id);

alter table public.subscriptions enable row level security;

-- ── start_free_trial ──────────────────────────────────────────────────────────
create or replace function public.start_free_trial()
returns timestamptz
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id  uuid        := auth.uid();
  v_now      timestamptz := now();
  v_expires_at timestamptz;
  v_trial_used_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Lock the row to prevent concurrent calls.
  select trial_used_at into v_trial_used_at
    from public.subscriptions
   where user_id = v_user_id
   for update;

  if v_trial_used_at is not null then
    raise exception 'trial_already_used' using errcode = 'P0001';
  end if;

  v_expires_at := v_now + interval '4 days';

  insert into public.subscriptions (user_id, expires_at, source, trial_used_at, cancelled)
  values (v_user_id, v_expires_at, 'free_trial', v_now, false)
  on conflict (user_id) do update
    set expires_at     = excluded.expires_at,
        source         = 'free_trial',
        trial_used_at  = excluded.trial_used_at,
        cancelled      = false;

  return v_expires_at;
end;
$$;

revoke all on function public.start_free_trial() from public;
grant execute on function public.start_free_trial() to authenticated;

-- ── apply_rc_entitlement ──────────────────────────────────────────────────────
create or replace function public.apply_rc_entitlement(
  p_expires_at  timestamptz,
  p_source      text,
  p_store_tx_id text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid        := auth.uid();
  v_now     timestamptz := now();
  v_current_expires_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  -- 'free_trial' goes through start_free_trial() (enforces one-time use).
  -- 'promo_code' goes through redeem_promo_code() (server-side stacking).
  if p_source not in ('play_store', 'app_store', 'stripe', 'unknown') then
    raise exception 'invalid_source' using errcode = '22023';
  end if;
  if p_expires_at is null or p_expires_at <= v_now then
    raise exception 'invalid_expiry_past' using errcode = '22023';
  end if;
  if p_expires_at > v_now + interval '400 days' then
    raise exception 'invalid_expiry_far_future' using errcode = '22023';
  end if;
  if p_store_tx_id is not null and length(p_store_tx_id) > 200 then
    raise exception 'invalid_store_tx_id' using errcode = '22023';
  end if;

  select expires_at into v_current_expires_at
    from public.subscriptions
   where user_id = v_user_id;

  if v_current_expires_at is not null and v_current_expires_at > p_expires_at then
    update public.subscriptions
       set source      = p_source,
           store_tx_id = coalesce(p_store_tx_id, store_tx_id),
           cancelled   = false
     where user_id = v_user_id;
    return;
  end if;

  insert into public.subscriptions (user_id, expires_at, source, store_tx_id, cancelled)
  values (v_user_id, p_expires_at, p_source, p_store_tx_id, false)
  on conflict (user_id) do update
    set expires_at  = excluded.expires_at,
        source      = excluded.source,
        store_tx_id = coalesce(excluded.store_tx_id, public.subscriptions.store_tx_id),
        cancelled   = false;
end;
$$;
