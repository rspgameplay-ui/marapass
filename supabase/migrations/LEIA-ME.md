# Migrations

O histórico oficial é o do banco (`supabase_migrations.schema_migrations` no projeto `Marapass`). Esta pasta guarda só as migrations a partir de 16/11/2026; as anteriores estão consolidadas em `../schema.sql`.

## Regra para migrations novas

1. Aplique pelo Supabase (MCP `apply_migration` ou `supabase db push`).
2. Salve o arquivo aqui com **a mesma versão que o banco registrou**: `<versão>_<nome>.sql`. Confira com `select version, name from supabase_migrations.schema_migrations order by version desc limit 5;`.

Assim um `supabase db push` futuro não tenta aplicar de novo o que já está no banco.

## Arquivos sem versão própria

Estes dois não correspondem a uma única migration do banco e ficam só como referência. **Não aplique de novo:**

| Arquivo | Corresponde a |
|---|---|
| `20261115_delete_my_account.sql` | `20261116095702_mvp_delete_account_and_partner_approval` e `20261119183558_delete_my_account_v2_turista` |
| `20261117_mvp_admin_and_lodging.sql` | `20261116101224_mvp_admin_command` e `20261116102515_mvp_reservations_lodging_period` |
