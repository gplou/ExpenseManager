// RevenueCat webhook receiver.
//
// Configure in RevenueCat Dashboard → Project → Integrations → Webhooks:
//   URL:                 https://<project>.supabase.co/functions/v1/revenuecat-webhook
//   Authorization header: Bearer <REVENUECAT_WEBHOOK_SECRET>
//
// Set these as Supabase Edge Function secrets (NOT in dart_defines.json):
//   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<long-random-string>
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
//
// This function authenticates with the service-role key so it can bypass RLS
// and write to the subscriptions table — which is locked down for regular
// clients per the 20260526000002 migration.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? ''

// Use the service-role client — bypasses RLS, can write to subscriptions
// directly. We never log the user's data or the raw event body.
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
})

// Map RevenueCat store strings to the source values our subscriptions schema
// accepts (see apply_rc_entitlement whitelist).
function mapStoreToSource(store: string | undefined): string {
  switch (store) {
    case 'PLAY_STORE': return 'play_store'
    case 'APP_STORE':
    case 'MAC_APP_STORE': return 'app_store'
    case 'STRIPE': return 'stripe'
    case 'PROMOTIONAL': return 'promo_code'
    default: return 'unknown'
  }
}

// Constant-time comparison to avoid timing leaks on the shared secret check.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let mismatch = 0
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return mismatch === 0
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405 })
  }

  // ── 1. Verify shared secret ────────────────────────────────────────────
  if (!WEBHOOK_SECRET) {
    return new Response('server misconfigured', { status: 500 })
  }
  const authHeader = req.headers.get('Authorization') ?? ''
  const expected = `Bearer ${WEBHOOK_SECRET}`
  if (!timingSafeEqual(authHeader, expected)) {
    return new Response('unauthorized', { status: 401 })
  }

  // ── 2. Parse payload ───────────────────────────────────────────────────
  let payload: any
  try {
    payload = await req.json()
  } catch {
    return new Response('bad request', { status: 400 })
  }

  const event = payload?.event
  if (!event || typeof event !== 'object') {
    return new Response('missing event', { status: 400 })
  }

  const eventType: string = event.type ?? ''
  const userId: string | undefined = event.app_user_id
  if (!userId || typeof userId !== 'string' || !/^[0-9a-f-]{36}$/i.test(userId)) {
    // We use Supabase user.id as the RC app_user_id (see _syncRevenueCatIdentity).
    // Anything that doesn't look like a uuid is a misconfiguration or anonymous RC user.
    return new Response('invalid app_user_id', { status: 400 })
  }

  // ── 3. Apply the event ──────────────────────────────────────────────────
  // RC event reference: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
  // We treat purchase-like events as "extend or set expiry" and cancellation /
  // expiration as state flags. Renewal events arrive with the new expiry.
  const expiresAtMs: number | undefined = event.expiration_at_ms
  const eventTimestampMs: number | undefined = event.event_timestamp_ms
  const store: string | undefined = event.store
  const txId: string | undefined = event.transaction_id ?? event.original_transaction_id
  const source = mapStoreToSource(store)

  try {
    switch (eventType) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'NON_RENEWING_PURCHASE':
      case 'UNCANCELLATION':
      case 'PRODUCT_CHANGE': {
        if (!expiresAtMs) {
          return new Response('missing expiration_at_ms', { status: 400 })
        }
        const expiresAt = new Date(expiresAtMs).toISOString()
        await supabase.from('subscriptions').upsert(
          {
            user_id: userId,
            expires_at: expiresAt,
            source,
            store_tx_id: txId ?? null,
            cancelled: false,
          },
          { onConflict: 'user_id' },
        )
        break
      }

      case 'CANCELLATION': {
        // User cancelled — they keep access until expiration_at_ms. Just flag.
        await supabase
          .from('subscriptions')
          .update({ cancelled: true })
          .eq('user_id', userId)
        break
      }

      case 'EXPIRATION': {
        // Sub fully ended. Set expires_at to event timestamp so isPro flips false.
        const ts = new Date(eventTimestampMs ?? Date.now()).toISOString()
        await supabase
          .from('subscriptions')
          .update({ expires_at: ts, cancelled: true })
          .eq('user_id', userId)
        break
      }

      case 'BILLING_ISSUE': {
        // Don't revoke access yet — RC keeps retrying. Just mark cancelled.
        await supabase
          .from('subscriptions')
          .update({ cancelled: true })
          .eq('user_id', userId)
        break
      }

      case 'TRANSFER': {
        // Subscription moved between app_user_ids. RC sends `transferred_from`
        // and `transferred_to` arrays; for safety we only act on this if we
        // receive a normal entitlement update later. Acknowledge and skip.
        break
      }

      default:
        // Unknown / test events: acknowledge with 200 so RC doesn't retry.
        break
    }
  } catch (_e) {
    // Returning 5xx makes RC retry. Only do so for transient errors — for now
    // any DB error is treated as transient.
    return new Response('db error', { status: 500 })
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  })
})
