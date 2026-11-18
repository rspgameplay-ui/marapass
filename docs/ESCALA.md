# MaraPass — Escala e operação

Estado verificado em 18/11/2026 (código + advisors do Supabase; sem teste de carga).

## 1. Conexões ao Postgres
- O app usa só `supabase_flutter` (REST/RPC via PostgREST). Nenhum código abre conexão direta ao banco, então o limite de conexões é do pooler interno do Supabase.
- Se algum dia houver Edge Function ou worker com driver Postgres, use a string do pooler (transaction mode, porta 6543), nunca a porta 5432.
- Ao subir para o Pro, ajuste *Settings > Database > Connection pooling* conforme o tamanho da instância.

## 2. Concorrência
- Cupom: `mvp_activate_offer_coupon` trava a oferta com `FOR UPDATE`, então o `issue_limit` não estoura. Índice único `mvp_coupons_one_active` e `mvp_one_conversion` impedem duplicidade. Confirmação de recebimento usa `FOR UPDATE` no cupom.
- Reserva: é pedido que o parceiro aceita (sem estoque de vagas), e `request_key` UNIQUE torna o reenvio idempotente. Se um dia houver vagas por horário, será preciso uma tabela de capacidade com `FOR UPDATE`.
- Check-in: `ON CONFLICT (user_id,item_key,day)` e teto de 20/dia.

## 3. WhatsApp
Já existe fila (`private.mvp_wa_queue`) com lease de 5 min, `FOR UPDATE SKIP LOCKED`, até 6 tentativas com backoff exponencial e consentimento. O envio roda no `pg_cron` (1/min, 10 jobs por rodada), fora da requisição do usuário. Capacidade ≈ 600 mensagens/hora; para mais, aumente o `limit 10` ou agende mais vezes.

## 4. Rate limiting
- Banco: migration `20261118_mvp_scale_guards.sql` cria `private.mvp_rate_check` e limita pedidos de reserva a 10/min por usuário (confirmação de cupom já tinha 30/min; check-in, 20/dia). **Ainda não aplicada.**
- Borda (Cloudflare, plano Free): *Security > WAF > Rate limiting rules*, por exemplo 100 req/10 s por IP em `/auth/v1/*` e `/rest/v1/rpc/*` do domínio do Supabase, se ele passar pelo Cloudflare. Ative Bot Fight Mode no site.
- Auth: em *Authentication > Rate Limits* do Supabase, reduza e-mail/OTP por hora e ative CAPTCHA (Turnstile).

## 5. Mídia
- Bucket `marapass-assets` limita 5 MB (jpeg/png/webp). O app agora decodifica com `cacheWidth: 900`.
- Reduzir banda de verdade exige redimensionar no upload (ex.: 1280 px, WebP) ou usar Storage image transformations (plano Pro) com `?width=`. Recomendado antes de abrir ao público.

## 6. Ambientes
Homologação aponta para o banco de produção. Antes de teste de carga: criar projeto Supabase de staging, aplicar `schema.sql` + migrations, configurar `SUPABASE_URL`/chave de staging no build e só então rodar k6.

## 7. Monitoramento
- Supabase: *Reports* (API, DB, Auth), `get_advisors` (segurança e performance) toda semana e alertas de uso/spend cap.
- Cloudflare: Web Analytics e notificações de pico/erros 5xx.
- Externo: UptimeRobot/Better Stack no endereço público e em `/rest/v1/` com chave publicável.
- Fila WhatsApp: alerta se `select count(*) from private.mvp_wa_queue where state in ('failed','retry')` passar de um limite.

## 8. Desempenho (advisors)
Corrigido em 18/11/2026 (`20261118_mvp_rls_and_fk_indexes.sql`, aplicada): policies com `(select auth.jwt())`, policies de leitura de admin fundidas por OR, policies ALL de admin separadas em INSERT/UPDATE/DELETE, e índices nas 13 FKs. O advisor de desempenho só mostra mais `unused_index` (esperado, tráfego baixo) e `private.coupon_media_uploads` sem chave primária.

## 9. Avisos de segurança do advisor (revisados em 18/11/2026)
Nada exigiu mudança de código ou de banco:
- `mvp_public_sales` executável por `anon`: intencional (catálogo público; já remove `payment` e `url`). É a única função `SECURITY DEFINER` acessível ao anon.
- 33 funções `SECURITY DEFINER` para `authenticated`: são a API do app (RPC) e cada uma valida usuário/papel dentro (`mvp_require_user`, `mvp_is_partner`). Revogar quebraria o app.
- Tabelas `private.*` e algumas `public.*` com RLS e sem policy: intencional (só funções definer e service_role acessam).
- `pg_net` em `public`: a extensão não é relocável; mover exige recriar e interromper o job do `pg_cron`. Risco baixo, deixar.
- "Anonymous Access Policies": o app Flutter não usa login anônimo. Se o projeto não precisa, desligue em *Authentication > Sign In / Providers > Allow anonymous sign-ins*.
- Senha vazada (HaveIBeenPwned): ligar em *Authentication > Providers > Email* (recurso do plano Pro). Só vale se o app usar senha; hoje o login é por e-mail com código.
