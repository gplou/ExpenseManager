-- ─────────────────────────────────────────────────────────────────────────────
-- Endurecimiento de seguridad (auditoría 2026-11-10)
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. chat_user_context_cache era escribible por el propio usuario (policy FOR
--    ALL). La edge function chat-transactions interpolaba `cache_name` en una
--    URL de la API de Gemini autenticada con GOOGLE_AI_KEY (DELETE
--    /v1beta/<cache_name>) y lo reenviaba como `cachedContent`. Un usuario PRO
--    (o en trial) podía escribir un cache_name arbitrario y hacer que el
--    servidor borrase recursos ajenos de la cuenta de Gemini, o apuntar su
--    chat al contexto cacheado de otro usuario. Ahora la tabla es solo del
--    service role (la función usa su cliente service-role y además valida el
--    formato del nombre).
-- 2. increment_rate_limit aceptaba cualquier p_endpoint / p_window_start: un
--    usuario autenticado podía llamarla por RPC en bucle e insertar filas
--    ilimitadas (con textos de tamaño arbitrario) en rate_limits hasta agotar
--    la cuota de disco. Ahora solo admite los endpoints conocidos y ventanas
--    alineadas al minuto dentro de la última hora.
-- 3. Las columnas de texto no tenían límite de longitud: cualquier cuenta
--    (el registro es abierto) podía guardar descripciones de megabytes vía
--    PostgREST. Se añaden CHECKs generosos respecto a los límites de la app.
-- 4. Defensa en profundidad: `anon` tenía todos los privilegios de tabla
--    (dependía solo de RLS) y `authenticated` tenía INSERT/UPDATE/DELETE sobre
--    tablas que solo deben escribirse desde funciones SECURITY DEFINER o el
--    service role. Se revocan para que un fallo futuro en una policy no
--    exponga nada.
-- 5. delete_user_account fijaba search_path = public sin pg_temp explícito.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. chat_user_context_cache: solo service role ───────────────────────────
drop policy if exists "Users manage their own chat cache" on public.chat_user_context_cache;
revoke all on public.chat_user_context_cache from anon, authenticated;
-- Las filas existentes pudieron ser escritas por clientes: se descartan (la
-- caché se regenera sola en el siguiente mensaje).
delete from public.chat_user_context_cache;
alter table public.chat_user_context_cache
  add constraint chat_user_context_cache_name_format
  check (cache_name ~ '^cachedContents/[A-Za-z0-9_-]{1,128}$');

-- ── 2. increment_rate_limit: validar endpoint y ventana ─────────────────────
create or replace function public.increment_rate_limit(
  p_user_id      uuid,
  p_endpoint     text,
  p_window_start timestamptz,
  p_limit        integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
  v_now   timestamptz := now();
begin
  -- Solo el propio usuario puede consumir su bucket.
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Lista cerrada: evita crear buckets arbitrarios (y textos enormes) por RPC.
  if p_endpoint is null
     or p_endpoint not in ('chat-transactions', 'parse-voice', 'redeem_promo_code') then
    raise exception 'invalid_endpoint' using errcode = '22023';
  end if;

  if p_limit is null or p_limit < 1 then
    raise exception 'invalid_limit' using errcode = '22023';
  end if;

  -- Las ventanas legítimas están truncadas al minuto o a la hora en curso.
  -- Exigir alineación al minuto + rango acota a ~65 filas vivas por
  -- (usuario, endpoint); cleanup_rate_limits() (pg_cron) purga el resto.
  if p_window_start is null
     or p_window_start <> date_trunc('minute', p_window_start)
     or p_window_start > v_now + interval '2 minutes'
     or p_window_start < v_now - interval '65 minutes' then
    raise exception 'invalid_window' using errcode = '22023';
  end if;

  insert into public.rate_limits (user_id, endpoint, window_start, count)
  values (p_user_id, p_endpoint, p_window_start, 1)
  on conflict (user_id, endpoint, window_start)
  do update set count = public.rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;

revoke all on function public.increment_rate_limit(uuid, text, timestamptz, integer) from public, anon;
grant execute on function public.increment_rate_limit(uuid, text, timestamptz, integer) to authenticated;

-- ── 3. Límites de tamaño / rango en datos de usuario ────────────────────────
-- NOT VALID + VALIDATE: el ALTER no bloquea escrituras mientras se revisan las
-- filas existentes (todas cumplen: máx. actual 34 chars de descripción).
alter table public.transactions
  add constraint transactions_amount_positive check (amount > 0) not valid,
  add constraint transactions_text_len check (
    char_length(category) <= 100
    and (subcategory is null or char_length(subcategory) <= 100)
    and (description is null or char_length(description) <= 1000)
    and char_length(currency) <= 10
  ) not valid;
alter table public.transactions validate constraint transactions_amount_positive;
alter table public.transactions validate constraint transactions_text_len;

alter table public.recurring_transactions
  add constraint recurring_transactions_amount_positive check (amount > 0) not valid,
  add constraint recurring_transactions_text_len check (
    char_length(category) <= 100
    and (subcategory is null or char_length(subcategory) <= 100)
    and (description is null or char_length(description) <= 1000)
  ) not valid;
alter table public.recurring_transactions validate constraint recurring_transactions_amount_positive;
alter table public.recurring_transactions validate constraint recurring_transactions_text_len;

alter table public.budgets
  add constraint budgets_text_len check (
    char_length(category) <= 100 and char_length(currency) <= 10
  ) not valid;
alter table public.budgets validate constraint budgets_text_len;

alter table public.subcategories
  add constraint subcategories_text_len check (
    char_length(category) <= 100 and char_length(name) <= 100
  ) not valid;
alter table public.subcategories validate constraint subcategories_text_len;

alter table public.custom_categories
  add constraint custom_categories_text_len check (char_length(name) <= 100) not valid;
alter table public.custom_categories validate constraint custom_categories_text_len;

-- ── 4. Privilegios mínimos ──────────────────────────────────────────────────
-- anon no necesita ninguna tabla: toda la app opera con sesión iniciada.
revoke all on all tables in schema public from anon;
alter default privileges for role postgres in schema public
  revoke all on tables from anon;

-- authenticated nunca necesita TRUNCATE / REFERENCES / TRIGGER.
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- Tablas de solo lectura para el cliente (escriben RPCs SECURITY DEFINER o el
-- service role).
revoke insert, update, delete on
  public.subscriptions,
  public.promo_code_redemptions,
  public.stripe_customers,
  public.ai_usage,
  public.api_rate_limits
from authenticated;

-- Tablas sin acceso directo de cliente.
revoke all on public.promo_codes, public.rate_limits from anon, authenticated;

-- ── 5. delete_user_account: search_path explícito con pg_temp al final ──────
alter function public.delete_user_account() set search_path = public, pg_temp;

-- ── 6. redeem_promo_code: el rate limit no contaba los intentos fallidos ────
-- BUG: cada fallo ("Código no válido", etc.) salía con RAISE EXCEPTION, que
-- hace ROLLBACK de toda la transacción del RPC — incluido el incremento de
-- increment_rate_limit hecho al principio. El contador solo avanzaba con
-- canjes CORRECTOS, así que el límite de 5 intentos/hora nunca frenaba un
-- ataque de fuerza bruta sobre los códigos promocionales.
--
-- FIX: los fallos de validación ya no lanzan excepción. La función fija
-- `response.status = 400` (GUC de PostgREST) y devuelve el JSON de error con
-- la misma forma que PostgREST genera para un RAISE ({code, message, details,
-- hint}), de modo que la transacción hace COMMIT (el intento queda contado) y
-- el cliente sigue recibiendo la misma PostgrestException de siempre — las
-- versiones ya publicadas de la app no necesitan cambios.
-- El caso "rate limit excedido" sí conserva el RAISE: no hay nada que
-- persistir y así el contador no crece sin límite.
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
  v_error text;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- ── 0. Rate limit: 5 intentos/hora por usuario, válidos o no ─────────────
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

  -- ── 1. Validación (sin RAISE: ver cabecera) ─────────────────────────────
  if p_code is null or length(btrim(p_code)) = 0 then
    v_error := 'Código vacío';
  elsif length(p_code) > 64 then
    v_error := 'Código inválido';
  else
    select id, code, duration_days, max_uses, use_count, valid_until
      into v_promo
      from public.promo_codes
     where code = upper(btrim(p_code))
     for update;

    if not found then
      v_error := 'Código no válido';
    elsif v_promo.valid_until is not null and v_promo.valid_until < v_now then
      v_error := 'Código expirado';
    elsif v_promo.max_uses is not null and v_promo.use_count >= v_promo.max_uses then
      v_error := 'Código agotado';
    elsif v_promo.duration_days is null or v_promo.duration_days <= 0
       or v_promo.duration_days > 3650 then
      -- Defensive: never let a corrupted duration grant absurd access.
      v_error := 'Código mal configurado';
    else
      -- ── 2. Record the redemption (unique constraint blocks re-use) ──────
      begin
        insert into public.promo_code_redemptions (promo_code_id, user_id)
        values (v_promo.id, v_user_id);
      exception
        when unique_violation then
          v_error := 'Ya has canjeado este código';
      end;
    end if;
  end if;

  if v_error is not null then
    perform set_config('response.status', '400', true);
    return json_build_object(
      'code', 'P0001',
      'message', v_error,
      'details', null,
      'hint', null
    );
  end if;

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

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;
