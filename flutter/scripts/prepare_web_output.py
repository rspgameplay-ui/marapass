"""Assemble the Flutter web app and same-origin map control panel after build."""
from pathlib import Path
import shutil
import os
import json

project = Path(__file__).resolve().parents[1]
output = project / 'build' / 'web'
if not (output / 'index.html').is_file():
    raise SystemExit('Compile primeiro: flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json')
admin = project / 'admin'
shutil.copyfile(project/'assets/data/condominiums.json',admin/'data/condominiums.json')
if any(admin.glob('qa-only*')):
    raise SystemExit('Arquivos de QA não podem ser publicados no painel.')
shutil.copytree(admin, output / 'admin', dirs_exist_ok=True)
shutil.copytree(project / 'web' / 'navigation-3d', output / 'navigation-3d', dirs_exist_ok=True)
headers = (admin / '_headers').read_text().replace('/*\n', '/admin/*\n', 1)

(output / '_headers').write_text(headers)
print('Build Flutter + /admin/ preparado. Ambos precisam da mesma origem.')

# Restricted browser key: explicit deployment-time opt-in, never a service key.
google_key = os.environ.get('GOOGLE_PLACES_WEB_KEY', '').strip()
if google_key and not __import__('re').fullmatch(r'AIza[A-Za-z0-9_-]{20,100}', google_key):
    raise SystemExit('GOOGLE_PLACES_WEB_KEY deve ser uma chave web restrita válida.')
# One initial document works inside an opaque sandbox, without authenticated
# subresources or access to the admin parent/localStorage.
source = project / 'web' / 'google_places'
html = (source / 'index.html').read_text()
html = html.replace('<link rel="stylesheet" href="panel.css">', '<style>' + (source / 'panel.css').read_text() + '</style>')
config = json.dumps({'enabled': bool(google_key), 'apiKey': google_key})
html = html.replace('<script type="module" src="panel.js"></script>', '<script>window.MaraPassGoogleConfig=' + config + ';</script><script type="module">' + (source / 'panel.js').read_text() + '</script>')
(output / 'google_places' / 'index.html').write_text(html)
