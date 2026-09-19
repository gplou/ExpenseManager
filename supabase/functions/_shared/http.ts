const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? ''

export function getCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? ''
  const allowOrigin = (ALLOWED_ORIGIN && origin === ALLOWED_ORIGIN) ? origin : ''
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  corsHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  })
}
