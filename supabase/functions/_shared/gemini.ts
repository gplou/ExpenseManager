/// Calls a Gemini `generateContent` endpoint with a hard abort timeout.
/// Callers are responsible for checking `res.ok` and mapping errors — the
/// exact error/retry handling differs enough between callers (e.g. context
/// caching fallback) that it isn't forced into this shared helper.
export async function callGemini(
  model: string,
  apiKey: string,
  body: Record<string, unknown>,
  timeoutMs = 25_000,
): Promise<Response> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify(body),
        signal: controller.signal,
      },
    )
  } finally {
    clearTimeout(timeoutId)
  }
}
