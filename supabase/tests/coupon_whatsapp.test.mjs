import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { createHandler } from "../functions/coupon-whatsapp/handler.mjs";

const config = {
  SUPABASE_URL: "http://db.test",
  SUPABASE_SERVICE_ROLE_KEY: "mock-service",
  WA_GRAPH_VERSION: "v23.0",
  WA_PHONE_NUMBER_ID: "999000",
  WA_ACCESS_TOKEN: "mock-token",
  WA_VERIFY_TOKEN: "mock-verify",
  WA_APP_SECRET: "mock-hmac",
  WA_TEMPLATE_CONVERTED_TOURIST: "converted_tourist",
  WA_TEMPLATE_CONVERTED_PARTNER: "converted_partner",
  COUPON_WORKER_SECRET: "mock-worker",
  WA_TEMPLATE_TOURIST: "issued_tourist_test",
  WA_TEMPLATE_PARTNER: "issued_partner_test",
};
const id = "a2af5575-f29b-4a98-b378-cb11347901f6";
const job = {
  id,
  event: "issued",
  role: "partner",
  lease: "mock-lease",
  to: "5500000000000",
  title: "Hospedagem de teste",
  due: 9000,
  code: "MP-" + "A".repeat(32),
};
function harness(reply) {
  const calls = [];
  const fn = createHandler(
    (name) => config[name],
    async (url, init) => {
      const body = JSON.parse(init.body);
      const name = url.split("/").at(-1);
      calls.push({ name, url, body });
      return reply(name, body);
    },
  );
  return { fn, calls };
}
const post = (suffix, headers = {}, body = "{}") =>
  new Request("https://test.invalid/coupon-whatsapp" + suffix, {
    method: "POST",
    headers,
    body,
  });
test("challenge de inscrição e autenticação antes de qualquer RPC", async () => {
  const { fn, calls } = harness(() => {
    throw Error();
  });
  const r = await fn(
    new Request(
      "https://test.invalid/?hub.mode=subscribe&hub.challenge=123&hub.verify_token=mock-verify",
    ),
  );
  assert.equal(await r.text(), "123");
  assert.equal((await fn(post("/dispatch"))).status, 403);
  assert.equal(
    (await fn(post("", { "X-Hub-Signature-256": "sha256=" + "0".repeat(64) })))
      .status,
    403,
  );
  assert.deepEqual(calls, []);
});
test("template oficial usa nome aprovado, valor, botão e identificador estável", async () => {
  const { fn, calls } = harness((name) =>
    Response.json(
      name === "mvp_wa_claim"
        ? [job]
        : name === "messages"
          ? { messages: [{ id: "wamid.test" }] }
          : null,
    ),
  );
  const r = await fn(
    post("/dispatch", { Authorization: "Bearer mock-worker" }),
  );
  assert.equal(r.status, 200);
  assert.deepEqual(
    calls.map((x) => x.name),
    ["mvp_wa_claim", "messages", "mvp_wa_finish"],
  );
  assert.equal(
    calls[1].url,
    "https://graph.facebook.com/v23.0/999000/messages",
  );
  assert.equal(calls[1].body.biz_opaque_callback_data, id);
  assert.equal(calls[1].body.template.name, config.WA_TEMPLATE_PARTNER);
  assert.equal(
    calls[1].body.template.components[0].parameters[1].text,
    "R$ 90,00",
  );
  assert.equal(
    calls[1].body.template.components[1].parameters[0].text,
    job.code,
  );
  assert.equal(calls[2].body.p_status, "accepted");
});
test("falha transitória reagenda apenas a notificação e falha de modelo encerra a tentativa", async () => {
  for (const [http, expected] of [
    [503, "retry"],
    [429, "retry"],
    [400, "failed"],
  ]) {
    const { fn, calls } = harness((name) =>
      name === "messages"
        ? Response.json({ error: { code: 100 } }, { status: http })
        : Response.json(name === "mvp_wa_claim" ? [job] : null),
    );
    await fn(post("/dispatch", { Authorization: "Bearer mock-worker" }));
    assert.equal(calls.at(-1).body.p_status, expected);
    assert.deepEqual(
      calls.map((x) => x.name),
      ["mvp_wa_claim", "messages", "mvp_wa_finish"],
    );
  }
});
test("assinatura do corpo original, conta destinatária, status e opt-out", async () => {
  const { fn, calls } = harness(() => Response.json(null));
  function body(phone) {
    return JSON.stringify({
      object: "whatsapp_business_account",
      entry: [
        {
          changes: [
            {
              field: "messages",
              value: {
                metadata: { phone_number_id: phone },
                statuses: [
                  {
                    id: "wamid.test",
                    status: "delivered",
                    biz_opaque_callback_data: id,
                  },
                ],
                messages: [
                  { id: "wamid.stop", from: job.to, text: { body: "SAIR" } },
                ],
              },
            },
          ],
        },
      ],
    });
  }
  const signed = (raw) => ({
    "X-Hub-Signature-256":
      "sha256=" +
      createHmac("sha256", config.WA_APP_SECRET).update(raw).digest("hex"),
  });
  const raw = body(config.WA_PHONE_NUMBER_ID);
  assert.equal((await fn(post("", signed(raw), raw + " "))).status, 403);
  const other = body("888");
  assert.equal((await fn(post("", signed(other), other))).status, 200);
  assert.equal(calls.length, 0);
  assert.equal((await fn(post("", signed(raw), raw))).status, 200);
  assert.deepEqual(
    calls.map((x) => x.name),
    ["mvp_wa_callback", "mvp_wa_stop"],
  );
  assert.equal(calls[0].body.p_id, id);
  assert.equal(calls[1].body.p_phone, job.to);
});
test("conversão seleciona o modelo final e preserva a identidade da entrega", async () => {
  const { fn, calls } = harness((name) =>
    Response.json(
      name === "mvp_wa_claim"
        ? [{ ...job, event: "converted", role: "tourist" }]
        : name === "messages"
          ? { messages: [{ id: "wamid.final" }] }
          : null,
    ),
  );
  await fn(post("/dispatch", { Authorization: "Bearer mock-worker" }));
  assert.equal(
    calls[1].body.template.name,
    config.WA_TEMPLATE_CONVERTED_TOURIST,
  );
  assert.equal(calls[1].body.biz_opaque_callback_data, job.id);
});
