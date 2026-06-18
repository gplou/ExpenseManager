-- ─────────────────────────────────────────────────────────────────────────────
-- Server-side rate limit for redeem_promo_code
-- ─────────────────────────────────────────────────────────────────────────────
-- BEFORE: the only rate limit on promo redemption attempts lived in Dart
-- memory (3 fallos → 30s cooldown) and se reinicia matando la app, así que un
-- cliente hostil podía probar códigos por fuerza bruta contra el RPC.
--
-- AFTER: el propio RPC consume un bucket de public.increment_rate_limit
-- (migración 20260526000001) ANTES de validar nada: máx. 5 intentos por hora
-- y usuario, válidos o no. Al exceder, lanza P0001 con
-- hint = 'promo_rate_limited:<segundos_restantes>' para que el cliente lo
-- mapee a PromoCooldownException y muestre el cooldown real.
-- El límite client-side se conserva como primera barrera de UX.
--
-- El resto del cuerpo es idéntico al de 20260526000003.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.redeem_promo_code(p_code text)
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
  v_retry_seconds integer;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- ── 0. Rate limit: 5 intentos/hora por usuario, válidos o no ─────────────
  -- Se consume ANTES de validar para que los códigos malformados también
  -- cuenten. Ventana horaria alineada con cleanup_rate_limits().
  if not public.increment_rate_limit(
    v_user_id,
    'redeem_promo_code',
    date_trunc('hour', v_now),
    5
  ) then
    v_retry_seconds := ceil(extract(epoch from
      (date_trunc('hour', v_now) + interval '1 hour' - v_now)))::integer;
    raise exception 'Demasiados intentos. Inténtalo más tarde.'
      using errcode = 'P0001',
            hint = 'promo_rate_limited:' || v_retry_seconds;
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
