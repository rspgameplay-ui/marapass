# Decisões e pendências — 18/11/2026

## Respostas do cliente (18/11/2026)
Resumo completo na seção 1.1 de `ESPECIFICACAO_MARAPASS.md`. Em resumo: titular com CNPJ, Mercado Pago com split, comissão de 5%, entrega em 29/01/2027, servidor em São Paulo, domínio marapass.com, idiomas português e inglês, WhatsApp Business (98) 98433-4256 como canal oficial e para validar cupons.

Rodada 2 (respondida): titular Foco Inteligência de Negócios (CNPJ 37.605.432/0001-36), comissão de 5%, taxa do Mercado Pago descontada do parceiro, conta do Mercado Pago já existe, edital Centelha, marca não registrada no INPI, inglês do app inteiro em janeiro, número de WhatsApp autorizado e conta Meta verificada, validação de cupom por WhatsApp e painel, lista de parceiros até 15/12.

Em aberto: municípios dos parceiros da demo, prazo e exigências do Centelha, criar a caixa atendimento@marapass.com, registro da marca, ID e token do WhatsApp Business (Meta), modelos de mensagem, sandbox e split do Mercado Pago, projeto do Supabase em São Paulo, tradução do app para inglês.

Inglês: a base está pronta (arquivos em `flutter/lib/l10n`, troca PT/EN no Perfil, teste em `test/mvp_language_test.dart`). Já traduzidos: abas inferiores e a tela de canais de atendimento. Falta passar cerca de 600 textos fixos do app (400 no módulo `lib/mvp`) para os arquivos de tradução, além do painel de gestão e das páginas legais.

## Decisões padrão adotadas (confirmadas pelo cliente, com ajuste de idiomas)
- Cancelamento grátis até 24 h antes.
- Pontos do passaporte dão níveis e conquistas e desbloqueiam cupons.
- Parceiros aprovados pela gestão central.
- Cadastur desejável, com selo; não barra quem não tem.
- Só português, com o app preparado para outros idiomas.
- Avaliações visíveis só para a gestão.

## Pendências técnicas — situação
| Item | Situação |
|---|---|
| Banco vazio | Resolvido: migration `20261118120000_mvp_demo_seed.sql` criou 1 parceiro, 2 estabelecimentos, 3 experiências, 28 horários, 2 ofertas e 1 passaporte (rascunho), tudo marcado "(exemplo)". Remover: `delete from partners where id='00000000-0000-4000-8000-0000000000de'` e o passaporte `...00b1`. |
| Excluir conta (LGPD) | Já existia: RPC `delete_my_account` aplicada no banco. |
| RLS e alertas | Lidos. Nenhuma tabela sem RLS. Tabelas `private.*` sem política = bloqueadas (intencional). Funções SECURITY DEFINER são as RPCs do app (intencional). A ação: ativar "Leaked password protection" no painel Auth; `pg_net` no schema public (baixo risco). |
| App sem login/reserva/cupom/passaporte | Desatualizado: o módulo `lib/mvp` já tem essas telas e RPCs. |
| Testes e analisador | 185/185 testes passando; analisador de 189 para 11 avisos (só "info", zero erros). |
| GPS no Safari, PRs 1 e 4 | Precisa de iPhone real para testar; GitHub indisponível nesta sessão. |
| Gradle wrapper e chaves Google Maps | Precisa de você (chaves no Google Cloud). |
| Chaves em `.env.txt` | Trocar no Supabase e Cloudflare no fim do projeto. |
