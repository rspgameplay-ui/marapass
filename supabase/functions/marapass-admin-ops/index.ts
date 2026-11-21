import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";

/**
 * MaraPass MVP / Admin operations bridge.
 * Trusted auth.uid is verified with Auth, then authorization with current
 * RLS-aware my_access_context() using the caller's own JWT/AAL2.
 * service_role credential NEVER crosses the browser boundary.
 */
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Max-Age": "600",
};
const responseHeaders = {
  ...cors,
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
};
type JsonValue = Record<string, unknown>;
function reply(status: number, data: JsonValue) {
  return new Response(JSON.stringify(data), { status, headers: responseHeaders });
}
function uuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
function cleanName(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new Error("invalid_name");
  const normalized = value.trim();
  if (!normalized) return null;
  if (normalized.length > 160) throw new Error("invalid_name");
  return normalized;
}
async function internalFetch(url: string, init: RequestInit) {
  return await fetch(url, { ...init, signal: AbortSignal.timeout(12000) });
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const bearer = req.headers.get("authorization") || "";
  if (!/^Bearer [^\s]+$/i.test(bearer)) return reply(401, { error: "unauthenticated" });
  const contentType = req.headers.get("content-type") || "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return reply(415, { error: "json_required" });
  }
  const contentLength = Number(req.headers.get("content-length") || 0);
  if (contentLength > 4096) return reply(413, { error: "payload_too_large" });
  const supa = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supa || !anon || !service) return reply(503, { error: "server_not_ready" });

  let body: JsonValue;
  try {
    const raw = await req.text();
    if (raw.length > 4096) return reply(413, { error: "payload_too_large" });
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return reply(400, { error: "invalid_request" });
    }
    body = parsed as JsonValue;
  } catch {
    return reply(400, { error: "invalid_json" });
  }
  const action = body.action;
  let rpcName: string;
  let args: Record<string, unknown>;
  if (action === "review_partner_application") {
    if (!uuid(body.applicationId) || (body.decision !== "approved" && body.decision !== "rejected")) {
      return reply(400, { error: "invalid_application_or_decision" });
    }
    try {
      args = {
        p_application_id: body.applicationId,
        p_decision: body.decision,
        p_legal_name: cleanName(body.legalName),
        p_trade_name: cleanName(body.tradeName),
      };
    } catch {
      return reply(400, { error: "invalid_partner_name" });
    }
    rpcName = "review_partner_application";
  } else if (action === "set_establishment_publication") {
    if (!uuid(body.establishmentId) || typeof body.publish !== "boolean") {
      return reply(400, { error: "invalid_establishment_or_visibility" });
    }
    rpcName = "review_establishment_publication";
    args = { p_establishment_id: body.establishmentId, p_publish: body.publish };
  } else if (action === "register_direct_company") {
    const categories = new Set(["tours","nature","culture","gastronomy","lodging","events","crafts","photography","tourist_transport","services"]);
    try {
      const legal = cleanName(body.legalName);
      const trade = cleanName(body.tradeName);
      const city = cleanName(body.city);
      const email = typeof body.contactEmail === "string" ? body.contactEmail.trim().toLowerCase() : "";
      const phone = body.contactPhone == null ? null : String(body.contactPhone).trim();
      const tax = body.taxId == null ? null : String(body.taxId).replace(/[^0-9]/g, "") || null;
      if (!legal || legal.length < 2 || !trade || trade.length < 2 || !city || city.length < 2 || city.length > 120
         || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254
         || !categories.has(body.category)
         || (phone !== null && phone.length > 32)
         || (tax !== null && tax.length !== 14)) {
        return reply(400, { error: "invalid_company_details" });
      }
      rpcName = uuid(body.requestId)
        ? "admin_register_direct_company_once"
        : "admin_register_direct_company";
      args = {
        p_legal_name: legal, p_trade_name: trade, p_contact_email: email,
        p_city: city, p_category: body.category, p_contact_phone: phone || null,
        p_tax_id: tax,
        ...(rpcName === "admin_register_direct_company_once" ? { p_request_key: body.requestId } : {})
      };
    } catch {
      return reply(400, { error: "invalid_company_details" });
    }
  } else if (action === "create_commercial_offer") {
    if (!body.rules || typeof body.rules !== "object" || Array.isArray(body.rules)) {
      return reply(400, { error: "invalid_commercial_rules" });
    }
    rpcName = "mp_admin_create_offer";
    args = { p_data: body.rules };
  } else if (action === "create_passport_draft") {
    if (!body.rules || typeof body.rules !== "object" || Array.isArray(body.rules)) {
      return reply(400, { error: "invalid_passport_rules" });
    }
    rpcName = "mp_admin_create_passport_draft";
    args = { p_data: body.rules };
  } else if (action === "attach_passport_benefit") {
    if (!uuid(body.productId) || !uuid(body.offerId)
      || !Number.isInteger(body.issueDays) || !Number.isInteger(body.convertDays)
      || !Number.isInteger(body.useDays) || !Number.isInteger(body.maxPerHolder)
      || body.issueDays < 1 || body.convertDays < body.issueDays
      || body.useDays < body.convertDays || body.useDays > 730
      || body.maxPerHolder < 1 || body.maxPerHolder > 20
      || typeof body.bookingRequired !== "boolean") {
      return reply(400, { error: "invalid_benefit_windows" });
    }
    rpcName = "mp_admin_attach_passport_benefit";
    args = {
      p_product_id: body.productId, p_offer_id: body.offerId,
      p_issue_days: body.issueDays, p_convert_days: body.convertDays,
      p_use_days: body.useDays, p_max_per_holder: body.maxPerHolder,
      p_booking_required: body.bookingRequired,
    };
  } else if (action === "publish_passport") {
    if (!uuid(body.productId)) return reply(400, { error: "invalid_passport_id" });
    rpcName = "mp_admin_publish_passport";
    args = { p_product_id: body.productId };
  } else if (action === "invite_developer") {
    const e=typeof body.email==="string" ? body.email.trim().toLowerCase() : "";
    if(e.length>254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) {
      return reply(400,{error:"invalid_developer_email"});
    }
    rpcName="mp_admin_authorize_developer";
    args={p_email:e};
  } else if (action === "list_developers") {
    rpcName="mp_admin_list_developers";
    args={};
  } else if (action === "revoke_developer") {
    if(!uuid(body.userId))return reply(400,{error:"invalid_developer_account"});
    rpcName="mp_admin_revoke_developer";
    args={p_developer_user_id:body.userId};
  } else if (action === "send_partner_invitation") {
    if (!uuid(body.partnerId)) return reply(400, { error: "invalid_partner_id" });
    rpcName = "admin_prepare_partner_invitation";
    args = { p_partner_id: body.partnerId };
  } else if (action === "activate_invited_partner") {
    if (!uuid(body.partnerId)) return reply(400, { error: "invalid_partner_id" });
    rpcName = "admin_activate_invited_partner";
    args = { p_partner_id: body.partnerId };
  } else {
    return reply(400, { error: "unsupported_action" });
  }

  try {
    // Verify bearer against Supabase Auth, not by decoding untrusted user data.
    const authResponse = await internalFetch(supa + "/auth/v1/user", {
      method: "GET", headers: { apikey: anon, Authorization: bearer },
    });
    if (!authResponse.ok) return reply(401, { error: "invalid_session" });
    const user = await authResponse.json();
    if (!uuid(user?.id) || !user.email_confirmed_at) {
      return reply(403, { error: "confirmed_login_required" });
    }
    const roleResponse = await internalFetch(supa + "/rest/v1/rpc/my_access_context", {
      method: "POST", headers: {
        apikey: anon, Authorization: bearer,
        "Content-Type": "application/json",
      }, body: "{}",
    });
    if (!roleResponse.ok) return reply(503, { error: "authorization_unavailable" });
    const roles = await roleResponse.json();
    const context = Array.isArray(roles) ? roles[0] : null;
    if (!context || context.user_id !== user.id ||
        context.admin_role !== true ||
        context.mfa_verified !== true ||
        context.admin_console_ready !== true) {
      return reply(403, { error: "admin_mfa_required" });
    }

    args.p_admin_user_id = user.id;

    if (rpcName === "mp_admin_authorize_developer") {
      const authAdmin=createClient(supa,service,{
        auth:{autoRefreshToken:false,persistSession:false,detectSessionInUrl:false}
      });
      const address=String(args.p_email);
      // Invite only a new account. Existing application users are never promoted.
      let invited;
      try {
        const result=await authAdmin.auth.admin.inviteUserByEmail(address,{
          redirectTo:"https://marapass-admin-dev.pages.dev/ativar-desenvolvedor.html"
        });
        if(result.error || !uuid(result.data?.user?.id))
          return reply(409,{error:"developer_invite_failed_or_account_exists"});
        invited=result.data.user;
      } catch {
        return reply(503,{error:"developer_invite_delivery_unavailable"});
      }
      const assign=await internalFetch(supa+"/rest/v1/rpc/mp_admin_authorize_developer",{
        method:"POST",
        headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},
        body:JSON.stringify({
          p_admin_user_id:user.id,p_developer_user_id:invited.id,p_email:address
        })
      });
      if(!assign.ok){
        // No role granted on failure; administrator must review the orphan invite.
        return reply(409,{error:"developer_role_not_assigned_contact_support"});
      }
      return reply(200,{
        success:true,action:"invite_developer",readOnly:true,
        note:"Convite solicitado. O destinatário define a própria senha no link recebido."
      });
    }


    // Invite actions never accept a target email from the browser. SQL reads the
    // partner's registered contact and constrains the recipient and ownership.
    if (rpcName === "admin_prepare_partner_invitation") {
      const authServer = createClient(supa, service, {
        auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
      });
      const anonServer = createClient(supa, anon, {
        auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
      });
      const rpc = async (name: string, payload: Record<string,unknown>) => {
        const resp = await internalFetch(supa + "/rest/v1/rpc/" + name, {
          method: "POST",
          headers: { apikey: service, Authorization: "Bearer " + service, "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        let data: unknown = null;
        try { data = await resp.json(); } catch {}
        return { ok: resp.ok, data };
      };
      const prep = await rpc(rpcName, args);
      if (!prep.ok || !prep.data || typeof prep.data !== "object") {
        return reply(409, { error: "invitation_not_available_or_cooldown" });
      }
      const entry = prep.data as Record<string,unknown>;
      if (!uuid(entry.invitation_id) || typeof entry.email !== "string") {
        return reply(503, { error: "invitation_configuration_failure" });
      }
      const redirectTo = "https://marapass-admin-dev.pages.dev/parceiro.html";
      let method = "invite";
      let sendSuccess = false;
      try {
        const { error: inviteError } = await authServer.auth.admin.inviteUserByEmail(entry.email, { redirectTo });
        if (!inviteError) {
          sendSuccess = true;
        } else if (/already|registered|exists|duplicate/i.test(inviteError.message || "")) {
          // Existing accounts receive a one-time sign-in link instead.
          const { error: otpError } = await anonServer.auth.signInWithOtp({
            email: entry.email,
            options: { shouldCreateUser: false, emailRedirectTo: redirectTo },
          });
          method = "magiclink";
          sendSuccess = !otpError;
        }
      } catch {
        sendSuccess = false;
      }
      const record = await rpc("admin_record_partner_invitation_dispatch", {
        p_admin_user_id: user.id,
        p_invitation_id: entry.invitation_id,
        p_success: sendSuccess,
        p_method: sendSuccess ? method : null,
      });
      if (!sendSuccess) return reply(503, { error: "invite_email_dispatch_failed" });
      if (!record.ok) return reply(503, { error: "invite_record_confirmation_failed" });
      return reply(200, {
        success: true, action, partnerId: entry.partner_id, dispatchStatus: "requested",
        method, note: "Supabase Auth accepted the dispatch request. Inbox delivery is not guaranteed.",
      });
    }

    // Trusted project secret stays server-side. Original SQL RPC rechecks staff role.
    const result = await internalFetch(supa + "/rest/v1/rpc/" + rpcName, {
      method: "POST", headers: {
        apikey: service,
        Authorization: "Bearer " + service,
        "Content-Type": "application/json",
      }, body: JSON.stringify(args),
    });
    if (!result.ok) {
      // Safe, classified errors. Never expose untrusted raw SQL messages.
      let sqlCode = "";
      try {
        const cause = await result.json();
        sqlCode = typeof cause?.code === "string" ? cause.code : "";
      } catch {}
      if (sqlCode === "23505") return reply(409, { error: "company_duplicate" });
      if (sqlCode === "23514" || sqlCode === "22001" || sqlCode === "P0001")
        return reply(422, { error: "company_validation_failed" });
      if (sqlCode === "42501") return reply(403, { error: "admin_not_authorized" });
      return reply(result.status >= 500 ? 503 : 409, { error: "operation_not_applied" });
    }
    let operationResult: unknown = null;
    const raw = await result.text();
    if (raw) {
      try { operationResult = JSON.parse(raw); }
      catch { operationResult = null; }
    }
    return reply(200, {
      success: true,
      action,
      ...(rpcName === "review_partner_application"
        ? { partnerId: typeof operationResult === "string" ? operationResult : null }
        : rpcName === "admin_register_direct_company" || rpcName === "admin_register_direct_company_once"
        ? { registration: operationResult }
        : rpcName === "admin_activate_invited_partner"
        ? { activation: operationResult }
        : rpcName === "mp_admin_list_developers"
        ? { developers: Array.isArray(operationResult)?operationResult:[] }
        : rpcName === "mp_admin_revoke_developer"
        ? { revoked: operationResult }
        : ["mp_admin_create_offer","mp_admin_create_passport_draft",
           "mp_admin_attach_passport_benefit","mp_admin_publish_passport"].includes(rpcName)
        ? { details: operationResult }
        : { establishmentId: body.establishmentId, published: body.publish }),
    });
  } catch (_err) {
    return reply(503, { error: "server_unavailable" });
  }
});
