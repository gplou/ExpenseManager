-- ─────────────────────────────────────────────────────────────────────────────
-- Presupuestos por categoría (Plan 3 — A1, 2026-06-12)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tabla owner-only para usuarios PRO (los FREE usan solo la tabla espejo en
-- SQLite). Un presupuesto por (user_id, category); period fijo 'monthly' en v1
-- (el CHECK se ampliará si se añaden otros periodos). La divisa es display-only
-- igual que en transactions: sin conversión.
--
-- delete_user_account no necesita cambios: el ON DELETE CASCADE del FK a
-- auth.users elimina los presupuestos al borrar el usuario.

create table public.budgets (
  id          uuid        not null default gen_random_uuid() primary key,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  category    text        not null,
  amount      numeric(12,2) not null check (amount > 0),
  period      text        not null default 'monthly' check (period in ('monthly')),
  currency    text        not null default 'EUR',
  created_at  timestamptz not null default now(),
  unique (user_id, category)
);

create index idx_budgets_user on public.budgets (user_id);

alter table public.budgets enable row level security;

-- (select auth.uid()): se evalúa una vez por query, no por fila
-- (convención de 20260611000002_advisors_rls_perf).
create policy "Users manage their own budgets"
  on public.budgets
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
