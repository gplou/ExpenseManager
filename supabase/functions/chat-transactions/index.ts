import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_KEY = Deno.env.get('GOOGLE_AI_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const MODEL = 'gemini-2.5-flash-lite'
const CACHE_TTL_SECONDS = 600

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? ''

function getCorsHeaders(req: Request) {
  const origin = req.headers.get('Origin') ?? ''
  const allowOrigin = (ALLOWED_ORIGIN && origin === ALLOWED_ORIGIN) ? origin : ''
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200, corsHeaders: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  })
}

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
}

function buildSystemPrompt(todayDate: string, locale: string): string {
  const lang = locale.startsWith('es') ? 'Spanish'
    : locale.startsWith('fr') ? 'French'
    : locale.startsWith('de') ? 'German'
    : 'English'

  return `You are a friendly and concise financial assistant inside a personal finance app.
The user's preferred language is ${lang}. Always reply in ${lang}.
Today's date is ${todayDate}.

Rules:
- Answer questions about the user's spending, income, budgets, and categories.
- Use the user data provided in this context to give specific, accurate answers with real numbers.
- When comparing periods, be clear about the time ranges.
- Give practical, actionable savings tips based on their actual spending patterns.
- Keep responses concise (2-4 sentences for simple questions, more for analysis).
- Use currency symbols matching the data. Format numbers nicely.
- If you don't have enough data to answer, say so honestly.
- Never invent transactions or amounts that aren't in the data.
- Do NOT use markdown formatting (no **, no ##, no bullets with *). Use plain text only.`
}

async function sha1Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(text))
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')
}

interface UserData {
  summaryBlock: string
  recentTxBlock: string
}

async function fetchUserData(supabase: SupabaseClient, userId: string): Promise<UserData> {
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10)
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().slice(0, 10)
  const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().slice(0, 10)
  const prevMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0).toISOString().slice(0, 10)

  const { data: transactions } = await supabase
    .from('transactions')
    .select('amount, type, category, subcategory, description, date')
    .eq('user_id', userId)
    .gte('date', prevMonthStart)
    .lte('date', monthEnd)
    .order('date', { ascending: false })
    .limit(200)

  if (!transactions || transactions.length === 0) {
    return {
      summaryBlock: 'No transaction data available.',
      recentTxBlock: 'No recent transactions.',
    }
  }

  const currentMonth = transactions.filter((t: any) => t.date >= monthStart && t.date <= monthEnd)
  const prevMonth = transactions.filter((t: any) => t.date >= prevMonthStart && t.date < monthStart)

  const curIncome = currentMonth.filter((t: any) => t.type === 'income').reduce((s: number, t: any) => s + t.amount, 0)
  const curExpense = currentMonth.filter((t: any) => t.type === 'expense').reduce((s: number, t: any) => s + t.amount, 0)

  const catTotals: Record<string, number> = {}
  for (const t of currentMonth.filter((t: any) => t.type === 'expense')) {
    catTotals[t.category] = (catTotals[t.category] || 0) + t.amount
  }
  const catSummary = Object.entries(catTotals)
    .sort((a, b) => b[1] - a[1])
    .map(([cat, total]) => `  ${cat}: ${total.toFixed(2)}`)
    .join('\n')

  const prevIncome = prevMonth.filter((t: any) => t.type === 'income').reduce((s: number, t: any) => s + t.amount, 0)
  const prevExpense = prevMonth.filter((t: any) => t.type === 'expense').reduce((s: number, t: any) => s + t.amount, 0)

  const summaryBlock = `Current month (${monthStart} to ${monthEnd}):
  Total income: ${curIncome.toFixed(2)}
  Total expenses: ${curExpense.toFixed(2)}
  Balance: ${(curIncome - curExpense).toFixed(2)}
  Expenses by category:
${catSummary || '  (none)'}

Previous month (${prevMonthStart} to ${prevMonthEnd}):
  Total income: ${prevIncome.toFixed(2)}
  Total expenses: ${prevExpense.toFixed(2)}
  Balance: ${(prevIncome - prevExpense).toFixed(2)}`

  const recent = transactions.slice(0, 20)
  const recentTxBlock = recent
    .map((t: any) => `${t.date} | ${t.type} | ${t.category}${t.subcategory ? '/' + t.subcategory : ''} | ${t.amount.toFixed(2)}${t.description ? ' | ' + t.description : ''}`)
    .join('\n')

  return { summaryBlock, recentTxBlock }
}

/// Returns a Gemini cachedContents name if a fresh cache exists or was created.
/// Returns null if caching is not viable (e.g., content below Gemini's min token
/// threshold). Caller must fall back to inline systemInstruction in that case.
async function getOrCreateUserCache(
  supabase: SupabaseClient,
  userId: string,
  systemPrompt: string,
  summaryBlock: string,
  recentTxBlock: string,
): Promise<string | null> {
  const signature = await sha1Hex(`${systemPrompt}\n${summaryBlock}\n${recentTxBlock}`)

  const { data: existing } = await supabase
    .from('chat_user_context_cache')
    .select('cache_name, signature, expires_at')
    .eq('user_id', userId)
    .maybeSingle()

  const now = new Date()
  if (existing && existing.signature === signature && new Date(existing.expires_at) > now) {
    return existing.cache_name as string
  }

  if (existing) {
    // Fire-and-forget: free the stale Gemini cache so we don't keep paying for storage.
    fetch(`https://generativelanguage.googleapis.com/v1beta/${existing.cache_name}`, {
      method: 'DELETE',
      headers: { 'x-goog-api-key': GOOGLE_AI_KEY },
    }).catch(() => {})
  }

  const dataMessage = `User financial data:\n${summaryBlock}\n\nRecent transactions (last 20):\n${recentTxBlock}`

  const createRes = await fetch('https://generativelanguage.googleapis.com/v1beta/cachedContents', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': GOOGLE_AI_KEY },
    body: JSON.stringify({
      model: `models/${MODEL}`,
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: [
        { role: 'user', parts: [{ text: dataMessage }] },
        { role: 'model', parts: [{ text: 'Understood.' }] },
      ],
      ttl: `${CACHE_TTL_SECONDS}s`,
    }),
  })

  if (!createRes.ok) {
    // Most likely cause: content below Gemini's min cache size. Fall back to inline.
    return null
  }

  const cacheData = await createRes.json()
  const cacheName = cacheData?.name as string | undefined
  if (!cacheName) return null

  const expiresAt = new Date(Date.now() + CACHE_TTL_SECONDS * 1000).toISOString()

  await supabase
    .from('chat_user_context_cache')
    .upsert({
      user_id: userId,
      cache_name: cacheName,
      signature,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    })

  return cacheName
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── 1. Verify the user is authenticated ──────────────────────────────────
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders)

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError || !user) return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders)

  // ── 2. Verify PRO subscription ──────────────────────────────────────────
  const { data: sub } = await supabase
    .from('subscriptions')
    .select('expires_at')
    .eq('user_id', user.id)
    .single()

  if (!sub || new Date(sub.expires_at) < new Date()) {
    return jsonResponse({ error: 'PRO subscription required' }, 403, corsHeaders)
  }

  // ── 3. Rate limit: 20 msgs per hour ────────────────────────────────────
  const windowStart = new Date()
  windowStart.setMinutes(0, 0, 0)

  const { data: allowed, error: rateLimitError } = await supabase.rpc('increment_rate_limit', {
    p_user_id: user.id,
    p_endpoint: 'chat-transactions',
    p_window_start: windowStart.toISOString(),
    p_limit: 20,
  })

  if (rateLimitError || allowed === false) {
    return jsonResponse({ error: 'Rate limit exceeded. Maximum 20 messages per hour.' }, 429, corsHeaders)
  }

  // ── 4. Parse request body ──────────────────────────────────────────────
  let message: string
  let history: ChatMessage[]
  let locale: string
  try {
    const body = await req.json()
    message = body?.message
    const rawHistory = Array.isArray(body?.history) ? body.history : []
    locale = typeof body?.locale === 'string' ? body.locale.slice(0, 10) : 'es'
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      throw new Error('invalid')
    }
    if (message.length > 500) message = message.slice(0, 500)
    // Sanitise each history entry: clamp shape, types, and content length so a
    // malformed client cannot push arbitrary fields or massive strings into the
    // Gemini request body.
    history = rawHistory
      .filter((m: unknown): m is Record<string, unknown> =>
        m !== null && typeof m === 'object')
      .map((m: Record<string, unknown>): ChatMessage => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: typeof m.content === 'string' ? m.content.slice(0, 1000) : '',
      }))
      .filter((m: ChatMessage) => m.content.length > 0)
      .slice(-10)
  } catch {
    return jsonResponse({ error: 'Bad request: message is required' }, 400, corsHeaders)
  }

  if (!GOOGLE_AI_KEY) {
    return jsonResponse({ error: 'Server misconfiguration: GOOGLE_AI_KEY is not set' }, 500, corsHeaders)
  }

  // ── 5. Fetch user data + system prompt ────────────────────────────────
  const todayDate = new Date().toISOString().slice(0, 10)
  const systemPrompt = buildSystemPrompt(todayDate, locale)
  const { summaryBlock, recentTxBlock } = await fetchUserData(supabase, user.id)

  // ── 6. Try to use Gemini context caching ──────────────────────────────
  const cacheName = await getOrCreateUserCache(
    supabase,
    user.id,
    systemPrompt,
    summaryBlock,
    recentTxBlock,
  )

  // ── 7. Build conversation turns (history + current message) ───────────
  const turns: Array<{ role: string; parts: Array<{ text: string }> }> = []
  for (const msg of history) {
    turns.push({
      role: msg.role === 'user' ? 'user' : 'model',
      parts: [{ text: msg.content }],
    })
  }
  turns.push({ role: 'user', parts: [{ text: message }] })

  // ── 8. Call Gemini API ────────────────────────────────────────────────
  const requestBody: Record<string, unknown> = {
    contents: turns,
    generationConfig: { maxOutputTokens: 800, temperature: 0.7 },
  }

  if (cacheName) {
    requestBody.cachedContent = cacheName
  } else {
    // Fallback: inline system instruction + user data
    const inlineSystem = `${systemPrompt}\n\nUser financial data:\n${summaryBlock}\n\nRecent transactions (last 20):\n${recentTxBlock}`
    requestBody.systemInstruction = { parts: [{ text: inlineSystem }] }
  }

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': GOOGLE_AI_KEY },
      body: JSON.stringify(requestBody),
    },
  )

  if (!geminiRes.ok) {
    const geminiErr = await geminiRes.text()
    return jsonResponse({ error: `Gemini ${geminiRes.status}: ${geminiErr}` }, 502, corsHeaders)
  }

  const geminiData = await geminiRes.json()
  const text: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''

  return jsonResponse({ reply: text.trim() }, 200, corsHeaders)
})
