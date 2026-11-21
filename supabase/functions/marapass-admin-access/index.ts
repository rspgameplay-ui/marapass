import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const headers = { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" };
function respond(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers });
}
Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST" && request.method !== "GET") {
    return respond({ error: "method_not_allowed" }, 405);
  }
  const bearer = request.headers.get("Authorization");
  if (!bearer || !/^Bearer\s+[^\s]+$/i.test(bearer)) {
    return respond({ error: "unauthenticated" }, 401);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return respond({ error: "configuration_unavailable" }, 503);
  const privateHeaders = { "apikey": anon, "Authorization": bearer, "Content-Type": "application/json" };
  try {
    // Auth verifies the JWT independently of untrusted request-body fields.
    const authResponse = await fetch(url + "/auth/v1/user", {
      method: "GET", headers: privateHeaders, signal: AbortSignal.timeout(8000),
    });
    if (!authResponse.ok) return respond({ error: "invalid_session" }, 401);
    const user = await authResponse.json();
    if (!user?.id || !user?.email_confirmed_at) {
      return respond({ error: "unverified_identity" }, 403);
    }
    // Uses the caller's JWT, never the service_role credential. RLS restricts rows.
    const roleResponse = await fetch(url + "/rest/v1/rpc/my_access_context", {
      method: "POST", headers: privateHeaders, body: "{}", signal: AbortSignal.timeout(8000),
    });
    if (!roleResponse.ok) return respond({ error: "access_check_unavailable" }, 503);
    const rows = await roleResponse.json();
    const context = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    if (!context || context.user_id !== user.id) {
      return respond({ error: "access_context_mismatch" }, 403);
    }
    const admin = context.admin_role === true;
    const mfa = context.mfa_verified === true;
    const ready = admin && mfa && context.admin_console_ready === true;
    return respond({
      authenticated: true,
      role: admin ? "admin" : (context.partner_owner || context.partner_manager || context.partner_validator) ? "partner" : "tourist",
      adminRole: admin,
      mfaVerified: mfa,
      adminConsoleReady: ready,
      nextAction: admin && !mfa ? "enroll_or_verify_totp" : ready ? "enter_admin" : "continue_standard",
    });
  } catch (_error) {
    // Never return JWTs, credential material or database internals.
    return respond({ error: "access_service_unavailable" }, 503);
  }
});
