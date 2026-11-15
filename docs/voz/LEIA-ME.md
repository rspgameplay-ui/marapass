# MaraPass — busca por voz, rotas e calendário de ofertas

Entrega de 08/11/2026. Mantém a base do mapa e acrescenta um microfone na barra de busca. A voz abre um painel para revisar o comando, pesquisar e escolher um resultado. A mesma frase pode ser digitada nesse painel. O layout principal permanece com 75,7% de área livre para o mapa no teste móvel existente.

## Uso

1. Toque no microfone da busca; depois em “Falar comando”. O sistema solicitará permissão quando necessário.
2. Diga ou digite: “Localize restaurante em Barreirinhas que tem cupons de descontos no dia 20 de janeiro”.
3. Confira a interpretação: Gastronomia, Barreirinhas, ofertas publicadas, 20/01/2027. Sem ano, utiliza a próxima ocorrência; a data interpretada fica explícita.
4. Toque em “Pesquisar comando”. Se houver oferta publicada com vigência compatível, ela aparece com o estabelecimento. A consulta não emite, não reserva e não garante estoque futuro.
5. Toque no estabelecimento para vê-lo no mapa, ou no ícone de direção para planejar sua rota. GPS real só é solicitado ao iniciar a navegação existente.

Outros comandos: “Trace uma rota para Barreirinhas”, “Restaurante em São Luís”, “Pousada em Santo Amaro do Maranhão”, “Cupons em Barreirinhas amanhã”. Datas numéricas e nomes de meses são aceitos; o dia pode ser falado por extenso. Comandos ambíguos, datas inválidas/passadas ou além de 366 dias são recusados. Não é um modelo de linguagem aberto: usa interpretação determinística em português para os padrões documentados.

## Dados reais e calendário

O endpoint `map_offer_calendar` consulta somente ofertas publicadas de estabelecimentos ativos, públicos e no Maranhão. Filtra município, categoria, termo e intervalo de vigência na data civil de **America/Fortaleza**. Exclui ofertas cujo limite global de emissões já foi atingido. Limita a consulta a 100 resultados; solicita refinamento se o limite for excedido. Mostra uma oferta por estabelecimento na lista.

A vigência não garante resgate em qualquer horário do dia: condições comerciais, dias permitidos, regras específicas, disponibilidade e limites por usuário continuam sujeitos à validação na emissão pelo módulo de cupons. Esses mecanismos não foram alterados. Não foram publicados parceiros ou cupons fictícios para preencher a demonstração.

Teste real de 08/11/2026: a consulta de Barreirinhas em **20/01/2027** retornou uma lista vazia de ofertas publicadas. A interface distingue ausência de oferta de falha de conexão. Ofertas futuras retornadas pelo calendário não recebem o selo de cupom utilizável agora.

Os overloads de dois e quatro parâmetros do endpoint preservam compatibilidade; o aplicativo usa quatro parâmetros, com cidade, data, categoria e termo. As funções internas ficam no esquema privado, com saída limitada a campos públicos; a função pública é invoker. As políticas de leitura das tabelas e a emissão de cupons não foram ampliadas. O esquema privado não é exposto como Data API. A categoria residencial já habilitada no validador editorial foi preservada.

## Voz e privacidade

`speech_to_text` **7.5.0** está fixado no projeto e no lockfile. Há uma única instância por sessão, com encaminhamento dos callbacks para o painel aberto. Isso permite fechar e abrir a busca novamente sem reaproveitar callbacks de um painel destruído. A escuta só começa ao tocar em “Falar comando”, dura até 18 segundos conforme os limites do sistema e é cancelada ao fechar o painel ou ocultar o aplicativo.

O MaraPass não salva gravações nem transcrições no backend. O reconhecimento é executado pelo navegador/sistema operacional e pode utilizar o provedor de voz do dispositivo, inclusive serviços remotos. Pode exigir internet e não é garantido em navegadores internos do ChatGPT ou em navegadores sem suporte. Permissão negada ou ausência do serviço apresentam uma mensagem e mantêm a entrada por texto.

Android: permissão RECORD_AUDIO e descoberta de RecognitionService. iOS: descrições de uso do microfone e reconhecimento de fala. Não foi pedido acesso a contatos, câmera ou escuta permanente. O plugin e as configurações nativas estão incluídos; captura real de áudio, Bluetooth, permissões e compilação Android/iOS exigem homologação nos aparelhos e SDKs correspondentes. A validação desta entrega é web, de interpretação de comandos e de consulta de dados; não simula que houve áudio físico reconhecido no navegador de testes.

## Arquivos

- `flutter/lib/voice/command.dart`: interpretação e validação de município, categoria, rota e data.
- `flutter/lib/voice/speech_engine.dart`: instância de reconhecimento e callbacks da sessão ativa.
- `flutter/lib/voice/voice_search_sheet.dart`: revisão, entrada por voz/texto, consulta e ações no mapa/rota.
- `flutter/lib/voice/offer_calendar.dart`: consulta do calendário com filtros; não transforma previsões em cupons atuais.
- `flutter/lib/application/map_state.dart`: inclui o resultado escolhido e centraliza sua posição, preservando os filtros existentes.
- `flutter/lib/presentation/map_screen.dart`: botão de voz dentro da busca existente.
- `flutter/database/offer_calendar.sql`: calendário público de dados publicados.
- `flutter/android/app/src/main/AndroidManifest.xml` e `flutter/ios/Runner/Info.plist`: permissões nativas de voz.
- `flutter/pubspec.yaml`, `flutter/pubspec.lock`: dependência fixada.
- `flutter/test/voice_command_test.dart`: exemplos, datas, ambiguidade, RPC e ausência de selo de uso atual em ofertas futuras.
- `flutter/test/condominiums_test.dart`: qualidade e visibilidade opcional da camada residencial.

## Validação e aplicação

Na pasta `flutter/`, com Flutter 3.47.8 / Dart 3.13.7:

```bash
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter pub get --enforce-lockfile
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter test --no-pub --reporter expanded
CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter build web --no-pub --release --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=config/catalogo.json
python scripts/prepare_web_output.py
```

A suíte completa passou: **87 testes**. A consulta do calendário também foi executada com o papel `anon`; datas passadas foram recusadas e rascunhos editoriais continuaram privados. As integrações nativas não foram compiladas neste ambiente Linux sem SDK Android e Xcode. Os logs acompanham esta entrega.

Conferência visual no Chrome: painel de comandos, interpretação da consulta de 20/01/2027, resposta vazia do catálogo e abertura do planejador interno até Barreirinhas verificados. A evidência captura a entrada por texto; não comprova captura física de áudio.
