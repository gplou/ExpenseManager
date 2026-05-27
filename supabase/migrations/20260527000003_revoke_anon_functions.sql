-- ─────────────────────────────────────────────────────────────────────────────
-- Revoke anon execute on all SECURITY DEFINER RPCs
-- ─────────────────────────────────────────────────────────────────────────────
-- Supabase grants EXECUTE to anon+authenticated+service_role explicitly on
-- every new function. REVOKE FROM PUBLIC doesn't remove those direct grants.
-- This migration removes the anon grant from each sensitive function.
-- ─────────────────────────────────────────────────────────────────────────────

revoke execute on function public.apply_rc_entitlement(timestamptz, text, text) from anon;
revoke execute on function public.start_free_trial() from anon;
revoke execute on function public.redeem_promo_code(text) from anon;
revoke execute on function public.increment_rate_limit(uuid, text, timestamptz, integer) from anon;
revoke execute on function public.cleanup_rate_limits() from anon, authenticated;
revoke execute on function public.delete_user_account() from anon;
revoke execute on function public.increment_ai_usage(uuid, date, text) from anon;
