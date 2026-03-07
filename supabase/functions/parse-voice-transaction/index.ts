import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_KEY = Deno.env.get('GOOGLE_AI_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const PROMPT_TEMPLATE = `You are a transaction parser for a personal finance app.
Extract transaction details from this text (may be in Spanish or English):
"{transcription}"

Available expense categories: Comida, Transporte, Vivienda, Ocio, Salud, Educación, Ropa, Tecnología, Otros
Available income categories: Salario, Freelance, Inversión, Regalo, Otros

Return ONLY valid JSON (no explanation):
{"amount": <positive number>, "type": "expense" or "income", "category": "<exact category name>", "description": "<brief description or empty string>"}

Rules:
- amount must be a positive number
- If type is ambiguous, default to "expense"
- Pick the closest matching category; use "Otros" if unclear
- description should be concise (max 50 chars)`

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
  let transcription: string
  try {
    const body = await req.json()
    transcription = body?.transcription
    if (!transcription || typeof transcription !== 'string' || transcription.trim().length === 0) {
      throw new Error('invalid')
    }
    // Limit input size to avoid abuse
    if (transcription.length > 500) {
      transcription = transcription.slice(0, 500)
    }
  } catch {
    return new Response(
      JSON.stringify({ error: 'Bad request: transcription is required' }),
      { status: 400, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  // ── 3. Call Gemini API (key stays server-side) ────────────────────────────
  if (!GOOGLE_AI_KEY) {
    return new Response(
      JSON.stringify({ error: 'Server misconfiguration: GOOGLE_AI_KEY is not set' }),
      { status: 500, headers: { ...corsHeaders, 'content-type': 'application/json' } }
    )
  }

  const prompt = PROMPT_TEMPLATE.replace('{transcription}', transcription)

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-8b:generateContent?key=${GOOGLE_AI_KEY}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
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

  // ── 4. Return only the parsed result to the client ────────────────────────
  const geminiData = await geminiRes.json()
  let text: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''

  // Strip markdown code fences Gemini sometimes adds (```json ... ```)
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()

  return new Response(
    JSON.stringify({ result: text }),
    { status: 200, headers: { ...corsHeaders, 'content-type': 'application/json' } }
  )
})
