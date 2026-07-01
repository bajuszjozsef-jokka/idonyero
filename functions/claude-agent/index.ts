// ============================================================================
// Időnyerő – Claude API proxy (Supabase Edge Function)
// ============================================================================
// Ez a függvény tartja titokban az Anthropic API kulcsot: a böngészőben futó
// kód SOHA nem éri el közvetlenül a Claude API-t, csak ezt a proxyt hívja.
// Az ANTHROPIC_API_KEY-t a Supabase projekt "Edge Function Secrets" alatt
// kell beállítani (supabase secrets set ANTHROPIC_API_KEY=sk-ant-...).
// ============================================================================

const ALLOWED_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_VERSION = "2023-06-01";
const MAX_TOKENS_CAP = 16000;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return jsonResponse({ error: "Server misconfigured: ANTHROPIC_API_KEY is not set" }, 500);
  }

  let body: {
    system?: string;
    messages?: unknown[];
    tools?: unknown[];
    max_tokens?: number;
    model?: string;
  };

  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonResponse({ error: "`messages` is required and must be a non-empty array" }, 400);
  }

  // Csak az engedélyezett modell hívható a proxyn keresztül (költség- és
  // visszaélés-védelem). Ha a kliens mást küld, felülírjuk.
  const model = body.model === ALLOWED_MODEL ? body.model : ALLOWED_MODEL;
  const max_tokens = Math.min(Number(body.max_tokens) || 4000, MAX_TOKENS_CAP);

  const payload: Record<string, unknown> = {
    model,
    max_tokens,
    messages: body.messages,
  };
  if (body.system) payload.system = body.system;
  if (Array.isArray(body.tools) && body.tools.length > 0) payload.tools = body.tools;

  try {
    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(payload),
    });

    const data = await anthropicRes.json();
    return jsonResponse(data, anthropicRes.status);
  } catch (err) {
    return jsonResponse({ error: "Failed to reach Claude API", detail: String(err) }, 502);
  }
});
