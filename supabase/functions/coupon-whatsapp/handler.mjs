// O endpoint público autentica a Meta pelo corpo original e o worker por um segredo próprio.
const encoder = new TextEncoder();
const json = (status, body) => Response.json(body, { status });
const transient = new Set([130429, 131000, 131016, 131048, 131056]);
const equal = (a, b) => {
  if (a.length !== b.length) return false;
  let different = 0;
  for (let i = 0; i < a.length; i++)
    different |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return different === 0;
};
async function signed(bytes, signature, secret) {
  if (!/^sha256=[0-9a-f]{64}$/.test(signature || "")) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const mac = Uint8Array.from(signature.slice(7).match(/../g), (b) =>
    parseInt(b, 16),
  );
  return crypto.subtle.verify("HMAC", key, mac, bytes);
}
const currency = (cents) =>
  "R$ " + Math.floor(cents / 100) + "," + String(cents % 100).padStart(2, "0");

export function createHandler(env, fetcher = fetch) {
  const get = (name) => {
    const value = env(name);
    if (!value) throw Error("configuration");
    return value;
  };
  async function rpc(name, args = {}) {
    const key = get("SUPABASE_SERVICE_ROLE_KEY");
    const response = await fetcher(
      get("SUPABASE_URL") + "/rest/v1/rpc/" + name,
      {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: "Bearer " + key,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        signal: AbortSignal.timeout(12000),
      },
    );
    if (!response.ok) throw Error("database");
    const body = await response.text();
    return body ? JSON.parse(body) : null;
  }
  async function dispatch() {
    const version = get("WA_GRAPH_VERSION"),
      phone = get("WA_PHONE_NUMBER_ID"),
      token = get("WA_ACCESS_TOKEN");
    const templates = {
      issued: {
        tourist: get("WA_TEMPLATE_TOURIST"),
        partner: get("WA_TEMPLATE_PARTNER"),
      },
      converted: {
        tourist: get("WA_TEMPLATE_CONVERTED_TOURIST"),
        partner: get("WA_TEMPLATE_CONVERTED_PARTNER"),
      },
    };
    if (!/^v[0-9]+\.[0-9]+$/.test(version) || !/^\d+$/.test(phone))
      throw Error("configuration");
    const jobs = await rpc("mvp_wa_claim");
    for (const job of jobs) {
      let status = "retry",
        provider = null,
        error = "network";
      try {
        const message = {
          messaging_product: "whatsapp",
          to: job.to,
          type: "template",
          biz_opaque_callback_data: job.id,
          template: {
            name: templates[job.event][job.role],
            language: { code: "pt_BR" },
            components: [
              {
                type: "body",
                parameters: [job.title, currency(job.due)].map((text) => ({
                  type: "text",
                  text,
                })),
              },
              {
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [{ type: "text", text: job.code }],
              },
            ],
          },
        };
        const r = await fetcher(
          "https://graph.facebook.com/" + version + "/" + phone + "/messages",
          {
            method: "POST",
            headers: {
              Authorization: "Bearer " + token,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(message),
            signal: AbortSignal.timeout(10000),
          },
        );
        const data = await r.json();
        provider = data.messages?.[0]?.id ?? null;
        if (r.ok && provider) {
          status = "accepted";
          error = null;
        } else {
          const code = data.error?.code;
          status =
            r.status === 429 || r.status >= 500 || transient.has(code)
              ? "retry"
              : "failed";
          error = code ? "meta_" + code : "http_" + r.status;
        }
      } catch {
        /* O lease e as retentativas são independentes do cupom. */
      }
      await rpc("mvp_wa_finish", {
        p_id: job.id,
        p_lease: job.lease,
        p_status: status,
        p_provider: provider,
        p_error: error,
      });
    }
    return json(200, { processed: jobs.length });
  }
  async function webhook(request) {
    const bytes = await request.arrayBuffer();
    if (
      !(await signed(
        bytes,
        request.headers.get("X-Hub-Signature-256"),
        get("WA_APP_SECRET"),
      ))
    )
      return json(403, {});
    const data = JSON.parse(new TextDecoder().decode(bytes));
    if (data.object !== "whatsapp_business_account") return json(200, {});
    const phone = get("WA_PHONE_NUMBER_ID");
    for (const entry of data.entry ?? [])
      for (const change of entry.changes ?? []) {
        const value = change.value;
        if (
          change.field !== "messages" ||
          value?.metadata?.phone_number_id !== phone
        )
          continue;
        for (const s of value.statuses ?? []) {
          const id = s.biz_opaque_callback_data;
          if (
            !s.id ||
            !["sent", "delivered", "read", "failed"].includes(s.status)
          )
            continue;
          await rpc("mvp_wa_callback", {
            p_id: /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id ?? "")
              ? id
              : null,
            p_message: s.id,
            p_status: s.status,
            p_retry: s.errors?.some((e) => transient.has(e.code)) ?? false,
          });
        }
        for (const m of value.messages ?? []) {
          if (
            m.id &&
            m.from &&
            ["SAIR", "PARAR", "STOP"].includes(
              m.text?.body?.trim().toUpperCase(),
            )
          )
            await rpc("mvp_wa_stop", { p_phone: m.from, p_message: m.id });
        }
      }
    return json(200, {});
  }
  return async (request) => {
    try {
      const url = new URL(request.url);
      if (url.pathname.endsWith("/dispatch")) {
        if (request.method !== "POST") return json(405, {});
        if (
          !equal(
            request.headers.get("Authorization") ?? "",
            "Bearer " + get("COUPON_WORKER_SECRET"),
          )
        )
          return json(403, {});
        return await dispatch();
      }
      if (request.method === "GET") {
        const q = url.searchParams,
          challenge = q.get("hub.challenge");
        if (
          q.get("hub.mode") === "subscribe" &&
          challenge &&
          equal(q.get("hub.verify_token") ?? "", get("WA_VERIFY_TOKEN"))
        )
          return new Response(challenge);
        return json(403, {});
      }
      if (request.method === "POST") return await webhook(request);
      return json(405, {});
    } catch {
      return json(503, { error: "Operação temporariamente indisponível." });
    }
  };
}
