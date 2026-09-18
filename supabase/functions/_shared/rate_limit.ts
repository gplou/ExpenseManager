import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/// Checks and atomically increments a sliding rate-limit bucket via the
/// `increment_rate_limit` RPC. Returns `true` if the call is allowed.
/// [windowStart] must already be truncated to the caller's window size
/// (e.g. `setSeconds(0, 0)` for per-minute, `setMinutes(0, 0, 0)` for
/// per-hour) — different endpoints use different granularities.
export async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string,
  endpoint: string,
  limit: number,
  windowStart: Date,
): Promise<boolean> {
  const { data: allowed, error } = await supabase.rpc('increment_rate_limit', {
    p_user_id: userId,
    p_endpoint: endpoint,
    p_window_start: windowStart.toISOString(),
    p_limit: limit,
  })
  return !error && allowed !== false
}
