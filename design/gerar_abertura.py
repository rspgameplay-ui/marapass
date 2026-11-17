"""Regenera a abertura animada dentro de flutter/web/index.html a partir do
arquivo OFICIAL da logo (flutter/assets/brand/logo_white.svg): as 6 hélices
coloridas, as 6 dobras sombreadas em degradê e as 8 letras do nome são os
desenhos originais, só animados.
Uso (pasta marapass-app): python design/gerar_abertura.py"""
import re

LOGO = 'flutter/assets/brand/logo_white.svg'
INDEX = 'flutter/web/index.html'

svg = open(LOGO, encoding='utf-8').read()
defs = svg[svg.index('<defs>'):svg.index('</defs>') + 7]
body = svg[svg.index('</defs>') + 7:svg.rindex('</svg>')]

blades = re.findall(r'<path fill="rgb\((?!100%)[^"]*"[^>]*/>', body)           # 6 hélices
folds = re.findall(r'<g transform="translate\([^)]*\)"><path d="[^"]*" fill="url\(#wg\d\)"/></g>', body)
letters = re.findall(r'<path fill="rgb\(100%, 100%, 100%\)"[^>]*/>', body)    # 8 letras
assert len(blades) == 6 and len(folds) == 6 and len(letters) == 8, (len(blades), len(folds), len(letters))

# Cada dobra pertence à hélice que ocupa a mesma região (ordem do arquivo).
# hélices: amarela, marrom, azul, vermelha, verde, areia
# dobras:  amarela, areia, marrom, verde, azul, vermelha
fold_of = {0: 0, 1: 2, 2: 4, 3: 5, 4: 3, 5: 1}
CX, CY = 504, 227.8
order = [0, 1, 2, 5, 4, 3]  # sentido horário a partir do topo (amarela, marrom, azul, areia, verde, vermelha)

groups = []
for k, i in enumerate(order):
    groups.append(
        f'<g transform="translate({CX} {CY})"><g class="mp-blade" style="animation-delay:{0.80 + k * 0.09:.2f}s">'
        f'<g transform="translate({-CX} {-CY})">{blades[i]}{folds[fold_of[i]]}</g></g></g>')

letter_svg = ''.join(
    f'<g class="mp-letter" style="animation-delay:{2.05 + n * 0.06:.2f}s">{p}</g>' for n, p in enumerate(letters))

rays = ''.join(
    f'<line class="mp-ray" x1="{CX}" y1="{CY}" x2="{CX + (150 if n % 2 == 0 else 105) * __import__("math").cos(n * 0.785398):.1f}" '
    f'y2="{CY + (150 if n % 2 == 0 else 105) * __import__("math").sin(n * 0.785398):.1f}"/>' for n in range(8))

CSS = '''/* ===SPLASH-CSS=== (gerado por design/gerar_abertura.py) */
@font-face{font-family:'Plus Jakarta Sans';src:url('assets/assets/fonts/PlusJakartaSans.ttf') format('truetype');font-weight:200 800;font-display:block}
#mp-loading{position:fixed;inset:0;z-index:9999;overflow:hidden;background:#1b2a3b;display:flex;flex-direction:column;
  align-items:center;justify-content:center;transition:opacity .5s ease,transform .5s ease;
  font-family:'Plus Jakarta Sans',system-ui,-apple-system,'Segoe UI',sans-serif;-webkit-tap-highlight-color:transparent}
#mp-loading.out{opacity:0;transform:scale(1.04);pointer-events:none}
#mp-bg{position:absolute;inset:-4%;background:url('assets/assets/photos/splash_bg.jpg') center/cover no-repeat;
  animation:mp-kb 4.2s ease-out both;will-change:transform}
#mp-shade{position:absolute;inset:0;background:linear-gradient(180deg,rgba(14,27,42,.72) 0%,rgba(20,36,54,.30) 40%,rgba(14,27,42,.92) 100%)}
#mp-stage{position:relative;width:min(76vw,340px);aspect-ratio:385.9/368.2;transform:translateY(15%);
  animation:mp-lift .8s cubic-bezier(.22,1,.36,1) 1.95s both}
#mp-stage svg{position:absolute;inset:0;width:100%;height:100%;overflow:visible}
.mp-halo{fill:url(#mp-glow);transform-box:fill-box;transform-origin:center;opacity:0;animation:mp-halo 2.4s ease-out .15s both}
.mp-ring{fill:none;stroke:rgba(255,255,255,.22);stroke-width:.9;transform-box:fill-box;transform-origin:center;transform:scale(0);
  animation:mp-grow 1.1s cubic-bezier(.22,1,.36,1) both}
.mp-ray{stroke:rgba(255,255,255,.14);stroke-width:.8;stroke-dasharray:160;stroke-dashoffset:160;animation:mp-draw 1s ease-out .2s both}
.mp-dot{fill:#fac61d;transform-box:fill-box;transform-origin:center;animation:mp-dot .85s ease-out both}
#mp-spin{transform-origin:504px 227.8px;animation:mp-spin 1.05s cubic-bezier(.22,1,.36,1) 1.45s both}
.mp-blade{transform-origin:0 0;opacity:0;animation:mp-blade .62s cubic-bezier(.34,1.5,.64,1) both}
.mp-letter{opacity:0;animation:mp-letter .5s cubic-bezier(.22,1,.36,1) both}
#mp-tag{position:relative;margin-top:6px;text-align:center;color:#fff;opacity:0;animation:mp-tag .8s ease-out 2.55s both}
#mp-tag b{display:block;font-size:13.5px;font-weight:800;letter-spacing:.36em;padding-left:.36em}
#mp-tag span{display:block;margin-top:9px;font-size:11px;font-weight:600;letter-spacing:.42em;padding-left:.42em;color:rgba(255,255,255,.62)}
#mp-bar{position:absolute;left:0;right:0;bottom:0;height:5px;display:flex;transform-origin:left;transform:scaleX(0);animation:mp-bar 1.2s cubic-bezier(.22,1,.36,1) 1.9s both}
#mp-bar i{flex:1}
@keyframes mp-kb{from{transform:scale(1.14)}to{transform:scale(1)}}
@keyframes mp-grow{to{transform:scale(1)}}
@keyframes mp-draw{to{stroke-dashoffset:0}}
@keyframes mp-dot{0%{transform:scale(0);opacity:0}45%{transform:scale(1.6);opacity:1}100%{transform:scale(0);opacity:0}}
@keyframes mp-halo{0%{opacity:0;transform:scale(.3)}35%{opacity:1}70%{opacity:.95;transform:scale(1.1)}100%{opacity:.4;transform:scale(1)}}
@keyframes mp-blade{from{opacity:0;transform:rotate(-115deg) translateY(-34px) scale(.05)}to{opacity:1;transform:none}}
@keyframes mp-spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}
@keyframes mp-lift{to{transform:translateY(0)}}
@keyframes mp-letter{from{opacity:0;transform:translateY(26px)}to{opacity:1;transform:none}}
@keyframes mp-tag{to{opacity:1}}
@keyframes mp-bar{to{transform:scaleX(1)}}
#mp-loading.skip *{animation-delay:0s!important;animation-duration:.01s!important}
@media (prefers-reduced-motion:reduce){#mp-loading *{animation-duration:.01s!important;animation-delay:0s!important}}
/* ===/SPLASH-CSS=== */'''

HTML = f'''<!-- ===SPLASH-HTML=== (gerado por design/gerar_abertura.py) -->
  <div id="mp-loading" role="status" aria-label="MaraPass, carregando">
    <div id="mp-bg"></div><div id="mp-shade"></div>
    <div id="mp-stage">
      <svg viewBox="311 99.1 385.9 368.2" aria-hidden="true">
        {defs.replace('</defs>', '<radialGradient id="mp-glow"><stop offset="0" stop-color="#f5c428" stop-opacity=".42"/><stop offset="1" stop-color="#f5c428" stop-opacity="0"/></radialGradient></defs>')}
        <circle class="mp-halo" cx="{CX}" cy="{CY}" r="170"/>
        <circle class="mp-ring" cx="{CX}" cy="{CY}" r="70"/>
        <circle class="mp-ring" cx="{CX}" cy="{CY}" r="115" style="animation-delay:.12s"/>
        <circle class="mp-ring" cx="{CX}" cy="{CY}" r="160" style="animation-delay:.24s"/>
        {rays}
        <circle class="mp-dot" cx="{CX}" cy="{CY}" r="9"/>
        <g id="mp-spin">{''.join(groups)}</g>
        {letter_svg}
      </svg>
    </div>
    <div id="mp-tag"><b>DESCUBRA · VIVA · VALORIZE</b><span>MARANHÃO 2026</span></div>
    <div id="mp-bar"><i style="background:#f5c428"></i><i style="background:#7c5d46"></i><i style="background:#2e7cf6"></i><i style="background:#dfc39d"></i><i style="background:#43a854"></i><i style="background:#e3524b"></i></div>
  </div>
  <script>
    (function () {{
      var el = document.getElementById('mp-loading');
      var t0 = performance.now(), ready = false, gone = false;
      function hide() {{
        if (gone || !el) return; gone = true;
        el.classList.add('out'); setTimeout(function () {{ el.remove(); }}, 520);
      }}
      window.addEventListener('flutter-first-frame', function () {{
        ready = true;
        setTimeout(hide, Math.max(0, 4100 - (performance.now() - t0)));
      }});
      // Um toque pula a animação (o app entra assim que estiver pronto).
      el.addEventListener('click', function () {{ el.classList.add('skip'); if (ready) hide(); }});
    }})();
  </script>
  <!-- ===/SPLASH-HTML=== -->'''

s = open(INDEX, encoding='utf-8').read()

# CSS: troca o bloco antigo (com ou sem marcadores)
if '/* ===SPLASH-CSS===' in s:
    s = re.sub(r'/\* ===SPLASH-CSS===.*?/\* ===/SPLASH-CSS=== \*/', lambda m: CSS, s, flags=re.S)
else:
    i = s.index('/* Abertura animada em HTML/CSS')
    j = s.index('@media (prefers-reduced-motion:reduce){#mp-loading *{animation-duration:.01s!important;animation-delay:0s!important}}') \
        + len('@media (prefers-reduced-motion:reduce){#mp-loading *{animation-duration:.01s!important;animation-delay:0s!important}}')
    s = s[:i] + CSS + s[j:]

# HTML + script
if '<!-- ===SPLASH-HTML===' in s:
    s = re.sub(r'<!-- ===SPLASH-HTML===.*?<!-- ===/SPLASH-HTML=== -->', lambda m: HTML, s, flags=re.S)
else:
    a = s.index('<div id="mp-loading"')
    b = s.index('</script>', a) + len('</script>')
    s = s[:a] + HTML + s[b:]

# Pré-carrega a fonte e a foto, para a primeira imagem já sair certa.
pre = ('<link rel="preload" href="assets/assets/fonts/PlusJakartaSans.ttf" as="font" type="font/ttf" crossorigin>\n'
       '  <link rel="preload" href="assets/assets/photos/splash_bg.jpg" as="image">')
if 'rel="preload" href="assets/assets/fonts/PlusJakartaSans.ttf"' not in s:
    s = s.replace('<title>MaraPass</title>', '<title>MaraPass</title>\n  ' + pre, 1)

open(INDEX, 'w', encoding='utf-8', newline='\n').write(s)
print('ok', len(s) // 1024, 'KB')
