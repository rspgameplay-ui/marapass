# MaraPass — verificação inicial de segurança e migração (14/11/2026)

Escopo: inspeção **somente leitura** dos metadados do Supabase e código retornado pelas 12 Edge Functions. Esta auditoria não é pentest, homologação nem atestado de conformidade LGPD.

## Itens confirmados
- Projeto Supabase ativo: `nwwxobiqynawxxnbvubz`.
- 41 tabelas (31 no schema `public`, 10 em `private`); todas as 41 aparecem com Row Level Security (RLS) ativado.
- 57 políticas cadastradas nos dois esquemas.
- 69 funções SQL do projeto identificadas; fontes exportadas para `supabase/recovery/functions_snapshot.sql`.
- 12 Edge Functions ativas. Seis com `verify_jwt=true`, seis com `verify_jwt=false`.
- Foram encontrados avisos do Supabase Advisors sobre políticas que podem incluir logins anônimos e seis tabelas com RLS sem políticas definidas. Uma tabela RLS sem política pode ser bloqueio intencional, não necessariamente exposição.

## Pontos para revisão
1. Verificar **cada** endpoint com `verify_jwt=false` e comprovar autenticação/autorização própria quando aceitar operações sensíveis: `marapass-activate-mfa`, `marapass-admin-painel`, `marapass-mapa-barreirinhas-v3`, `marapass-mapa-original-v4`, `marapass-coupons` e `marapass-environment`. O campo sozinho não demonstra vulnerabilidade.
2. Investigar avisos de acesso anônimo: garantir que políticas diferenciadas usem condições explícitas do usuário e escopo da empresa, não somente o papel `authenticated`.
3. Tabelas com RLS mas sem políticas: `private.audit_events`, `private.coupon_media_uploads`, `private.custom_offer_requests`, `private.offer_creation_requests`, `public.map_environment_cache`, `public.passport_benefit_incidents`. Confirmar se o acesso bloqueado é esperado.
4. Não distribuir `service_role` nem `sb_secret_` no frontend ou commits; publishable key é pública, mas depende de RLS correta.
5. As Edge Functions de mapa V3/V4 usam leitura de `site.html`. O conector retornou apenas o entrypoint; não afirmar que o snapshot recupera todo seu bundle ou que ele recompila isoladamente.
6. Antes de mesclar, testar autenticação, MFA, separação turista/parceiro/admin, cupons com idempotência, pedidos e RLS para usuários anônimos e de empresas distintas.
7. O código Flutter de arquivos anteriores não foi compilado neste ambiente. A mudança recente da biblioteca supabase-flutter v3 exige avaliação separada; não atualizar dependências automaticamente.

## Complemento da revisão de código (14/11/2026)
- **Permissões `EXECUTE` não exportadas.** `functions_snapshot.sql` não inclui os `GRANT`. Funções que recebem o usuário por parâmetro (`issue_coupon` → `mp_issue_coupon_v2`, `reserve_coupon_media`, `submit_business_profile`) rodam como *security invoker*, então o RLS se aplica. Mesmo assim, é preciso confirmar no banco que `anon` e `authenticated` não têm `EXECUTE` direto nelas.
- **As 7 funções `SECURITY DEFINER` fixam `search_path=''`.**
- Pela leitura do código, os 6 endpoints com `verify_jwt=false` têm justificativa:
  - `marapass-coupons` valida a sessão em `/auth/v1/user`, exige e-mail confirmado e exige `aal2` quando há MFA verificado;
  - `marapass-environment` é a previsão do tempo pública;
  - `marapass-activate-mfa`, `marapass-admin-painel` e os mapas V3/V4 servem HTML.
  Isso não substitui o teste das páginas e das chamadas que elas fazem.
- Em `marapass-coupons`:
  - a origem de desenvolvimento `http://terminal.local:4173` está liberada no CORS de produção;
  - o comentário "User-scoped reads keep existing RLS" não corresponde à ação `wallet`, que usa `service_role` (ignora o RLS) e filtra pelo `uid` autenticado.
- A chave `sb_publishable_…` aparece no código de 3 funções. É pública por definição e depende de RLS correta.

## Fontes
- Supabase Advisors: https://supabase.com/docs/guides/database/database-advisors
- Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Changelog Supabase Flutter v3: https://supabase.com/changelog/supabase-flutter-v3

**Nenhuma modificação foi aplicada ao banco de produção durante esta recuperação.**
