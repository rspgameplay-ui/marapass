#!/usr/bin/env bash
# Publica app + painel /admin/ em marapass-teste.pages.dev.
# Uso: ENV_FILE=/caminho/.env.txt bash scripts/deploy_teste.sh
# Sempre compila com config/catalogo.json (sem ele o app abre sem o Supabase).
set -eo pipefail
cd "$(dirname "$0")/../flutter"
export PATH="${FLUTTER_BIN:-/c/src/flutter/bin}:$PATH"
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json 2>&1 | tail -1
ENVF="${ENV_FILE:?Defina ENV_FILE com o caminho do .env.txt}"
get(){ tr -d '\r' < "$ENVF" | awk -v k="$1:" 'index($0,k)==1{v=substr($0,length(k)+1); gsub(/^[ \t"]+|[ \t"]+$/,"",v); print v}'; }
rm -rf build/web/admin && mkdir -p build/web/admin
cp -r admin/. build/web/admin/ && rm -f build/web/admin/_headers build/web/admin/LEIA-ME.md
PUB=$(get SUPABASE_PUBLIC)
sed -i "s|__SUPABASE_PUBLISHABLE_KEY__|$PUB|g" build/web/admin/app.js build/web/admin/parceiro.js
{ echo '/admin/*'; tail -n +2 admin/_headers; } >> build/web/_headers
export CLOUDFLARE_API_TOKEN=$(get Chave)
export CLOUDFLARE_ACCOUNT_ID=$(curl -s -m 20 https://api.cloudflare.com/client/v4/accounts -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python -I -c "import sys,json;r=json.load(sys.stdin)['result'];print([a['id'] for a in r if a['name'].lower().startswith('rspgameplay')][0])")
npx --yes wrangler@4.45.0 pages deploy build/web --project-name marapass-teste --branch main --commit-dirty=true 2>&1 | grep -v -i token | tail -1
