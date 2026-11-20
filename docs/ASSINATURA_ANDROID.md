# Assinatura do Android (chave de upload da Google Play)

O app usa o **Play App Signing**: a Google guarda a chave definitiva e nós assinamos cada envio com uma **chave de upload**. Se a chave de upload se perder, dá para pedir uma nova à Google, mas leva dias. Guarde duas cópias.

## 1. Criar a chave (uma vez, na máquina de quem vai guardá-la)

Precisa do Java (vem com o Android Studio). Rode no PowerShell, **fora** da pasta do projeto:

```powershell
keytool -genkey -v -keystore $HOME\marapass-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

O `keytool` pede uma senha e os dados da empresa (nome: Foco Inteligência de Negócios; cidade: São Luís; estado: MA; país: BR).

Guarde o arquivo `marapass-upload.jks` e a senha num cofre de senhas da empresa. **Nunca** coloque no repositório (o `.gitignore` já bloqueia `*.jks` e `key.properties`).

## 2. Build local

Crie `flutter/android/key.properties` (fica fora do Git):

```
storeFile=C:/Users/<você>/marapass-upload.jks
storePassword=<senha>
keyAlias=upload
keyPassword=<senha>
```

Depois:

```powershell
flutter build appbundle --release --dart-define-from-file=config/catalogo.json --dart-define=SITE_URL=https://marapass.com
```

O arquivo sai em `flutter/build/app/outputs/bundle/release/app-release.aab`.

## 3. Build pelo GitHub Actions

Converta a chave para base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\marapass-upload.jks")) | Set-Clipboard
```

Cadastre em *Settings > Secrets and variables > Actions*:

| Segredo | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | o texto copiado acima |
| `ANDROID_KEYSTORE_PASSWORD` | senha do keystore |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | senha da chave |

Rode *Actions > Builds de loja > Run workflow*. O AAB fica nos artefatos da execução.

## 4. Declarações na Play Console

- **Serviço em primeiro plano de localização** (`FOREGROUND_SERVICE_LOCATION`): usado só na navegação guiada por voz, para continuar as instruções com a tela bloqueada. A Play pede uma justificativa e um vídeo curto mostrando a navegação com a notificação fixa.
- **Microfone** (`RECORD_AUDIO`): busca por voz, só quando o usuário toca no microfone.
- O app **não** pede localização em segundo plano (`ACCESS_BACKGROUND_LOCATION`).
