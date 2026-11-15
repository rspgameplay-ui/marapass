# Validação — mapa, catálogo e navegação interna

Flutter 3.47.8 / Dart 3.13.7 em Linux. A entrega permanece uma prévia Flutter web com código compartilhado para Android/iOS.

## Verificado nesta versão

- **20 testes**: filtro e validade das ofertas públicas, contingência de rede, busca sem acentos, favoritos, clusters, resposta antiga de viewport, cadastro/visibilidade/importação local, inventário de 217 municípios e proveniência dos 3.991 registros OSM, geometria real de São Luís–Barreirinhas, manobras, projeção na rota, descarte de GPS impreciso/antigo, chegada confirmada, desvio e recálculo com intervalo, resposta tardia após encerrar e planejador interno em tela compacta.
- Testes de interface do mapa, central e planejador com largura de **320 px** e texto ampliado em **1,6x**. Os painéis do planejador têm rolagem e altura limitada para não esconder controles em telas pequenas. Não substitui ensaios de acessibilidade com leitores de tela reais.
- `flutter analyze --no-pub`: sem problemas no código do aplicativo após a correção de layout e do provedor de ruas.
- Compilação release para web, JavaScript/CanvasKit, com fontes e renderizador no pacote. A dependência de voz `flutter_tts` emite avisos no ensaio experimental de WebAssembly; essa modalidade não é a distribuição usada nem foi homologada.
- API real de rotas OSRM/FOSSGIS respondeu com duas alternativas entre as sedes oficiais de São Luís e Barreirinhas. A principal tem cerca de **255 km**, **38 passos** e tempo estimado de **3 h 56 min** na conferência. É estimativa do serviço, sem trânsito ao vivo e sem confirmação de condições em estrada.
- Conferência visual no navegador: identidade MaraPass, busca por Barreirinhas, ficha com fonte IBGE, botão de navegação interno, desenho da rota, alternativas, lista de manobras e nomes reais de vias, como Avenida Dom Pedro II, Avenida Beira Mar e rodovias da região.
- A camada raster pública OSM devolveu imagens de bloqueio durante a primeira conferência. Ela foi removida da configuração final. A camada OpenFreeMap renderizada pelo Flutter carregou mapa, vias e rótulos no mesmo navegador sem WebGL; não houve contorno do bloqueio do servidor anterior.
- Nenhuma migração ou escrita no Supabase, nenhum cadastro real de parceiro e nenhuma emissão de cupom foram feitos por esta atualização.

## Limites dos testes

O GPS foi exercitado por posições controladas em testes de lógica. Não foi reproduzido deslocamento real, recebimento de voz no aparelho, túnel, perda prolongada de sinal ou desvio em rodovia. Não há certificação de navegação segura nem medição de precisão em campo. Android/iOS ainda precisam de compilação, instalação, assinatura e validação em aparelhos reais; não há APK ou IPA assinado no pacote.

O importador vinculou 3.991 de 3.997 registros OSM a municípios de forma única, usando a malha original do IBGE. Os seis restantes foram excluídos. A distribuição tem 217 sedes e 9 referências editoriais herdadas, totalizando 4.217 pontos. Há POIs nomeados desta consulta em 146 municípios; os outros 71 têm lacunas de cadastro. Todas as posições importadas são referências, sem garantia da entrada física do estabelecimento.

Os testes não comprovam atualização de horários/telefones, homologação dos polos, disponibilidade comercial, cupons, reservas, limites viários ou trânsito em tempo real. O agrupamento territorial turístico anterior continua editorial. Google Navigation, Mapbox Navigation e alertas do Waze não foram integrados ou simulados.

## Lançamento

Validar o percurso em Android/iPhone; selecionar provedor/hospedagem de rotas com capacidade e termos adequados; implantar cotas globais, observabilidade e revisão de privacidade; completar os cadastros dos 71 municípios sem pontos desta extração; homologar acessos e dados dos responsáveis. Testar desempenho, memória, bateria e leitores de tela. O modo essencial não possui ruas nem roteamento offline. Nenhuma meta de 60 fps foi presumida como medida.

A central continua local, com backup JSON. Não sincroniza usuários ou aparelhos e não se apresenta como administração de produção autenticada. As leituras públicas de parceiros e ofertas permanecem separadas dos registros OSM e dos cadastros locais.

## Entrega 0.3.0 — cadastro compartilhado, publicação e permissões

Data: 30/10/2026. O mapa permanece em Flutter; o painel V10 aproveita o acesso/MFA e módulos do painel V9.

- 22 testes Flutter aprovados, incluindo dois testes novos do leitor de publicações: sincronização entre instâncias, persistência offline, supressão por arquivamento e falha intermediária de paginação sem substituir um snapshot íntegro.
- Teste de navegação até a nova central e recuperação da antiga área local atualizado e aprovado. Central nova validada em 320 px e escala de texto 1,6, além dos testes anteriores de mapa/rotas.
- Análise estática sem problemas. Build web JavaScript/CanvasKit concluído. O aviso de dry-run Wasm do flutter_tts anterior continua sem afetar esse build JavaScript.
- Integração real em PostgreSQL com transação e rollback: acesso administrativo/sessão; rascunho privado; reenvio idempotente; publicação sem prévia negada; publicação com prévia; edição mantém versão pública; conflito de revisão; prévia antiga rejeitada; nova publicação; restauração gera rascunho e preserva o publicado; histórico; arquivamento com tombstone; atribuição de editor; território fora do escopo negado; editor não arquiva/publica; envio à revisão; atribuição de revisor; publicação pelo revisor; revogação imediata; MFA ausente e sessão ausente negados. Todos os dados e alterações temporárias de equipe foram revertidos.
- Endpoint público real: GET de map_publications respondeu HTTP 200. RPC editorial anônimo respondeu HTTP 401 por falta de privilégio de execução. Privilégios SQL confirmam ausência de escrita direta authenticated nas publicações. Não foi usado service_role no cliente.
- Advisories de segurança do Supabase consultados: nenhuma ocorrência para as novas tabelas privadas do mapa após as políticas explícitas de negação. Avisos de Auth/políticas anteriores do projeto foram preservados e documentados fora do escopo.
- QA no navegador: tela de login real do painel preservada. Módulo de edição, ficha, comparação, publicação e histórico verificados com adaptador de dados fictícios **somente local**, separado da autenticação real e excluído da publicação. A prévia recebeu a ficha em memória e renderizou ruas reais de São Luís pelo mesmo Flutter/OpenFreeMap, sem WebGL.
- A sessão MFA do titular não foi assumida nem alterada. Não foi feito teste físico ponta a ponta com computador e celular autenticados pelo titular, nem compilação/instalação de APK/IPA.

Critério operacional para homologação pelo titular: entrar no painel → adotar uma referência ou criar ponto real → salvar → conferir prévia → publicar → abrir o mapa atualizado no celular conectado → buscar o nome → conferir histórico → restaurar versão como rascunho. Isso usa a integração já implementada; o teste físico continua pendente.
