import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const turnKeyId = Deno.env.get("CLOUDFLARE_TURN_KEY_ID");
    const turnApiToken = Deno.env.get("CLOUDFLARE_TURN_API_TOKEN");

    if (!supabaseUrl || !anonKey) return json({ error: "Supabase function configuration is incomplete" }, 500);
    if (!turnKeyId || !turnApiToken) return json({ error: "TURN service is not configured" }, 503);

    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Invalid authentication token" }, 401);

    const body = await req.json().catch(() => ({}));
    const requestedTtl = Number(body?.ttl);
    const ttl = Math.min(86400, Math.max(300, Number.isFinite(requestedTtl) ? requestedTtl : 3600));

    const cf = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(turnKeyId)}/credentials/generate`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${turnApiToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl }),
      },
    );

    if (!cf.ok) {
      const detail = await cf.text().catch(() => "");
      console.error("Cloudflare TURN request failed", cf.status, detail);
      return json({ error: "TURN provider rejected the credential request" }, 502);
    }

    const data = await cf.json();
    if (!Array.isArray(data?.iceServers) || data.iceServers.length === 0) {
      return json({ error: "TURN provider returned no ICE servers" }, 502);
    }

    return json({
      iceServers: data.iceServers,
      expiresIn: ttl,
      userId: user.id,
    });
  } catch (error) {
    console.error("turn-credentials failed", error);
    return json({ error: "Unable to create TURN credentials" }, 500);
  }
});
