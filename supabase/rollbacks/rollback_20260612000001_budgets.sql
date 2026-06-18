-- Rollback de 20260612000001_budgets.sql
-- Elimina la tabla de presupuestos (y sus policies/índices con ella).
-- ⚠️ Destruye los presupuestos guardados de usuarios PRO.

drop table if exists public.budgets;
