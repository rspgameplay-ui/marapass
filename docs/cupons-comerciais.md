# Cupons comerciais do MaraPass

## Teste guiado em homologação

Use um projeto Supabase de homologação com os contratos `mvp_*` do app, um administrador com segundo fator, um turista e duas contas de parceiros distintos. A prévia de interface sem backend continua sendo uma demonstração. O teste abaixo usa contas e valores fictícios.

1. No painel do parceiro, abra **Cupons → Criar oferta**. Cadastre uma diária de R$ 100,00, desconto de 10%, estoque de uma unidade e pagamento direto ao estabelecimento. Confira a prévia de R$ 90,00 e R$ 4,50. Envie para aprovação.
2. Em **Administração → App MaraPass → Ofertas**, confira o desconto, o valor final, a regra e o destino do pagamento. Ative a oferta. A alteração das condições comerciais exige nova aprovação. Cupons já emitidos guardam as condições anteriores.
3. Se os dois destinatários quiserem avisos, cada um deve abrir **Perfil → Cupons pelo WhatsApp**, verificar seu próprio telefone e autorizar. A resposta **SAIR** e a revogação no perfil cancelam a autorização. O consentimento se refere aos avisos do cupom.
4. Entre como turista, emita o cupom e consulte a carteira. O painel já deve mostrar o código e comissão zero. Abra a cobrança ou as instruções do parceiro. **Já paguei ao parceiro** registra o aviso. O valor a receber pelo MaraPass continua em zero.
5. Entre como parceiro, abra o link recebido ou **Validar** e leia o QR. As duas entradas usam a mesma confirmação. Registre o valor recebido pelo item elegível. Um valor divergente abre uma contestação. Registre a solução e confira o valor antes de tentar novamente.
6. Com R$ 90,00 confirmados, confira a comissão de R$ 4,50, 90 pontos no Passaporte e o aviso final para cada destinatário autorizado. A repetição da confirmação deve devolver a conversão existente. A conta do outro parceiro deve receber uma resposta de cupom indisponível.
7. Repita com uma diária de R$ 120,00 e desconto fixo de R$ 20,00. O resultado deve ser R$ 100,00 pagos, R$ 5,00 de comissão e 100 pontos. Registre um reembolso comprovado de R$ 40,00 com referência única. O extrato conserva a conversão original, lança −R$ 2,00 de comissão e −40 pontos. Os saldos ficam em R$ 60,00, R$ 3,00 e 60 pontos.
8. Quando houver prestação do serviço ou entrega do produto, use **Registrar utilização** e **Concluir entrega**. Na administração, consulte o histórico do cupom e registre faturamento, quitação ou contestação com a referência correspondente.

## Integração com o projeto atual

| Área | Contrato |
| --- | --- |
| Catálogo e emissão | As ofertas continuam em `mvp_partner_offers` e os cupons em `mvp_coupons`. A emissão mantém a assinatura `mvp_activate_offer_coupon(uuid)`. O cadastro comercial aceita desconto percentual, desconto nominal e preço promocional. |
| Validação | `mvp_confirm_receipt` valida o código aleatório emitido pelo servidor, identidade, titular da oferta, estado, prazo e valor. O RPC anterior `mvp_validate_coupon` encaminha a chamada à mesma operação. Abrir um link consulta o cupom. A confirmação exige login e ação explícita. |
| Contabilidade e Passaporte | Conversão, comissão e pontos são lançados na mesma transação. Estornos são movimentos adicionais com referência única por cupom. Os ajustes usam o saldo remanescente para absorver os efeitos de arredondamento. O saldo financeiro do extrato expressa o valor a receber pelo MaraPass. A liquidação da venda ocorre entre turista e parceiro. |
| Acesso e histórico | O vínculo de estabelecimento adotado pelo MVP é a conta aprovada em `mvp_partner_members` que criou a oferta. Os exemplos editoriais ficam fora da contabilidade. Cupons anteriores sem preço comprovado continuam consultáveis para atendimento. Os pontos históricos desses cupons são preservados. |
| Disponibilidade | O servidor congela condições e data final no fuso de Fortaleza. A pausa afeta novas emissões. Um cancelamento ou recusa antes da conversão libera a unidade. Compras confirmadas continuam no histórico após pausa ou ajuste de preço. |
| Extratos | O filtro por período seleciona a data de emissão no Maranhão. Vendas, comissão e ticket médio usam o valor confirmado líquido de estornos daqueles cupons. O total de descontos se refere ao momento da conversão. |
| Notificações | Cada par de evento e destinatário autorizado ocupa uma posição única na fila. Um envio falho permanece isolado do registro comercial. O worker usa uma reserva temporária de trabalho e até seis tentativas. A conciliação dos retornos da Meta usa ID de entrega e status. Uma resposta perdida depois do aceite da Meta pode causar nova entrega do aviso. |

## Migrações e implantação em homologação

A ordem é `20261117231908_mvp_coupon_commerce.sql`, `20261117232129_mvp_coupon_whatsapp.sql` e `20261117234134_mvp_coupon_operations.sql`. A primeira amplia as tabelas em uso e acrescenta extrato, conversão, proteção de acesso e ajustes. A segunda acrescenta consentimento, fila e retornos de entrega. A terceira acrescenta operações de atendimento, faturamento e indicadores. O código de algumas migrações anteriores está apenas no histórico do Supabase. Para um projeto novo, restaure primeiro o esquema de referência do MVP. Os testes incluem um contrato mínimo para uma base PostgreSQL vazia.

Aponte o Flutter e o painel para o projeto de homologação usando a configuração de backend já existente. Publique a função `coupon-whatsapp` nesse mesmo projeto. Esse endpoint atende chamadas da Meta sem JWT do Supabase, por isso a implantação precisa usar `supabase functions deploy coupon-whatsapp --no-verify-jwt --project-ref <ref-de-homologacao>`. A verificação HMAC usa o corpo original da requisição. O caminho `/dispatch` exige um segredo independente.

### Variáveis do servidor

| Variáveis | Uso |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Disponíveis no runtime da Edge Function para chamadas internas. |
| `WA_PHONE_NUMBER_ID`, `WA_ACCESS_TOKEN`, `WA_GRAPH_VERSION` | Número emissor, token do sistema com permissão de envio e versão habilitada da Graph API. |
| `WA_APP_SECRET`, `WA_VERIFY_TOKEN` | Assinatura HMAC-SHA256 e verificação da inscrição do webhook. |
| `WA_TEMPLATE_TOURIST`, `WA_TEMPLATE_PARTNER` | Modelos aprovados de emissão para cada público. |
| `WA_TEMPLATE_CONVERTED_TOURIST`, `WA_TEMPLATE_CONVERTED_PARTNER` | Modelos aprovados de conversão para cada público. |
| `COUPON_WORKER_SECRET` | Autenticação do disparador periódico. |

Cadastre quatro modelos transacionais com idioma `pt_BR`. Cada corpo recebe dois parâmetros posicionais, o nome do item e o valor final em reais. Configure o botão de URL dinâmico com o código do cupom como sufixo. O modelo do turista deve apontar para a raiz HTTPS do app de homologação com `?uso=turista&cupom={{1}}`. O modelo do parceiro usa `?uso=parceiro&cupom={{1}}`. Use **Pagar ao parceiro** e **Conferir recebimento** na emissão e **Ver cupom** ou **Ver extrato** na conversão.

Cadastre a URL da função terminada em `/functions/v1/coupon-whatsapp` como webhook da conta de WhatsApp Business e assine o campo `messages`. Configure um provedor de OTP de telefone no Supabase Auth para verificar números novos. Habilite Cron, pg_net e Vault na homologação. Grave no Vault `coupon_dispatch_url` com o caminho HTTPS da função terminado em `/dispatch` e `coupon_worker_secret` com o mesmo segredo do worker. Execute `supabase/ops/schedule_coupon_whatsapp.sql` para agendar o envio a cada minuto. Esse script atualiza a tarefa pelo nome.

Antes de liberar o canal, faça um ciclo com números de teste autorizados, confira a mensagem nos dois aparelhos, abra o pagamento, converta com a conta correta e confira a entrega final no painel.

## Verificações reproduzíveis

- PostgreSQL. Em uma base local **vazia** chamada `marapass_coupon_test`, defina `MARA_TEST_DSN`, instale `psycopg[binary]` e rode `python supabase/tests/test_coupon_commerce.py`. A suíte usa conexões distintas para as corridas de emissão e de confirmação.
- WhatsApp. Rode `node --test supabase/tests/coupon_whatsapp.test.mjs`. O transporte da Graph API é simulado e as assinaturas são calculadas sobre os bytes do corpo.
- Flutter e painel. A partir de `flutter/`, rode `flutter pub get --enforce-lockfile`, `flutter test` e `flutter build web --release --no-web-resources-cdn`. Rode `node --check flutter/admin/mvp-admin.js` na raiz. O workflow `.github/workflows/cupons.yml` executa as verificações em cada PR que altera o módulo.

[Plataforma oficial do WhatsApp Business](https://developers.facebook.com/documentation/business-messaging/whatsapp/overview/) · [Agendamento de Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions) · [Verificação de telefone no Flutter](https://supabase.com/docs/reference/dart/auth-verifyotp)

