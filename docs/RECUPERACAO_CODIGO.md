# Recuperação MaraPass — 14/11/2026

> **Atualização (revisão de 14/11/2026, noite):** este documento foi escrito antes da recuperação da v36. O código-fonte completo da versão publicada (v36, commit `91b1e7e`) **foi recuperado depois** e está na branch `backup/marapass-versao-publicada`. A correção candidata do GPS está em `correcao/gps-v36-2026-11-14`. Este PR contém apenas o material Supabase e a documentação. Ver a seção "Estado atual" no final.

Este commit preserva fontes **efetivamente inspecionadas** nas integrações Supabase e Biblioteca de arquivos do MaraPass.

- Supabase ref: `nwwxobiqynawxxnbvubz`, inspecionado em modo leitura.
- `supabase/functions/`: fontes retornadas pela API para as Edge Functions implantadas; algumas podem depender de arquivos adicionais não entregues pela API.
- `supabase/recovery/`: inventários estruturais, **não** exportações de dados de produção e **não** migrações executáveis.
- `web/mapa-original-v4/` e `web/admin-v5/`: **NÃO recuperados**. Os arquivos presentes contêm apenas a mensagem de falha de leitura (ver seção abaixo).
- `docs/`: documentação da recuperação. O contrato de cupons e o relatório de homologação **NÃO foram recuperados** (ver seção abaixo).

**Limitação:** o ZIP `MaraPass_Mapa_Flutter_V1.zip` foi recuperado para inspeção local, mas os arquivos Dart, datasets e os binários dele ainda não estão neste commit. É necessário importar separadamente esse ZIP. A versão V5 das praias permanece não publicada.

**Segurança:** nenhum registro pessoal das tabelas, credencial secreta, `service_role`, senha ou token foi intencionalmente versionado. Não utilizar este snapshot como migração de produção, nem promover a branch sem revisão.

**Branch:** `recuperacao/codigo-2026-11-14`. Não houve modificação do projeto Supabase em produção.

## Arquivos que falharam na leitura (placeholders)

Os 5 arquivos abaixo foram gravados com o texto `The requested file read failed. See warnings for details.` (57 bytes) no lugar do conteúdo. A leitura na Biblioteca falhou, e o manifesto registra a origem como `MaraPass Library undefined`. **Não contêm o material original.** Foram mantidos sem alteração apenas para rastrear a falha. Não devem ser usados, executados nem citados como fonte.

| Arquivo | Conteúdo esperado | Situação |
| --- | --- | --- |
| `web/admin-v5/app.js` | Script do painel admin V5 | Falha de leitura |
| `web/admin-v5/index.html` | HTML do painel admin V5 | Falha de leitura |
| `web/mapa-original-v4/index.html` | Protótipo do mapa original V4 | Falha de leitura |
| `docs/CONTRATO_INTEGRIDADE_CUPONS.md` | Contrato técnico de integridade dos cupons | Falha de leitura |
| `docs/RELATORIO_HOMOLOGACAO_2026-11-11.md` | Relatório de homologação de 11/11 | Falha de leitura |

Para recuperar o conteúdo real: baixar de novo os arquivos da Biblioteca e substituir os placeholders num commit próprio, conferindo o tamanho e o SHA-256. Se não houver cópia disponível, remover os placeholders antes do merge.

## Estado atual das branches (14/11/2026)

| Branch | Conteúdo |
| --- | --- |
| `main` | Somente o README inicial. |
| `backup/marapass-versao-publicada` | **v36 publicada**: Flutter, `navigation3d/`, `dist/` e documentação (382 arquivos). Commit `91b1e7e`, deploy de 14/11 às 09:05 UTC. |
| `correcao/gps-v36-2026-11-14` | v36 com a correção candidata do GPS (Safari/iPhone), publicada em homologação privada. Validação em iPhone real **pendente**. |
| `recuperacao/codigo-2026-11-14` (este PR) | Edge Functions, inventários Supabase e documentação. |
| `backup/inventario-2026-11-14` | Este PR mais o inventário dos ZIPs históricos. |

**Antes do merge:**
1. Resolver os 5 placeholders acima.
2. Definir a base da `main`. Mesclar este PR numa `main` vazia deixaria a `main` só com a recuperação, sem o app. Recomenda-se levar primeiro a v36 para a `main` e depois somar `supabase/`.
3. Concluir as verificações de segurança de `SEGURANCA_SUPABASE_2026-11-14.md`, incluindo as permissões `EXECUTE` das funções SQL, que não foram exportadas.

