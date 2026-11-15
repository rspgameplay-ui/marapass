# Jornada MaraPass — marcadores e confiabilidade

Entrega de 8 de novembro de 2026. A compilação web usa Flutter 3.47.8 / Dart 3.13.7 e as dependências fixadas no pubspec.lock. O layout da versão 18 foi preservado. A publicação desta entrega substitui o pacote web; não distribui APK nem aplicativo iOS.

## O que está integrado

- Marcador terrestre no azul MaraPass: ponto de 12 px, borda branca de 2 px, halo de 15% com raio visual crescente conforme a incerteza, bico de rumo.
- Marcador náutico no dourado já existente: pin de 32 px com vela branca, sombra e flutuação de 3 px em ciclo de 2 segundos no renderizador Flutter. Acessibilidade com redução de movimento desliga a flutuação.
- Troca de modo por etapa `ferry` do provedor, sem inferir uma travessia apenas por proximidade da água. Fade/scale de 250 ms; posição interpolada em 800 ms; rumo pelo arco curto e filtro de pequenas oscilações.
- Curso GPS em movimento a partir de 0,8 m/s; bússola nativa abaixo disso. Rumo ainda não medido é anunciado como indisponível, sem atribuir norte ao usuário. Android usa referência magnética; iOS prefere norte verdadeiro quando disponível.
- Sinal perdido/posição inválida: marcador cinza e semitransparente, aviso existente com texto “Localização imprecisa”, progresso congelado até leitura válida. Precisão superior a 50 m ou leitura com mais de 15 s não avança manobras. O watchdog verifica perda de sinal a cada 5 s.
- Recálculo terrestre após três posições fora da tolerância `max(50 m, 1,5 × precisão)`, intervalo mínimo de 30 s. Falha de conexão mantém a rota anterior. Não se recalcula um trecho de balsa com o roteador de automóveis; o aviso orienta conferir a travessia com o condutor.
- A rota carregada e o marcador continuam no mapa ao perder a rede. O mapa de referência offline existente permanece disponível. Isso não adiciona um motor de cálculo de novas rotas offline nem habilita download de tiles Google.

## Arquivos e finalidade

| Arquivo | Mudança |
| --- | --- |
| `flutter/lib/navigation/traveler_marker.dart` | Desenho proprietário, halo, jangada, flutuação, transição, rumo e semântica. |
| `flutter/lib/navigation/google_traveler_icons.dart` | Cache limitado a quatro bitmaps (dois modos × sinal normal/impreciso); âncora central, `flat: true`, rotação e opacidade. |
| `flutter/lib/navigation/compass_service.dart` | Canal nativo de bússola; plataformas sem suporte usam stream vazio. |
| `flutter/lib/maps/road_map.dart` | Integra marcador e anima apenas a camada de localização, evitando reconstruir tiles a cada frame; encaminha Google quando esse motor estiver habilitado. |
| `flutter/lib/maps/native_maps.dart` | Marcadores Google de ambos os modos, precisão em metros via Circle, posição/rotação interpoladas a 30 fps e fade de 250 ms. Polylines e bitmaps são preservados entre leituras; flutuação Google é estática para reduzir custo. |
| `flutter/lib/domain/navigation.dart` | Preserva `mode` das etapas OSRM. Incluído no commit preparatório anterior. |
| `flutter/lib/application/navigation_session.dart` | Seleção do modo, filtros de rumo, assinatura/cancelamento da bússola, proteção náutica e simulação determinística. |
| `flutter/lib/location/location_service.dart` | Interface própria para stream de navegação, mantendo aquisição de posição separada. |
| `flutter/lib/location/location_native.dart` | Android com foreground service e notificação visível; cadência de 10/5/2 segundos para parado/caminhada/deslocamento, três confirmações e 30 s de estabilidade antes de mudar perfil. iOS com localização de fundo e indicador do sistema. |
| `flutter/lib/presentation/navigation_screen.dart` | Encaminha precisão/rumo/modo; mantém rastreamento nativo ao ocultar a tela; web e simulação pausam ao ocultar; mantém os componentes visuais existentes. |
| `flutter/android/app/src/main/AndroidManifest.xml` | Permissões de serviço de localização e wake lock. |
| `flutter/android/app/src/main/kotlin/com/marapass/marapass_mapa/MainActivity.kt` | Bússola com sensor de rotação, descarte de sensor não confiável e ajuste à orientação da tela. |
| `flutter/ios/Runner/Info.plist` | Modo de fundo de localização. |
| `flutter/ios/Runner/AppDelegate.swift` | Bússola CoreLocation e encerramento da assinatura. |
| `flutter/assets/data/simulation_route.json` | Geometria de referência já usada nos testes, empacotada para a demonstração sem rede. |
| `flutter/test/traveler_marker_test.dart` | Arco curto e direções cardeais. |
| `flutter/test/journey_reliability_test.dart` | Simulação mista offline, proteção de balsa, perda/retorno de precisão, rumo, acessibilidade, animação reduzida e cache Google. |
| `flutter/test/location_service_test.dart` | Injeta bússola simulada para testar permissões/GPS sem depender de sensores físicos. |
| `dist/` | Resultado compilado, com painel e páginas auxiliares preservados. |

## Como testar em casa

Abra o mapa com `?route=barreirinhas&simulation=mixed`. A demonstração começa automaticamente, sem solicitar GPS, dura aproximadamente 48 segundos e troca para náutico no terço central. O banner identifica expressamente os modos fictícios. Os primeiros 1,8 km da geometria de referência São Luís–Barreirinhas são apenas suporte do teste visual: o modo náutico demonstrado NÃO comprova que exista navegação por barco nesse trecho. Nenhum deslocamento real é gravado. O botão existente “Parar navegação” encerra a demonstração; simulação comum continua disponível no botão “Simular percurso sem GPS”.

Para teste de código: `NavigationSession.loadMixedSimulation()` ou `startSimulation(mixed: true)` com rota carregada.

## Compilação e validação

Na pasta `flutter/`:

```bash
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter pub get --enforce-lockfile
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter test --no-pub --reporter expanded
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter build web --no-pub --release --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=config/catalogo.json
python scripts/prepare_web_output.py
```

A suíte completa passou: **76 testes**. A compilação release web concluiu com sucesso. A análise dirigida dos arquivos Dart alterados não encontrou erros nem warnings; restam sugestões de estilo. AndroidManifest e Info.plist foram analisados como XML/plist válidos. Conferência visual no Chrome concluída: tela inicial preservada; marcador terrestre visível, troca para jangada e acompanhamento contínuo da câmera verificados. Evidência em `docs/validation/simulacao-marcador-nautico.jpg`.

## Limites que exigem homologação nativa

Esta entrega foi compilada e testada para web. O ambiente não tem Xcode nem SDK Android: não foi gerado APK/IPA e não houve validação física de bússola, consumo de bateria, permissões aproximadas ou rastreamento com a tela bloqueada. As integrações nativas estão no código, mas dependem dessa homologação antes de afirmar confiabilidade em produção nesses cenários. Encerrar o aplicativo à força ou revogar permissão pode interromper o rastreamento; não se promete continuidade nessas condições.

O navegador não garante localização com tela bloqueada e não fornece a bússola nativa implementada aqui. A orientação web usa o curso GPS em movimento. A configuração atual mantém `GOOGLE_MAPS_READY=false`; o mapa publicado continua no renderizador existente. Para ativar o adaptador Google nativo serão necessárias chaves restritas/Map IDs e compilação dos apps Android/iOS, sem alterar a configuração web.
