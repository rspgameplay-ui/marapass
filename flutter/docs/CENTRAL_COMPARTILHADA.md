# MaraPass — central compartilhada do mapa · entrega 0.3.0

## Acesso e operação

A prévia Flutter permanece em https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site/ e o painel integrado fica em /admin/. Ambos preservam o acesso privado do Site. Dentro do painel, use a conta MaraPass já autorizada e o segundo fator. A sessão ChatGPT do Site não substitui a autenticação MaraPass. Nenhuma conta ou senha foi criada nesta entrega.

1. Entre no painel e escolha **Mapa e conteúdo**.
2. Busque uma referência pelo nome/município ou crie **Novo ponto**. O cadastro existente do mapa mantém seu identificador original quando adotado pela busca de referências.
3. Preencha município, categoria, nome, descrição, coordenadas e informações públicas. Confira o acesso real. Marque a localização como referência quando a entrada não estiver conferida.
4. Informe o motivo e **Salve o rascunho**. A gravação é compartilhada entre computadores autorizados, mas não muda a versão dos visitantes.
5. Abra **Conferir prévia**: ficha, mapa Flutter com ruas reais e comparação entre os valores. A prévia recebe somente o conteúdo da revisão salva, em memória, pelo painel de mesma origem; rascunhos não são inseridos na URL nem em uma consulta pública.
6. Administrador publica o rascunho conferido. Editor envia para revisão. Revisor publica somente uma versão em revisão. A prévia precisa corresponder à revisão salva e ter menos de 30 minutos.
7. Abra o mapa atualizado no celular conectado. O aplicativo consulta o catálogo público ao iniciar, ao retornar à tela ativa e a cada 30 segundos. Há também **Buscar publicações agora** na central. O intervalo não é garantia de entrega quando há falha de rede, suspensão do navegador ou indisponibilidade do serviço.
8. **Histórico** mostra conteúdo, responsável, motivo e data de cada versão. Restaurar cria outro rascunho; não muda a versão pública até nova prévia/publicação. Arquivar remove do mapa compartilhado, preservando o histórico.

O catálogo editorial começa vazio: as 4.217 referências continuam no mapa e podem ser adotadas individualmente para gestão central. Os testes não deixaram pontos fictícios publicados. As antigas alterações locais não são migradas automaticamente. A área local continua acessível para recuperação/backups; um identificador já administrado na central sempre usa a publicação compartilhada no mapa.

## Permissões

- **Administrador**: obtido da equipe administrativa existente (staff_members). Controle do módulo e atribuição/revogação de acessos.
- **Editor territorial**: salvar/restaurar/enviar para revisão nos municípios atribuídos. Precisa de pelo menos um município. Não publica nem arquiva.
- **Revisor**: editar/revisar/publicar/arquivar nos municípios atribuídos; lista vazia significa todo o estado. Publica apenas estado “Em revisão”.
- **Visitante**: lê somente o snapshot publicado, sem rascunhos, responsáveis ou histórico.

Atribua acesso pelo e-mail de uma conta MaraPass já confirmada em **Permissões**. Nenhum convite ou e-mail é enviado por esse módulo. A conta precisa existir primeiro. Mudanças de acesso são auditadas e verificadas na próxima operação; o JWT não é utilizado como fonte de cargo. O perfil administrativo global continua sendo gerido pela equipe administrativa existente.

O servidor verifica auth.uid, sessão Auth ainda existente/ativa, conta não excluída/bloqueada, MFA AAL2, associação vigente e território antigo/novo. Não usa user_metadata para autorização. Publicações não aceitam campos de parceria nem de ofertas. Uma empresa mapeada é uma referência comercial até homologação no módulo Parceiros. Os registros de cupons e ofertas existentes não foram alterados.

## Consistência e manutenção

- Controle otimista de revisão evita sobrescrita silenciosa. Em conflito, atualize o registro e refaça a edição sobre a versão mais recente.
- Identificador idempotente por operação e usuário evita duplicidade em reenvios da mesma solicitação; respostas são guardadas no servidor.
- Cada comando grava versão e publicação na mesma transação. Não há caminho de escrita direta pelo navegador nas tabelas de documentos, publicações ou auditoria.
- Dados de trabalho e versões ficam no schema privado. A função exposta é SECURITY INVOKER; o comando transacional privilegiado fica no schema privado com search_path vazio, execução revogada de PUBLIC/anon, autorização explícita e privilégios de cliente mínimos.
- Tabelas privadas têm RLS e política explícita de negação de acesso direto. Apenas as publicações têm leitura pública por design.
- Arquivamento usa tombstone público com ID/revisão e conteúdo nulo, para suprimir também um ponto da base embarcada. A sincronização usa paginação por ID e substitui o cache somente após receber o snapshot completo.
- Sem conexão, o app preserva o último snapshot e informa falha de atualização. A cache contém somente dados já publicados. Não é canal para retirar imediatamente informação de um aparelho offline.
- Fotos usam URL HTTPS autorizada; upload/recorte de arquivos e comprovação automática de direitos não fazem parte desta entrega.
- Cada versão de código continua exigindo build/deploy. Alterações editoriais publicadas usam dados remotos e dispensam recompilar o app instalado com esta versão.

## Instalação e implantação

O diretório `admin/` contém a evolução V10 do painel V9 preservado, com autenticação e módulos operacionais existentes. O mapa continua em Flutter. Execute `python scripts/prepare_web_output.py` APÓS `flutter build web` para copiar o painel e preparar os cabeçalhos; não publique arquivos de QA. `admin/data/` contém as mesmas referências públicas IBGE/OSM do aplicativo.

`database/map_content.sql` é o instalador consolidado para uma base que já tem a fundação territorial MaraPass. Não executar novamente no projeto atual: as mudanças já foram aplicadas por migrações registradas no Supabase. Não é uma rotina de importação nem deve ser chamado pelo aplicativo.

Migrações desta entrega: marapass_map_shared_editorial_workflow; marapass_map_command_scope_fix; marapass_map_team_labels_and_private_policies; marapass_map_history_actor_label_fix. O instalador consolidado incorpora as correções finais. Os 217 códigos/nomes municipais foram acrescentados sem sobrescrever registros existentes. Não foram homologados vínculos de polos nem publicados limites territoriais não verificados.

`database/test_map_content.sql` testa o fluxo real no banco dentro de uma transação com rollback. Usa uma sessão administrativa existente apenas em SQL privilegiado; não emite tokens, não altera MFA e não cria contas. Não deve ser exposto no navegador.

O endpoint e chave publicável estão em `config/catalogo.json`. `CONTROL_CENTER_URL` pode apontar para o domínio definitivo ao compilar Android/iOS. Nenhuma chave administrativa foi incluída no cliente.

O painel utiliza a mesma renderização Flutter/OpenFreeMap do aplicativo, inclusive em navegadores sem WebGL. Um iframe da mesma origem recebe somente a ficha salva por postMessage, sem tokens. O receptor valida origem, janela remetente, tamanho, tipo de mensagem e conteúdo. A camada de ruas continua dependendo da rede e do provedor. O Flutter mantém OSRM para as rotas da versão anterior. O arquivo `_headers` limita CSP no painel e preserva bloqueio de frames e cache de autenticação. No Site, o cabeçalho de segurança precisa ser verificado no host; outros provedores devem servir essas diretivas.

## Verificação e limites

Verificações realizadas e limitações atualizadas em `VALIDACAO.md`. O teste físico computador → celular com a conta e o MFA do titular não é substituído pelo teste transacional ou pela simulação de interface. Não há APK/IPA compilado/instalado nem validação em lojas nesta entrega.

Avisos de segurança anteriores do projeto Supabase (incluindo configuração de proteção contra senhas vazadas) permanecem fora do escopo deste módulo. A leitura pública de conteúdo editorial não concede acesso às áreas comercial/financeira.
