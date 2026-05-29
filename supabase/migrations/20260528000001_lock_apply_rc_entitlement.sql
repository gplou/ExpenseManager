-- ─────────────────────────────────────────────────────────────────────────────
-- Lock apply_rc_entitlement: revoke direct client access
-- ─────────────────────────────────────────────────────────────────────────────
-- The Flutter client used to call apply_rc_entitlement directly after a
-- RevenueCat purchase. Any authenticated user could call this endpoint and
-- grant themselves PRO status for up to 400 days without paying.
--
-- The revenuecat-webhook Edge Function (service_role) is the only authoritative
-- writer for store-backed subscriptions. It writes directly to the subscriptions
-- table via upsert, bypassing RLS.
--
-- After this migration:
--   - authenticated  → no longer allowed to call apply_rc_entitlement
--   - service_role   → retains access (used by revenuecat-webhook indirectly)
--   - anon           → never had access (already revoked in 20260527000002)
-- ─────────────────────────────────────────────────────────────────────────────

revoke execute on function public.apply_rc_entitlement(timestamptz, text, text)
  from authenticated;
