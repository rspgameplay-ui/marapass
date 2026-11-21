# Migrations

Esta pasta tem o **histórico completo** do banco (73 migrations em 21/11/2026), baixado com `supabase migration fetch`. Cada arquivo é idêntico ao SQL registrado em `supabase_migrations.schema_migrations`.

Exceção: as três migrations de cupons de 17/11 (`mvp_coupon_commerce`, `mvp_coupon_whatsapp`, `mvp_coupon_operations`) foram aplicadas sem guardar o SQL no histórico; os arquivos aqui vêm do PR 9.

`../schema.sql` é a concatenação desta pasta, em ordem, e serve para recriar o banco do zero.

## Regra para migrations novas

1. Aplique pelo Supabase (MCP `apply_migration` ou `supabase db push`).
2. Atualize esta pasta com o que o banco registrou:

   ```powershell
   supabase migration fetch --project-ref nwwxobiqynawxxnbvubz --workdir <pasta temporária>
   ```

   e copie o arquivo novo para cá. Não escreva o arquivo à mão com outra versão: um `supabase db push` futuro tentaria aplicá-lo de novo.
3. Regenere o `schema.sql` (concatenação de `migrations/*.sql` com o cabeçalho `-- <versão> <nome>`).
