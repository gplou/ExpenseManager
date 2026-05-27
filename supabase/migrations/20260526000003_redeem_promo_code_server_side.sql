-- ─────────────────────────────────────────────────────────────────────────────
-- Server-side redeem_promo_code
-- ─────────────────────────────────────────────────────────────────────────────
-- BEFORE: redeem_promo_code returned (type, duration_days, discount_percentage)
-- and the client stacked the expiry locally + wrote the subscriptions row.
-- A hostile client with a 1-day promo could upsert expires_at = 2099 directly.
--
-- AFTER: the function does the stacking and the upsert itself inside one
-- transaction with FOR UPDATE locks on both promo_codes and subscriptions.
-- The client just calls it and refetches state — it cannot influence the
-- final expiry. apply_rc_entitlement no longer needs 'promo_code' in its
-- whitelist (removed in this migration).
--
-- The function signature stays compatible: returns json {type, duration_days}.
-- discount_percentage is preserved as null for backwards compat with the
-- existing dart client. The `type` field is always 'subscription' since the
-- promo_codes schema only models duration-based promos.
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop the legacy function explicitly. CREATE OR REPLACE FUNCTION cannot
-- change the return type (the old one returned jsonb, the new one returns
-- json), so we have to remove it first. The argument type stays text, so
-- this drop is unambiguous.
drop function if exists public.redeem_promo_code(text);

create function public.redeem_promo_code(p_code text)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_promo record;
  v_current_expires_at timestamptz;
  v_base timestamptz;
  v_new_expires_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_code is null or length(btrim(p_code)) = 0 then
    raise exception 'Código vacío' using errcode = 'P0001';
  end if;
  if length(p_code) > 64 then
    raise exception 'Código inválido' using errcode = 'P0001';
  end if;

  -- ── 1. Lock + validate the promo ────────────────────────────────────────
  select id, code, duration_days, max_uses, use_count, valid_until
    into v_promo
    from public.promo_codes
   where code = upper(btrim(p_code))
   for update;

  if not found then
    raise exception 'Código no válido' using errcode = 'P0001';
  end if;

  if v_promo.valid_until is not null and v_promo.valid_until < v_now then
    raise exception 'Código expirado' using errcode = 'P0001';
  end if;

  if v_promo.max_uses is not null and v_promo.use_count >= v_promo.max_uses then
    raise exception 'Código agotado' using errcode = 'P0001';
  end if;

  if v_promo.duration_days is null or v_promo.duration_days <= 0
     or v_promo.duration_days > 3650 then
    -- Defensive: never let a corrupted duration grant absurd access.
    raise exception 'Código mal configurado' using errcode = 'P0001';
  end if;

  -- ── 2. Record the redemption (unique constraint blocks re-use) ──────────
  begin
    insert into public.promo_code_redemptions (promo_code_id, user_id)
    values (v_promo.id, v_user_id);
  exception
    when unique_violation then
      raise exception 'Ya has canjeado este código' using errcode = 'P0001';
  end;

  -- ── 3. Increment use_count atomically ───────────────────────────────────
  update public.promo_codes
     set use_count = use_count + 1
   where id = v_promo.id;

  -- ── 4. Stack on top of current expiry (server-side; client cannot influence) ──
  select expires_at into v_current_expires_at
    from public.subscriptions
   where user_id = v_user_id
   for update;

  v_base := greatest(coalesce(v_current_expires_at, v_now), v_now);
  v_new_expires_at := v_base + (v_promo.duration_days || ' days')::interval;

  insert into public.subscriptions (user_id, expires_at, source, cancelled)
  values (v_user_id, v_new_expires_at, 'promo_code', false)
  on conflict (user_id) do update
    set expires_at = excluded.expires_at,
        source     = 'promo_code',
        cancelled  = false;

  -- ── 5. Return same shape the dart client already parses ─────────────────
  return json_build_object(
    'type', 'subscription',
    'duration_days', v_promo.duration_days,
    'discount_percentage', null,
    'expires_at', v_new_expires_at
  );
end;
$$;

revoke all on function public.redeem_promo_code(text) from public;
grant execute on function public.redeem_promo_code(text) to authenticated;

-- ─── Remove 'promo_code' from apply_rc_entitlement whitelist ──────────────
-- Now that redeem_promo_code writes its own row server-side, the client no
-- longer needs (and must not be able) to call apply_rc_entitlement with
-- source = 'promo_code'.
create or replace function public.apply_rc_entitlement(
  p_expires_at timestamptz,
  p_source text,
  p_store_tx_id text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
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
