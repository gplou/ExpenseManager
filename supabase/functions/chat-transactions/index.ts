import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_KEY = Deno.env.get('GOOGLE_AI_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  })
}

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
}

function buildSystemPrompt(
  summaryBlock: string,
  recentTxBlock: string,
  todayDate: string,
  locale: string,
): string {
  const lang = locale.startsWith('es') ? 'Spanish'
    : locale.startsWith('fr') ? 'French'
    : locale.startsWith('de') ? 'German'
    : 'English'

  return `You are a friendly and concise financial assistant inside a personal finance app.
The user's preferred language is ${lang}. Always reply in ${lang}.
Today's date is ${todayDate}.

Here is a summary of the user's financial data:
${summaryBlock}

Recent transactions (last 20):
${recentTxBlock}

Rules:
- Answer questions about the user's spending, income, budgets, and categories.
- Use the data above to give specific, accurate answers with real numbers.
- When comparing periods, be clear about the time ranges.
- Give practical, actionable savings tips based on their actual spending patterns.
- Keep responses concise (2-4 sentences for simple questions, more for analysis).
- Use currency symbols matching the data. Format numbers nicely.
- If you don't have enough data to answer, say so honestly.
- Never invent transactions or amounts that aren't in the data.
- Do NOT use markdown formatting (no **, no ##, no bullets with *). Use plain text only.`
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── 1. Verify the user is authenticated ──────────────────────────────────
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401)

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError || !user) return jsonResponse({ error: 'Unauthorized' }, 401)

  // ── 2. Verify PRO subscription ──────────────────────────────────────────
  const { data: sub } = await supabase
    .from('subscriptions')
    .select('expires_at')
    .eq('user_id', user.id)
    .single()

  if (!sub || new Date(sub.expires_at) < new Date()) {
    return jsonResponse({ error: 'PRO subscription required' }, 403)
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
    return jsonResponse({ error: 'Rate limit exceeded. Maximum 20 messages per hour.' }, 429)
  }

  // ── 4. Parse request body ──────────────────────────────────────────────
  let message: string
  let history: ChatMessage[]
  let locale: string
  try {
    const body = await req.json()
    message = body?.message
    history = body?.history ?? []
    locale = body?.locale ?? 'es'
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      throw new Error('invalid')
    }
    if (message.length > 500) message = message.slice(0, 500)
    // Keep only last 10 history messages to limit token usage
    if (history.length > 10) history = history.slice(-10)
  } catch {
    return jsonResponse({ error: 'Bad request: message is required' }, 400)
  }

  // ── 5. Fetch user's financial data ─────────────────────────────────────
  const todayDate = new Date().toISOString().slice(0, 10)

  // Get current month boundaries
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10)
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().slice(0, 10)

  // Previous month
  const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().slice(0, 10)
  const prevMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0).toISOString().slice(0, 10)

  // Fetch transactions for current + previous month
  const { data: transactions } = await supabase
    .from('transactions')
    .select('amount, type, category, subcategory, description, date')
    .eq('user_id', user.id)
    .gte('date', prevMonthStart)
    .lte('date', monthEnd)
    .order('date', { ascending: false })
    .limit(200)

  let summaryBlock = 'No transaction data available.'
  let recentTxBlock = 'No recent transactions.'

  if (transactions && transactions.length > 0) {
    // Split into current/previous month
    const currentMonth = transactions.filter((t: any) => t.date >= monthStart && t.date <= monthEnd)
    const prevMonth = transactions.filter((t: any) => t.date >= prevMonthStart && t.date < monthStart)

    // Aggregate current month
    const curIncome = currentMonth.filter((t: any) => t.type === 'income').reduce((s: number, t: any) => s + t.amount, 0)
    const curExpense = currentMonth.filter((t: any) => t.type === 'expense').reduce((s: number, t: any) => s + t.amount, 0)

    // Aggregate by category (current month expenses)
    const catTotals: Record<string, number> = {}
    for (const t of currentMonth.filter((t: any) => t.type === 'expense')) {
      catTotals[t.category] = (catTotals[t.category] || 0) + t.amount
    }
    const catSummary = Object.entries(catTotals)
      .sort((a, b) => b[1] - a[1])
      .map(([cat, total]) => `  ${cat}: ${total.toFixed(2)}`)
      .join('\n')

    // Aggregate previous month
    const prevIncome = prevMonth.filter((t: any) => t.type === 'income').reduce((s: number, t: any) => s + t.amount, 0)
    const prevExpense = prevMonth.filter((t: any) => t.type === 'expense').reduce((s: number, t: any) => s + t.amount, 0)

    summaryBlock = `Current month (${monthStart} to ${monthEnd}):
  Total income: ${curIncome.toFixed(2)}
  Total expenses: ${curExpense.toFixed(2)}
  Balance: ${(curIncome - curExpense).toFixed(2)}
  Expenses by category:
${catSummary || '  (none)'}

Previous month (${prevMonthStart} to ${prevMonthEnd}):
  Total income: ${prevIncome.toFixed(2)}
  Total expenses: ${prevExpense.toFixed(2)}
  Balance: ${(prevIncome - prevExpense).toFixed(2)}`

    // Recent 20 transactions
    const recent = transactions.slice(0, 20)
    recentTxBlock = recent
      .map((t: any) => `${t.date} | ${t.type} | ${t.category}${t.subcategory ? '/' + t.subcategory : ''} | ${t.amount.toFixed(2)}${t.description ? ' | ' + t.description : ''}`)
      .join('\n')
  }

  // ── 6. Call Gemini API ─────────────────────────────────────────────────
  if (!GOOGLE_AI_KEY) {
    return jsonResponse({ error: 'Server misconfiguration: GOOGLE_AI_KEY is not set' }, 500)
  }

  const systemPrompt = buildSystemPrompt(summaryBlock, recentTxBlock, todayDate, locale)

  // Build conversation contents for Gemini
  const contents: Array<{ role: string; parts: Array<{ text: string }> }> = []

  // System instruction as first user message
  contents.push({ role: 'user', parts: [{ text: systemPrompt }] })
  contents.push({ role: 'model', parts: [{ text: 'Understood. I\'m ready to help with your finances.' }] })

  // Add conversation history
  for (const msg of history) {
    contents.push({
      role: msg.role === 'user' ? 'user' : 'model',
      parts: [{ text: msg.content }],
    })
  }

  // Add current message
  contents.push({ role: 'user', parts: [{ text: message }] })

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GOOGLE_AI_KEY}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        contents,
        generationConfig: { maxOutputTokens: 800, temperature: 0.7 },
      }),
    },
  )

  if (!geminiRes.ok) {
    const geminiErr = await geminiRes.text()
    return jsonResponse({ error: `Gemini ${geminiRes.status}: ${geminiErr}` }, 502)
  }

  const geminiData = await geminiRes.json()
  const text: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''

  return jsonResponse({ reply: text.trim() })
})
