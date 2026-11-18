// Edge Function: validação de cupom pelo WhatsApp (Cloud API da Meta).
//
// Fluxo: o parceiro manda "VALIDAR <código> <valor>" (ex.: VALIDAR MP4K7Q2 85,50)
// do número cadastrado em public.partner_whatsapp_validators. A função confere a
// assinatura da Meta, resolve o número para o usuário validador, chama
// public.redeem_coupon (que aplica todas as regras) e responde no mesmo chat.
// O turista, se tiver telefone no perfil, recebe um aviso de confirmação.
//
// Deploy:  supabase functions deploy whatsapp-coupon --no-verify-jwt
// Secrets: WHATSAPP_VERIFY_TOKEN, WHATSAPP_APP_SECRET, WHATSAPP_ACCESS_TOKEN,
//          WHATSAPP_PHONE_NUMBER_ID  (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY
//          já vêm do ambiente). Webhook da Meta: <url da função>, campo "messages".

import { createClient } from "npm:@supabase/supabase-js@2";

const GRAPH = "https://graph.facebook.com/v21.0";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const HELP =
  "Para validar um cupom, envie:\nVALIDAR <código> <valor da compra>\nEx.: VALIDAR MP4K7Q2 85,50";

async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function sendText(to: string, body: string) {
  const res = await fetch(`${GRAPH}/${Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("WHATSAPP_ACCESS_TOKEN")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to,
      type: "text",
      text: { body },
    }),
  });
  if (!res.ok) console.error("whatsapp send failed", res.status, await res.text());
}

/** "85,50" ou "85.50" → centavos. */
function parseCents(raw: string): number | null {
  const m = raw.replace(/^R\$/i, "").trim().match(/^(\d{1,6})(?:[.,](\d{1,2}))?$/);
  if (!m) return null;
  return parseInt(m[1], 10) * 100 + parseInt((m[2] ?? "0").padEnd(2, "0"), 10);
}

const brl = (cents: number) =>
  (cents / 100).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

async function handleMessage(from: string, messageId: string, text: string) {
  const parts = text.trim().split(/\s+/);
  if (parts[0]?.toUpperCase() !== "VALIDAR") {
    await sendText(from, HELP);
    return;
  }
  if (parts.length < 3) {
    await sendText(from, `Faltou informar o valor da compra.\n${HELP}`);
    return;
  }

  const { data: validator } = await db
    .from("partner_whatsapp_validators")
    .select("user_id")
    .eq("phone_e164", from)
    .eq("is_active", true)
    .maybeSingle();
  if (!validator) {
    await sendText(
      from,
      "Este número não está autorizado a validar cupons. Peça ao MaraPass para cadastrá-lo no seu estabelecimento.",
    );
    return;
  }

  const cents = parseCents(parts.slice(2).join(" "));
  if (cents === null) {
    await sendText(from, `Valor inválido.\n${HELP}`);
    return;
  }

  const { data: found } = await db.rpc("whatsapp_find_coupon", { p_code: parts[1] });
  const coupon = Array.isArray(found) ? found[0] : found;
  if (!coupon) {
    await sendText(from, `Cupom ${parts[1].toUpperCase()} não encontrado. Confira o código com o cliente.`);
    return;
  }
  if (coupon.status === "redeemed") {
    await sendText(from, "Este cupom já foi utilizado.");
    return;
  }
  if (coupon.status !== "issued" || new Date(coupon.expires_at) <= new Date()) {
    await sendText(from, "Este cupom está vencido ou cancelado.");
    return;
  }

  // A chave de idempotência vem do id da mensagem: reentrega do webhook não duplica.
  const { error } = await db.rpc("redeem_coupon", {
    p_coupon_instance_id: coupon.coupon_id,
    p_validator_user_id: validator.user_id,
    p_idempotency_key: `wa-${messageId}`.padEnd(16, "0"),
    p_transaction_amount_cents: cents,
  });
  if (error) {
    console.error("redeem_coupon", error.message);
    const msg = error.message.includes("unauthorized")
      ? "Seu número não tem permissão para validar cupons deste estabelecimento."
      : error.message.includes("not eligible")
      ? "A compra não atinge o mínimo para este cupom."
      : "Não foi possível validar o cupom agora. Tente novamente ou fale com o suporte.";
    await sendText(from, msg);
    return;
  }

  await sendText(from, `✅ Cupom validado: ${coupon.offer_title} · compra de ${brl(cents)}. Obrigado!`);

  // Aproxima cliente e restaurante: confirmação para o turista, se houver telefone.
  const { data: phone } = await db.rpc("whatsapp_customer_phone", {
    p_user_id: coupon.beneficiary_user_id,
  });
  const digits = typeof phone === "string" ? phone : "";
  if (digits.length >= 10) {
    const to = digits.length <= 11 ? `55${digits}` : digits;
    await sendText(
      to,
      `Seu cupom "${coupon.offer_title}" foi usado. Aproveite! Os pontos já entram no seu passaporte MaraPass.`,
    );
  }
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Verificação do webhook pela Meta.
  if (req.method === "GET") {
    const ok = url.searchParams.get("hub.mode") === "subscribe" &&
      url.searchParams.get("hub.verify_token") === Deno.env.get("WHATSAPP_VERIFY_TOKEN");
    return ok
      ? new Response(url.searchParams.get("hub.challenge") ?? "", { status: 200 })
      : new Response("forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const raw = await req.text();
  const secret = Deno.env.get("WHATSAPP_APP_SECRET") ?? "";
  const given = (req.headers.get("x-hub-signature-256") ?? "").replace("sha256=", "");
  if (!secret || !safeEqual(given, await hmacHex(secret, raw))) {
    return new Response("invalid signature", { status: 401 });
  }

  try {
    const payload = JSON.parse(raw);
    for (const entry of payload.entry ?? []) {
      for (const change of entry.changes ?? []) {
        for (const m of change.value?.messages ?? []) {
          if (m.type === "text" && m.text?.body) {
            await handleMessage(String(m.from), String(m.id), String(m.text.body));
          }
        }
      }
    }
  } catch (e) {
    console.error("webhook error", e);
  }
  // Sempre 200: a Meta reenvia em caso de erro e o processamento já é idempotente.
  return new Response("ok", { status: 200 });
});
