-- ─────────────────────────────────────────────────────────────────────────────
-- ROLLBACK de 20260611000002_advisors_rls_perf.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- Restaura las 4 policies a su forma previa (baseline): auth.uid()/auth.role()
-- evaluados por fila y policies aplicadas a {public} sin scope de rol.
-- Los permisos efectivos son los mismos en ambas versiones; este rollback solo
-- existe por si el scope "to authenticated / to service_role" diera problemas
-- con algún acceso no contemplado (p. ej. un job que no use service_role).
--
-- Cómo ejecutarlo: SQL Editor del dashboard, o
--   psql "$DATABASE_URL" -f supabase/rollbacks/rollback_20260611000002_advisors_rls_perf.sql
-- Si el rollback es definitivo, borra también la migración del repo y de
-- supabase_migrations.schema_migrations (version = '20260611000002').
-- ─────────────────────────────────────────────────────────────────────────────

-- subscriptions ───────────────────────────────────────────────────────────────
drop policy if exists "Users can view their subscription" on public.subscriptions;
create policy "Users can view their subscription"
  on public.subscriptions
  for select
  using (auth.uid() = user_id);

-- chat_user_context_cache ─────────────────────────────────────────────────────
drop policy if exists "Users manage their own chat cache" on public.chat_user_context_cache;
create policy "Users manage their own chat cache"
  on public.chat_user_context_cache
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- stripe_customers ────────────────────────────────────────────────────────────
drop policy if exists "Users can read own stripe customer" on public.stripe_customers;
create policy "Users can read own stripe customer"
  on public.stripe_customers
  for select
  using (auth.uid() = user_id);

drop policy if exists "Service role can manage stripe customers" on public.stripe_customers;
create policy "Service role can manage stripe customers"
  on public.stripe_customers
  using (auth.role() = 'service_role'::text);
