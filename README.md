# MaraPass — v10 (Homologação)

Código-fonte da homologação web v10, extraído do commit `87cf4b73aee72bb8e5c0f205172fd02f8bdb8551` do Sites. O projeto Flutter fica em `flutter/`. A camada web 3D é mantida em `navigation3d/`, com a compilação usada pela v10 já em `flutter/web/navigation-3d/`.

## Ambiente

- Flutter **3.47.8** e Dart **3.13.7**, versões registradas no projeto.
- O arquivo [.env.example](.env.example) lista as opções de configuração. O Flutter recebe os valores por `--dart-define` ou `--dart-define-from-file`.
- **Supabase** — `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`. Configure também o marcador `__SUPABASE_PUBLISHABLE_KEY__` nos arquivos `flutter/admin/app.js` e `flutter/admin/parceiro.js` em uma cópia local usada para o build do painel.
- **Cartografia** — `MAPLIBRE_STYLE_URL` usa OpenFreeMap por padrão. `LICENSED_OFFLINE_STYLE_URL` é opcional.
- **Roteamento** — `ROUTING_BASE_URL` para carro e `WALKING_ROUTING_BASE_URL` para caminhada. Os padrões usam OSRM/FOSSGIS.
- **Painel** — `CONTROL_CENTER_URL` define a URL da central editorial. As opções de Google Maps são opcionais.
- **Servidor ambiental** — configure a chave publicável ou anônima no ambiente do servidor. Credenciais privilegiadas pertencem exclusivamente ao ambiente protegido do servidor.

## Build web

```bash
cd flutter
flutter pub get
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUBSTITUA_PELA_CHAVE_PUBLICAVEL \
  --dart-define=MAPLIBRE_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=ROUTING_BASE_URL=https://routing.openstreetmap.de/routed-car \
  --dart-define=WALKING_ROUTING_BASE_URL=https://routing.openstreetmap.de/routed-foot
python3 scripts/prepare_web_output.py
```

O script reúne o painel e os artefatos web em `flutter/build/web/`.

## Banco de dados

O arquivo [supabase/schema.sql](supabase/schema.sql) encadeia as 45 migrações registradas no Supabase MaraPass. Destina-se a um projeto Supabase com os schemas e funções gerenciados da plataforma já instalados. Inclui a configuração do bucket e os dados públicos de referência municipal presentes nas migrações. Conferir em uma instância descartável antes de qualquer aplicação.

## Arquivos binários

Os assets binários da versão recuperada foram incluídos. Para Android, o JAR do Gradle Wrapper não estava no snapshot e precisa ser gerado com a distribuição registrada em `flutter/android/gradle/wrapper/gradle-wrapper.properties`. Caminho exato do JAR: `flutter/android/gradle/wrapper/gradle-wrapper.jar`. A geração do wrapper também fornece os scripts `flutter/android/gradlew` e `flutter/android/gradlew.bat`.

A compilação web utiliza as fontes, ícones, imagens e a camada 3D já presentes no repositório. Consulte [flutter/README.md](flutter/README.md) para os demais detalhes do projeto.
