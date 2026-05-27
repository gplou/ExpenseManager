-- ─────────────────────────────────────────────────────────────────────────────
-- Cleanup: close the gaps the baseline dump revealed
-- ─────────────────────────────────────────────────────────────────────────────
-- The 20260526 migrations attempted to lock things down but missed three
-- pre-existing objects whose names didn't match the drop targets:
--   1. Policy "Users manage own subscription" on subscriptions — FOR ALL,
--      coexisted with my new SELECT-only policy. Postgres OR's policies, so
--      the permissive one won and the lockdown never took effect.
--   2. Legacy function redeem_promo_code(code text) RETURNS jsonb — my new
--      function uses a different param name (p_code) and return type (json),
--      so CREATE OR REPLACE created a sibling overload instead of replacing.
--   3. Policy "Allow public read" on promo_codes — leaks all promo codes
--      (including secret ones) to every authenticated *and* anonymous user.
--      The redeem_promo_code RPC is SECURITY DEFINER so it doesn't need RLS.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Kill the policy that bypassed the subscription lockdown.
drop policy if exists "Users manage own subscription" on public.subscriptions;

-- 2. (Legacy redeem_promo_code drop is handled inside 20260526000003 itself —
--    it has to run before that migration's CREATE FUNCTION to allow the
--    return-type change from jsonb to json.)

-- 3. Remove the public-read policy on promo_codes. All access now goes
--    through the SECURITY DEFINER RPC.
drop policy if exists "Allow public read" on public.promo_codes;
-- Defensive: revoke any lingering direct grants too.
revoke select on public.promo_codes from anon, authenticated;
revoke insert, update, delete on public.promo_codes from anon, authenticated;
-- The service_role retains full access for administration via the dashboard.

-- 4. The "Users manage own redemptions" policy on promo_code_redemptions is
--    technically permissive (clients can INSERT redemption rows directly,
--    bypassing the redeem_promo_code function and faking a redemption).
--    A faked redemption row by itself grants nothing — it doesn't write to
--    subscriptions — but it DOES burn the user's one-redemption-per-code
--    quota legitimately. Tighten to SELECT-only; writes go through the RPC.
drop policy if exists "Users manage own redemptions" on public.promo_code_redemptions;
create policy "Users can view their redemptions"
  on public.promo_code_redemptions
  for select
  using ((select auth.uid()) = user_id);
-- No INSERT/UPDATE/DELETE policies → only the SECURITY DEFINER RPC writes.

-- 5. Sanity: ensure RLS is on for everything sensitive.
alter table public.subscriptions enable row level security;
alter table public.promo_codes enable row level security;
alter table public.promo_code_redemptions enable row level security;
