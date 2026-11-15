# Executar e simular o MaraPass em Flutter

O projeto contém código Flutter/Dart executável. A prévia publicada é uma compilação web; ela não é um emulador Android nem um aplicativo iOS instalado.

## Primeiro teste no Windows

1. Instale Git e VS Code e, no VS Code, a extensão Flutter (ela inclui o suporte Dart).
2. Pela paleta de comandos do VS Code, siga “Flutter: New Project” → “Download SDK” para instalar o SDK, caso ainda não tenha Flutter. Não é necessário criar outro aplicativo: depois da instalação, abra a pasta `marapass_flutter` deste pacote, que contém `pubspec.yaml`.
3. Use Flutter 3.47.8 ou versão compatível com as restrições do pubspec. Execute no terminal dessa pasta:

```sh
flutter doctor -v
flutter pub get
flutter devices
```

4. Instale Chrome se necessário. Em Executar e Depurar, escolha **MaraPass — Chrome** e pressione F5. A configuração de conexão pública do catálogo já será passada ao Flutter. Alternativa pelo terminal:

```sh
flutter run -d chrome --dart-define-from-file=config/catalogo.json
```

5. Com o aplicativo em execução em modo debug, altere uma tela em `lib/presentation/` e salve. Use o botão Hot Reload do VS Code; mudanças de inicialização e de configurações podem exigir reiniciar. Não exclua nem recrie o projeto.

## Android em uma janela de celular

1. Instale Android Studio e configure o Android SDK e as ferramentas recomendadas pelo `flutter doctor`. Este projeto usa plugins nativos; siga também os requisitos de JDK e Android documentados no README.
2. No Android Studio, abra **Device Manager**, crie um dispositivo virtual de telefone, instale uma imagem compatível e inicie o emulador. O computador precisa oferecer suporte à virtualização e recursos suficientes para executá-lo.
3. Volte ao VS Code, selecione esse dispositivo na barra inferior, escolha **MaraPass — Android / dispositivo selecionado** e pressione F5.
4. Se o dispositivo não aparecer, execute `flutter devices` e resolva os avisos do `flutter doctor`. O perfil não fixa um ID de emulador, pois ele varia de computador para computador.

O simulador de iPhone mostrado na imagem depende de macOS, Xcode e preparação iOS. Não pode ser iniciado como simulador nativo de iPhone no Windows. A prévia web pode ser aberta no iPhone pelo navegador, mas não substitui o teste nativo de GPS, voz e permissões.

## Roteiro de teste do mapa

- Pesquise São Luís e abra um ponto real.
- Confira endereço, fonte e situação da localização de referência.
- Abra Navegar no MaraPass e calcule uma rota com origem definida. Planejamento não significa que o GPS esteja acompanhando uma viagem.
- Confira filtros, favoritos e diretório municipal.
- Abra Central do mapa → Abrir painel compartilhado. O painel usa o domínio privado publicado: entre com ChatGPT e sua conta MaraPass autorizada/MFA.
- Salve um rascunho no painel, confira a prévia, publique e busque as publicações no mapa do outro dispositivo conectado. Não publique um atrativo fictício como se fosse real.

## Painel local, se necessário

O perfil `flutter run` executa o aplicativo. Ele não serve automaticamente os arquivos estáticos do painel administrativo `admin/`. O botão do aplicativo abre o painel já publicado. Para hospedar mapa e painel juntos, compile e prepare a saída:

```sh
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json
python scripts/prepare_web_output.py
```

Sirva `build/web` em uma mesma origem, conforme o guia CENTRAL_COMPARTILHADA.md. Não reaplique migrações no banco para fazer uma simulação local e não coloque chaves administrativas no Flutter.

## O que foi preparado

Dois perfis de execução do VS Code e recomendações de extensões. Os JSONs foram validados. Nenhuma instalação foi realizada no computador do titular e nenhum emulador Android/iPhone foi iniciado nesta entrega. A versão anterior já teve testes Flutter e build web; a execução nativa no seu computador precisa ser verificada no ambiente escolhido.

Documentação oficial: https://docs.flutter.dev/install/with-vs-code e https://docs.flutter.dev/platform-integration/android/setup
