import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import * as Sentry from 'npm:@sentry/deno'
import { getCorsHeaders, jsonResponse } from '../_shared/http.ts'
import { requireProUser } from '../_shared/auth.ts'
import { checkRateLimit } from '../_shared/rate_limit.ts'
import { callGemini } from '../_shared/gemini.ts'

const GOOGLE_AI_KEY = Deno.env.get('GOOGLE_AI_KEY') ?? ''
const MODEL = 'gemini-2.5-flash-lite'

Sentry.init({
  dsn: Deno.env.get('SENTRY_DSN_EDGE') ?? '',
  environment: Deno.env.get('SENTRY_ENVIRONMENT') ?? 'production',
  tracesSampleRate: 0.2,
})

const ALLOWED_MIME_TYPES = ['audio/wav', 'audio/mp3', 'audio/aac', 'audio/ogg', 'audio/flac', 'audio/aiff']
const MAX_BASE64_LENGTH = 8_000_000 // ~6 MB raw audio; client caps recordings to ~20s of 16kHz mono WAV
const MAX_SUBCATEGORY_ROWS = 200
const MAX_SUBCATEGORY_FIELD_LENGTH = 50
const LOCAL_DATE_RE = /^\d{4}-\d{2}-\d{2}$/

const SYSTEM_INSTRUCTION = `You are a transaction parser for a personal finance app.
You will receive a short voice recording of a user (speaking Spanish, English, French or German)
describing a transaction. Transcribe it mentally, then extract the transaction details.

Available expense categories: Comida, Transporte, Vivienda, Ocio, Salud, Educación, Ropa, Tecnología, Otros
Available income categories: Salario, Freelance, Inversión, Regalo, Otros

Return ONLY valid JSON (no explanation):
{"amount": <positive number>, "type": "expense" or "income", "category": "<exact category name>", "subcategory": "<subcategory or null>", "is_new_subcategory": <boolean>, "description": "<brief description or empty string>", "date": "<YYYY-MM-DD or null>", "is_recurring": <boolean>, "recurrence_type": "<weekly|monthly|annual or null>"}

Rules:
- amount must be a positive number
- If type is ambiguous, default to "expense"
- Pick the closest matching category; use "Otros" if unclear
- Think of the transaction in 3 levels of detail:
  1. category: the main theme (e.g. "Comida" for dining out)
  2. subcategory: PRIORITY — if the user explicitly says "subcategoría [name]" or "subcategory [name]", use that name exactly as the subcategory. Otherwise use the second most descriptive element (e.g. "Cena" for dinner). First try to match one of the user's existing subcategories for the detected category. If none match but the audio implies one, suggest a concise new name (max 30 chars). If nothing is implied, use null.
  3. description: the third level of detail if present (e.g. "Mexicano" for Mexican food). Should be concise (max 50 chars), in the same language the user spoke. If no extra detail beyond category and subcategory, use empty string.
- is_new_subcategory: true if you are suggesting a subcategory not in the user's existing list, false if matching an existing one, false if subcategory is null
- date: if the user mentions a date (e.g. "ayer", "el lunes", "yesterday", "last week"), resolve it relative to today and return in YYYY-MM-DD format. If no date is mentioned, return null.
- is_recurring: true if the user mentions the transaction is recurring (e.g. "recurrente", "cada mes", "cada semana", "mensual", "semanal", "anual", "every month"). Default false.
- recurrence_type: if is_recurring is true, detect the frequency: "weekly", "monthly" (or just "recurring"/"recurrente" with no frequency), "annual". If is_recurring is false, return null.
- If the audio contains no discernible transaction (silence, noise, unrelated speech), return: {"amount": 0, "type": "expense", "category": "Otros", "subcategory": null, "is_new_subcategory": false, "description": "", "date": null, "is_recurring": false, "recurrence_type": null}
- Example: "He salido a cenar mexicano" → category: "Comida", subcategory: "Cena", description: "Mexicano", date: null, is_recurring: false, recurrence_type: null`

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

/// Filters to plain objects and coerces every field to a short string,
/// mirroring chat-transactions' `history` sanitiser — a client-supplied
/// array is otherwise a crash (non-object rows) and cost/injection vector
/// (unbounded row count / field length) straight into the Gemini prompt.
function sanitizeSubcategories(
  raw: unknown,
): Array<{ category: string; type: string; name: string }> {
  if (!Array.isArray(raw)) return []
  return raw
    .filter((row): row is Record<string, unknown> => row !== null && typeof row === 'object')
    .slice(0, MAX_SUBCATEGORY_ROWS)
    .map((row) => ({
      category: String(row.category ?? '').slice(0, MAX_SUBCATEGORY_FIELD_LENGTH),
      type: String(row.type ?? '').slice(0, MAX_SUBCATEGORY_FIELD_LENGTH),
      name: String(row.name ?? '').slice(0, MAX_SUBCATEGORY_FIELD_LENGTH),
    }))
    .filter((row) => row.category && row.type && row.name)
}

serve(async (req: Request) => {
  try {
  const corsHeaders = getCorsHeaders(req)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── 1. Verify the user is authenticated and PRO ──────────────────────────
  const authed = await requireProUser(req, corsHeaders)
  if (authed instanceof Response) return authed
  const { supabase, user } = authed

  // ── 2. Check rate limit ───────────────────────────────────────────────────
  const windowStart = new Date()
  windowStart.setSeconds(0, 0)

  const allowed = await checkRateLimit(supabase, user.id, 'parse-voice', 7, windowStart)
  if (!allowed) {
    return jsonResponse({ error: 'Rate limit exceeded. Maximum 7 requests per minute.' }, 429, corsHeaders)
  }

  // ── 3. Validate request body ──────────────────────────────────────────────
  let audioBase64: string
  let mimeType: string
  let localDate: string | null = null
  let clientSubcategories: Array<{ category: string; type: string; name: string }> | null = null

  try {
    const body = await req.json()
    audioBase64 = body?.audio_base64
    mimeType = body?.mime_type
    if (!audioBase64 || typeof audioBase64 !== 'string') throw new Error('missing audio')
    if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) throw new Error('invalid mime')
    if (audioBase64.length > MAX_BASE64_LENGTH) throw new Error('audio too large')
    if (typeof body?.local_date === 'string' && LOCAL_DATE_RE.test(body.local_date)) {
      localDate = body.local_date
    }
    if (body?.subcategories !== undefined) clientSubcategories = sanitizeSubcategories(body.subcategories)
  } catch {
    return jsonResponse({ error: 'Bad request: audio_base64 and mime_type are required' }, 400, corsHeaders)
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
    return jsonResponse({ error: 'Server misconfiguration: GOOGLE_AI_KEY is not set' }, 500, corsHeaders)
  }

  // Prefer the device's local date (so "ayer"/"yesterday" resolves against
  // the user's own calendar day) and only fall back to the server's UTC
  // date for older clients that don't send one yet.
  const todayDate = localDate ?? new Date().toISOString().slice(0, 10)
  const userMessage = `Today's date is ${todayDate}.

User's existing subcategories:
${subcatBlock}

Analyze the attached audio recording and extract the transaction.`

  const geminiRes = await callGemini(MODEL, GOOGLE_AI_KEY, {
    systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [
      {
        role: 'user',
        parts: [
          { inlineData: { mimeType, data: audioBase64 } },
          { text: userMessage },
        ],
      },
    ],
    generationConfig: { maxOutputTokens: 250, temperature: 0 },
  })

  if (!geminiRes.ok) {
    const geminiErr = await geminiRes.text()
    Sentry.captureMessage(`Gemini error ${geminiRes.status}: ${geminiErr}`, 'error')
    console.error(`Gemini error ${geminiRes.status}:`, geminiErr)
    return jsonResponse({ error: 'AI service temporarily unavailable. Please try again.' }, 502, corsHeaders)
  }

  // ── 6. Return only the parsed result to the client ────────────────────────
  const geminiData = await geminiRes.json()
  let text: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()

  return jsonResponse({ result: text }, 200, corsHeaders)
  } catch (error) {
    Sentry.captureException(error)
    console.error('parse-voice-transaction unhandled error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, getCorsHeaders(req))
  }
})
