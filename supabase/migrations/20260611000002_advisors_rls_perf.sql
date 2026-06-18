-- ─────────────────────────────────────────────────────────────────────────────
-- Remediación de advisors de Supabase (2026-06-11)
-- ─────────────────────────────────────────────────────────────────────────────
-- Performance (auth_rls_initplan + multiple_permissive_policies):
--   * Las policies evaluaban auth.uid()/auth.role() POR FILA. Se recrean con
--     (select auth.uid()) para que Postgres lo evalúe una vez por query.
--   * Las policies se scopen al rol correcto (TO authenticated / TO
--     service_role); antes aplicaban a {public}, de modo que cada SELECT de
--     cualquier rol evaluaba también la policy del service role
--     (multiple_permissive_policies en stripe_customers).
--
-- Hallazgos INTENCIONALES que NO se tocan:
--   * promo_codes / rate_limits con RLS sin policies → deny-all deliberado:
--     solo se accede vía funciones SECURITY DEFINER.
--   * RPCs SECURITY DEFINER ejecutables por authenticated
--     (delete_user_account, redeem_promo_code, start_free_trial,
--     increment_ai_usage, increment_rate_limit) → son la API del cliente /
--     edge functions, con validación interna de auth.uid().
--   * Índices "sin uso" (chat cache, recurring user_id) → tráfico aún bajo,
--     se revisará más adelante.
--   * Leaked password protection → se activa en el dashboard de Auth
--     (no es DDL).
-- ─────────────────────────────────────────────────────────────────────────────

-- subscriptions ───────────────────────────────────────────────────────────────
drop policy if exists "Users can view their subscription" on public.subscriptions;
create policy "Users can view their subscription"
  on public.subscriptions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- chat_user_context_cache ─────────────────────────────────────────────────────
drop policy if exists "Users manage their own chat cache" on public.chat_user_context_cache;
create policy "Users manage their own chat cache"
  on public.chat_user_context_cache
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- stripe_customers ────────────────────────────────────────────────────────────
drop policy if exists "Users can read own stripe customer" on public.stripe_customers;
create policy "Users can read own stripe customer"
  on public.stripe_customers
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Scoped al rol: el chequeo auth.role() = 'service_role' por fila sobra.
-- (En la práctica service_role ya tiene BYPASSRLS; la policy se conserva por
-- claridad de intención y por si el bypass cambia.)
drop policy if exists "Service role can manage stripe customers" on public.stripe_customers;
create policy "Service role can manage stripe customers"
  on public.stripe_customers
  for all
  to service_role
  using (true)
  with check (true);
