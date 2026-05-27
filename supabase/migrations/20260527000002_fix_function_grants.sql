-- ─────────────────────────────────────────────────────────────────────────────
-- Fix function execute grants
-- ─────────────────────────────────────────────────────────────────────────────
-- The advisor confirmed anon can call several SECURITY DEFINER functions.
-- Explicitly revoke from PUBLIC (covers anon), then re-grant only to the
-- roles that legitimately need access.
-- ─────────────────────────────────────────────────────────────────────────────

-- apply_rc_entitlement — authenticated only (called by RC webhook path + client)
revoke all on function public.apply_rc_entitlement(timestamptz, text, text) from PUBLIC;
grant execute on function public.apply_rc_entitlement(timestamptz, text, text) to authenticated;

-- start_free_trial — authenticated only
revoke all on function public.start_free_trial() from PUBLIC;
grant execute on function public.start_free_trial() to authenticated;

-- redeem_promo_code — authenticated only
revoke all on function public.redeem_promo_code(text) from PUBLIC;
grant execute on function public.redeem_promo_code(text) to authenticated;

-- increment_rate_limit — authenticated only
revoke all on function public.increment_rate_limit(uuid, text, timestamptz, integer) from PUBLIC;
grant execute on function public.increment_rate_limit(uuid, text, timestamptz, integer) to authenticated;

-- cleanup_rate_limits — service_role only (housekeeping, not user-facing)
revoke all on function public.cleanup_rate_limits() from PUBLIC;
revoke all on function public.cleanup_rate_limits() from authenticated;
grant execute on function public.cleanup_rate_limits() to service_role;

-- delete_user_account — authenticated only (pre-existing function)
revoke all on function public.delete_user_account() from PUBLIC;
grant execute on function public.delete_user_account() to authenticated;

-- increment_ai_usage — authenticated only (pre-existing function)
revoke all on function public.increment_ai_usage(uuid, date, text) from PUBLIC;
grant execute on function public.increment_ai_usage(uuid, date, text) to authenticated;
