# Edge Functions

Código-fonte das Edge Functions ativas no Supabase (projeto `nwwxobiqynawxxnbvubz`), baixado em 21/11/2026 com:

```powershell
supabase functions download <nome> --project-ref nwwxobiqynawxxnbvubz --use-api
```

Cada pasta é idêntica à versão publicada nessa data. Segredos (`SUPABASE_SERVICE_ROLE_KEY` e outros) vêm de variáveis de ambiente do Supabase e não estão no código.

| Função | Para que serve |
| --- | --- |
| marapass-admin-painel | Página do painel admin |
| marapass-admin-ops / marapass-admin-access | Operações e acesso do admin |
| marapass-activate-mfa | Ativação do segundo fator (MFA) do admin |
| marapass-developer-console | Console de desenvolvedor (somente leitura) |
| marapass-partner-invitations | Convites de parceiros |
| marapass-coupons / coupon-whatsapp | Cupons e avisos por WhatsApp |
| marapass-tourist-benefits | Benefícios do passaporte |
| marapass-assistant | Assistente do app |
| marapass-environment | Dados de ambiente do mapa (clima, maré) |
| marapass-mapa-original-v4 / marapass-mapa-barreirinhas-v3 | Protótipos antigos do mapa |

Ao alterar uma função: edite aqui, publique com `supabase functions deploy <nome> --project-ref nwwxobiqynawxxnbvubz` e faça commit da mesma versão.
