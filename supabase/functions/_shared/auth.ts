import { createClient, SupabaseClient, User } from 'https://esm.sh/@supabase/supabase-js@2'
import { jsonResponse } from './http.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

let serviceClient: SupabaseClient | null = null

/// Service-role client (bypasses RLS) for server-owned tables that clients
/// must not be able to read or write (e.g. `chat_user_context_cache`).
/// Returns null when the key isn't available so callers can degrade instead
/// of crashing. NEVER use it for a query whose filter comes from the request
/// body — always scope by the `user.id` resolved in [requireUser].
export function getServiceClient(): SupabaseClient | null {
  if (!SUPABASE_SERVICE_ROLE_KEY) return null
  serviceClient ??= createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  return serviceClient
}

export interface AuthedUser {
  supabase: SupabaseClient
  user: User
}

/// Verifies the request carries a valid session and resolves the caller.
/// Returns a ready-to-return [Response] (401) on failure.
export async function requireUser(
  req: Request,
  corsHeaders: Record<string, string>,
): Promise<AuthedUser | Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders)

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError || !user) return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders)

  return { supabase, user }
}

/// Same as [requireUser], but also requires an active PRO subscription.
/// Returns a ready-to-return [Response] (401/403) on failure.
export async function requireProUser(
  req: Request,
  corsHeaders: Record<string, string>,
): Promise<AuthedUser | Response> {
  const authed = await requireUser(req, corsHeaders)
  if (authed instanceof Response) return authed

  const { data: sub } = await authed.supabase
    .from('subscriptions')
    .select('expires_at')
    .eq('user_id', authed.user.id)
    .single()

  if (!sub || new Date(sub.expires_at) < new Date()) {
    return jsonResponse({ error: 'PRO subscription required' }, 403, corsHeaders)
  }

  return authed
}
