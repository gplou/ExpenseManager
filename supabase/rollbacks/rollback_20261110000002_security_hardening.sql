-- Rollback de 20261110000002_security_hardening.sql
--
-- OJO: revertir reabre los fallos descritos en esa migración. Úsalo solo si
-- algo se rompe en producción y necesitas volver atrás mientras se corrige.
-- Los REVOKE de privilegios (sección 4) NO se revierten aquí a propósito: son
-- defensa en profundidad y ningún flujo de la app depende de ellos.

-- 1. chat_user_context_cache: vuelve a ser gestionable por el propio usuario
--    (solo necesario si se re-despliega la versión antigua de chat-transactions).
alter table public.chat_user_context_cache
  drop constraint if exists chat_user_context_cache_name_format;
grant select, insert, update, delete on public.chat_user_context_cache to authenticated;
create policy "Users manage their own chat cache"
  on public.chat_user_context_cache
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 2. increment_rate_limit sin validación de endpoint/ventana.
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
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.rate_limits (user_id, endpoint, window_start, count)
  values (p_user_id, p_endpoint, p_window_start, 1)
  on conflict (user_id, endpoint, window_start)
  do update set count = public.rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;

-- 3. Límites de tamaño / rango.
alter table public.transactions
  drop constraint if exists transactions_amount_positive,
  drop constraint if exists transactions_text_len;
alter table public.recurring_transactions
  drop constraint if exists recurring_transactions_amount_positive,
  drop constraint if exists recurring_transactions_text_len;
alter table public.budgets drop constraint if exists budgets_text_len;
alter table public.subcategories drop constraint if exists subcategories_text_len;
alter table public.custom_categories drop constraint if exists custom_categories_text_len;

-- 5. delete_user_account
alter function public.delete_user_account() set search_path = public;

-- 6. redeem_promo_code: para volver a la versión con RAISE (cuyo rate limit
--    no cuenta los fallos), re-ejecuta el CREATE OR REPLACE de
--    supabase/migrations/20260611000001_promo_redeem_rate_limit.sql.
