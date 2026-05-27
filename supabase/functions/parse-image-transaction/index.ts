import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as Sentry from 'npm:@sentry/deno'

const GOOGLE_AI_KEY = Deno.env.get('GOOGLE_AI_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

Sentry.init({
  dsn: Deno.env.get('SENTRY_DSN_EDGE') ?? '',
  environment: Deno.env.get('SENTRY_ENVIRONMENT') ?? 'production',
  tracesSampleRate: 0.2,
})

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
const MAX_BASE64_LENGTH = 5_600_000 // ~4 MB in base64

const SYSTEM_INSTRUCTION = `You are a transaction parser for a personal finance app.
Analyze images (receipts, invoices, price tags, bills) and extract the main transaction details.

Available expense categories: Comida, Transporte, Vivienda, Ocio, Salud, Educación, Ropa, Tecnología, Otros
Available income categories: Salario, Freelance, Inversión, Regalo, Otros

Return ONLY valid JSON (no explanation):
{"amount": <positive number>, "type": "expense" or "income", "category": "<exact category name>", "subcategory": "<subcategory or null>", "is_new_subcategory": <boolean>, "description": "<brief description or empty string>"}

Rules:
- amount must be a positive number (the total/final amount)
- If type is ambiguous, default to "expense"
- Pick the closest matching category; use "Otros" if unclear
- Think of the transaction in 3 levels of detail:
  1. category: the main theme (e.g. "Comida" for a restaurant receipt)
  2. subcategory: the second most descriptive element (e.g. "Cena" for a dinner receipt). First try to match one of the user's existing subcategories for the detected category. If none match but the image implies one, suggest a concise new name (max 30 chars). If nothing is implied, use null.
  3. description: the third level of detail if present (e.g. "Mexicano" for a Mexican restaurant). Should be concise (max 50 chars). If no extra detail beyond category and subcategory, use empty string.
- is_new_subcategory: true if you are suggesting a subcategory not in the user's existing list, false if matching an existing one, false if subcategory is null
- If no transaction is visible, return: {"amount": 0, "type": "expense", "category": "Otros", "subcategory": null, "is_new_subcategory": false, "description": ""}`

function buildSubcatBlock(subcategories: Array<{ category: string; type: string; name: string }> | null): string {
  if (!subcategories || subcategories.length === 0) return 'None yet.'
  const map: Record<string, string[]> = {}
  for (const row of subcategories) {
    const key = `${row.type} - ${row.category}`
    if (!map[key]) map[key] = []
    map[key].push(row.name)
  }
  return Object.entries(map).map(([k, v]) => `${k}: ${v.join(', ')}`).join('\n')
}

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? ''

function getCorsHeaders(req: Request) {
  const origin = req.headers.get('Origin') ?? ''
  const allowOrigin = (ALLOWED_ORIGIN && origin === ALLOWED_ORIGIN) ? origin : ''
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

serve(async (req: Request) => {
  try {
  const corsHeaders = getCorsHeaders(req)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── 1. Verify the user is authenticated ──────────────────────────────────
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 2. Check rate limit ───────────────────────────────────────────────────
  const windowStart = new Date()
  windowStart.setSeconds(0, 0)

  const { data: allowed, error: rateLimitError } = await supabase.rpc('increment_rate_limit', {
    p_user_id: user.id,
    p_endpoint: 'parse-image',
    p_window_start: windowStart.toISOString(),
    p_limit: 7,
  })

  if (rateLimitError || allowed === false) {
    return new Response(
      JSON.stringify({ error: 'Rate limit exceeded. Maximum 7 requests per minute.' }),
      { status: 429, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 3. Validate request body ──────────────────────────────────────────────
  let imageBase64: string
  let mimeType: string
  let clientSubcategories: Array<{ category: string; type: string; name: string }> | null = null

  try {
    const body = await req.json()
    imageBase64 = body?.image_base64
    mimeType = body?.mime_type
    if (!imageBase64 || typeof imageBase64 !== 'string') throw new Error('missing image')
    if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) throw new Error('invalid mime')
    if (imageBase64.length > MAX_BASE64_LENGTH) throw new Error('image too large')
    if (Array.isArray(body?.subcategories)) clientSubcategories = body.subcategories
  } catch {
    return new Response(
      JSON.stringify({ error: 'Bad request: image_base64 and mime_type are required' }),
      { status: 400, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 4. Resolve subcategories (client-sent or DB fallback) ─────────────────
  let subcatBlock = 'None yet.'
  if (clientSubcategories !== null) {
    subcatBlock = buildSubcatBlock(clientSubcategories)
  } else {
    try {
      const { data: subcatRows } = await supabase
        .from('subcategories')
        .select('category, type, name')
        .eq('user_id', user.id)
      subcatBlock = buildSubcatBlock(subcatRows ?? [])
    } catch {
      // proceed without subcategories
    }
  }

  // ── 5. Call Gemini API ────────────────────────────────────────────────────
  if (!GOOGLE_AI_KEY) {
    return new Response(
      JSON.stringify({ error: 'Server misconfiguration: GOOGLE_AI_KEY is not set' }),
      { status: 500, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  const userMessage = `User's existing subcategories:\n${subcatBlock}\n\nAnalyze the attached image and extract the transaction.`

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': GOOGLE_AI_KEY },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
        contents: [
          {
            role: 'user',
            parts: [
              { inlineData: { mimeType, data: imageBase64 } },
              { text: userMessage },
            ],
          },
        ],
        generationConfig: { maxOutputTokens: 200, temperature: 0 },
      }),
    }
  )

  if (!geminiRes.ok) {
    const geminiErr = await geminiRes.text()
    return new Response(
      JSON.stringify({ error: `Gemini ${geminiRes.status}: ${geminiErr}` }),
      { status: 502, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 6. Return only the parsed result to the client ────────────────────────
  const geminiData = await geminiRes.json()
  let text: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()

  return new Response(
    JSON.stringify({ result: text }),
    { status: 200, headers: { ...corsHeaders, 'content-type': 'application/json' } }
  )
  } catch (error) {
    Sentry.captureException(error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    })
  }
})
