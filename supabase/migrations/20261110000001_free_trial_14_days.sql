-- ─────────────────────────────────────────────────────────────────────────────
-- Free trial: 4 → 14 days (2 weeks).
-- ─────────────────────────────────────────────────────────────────────────────
-- Same rules as before, only the duration changes:
--   * The user must activate it explicitly (Pro screen → start_free_trial()).
--   * One-time per account (trial_used_at). Once used/expired, PRO is only
--     reachable through a store purchase (apply_rc_entitlement) or a promo code
--     (redeem_promo_code).
--   * Cannot be started while a paid/promo subscription is active.
-- Trials already started keep their original expires_at.
-- Keep in sync with kFreeTrialDays (lib/features/subscription/subscription_repository.dart).
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.start_free_trial()
returns timestamptz
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_trial_days constant integer := 14;
  v_now timestamptz := now();
  v_expires_at timestamptz := v_now + (v_trial_days || ' days')::interval;
  v_existing record;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select trial_used_at, source, expires_at
    into v_existing
    from public.subscriptions
   where user_id = v_user_id
   for update;

  if found and v_existing.trial_used_at is not null then
    raise exception 'trial_already_used' using errcode = 'P0001';
  end if;
  -- A paid/promo subscription is already active → no reason to start a trial.
  if found and v_existing.source is not null
     and v_existing.source <> 'free_trial'
     and v_existing.expires_at > v_now then
    raise exception 'subscription_active' using errcode = 'P0001';
  end if;

  insert into public.subscriptions (user_id, expires_at, source, trial_used_at, cancelled)
  values (v_user_id, v_expires_at, 'free_trial', v_now, false)
  on conflict (user_id) do update
    set expires_at    = excluded.expires_at,
        source        = excluded.source,
        trial_used_at = excluded.trial_used_at,
        cancelled     = false;

  return v_expires_at;
end;
$$;

-- create or replace keeps existing grants, but restate them explicitly.
revoke all on function public.start_free_trial() from public;
revoke execute on function public.start_free_trial() from anon;
grant execute on function public.start_free_trial() to authenticated;
