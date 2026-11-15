# Publicação automática no Cloudflare Pages

A cada merge na `main`, o workflow `.github/workflows/deploy-cloudflare.yml` compila o app web (Flutter 3.47.8), monta o painel `/admin/` e publica no projeto **marapass** do Cloudflare Pages. Enquanto os segredos abaixo não existirem, o workflow apenas avisa e não publica.

## Configuração (uma vez)

1. **Domínio no Cloudflare.** Adicione `marapass.com` em *Websites > Add a site* (plano Free) e troque os nameservers no registrador pelos indicados pelo Cloudflare.
2. **Token de API.** *My Profile > API Tokens > Create Token > Custom token*, com a permissão **Account · Cloudflare Pages · Edit**. Copie o token.
3. **ID da conta.** Aparece na barra lateral da página inicial do painel (*Account ID*).
4. **Segredos no GitHub.** No repositório: *Settings > Secrets and variables > Actions > New repository secret*:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
   - `SUPABASE_PUBLISHABLE_KEY` (a chave publicável; nunca a `service_role`/`sb_secret`)
   - Opcional, na aba *Variables*: `SITE_URL` (padrão `https://teste.marapass.com`).
5. **Primeira publicação.** Faça um push na `main` ou rode o workflow manualmente em *Actions > Publicação no Cloudflare Pages > Run workflow*. O projeto `marapass` é criado sozinho e fica em `https://marapass.pages.dev`.
6. **Endereço próprio.** No Cloudflare: *Workers & Pages > marapass > Custom domains > Set up a custom domain* → `teste.marapass.com`.
7. **Acesso restrito (recomendado).** Esta é a homologação ligada ao banco de produção. Em *Zero Trust > Access > Applications > Add an application > Self-hosted*, proteja `teste.marapass.com` e `marapass.pages.dev` com uma política que permita só o seu e-mail.

## Observações

- A chave publicável entra só no build; no repositório continua o marcador `__SUPABASE_PUBLISHABLE_KEY__`.
- Os cabeçalhos de segurança do painel (`_headers`) são aplicados pelo Cloudflare Pages.
- O domínio principal `marapass.com` fica reservado para o lançamento oficial.
