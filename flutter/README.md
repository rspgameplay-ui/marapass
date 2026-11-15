# Atualização 0.4.0 — navegação clara

Código Flutter com cartografia de referência embarcada e simulação sem GPS. Cobertura, uso e limites: [NAVEGACAO_CLARA.md](docs/NAVEGACAO_CLARA.md). O planejamento de rotas usa OSRM; trânsito ao vivo e alertas Waze não estão incluídos.

Para começar a programar e simular: [docs/SIMULAR_FLUTTER.md](docs/SIMULAR_FLUTTER.md). Perfis do VS Code para Chrome e dispositivo móvel selecionado incluídos.

# Entrega 0.3.0 — central compartilhada

O mapa Flutter agora recebe as publicações do painel em `/admin/`. Guia de uso e arquitetura: [docs/CENTRAL_COMPARTILHADA.md](docs/CENTRAL_COMPARTILHADA.md). O cadastro editorial e histórico já estão instalados no Supabase conectado. O painel preserva login e MFA do V9 e acrescenta o módulo Mapa e conteúdo.

Para o build web integrado, execute `python scripts/prepare_web_output.py` depois de compilar. Ele acrescenta `/admin/` e os cabeçalhos de segurança ao build. Hospede o painel e o mapa na mesma origem: a prévia usa o próprio Flutter por um canal privado de memória, sem gravar o rascunho em URL ou no catálogo público.

# MaraPass — mapa turístico em Flutter

Protótipo do mapa turístico, navegação interna e central de customização em Flutter. Código Flutter/Dart para Android, iOS e uma prévia compilável para navegador. O mapa inicial online usa Flutter Map com renderização vetorial OpenFreeMap, sem exigir chave. O adaptador Google Maps nativo está implementado e passa a ser o inicial quando as credenciais móveis forem configuradas.

## O que já faz

- Identidade MaraPass com azul-escuro e cata-vento vetorial inspirado na referência fornecida.
- **217 municípios**, com código IBGE, sede, região geográfica e geometria territorial de 2025.
- **3.991 lugares nomeados do OpenStreetMap**, vinculados por geometria a 146 municípios, além das sedes e de 9 referências editoriais anteriores: 4.217 pontos no total.
- Mapa de ruas, rodovias, bairros e edifícios, servido pelo OpenFreeMap e renderizado em Flutter. Não depende de WebGL do navegador nem de uma chave Google para abrir. Os detalhes disponíveis variam com o mapeamento da região.
- Busca por nome, município, endereço, categoria e palavras-chave; filtros; favoritos; diretório “Cidade por cidade”. As listas criam linhas sob demanda.
- **Rotas dentro do MaraPass**: origem por lugar/cidade ou GPS, geometria rodoviária, alternativas, distância, tempo estimado e lista de manobras em português.
- Acompanhamento GPS em primeiro plano, avanço das manobras, seguir posição, controle de voz, recálculo por desvio confirmado e indicação de chegada ao final da via. A lógica foi testada com posições controladas; ensaios em estrada e validação de Android/iPhone permanecem obrigatórios.
- Central local para cadastro, edição, visibilidade e backup JSON. Cadastrar uma empresa não a torna parceira e não cria ofertas.
- Leitura de parceiros e ofertas públicas do Supabase existente, sem alterar o banco. Ofertas em cache nunca são tratadas como vigentes.
- Catálogo essencial e favoritos disponíveis sem sinal. O modo essencial não contém ruas nem roteamento offline. O mapa vetorial tem cache de visitação, sem download de regiões garantido.

A base é real, mas **não é um inventário turístico completo ou homologado**. As 71 cidades sem pontos OSM nomeados nesta extração continuam com sede e mapa de ruas; seus cadastros precisam ser complementados. Endereços, horários e contatos ausentes são sinalizados. Não há avaliações, descontos, trânsito, interdições ou limites de velocidade inventados.

Veja `docs/DADOS_E_FONTES.md`, `assets/data/source_manifest.json` e `docs/cobertura_municipal.csv` para as fontes, metodologia e lacunas por cidade.

## Abrir a prévia publicada

https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site

A prévia é privada e pode pedir entrada com sua conta do ChatGPT. Ela usa a compilação web deste mesmo projeto Flutter. O mapa principal é renderizado pelo Flutter e também funciona em navegadores sem WebGL2. O adaptador MapLibre adicional depende desse suporte. A prévia não é um IPA/APK instalável.

## Área local de customização (legado)

A central principal agora oferece acesso ao painel compartilhado. O fluxo abaixo descreve somente a área local, disponível em “Área de trabalho deste aparelho”.

Abra o ícone de edição de localização no cabeçalho ("Central de customização").

1. Toque em **Novo cadastro** e escolha ponto de interesse, atrativo ou empresa.
2. Preencha nome, município, categoria, descrição e coordenadas. Vírgula ou ponto decimal são aceitos. É possível aproveitar o centro da área visível do mapa como referência inicial, mas isso não confirma a entrada do local.
3. Acrescente região editorial, palavras-chave, endereço, horários, telefone, WhatsApp, site, foto por URL HTTPS e fonte para conferência.
4. Salve como **Rascunho**, **Visível no meu mapa** ou **Arquivado**. Apenas visíveis entram no mapa e na pesquisa turística.
5. Pesquise na central e filtre por tipo, situação e categoria. Toque no registro para editar. O menu do ponto permite vê-lo no mapa, excluir um cadastro próprio ou restaurar uma referência original.
6. Use o menu de backup para exportar JSON. No navegador, há download; em plataformas nativas, copie o texto. Para restaurar, cole o JSON em **Importar backup JSON**, confira o resumo e confirme. A importação mescla IDs iguais e preserva os demais.

Os registros persistem em SharedPreferences neste navegador/aparelho. Não são sincronizados entre dispositivos e não publicam no catálogo de todos os turistas. Limpar os dados do navegador/aplicativo pode removê-los: exporte backups. Os JSONs incluem apenas suas personalizações; o catálogo embarcado e os parceiros públicos continuam sendo carregados separadamente.

A central edita referências embarcadas por sobreposição reversível. Não altera os estabelecimentos reais do Supabase. Cadastrar uma empresa não a torna parceira e não cria cupons. A administração compartilhada já está implementada no módulo separado descrito em docs/CENTRAL_COMPARTILHADA.md. Esta área local não substitui a publicação compartilhada.

As coordenadas são validadas pela extensão geográfica aproximada do Maranhão, não por uma malha municipal oficial nem pela entrada física do local. A precisão do acesso continua sob revisão editorial. Fotos são links externos, não uploads de arquivos.

## Rodar

Ambiente usado: Flutter 3.47.8, Dart 3.13.7. Dependências diretas fixadas e `pubspec.lock` incluído. Android API 24+, JDK 21 para o MapLibre e SDK Android compatível com o Flutter. iOS 16+ com Xcode e ferramentas exigidas por `flutter doctor`.

```bash
flutter pub get
flutter run --dart-define-from-file=config/catalogo.json
```

Para prévia no navegador, use Chrome instalado:

```bash
flutter run -d chrome --dart-define-from-file=config/catalogo.json
```

O arquivo `config/catalogo.json` contém somente a URL e a chave publicável do projeto MaraPass já utilizado pelo protótipo anterior. Ela identifica o projeto; a proteção dos registros continua sendo feita por RLS. Nunca coloque chave `service_role` ou segredo de servidor no aplicativo.

Para gerar a prévia web com o renderizador no próprio pacote:

```bash
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json
```

## Ativar Google Maps como mapa inicial

O Map ID de JavaScript e uma chave restrita por website do HTML anterior não ativam o SDK nativo. Configure os SDKs e chaves específicos, com faturamento, cotas e restrições do Google Cloud adequados.

1. Habilite Maps SDK for Android e Maps SDK for iOS no projeto Google Cloud.
2. Crie chave Android restrita ao pacote `com.marapass.marapass_mapa` e ao SHA-1 do certificado. Antes de distribuir, use o certificado de assinatura correto.
3. Defina a chave Android na variável `MARAPASS_GOOGLE_ANDROID_KEY` antes de `flutter run` ou `flutter build`. O Gradle injeta essa variável no Manifest.
4. Para iOS, crie chave restrita ao Bundle ID mostrado em Xcode → Runner. Em Build Settings, crie `GOOGLE_MAPS_API_KEY`; o Info.plist e o AppDelegate já leem esse valor. Nunca adicione a chave ao controle de versão.
5. Crie Map IDs dos tipos Android e iOS e associe a eles o estilo MaraPass que oculta POIs comerciais nativos. Preencha `GOOGLE_MAP_ID_ANDROID`, `GOOGLE_MAP_ID_IOS` e `GOOGLE_MAPS_READY: true` em uma cópia local da configuração.
6. Compile com essa cópia: `flutter run --dart-define-from-file=config/local.json`.

O código Google foi verificado pelo analisador e pela compilação compartilhada do projeto, mas ainda precisa de execução em dispositivos reais com essas chaves. Não há download nem reutilização de tiles Google no modo essencial. O botão principal de navegação agora abre o planejador interno OSRM/OpenStreetMap. O Waze permanece uma alternativa externa opcional. O adaptador Google de visualização não transforma as rotas OSRM em um serviço Google Navigation.

## Arquivos principais

| Arquivo | Responsabilidade |
| --- | --- |
| `lib/main.dart` | Inicializa dados locais, preferências, Riverpod e tema. |
| `lib/core/config.dart` | Configuração por compilação e seleção de Google nativo. |
| `lib/domain/tourism.dart` | Modelo turístico, categorias, distância, busca normalizada e clusters. |
| `lib/data/tourism_repository.dart` | Catálogo embarcado, leitura pública por área visível e cache. |
| `lib/application/map_state.dart` | Filtros, favoritos, pedidos de câmera e descarte de respostas antigas. |
| `lib/domain/navigation.dart` | Geometria rodoviária, manobras em português e projeção na rota. |
| `lib/data/routing_repository.dart` | Integração OSRM, limites de chamada e respostas sem rota. |
| `lib/application/navigation_session.dart` | GPS, progresso, voz, desvio e chegada em primeiro plano. |
| `lib/maps/road_map.dart` | Mapa vetorial Flutter, ruas, marcadores, rotas e atribuição. |
| `lib/presentation/navigation_screen.dart` | Planejamento e acompanhamento do percurso dentro do app. |
| `lib/presentation/city_directory.dart` | Diretório oficial dos 217 municípios e cobertura de POIs. |
| `lib/maps/native_maps.dart` | Adaptadores MapLibre e Google, camadas e ícones. |
| `lib/maps/essential_map.dart` | Contorno e referências navegáveis sem rede. |
| `lib/presentation/catalog_center.dart` | Central de pesquisa, cadastro, edição, visibilidade e backup. |
| `lib/data/catalog_workspace.dart` | Persistência e validação do catálogo local, importação atômica e exportação. |
| `lib/presentation/map_screen.dart` | Busca, filtros, lista, detalhes e guias essenciais. |
| `assets/data/places.json` | Base municipal IBGE, registros OSM e referências editoriais, com proveniência. |
| `assets/map/maranhao.geojson` | Contorno IBGE 2025 transformado e simplificado para exibição. |
| `config/catalogo.json` | Conexão pública com o catálogo MaraPass. |
| `test/` | Busca, validade de ofertas, clusters, consulta pública e fluxo de favoritos. |

## Rotas e limites

O serviço de rotas padrão é FOSSGIS/OSRM, compatível com o formato OSRM v5. Configure `ROUTING_BASE_URL` para um endpoint próprio/contratado compatível. A rede deve incluir automóveis no caminho `/route/v1/driving/`. Não coloque segredo de servidor no Dart. O aplicativo solicita geometria GeoJSON completa, passos e alternativas, com distância máxima de 500 m para encontrar uma via próxima a cada ponto.

O cálculo recebe origem e destino. Ao iniciar, o aplicativo solicita GPS e, se necessário, recalcula a partir da posição real, em vez de iniciar um trajeto cuja origem era apenas de planejamento. Posições com precisão pior que 50 m ou mais antigas que 15 s não avançam instruções. A chegada exige duas leituras com precisão até 30 m, perto do final da geometria. O serviço não confirma a entrada física do estabelecimento.

O acompanhamento termina ao sair da tela ou colocar o app em segundo plano. Voz depende do suporte do aparelho/navegador; não exige microfone. Não há acompanhamento em segundo plano, orientação por faixas, detecção de bloqueios, navegação por dunas/trilhas, trânsito ao vivo ou garantia de segurança viária. Travessias de balsa exigem confirmação de operação e horários.

A instância pública de rotas é uma integração de prévia sem SLA. O intervalo no cliente não implementa quota global da plataforma. Antes de lançar, contratar ou hospedar serviço adequado, rever privacidade e observar as condições dos provedores. A API e os dados comerciais de Google/Mapbox/Waze não foram copiados; sua integração específica exige credenciais e contratos próprios.

## Conteúdo e território

As sedes e os códigos vêm do IBGE; as posições de POIs vêm do OpenStreetMap e são tratadas como referências de acesso. O cruzamento espacial usa os polígonos originais da Malha Municipal 2025, transformados de SIRGAS 2000 para WGS84. A geometria exibida é simplificada para uso turístico, não para demarcação.

Regiões Geográficas do IBGE não são polos turísticos. A composição oficial dos polos, incluindo Balaiada, ainda requer homologação. Os agrupamentos editoriais herdados não são gravados no Supabase nem apresentados como vínculos territoriais oficiais.

## Evolução necessária para lançamento

- Completar o cadastro das 71 cidades sem pontos nesta extração; homologar entradas, categorias, horários, fotos e composição territorial oficial, incluindo Balaiada.
- Validar a navegação em estrada, sensores, bateria, voz e retorno de sinal em Android/iPhone; configurar rotas com capacidade e privacidade adequadas à produção.
- Acrescentar consulta PostGIS com clusters no servidor. Esta leitura de transição usa os campos numéricos atuais e limita o retorno a 500 estabelecimentos por área. Não foi avaliada em escala estadual com milhares de parceiros.
- Contratar ou confirmar uma fonte de tiles com licença offline e implementar pacotes MapLibre por polo, com tamanho real, pausa, retomada e atualização. Os guias atuais são dados próprios; não são pacotes de ruas.
- Integrar a emissão e validação de cupons, QR, check-ins pendentes e passaporte às operações atômicas existentes. Este módulo é de descoberta e não altera transações.
- Publicar traduções completas para inglês/espanhol. Os textos atuais são em português e os módulos estão separados para extração de mensagens.
- Validar contraste e leitor de tela nos dois sistemas, ampliação de texto, desempenho e consumo de memória em Android de entrada. A lista fornece alternativa acessível aos marcadores.
- Assinar, compilar e validar Android/iOS em aparelhos reais; distribuir Android e TestFlight conforme as contas do projeto.

## Fontes e licenças

- MapLibre Flutter: https://maplibre.org/flutter-maplibre-gl/
- Google Maps Flutter: https://pub.dev/packages/google_maps_flutter
- Map IDs por plataforma: https://developers.google.com/maps/documentation/get-map-id
- Estilo online: https://openfreemap.org/ — crédito de dados OpenStreetMap, OpenMapTiles e OpenFreeMap conforme o estilo; atribuição mantida no mapa. Não há download de regiões nesta implementação; observar os limites atuais do provedor ao implementá-lo.
- Base territorial atual: IBGE Localidades 2022 e Malha Municipal 2025, transformadas para WGS84.
- Conteúdo: municípios IBGE, extração OpenStreetMap e 9 referências editoriais herdadas. Fontes e limites estão em `docs/DADOS_E_FONTES.md`.

## Verificação

```bash
flutter analyze
flutter test
```

Veja `docs/VALIDACAO.md` para os resultados obtidos no ambiente de desenvolvimento e as verificações que ainda dependem de um aparelho.


### Jornada personalizada — 0.5.0

A navegação inclui Descobertas no caminho, interesses locais persistidos, proximidade do percurso, seleção por progresso, salvos e ofertas públicas com vigência e confirmação recente. A equipe continua editando os atrativos no CMS existente. Detalhes de funcionamento, validação, limites e preparação do catálogo comercial: [docs/JORNADA_050.md](docs/JORNADA_050.md).


### Piloto Barreirinhas — 0.6.0

Tela Flutter ?pilot=barreirinhas com seleção inicial, busca e filtros; vínculo googlePlaceId no CMS compartilhado e componente Google Places UI Kit web preparado, desativado até configuração de chave restrita. Estado e ativação: [docs/BARREIRINHAS_060.md](docs/BARREIRINHAS_060.md).
