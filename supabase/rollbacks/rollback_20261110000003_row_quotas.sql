-- Rollback de 20261110000003_row_quotas.sql
drop trigger if exists transactions_row_quota on public.transactions;
drop trigger if exists recurring_transactions_row_quota on public.recurring_transactions;
drop trigger if exists budgets_row_quota on public.budgets;
drop trigger if exists subcategories_row_quota on public.subcategories;
drop trigger if exists custom_categories_row_quota on public.custom_categories;
drop function if exists public.enforce_user_row_quota();
