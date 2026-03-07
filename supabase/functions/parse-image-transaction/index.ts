import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CLAUDE_API_KEY = Deno.env.get('CLAUDE_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
const MAX_BASE64_LENGTH = 5_600_000 // ~4 MB in base64

const TEXT_PROMPT = `You are a transaction parser for a personal finance app.
Analyze this image (receipt, invoice, price tag, or bill).
Extract the main transaction details visible.

Available expense categories: Comida, Transporte, Vivienda, Ocio, Salud, Educación, Ropa, Tecnología, Otros
Available income categories: Salario, Freelance, Inversión, Regalo, Otros

Return ONLY valid JSON (no explanation):
{"amount": <positive number>, "type": "expense" or "income", "category": "<exact category name>", "description": "<brief description or empty string>"}

Rules:
- amount must be a positive number (the total/final amount)
- If type is ambiguous, default to "expense"
- Pick the closest matching category; use "Otros" if unclear
- description should be concise (max 50 chars)
- If no transaction is visible, return: {"amount": 0, "type": "expense", "category": "Otros", "description": ""}`

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

serve(async (req: Request) => {
  // Handle CORS preflight
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

  // ── 2. Validate request body ──────────────────────────────────────────────
  let imageBase64: string
  let mimeType: string

  try {
    const body = await req.json()
    imageBase64 = body?.image_base64
    mimeType = body?.mime_type

    if (!imageBase64 || typeof imageBase64 !== 'string') throw new Error('missing image')
    if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) throw new Error('invalid mime')
    if (imageBase64.length > MAX_BASE64_LENGTH) throw new Error('image too large')
  } catch {
    return new Response(
      JSON.stringify({ error: 'Bad request: image_base64 and mime_type are required' }),
      { status: 400, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 3. Call Claude API (key stays server-side) ────────────────────────────
  if (!CLAUDE_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'Server misconfiguration: CLAUDE_API_KEY is not set' }),
      { status: 500, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': CLAUDE_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 300,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mimeType,
                data: imageBase64,
              },
            },
            { type: 'text', text: TEXT_PROMPT },
          ],
        },
      ],
    }),
  })

  if (!claudeRes.ok) {
    const claudeErr = await claudeRes.text()
    return new Response(
      JSON.stringify({ error: `Claude ${claudeRes.status}: ${claudeErr}` }),
      { status: 502, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 4. Return only the parsed result to the client ────────────────────────
  const claudeData = await claudeRes.json()
  let text: string = claudeData?.content?.[0]?.text ?? ''

  // Strip markdown code fences Claude sometimes adds (```json ... ```)
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()

  return new Response(
    JSON.stringify({ result: text }),
    { status: 200, headers: { ...corsHeaders, 'content-type': 'application/json' } }
  )
})
