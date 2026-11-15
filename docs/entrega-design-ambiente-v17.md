# MaraPass — refinamento cartográfico e ambiente

Entrega Flutter Web sobre o projeto original. Não altera o módulo separado de cupons nem a audiência do mapa.

## O que mudou

- Removidos o traçado azul decorativo e a tintura estadual do MapLibre; a base local não desenha borda perimetral. Divisas municipais discretas são linhas neutras, sem alterar a geometria.
- Estilos locais Terra Dia/Noite derivados do OpenFreeMap Liberty, com costa, rios, vegetação e vias do OpenStreetMap. Não se fabricaram geometrias nem se arredondou a costa.
- Paleta areia, sálvia e água suave; contraste concentrado nos pontos turísticos. Etiquetas de vias e pequenos núcleos aparecem progressivamente com o zoom.
- Marcadores próprios desenhados por código, pontos compactos, detalhes a partir do zoom 15 e agrupamento espacial com maior raio nos níveis regional e urbano, para reduzir o número de bolhas sem excluir pontos. Alvos de toque de 44 px preservados.
- Fonte Manrope sob OFL; licença embarcada. A fonte é aberta, não exclusiva do MaraPass.
- Relevo regional já existente (Mapzen/USGS + máscara IBGE) em baixa opacidade, oculto acima do zoom 11. É sombreamento raster regional, não levantamento 3D de precisão.
- Cartão compacto com previsão da sede municipal selecionada ou mais próxima do centro da vista. Detalhes abrem sob demanda. Dados ausentes aparecem como não informados.
- Vento em km/h, direção de origem em graus/cardinais e seta apontando para o destino do vento. Microanimação apenas no detalhe, respeitando movimento reduzido. Não se inventa um campo espacial de fluxo a partir de uma previsão pontual.
- Aparência automática às 6h/18h do Maranhão (UTC−3), com seleção Dia/Noite. Não calcula nascer/pôr do sol. Os estilos da base de ruas e MapLibre são locais; o Google alternativo mantém sua própria configuração e o modo essencial permanece uma referência simplificada.

## Dados ambientais e privacidade

`marapass-environment` é a função já publicada no projeto Supabase `nwwxobiqynawxxnbvubz`. O frontend envia apenas um código municipal IBGE. O provedor recebe a coordenada fixa da sede; não recebe o GPS preciso nem o IP do turista encaminhado pelo aplicativo.

Fonte: MET Norway / ECMWF, Locationforecast, CC BY 4.0. É **previsão automática por modelo**, não observação de uma estação em tempo real. Resolução global aproximada de 9 km; vento local pode diferir em dunas, ilhas e relevo complexo. Fonte e horários aparecem no detalhe.

Cache compartilhado de três horas no servidor, bloqueio atômico para coalescer consultas, cache de dez minutos no cliente. Reaproveitamento excepcional de uma resposta com até seis horas é explicitamente identificado. Previsões sem ponto válido próximo ao horário atual não são apresentadas como atuais. Consulta falha sem fabricar números.

A chave pública do projeto é adequada ao frontend. A chave de serviço permanece no servidor. O cache tem RLS e acesso de cliente revogado; o RPC de bloqueio é exclusivo do serviço. O endpoint meteorológico é público de leitura, não uma API de dados pessoais; a chave pública não equivale a autenticação individual nem a limitação de abuso.

## Marés e ondas — limite desta entrega

Foram incluídos links oficiais do CHM para tábuas de marés de 2026 e previsão de ondas. **Não há altura de ondas ou maré numérica integrada**. A associação de estações/portos e um feed licenciado e validado são a próxima etapa. Não transferir os valores de um porto para todas as ilhas. A previsão turística não substitui cartas náuticas, avisos oficiais ou decisão do operador.

## Aplicar no VS Code

1. Abra a pasta `flutter` do código entregue, usando Flutter 3.47.8 / Dart 3.13.7 ou ambiente compatível com o lockfile. Instale as extensões Flutter/Dart se necessário.
2. No terminal nessa pasta:

```powershell
flutter pub get --enforce-lockfile
flutter test
flutter run -d chrome --dart-define-from-file=config/catalogo.json
```

3. Para gerar o site:

```powershell
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json
python scripts/prepare_web_output.py
```

Publique o conteúdo de `flutter/build/web` na **mesma origem** do painel `/admin/`, mantendo `/google_places/` e `/seguranca/`. Na hospedagem Sites deste projeto a saída final fica em `dist/`. Não substitua o cadastro real por fixtures de teste.

A origem pública existente já está permitida na função de clima. Para testar clima no Chrome local com outra origem, adicione **essa origem exata** à constante `ORIGINS` em `flutter/server/environment.ts` e publique a função; não use `*` e não mude o endpoint para contornar CORS. O simulador sem origem autorizada mostra indisponibilidade, mantendo o mapa utilizável.

O backend e o cache já existem. `server/environment_cache.sql` documenta a estrutura; **não reaplique a estrutura em produção para instalar o frontend**. `server/environment.ts` e `cities.json` são cópias do código da função publicada, recuperadas do servidor.

## Manutenção e fontes

- Estilos: `lib/maps/road_map.dart`, `lib/maps/native_maps.dart`, `assets/map/style_day.json`, `style_night.json`.
- Gerador reproduzível: `scripts/prepare_map_styles.py`, entrada no repositório oficial `hyperknot/openfreemap-styles`, `styles/liberty/style.json`. Licença copiada ao lado dos estilos.
- Ambiente: `lib/environment/`; `server/`; testes `test/environment_test.dart` e `tests_node/environment.test.mjs`.
- Fontes: https://openfreemap.org/ ; https://api.met.no/doc/locationforecast/datamodel ; https://api.met.no/doc/TermsOfService ; https://www.marinha.mil.br/chm/tabuas-de-mare-6 ; https://pam.marinha.mil.br/ww3.html
- O renderizador mantém limites de cache e concorrência e debounce da vista. Não há promessa de 60 fps em todo aparelho, teste de carga simultânea ou SLA do provedor público.

## Segurança fora deste escopo

A conferência de advisors ainda aponta avisos preexistentes sobre políticas que aceitam sessões anônimas em tabelas de negócios e proteção contra senhas vazadas desativada. Não foram alteradas políticas dos cupons nesta entrega. A ausência de política no cache é intencional: clientes não podem lê-lo; apenas o serviço tem privilégios.

Referências para a revisão específica: https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins ; https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Validação final

- 68 testes Flutter passaram na revisão final, incluindo cadastro, busca, favoritos, navegação, ilhas e layout em tela pequena com texto ampliado.
- Sete testes Node do proxy passaram: conversão de vento, validade, cache, coordenadas fixas, ausência de credencial de serviço ao provedor e CORS.
- Compilação Flutter Web release JavaScript concluída. O dry-run inicial para Wasm aponta limitações preexistentes do flutter_tts; não foi publicado um build Wasm.
- Navegador confirmou mapa vetorial real, troca Dia/Noite e previsão com município, validade, fonte e direção do vento. Uma diferença entre inteiros no Dart VM e JavaScript foi corrigida no seletor de horário e conferida novamente no navegador.
- O navegador remoto usou renderização por CPU. Não foi medida taxa de quadros em aparelho físico nem validado GPS em campo nesta entrega.
