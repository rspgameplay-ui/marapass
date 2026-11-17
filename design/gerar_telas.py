"""Gera design/marapass-telas.html: 6 telas do app em HTML estático, para
importar no Figma como camadas editáveis (textos, formas e imagens).
Uso: python design/gerar_telas.py (a partir da pasta marapass-app)."""
import base64
import io

from PIL import Image

P = 'flutter/assets/photos/'


def img(n, w=420):
    im = Image.open(P + n + '.jpg').convert('RGB')
    r = w / im.width
    im = im.resize((w, int(im.height * r)))
    b = io.BytesIO()
    im.save(b, 'JPEG', quality=72)
    return 'data:image/jpeg;base64,' + base64.b64encode(b.getvalue()).decode()


def svg(path):
    s = open(path, encoding='utf-8').read()
    return 'data:image/svg+xml;base64,' + base64.b64encode(s.encode()).decode()


LW = svg('flutter/assets/brand/logo_white.svg')
ph = {k: img(k) for k in ['lagoa_boat', 'sunset', 'rest', 'p4', 'fish']}

CSS = """*{box-sizing:border-box;margin:0}
body{background:#e9edf1;font-family:'Plus Jakarta Sans',Arial,sans-serif;color:#13263d;display:flex;gap:40px;padding:40px;flex-wrap:wrap}
.screen{width:390px;height:844px;background:#f3f5f7;border-radius:36px;overflow:hidden;position:relative;box-shadow:0 20px 50px rgba(19,38,61,.18)}
.status{height:44px;display:flex;justify-content:space-between;align-items:center;padding:0 24px;font-size:15px;font-weight:700}
.hero{background:linear-gradient(135deg,#0b3a66,#0e4f80 55%,#14775a);border-radius:0 0 28px 28px;padding:0 20px 22px;color:#fff}
.row{display:flex;align-items:center}.sp{flex:1}
.ic{width:46px;height:46px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px}
.h1{font-size:28px;font-weight:800;letter-spacing:-.5px}.sub{font-size:16px;opacity:.85;margin-top:2px}
.search{background:#fff;border-radius:18px;height:58px;display:flex;align-items:center;gap:12px;padding:0 16px;color:#556677;font-size:17px;margin-top:16px;box-shadow:0 8px 18px rgba(6,26,46,.2)}
.pad{padding:16px 20px}
.grid4{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
.sc{background:#fff;border:1px solid #eef1f4;border-radius:18px;padding:12px 4px;text-align:center;font-size:14px;font-weight:700;box-shadow:0 4px 12px rgba(19,38,61,.06)}
.sc i{display:block;width:44px;height:44px;margin:0 auto 8px;border-radius:14px;font-style:normal;line-height:44px;font-size:20px}
.pass{margin-top:14px;border-radius:22px;padding:20px;color:#fff;background:linear-gradient(135deg,#0b3a66,#14775a)}
.bar{height:10px;border-radius:9px;background:rgba(255,255,255,.25);margin-top:10px}
.bar b{display:block;height:10px;width:30%;border-radius:9px;background:#fac61d}
.card{background:#fff;border:1px solid #eef1f4;border-radius:22px;box-shadow:0 4px 12px rgba(19,38,61,.06);padding:16px}
.title{font-size:20px;font-weight:800;margin:20px 0 10px}
.hscroll{display:flex;gap:12px}
.tour{width:220px;flex:none;background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 4px 12px rgba(19,38,61,.08)}
.tour img{width:220px;height:130px;object-fit:cover;display:block}
.tour div{padding:12px;font-weight:800;font-size:16px}
.tour small{display:block;color:#556677;font-weight:600;font-size:13px;margin-top:4px}
.nav{position:absolute;left:0;right:0;bottom:3px;height:83px;background:#fff;box-shadow:0 -2px 16px rgba(19,38,61,.1);display:flex;justify-content:space-around;padding-top:10px}
.nav div{text-align:center;font-size:12px;font-weight:600;color:#7b8794;width:80px}
.nav div i{display:block;margin:0 auto 4px;width:56px;height:30px;border-radius:15px;line-height:30px;font-style:normal;font-size:20px}
.nav .on{color:#0b3a66;font-weight:800}.nav .on i{background:#e3f1ff}
.stripe{position:absolute;bottom:0;left:0;right:0;height:3px;display:flex}.stripe b{flex:1}
.btn{height:56px;border-radius:14px;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:17px}
.primary{background:#14775a;color:#fff}.navy{background:#0b3a66;color:#fff}.yellow{background:#fac61d;color:#13263d}
.outline{border:1.5px solid #dce2e8;background:#fff;color:#0b3a66}
.pill{display:inline-block;padding:4px 10px;border-radius:999px;font-size:13px;font-weight:700}
.map{position:absolute;inset:0;background:linear-gradient(160deg,#e8efe6,#dfe9f2 60%,#d8e6f0)}
.chip{background:#fff;border:1px solid #dce2e8;border-radius:999px;padding:10px 14px;font-weight:700;font-size:14px;white-space:nowrap}
.fab{width:52px;height:52px;border-radius:14px;background:#fff;border:1.2px solid #dce2e8;box-shadow:0 6px 14px rgba(0,0,0,.18);display:flex;align-items:center;justify-content:center;font-weight:800}
.ticket{display:flex;background:#fff;border:1px solid #dce2e8;border-radius:18px;overflow:hidden;margin-bottom:12px}
.ticket img{width:100px;object-fit:cover}.ticket div{padding:12px}
"""

STRIPE = ('<div class="stripe"><b style="background:#14775a"></b><b style="background:#fac61d"></b>'
          '<b style="background:#c53b36"></b><b style="background:#0b3a66"></b></div>')


def nav(on):
    items = [('⌂', 'Início'), ('▦', 'Mapa'), ('✦', 'Cupons'), ('▤', 'Passaporte')]
    cells = ''.join(f'<div class="{"on" if label == on else ""}"><i>{icon}</i>{label}</div>' for icon, label in items)
    return f'<div class="nav">{cells}</div>{STRIPE}'


STATUS_DARK = '<div class="status"><span>9:41</span><span>●●● ▮</span></div>'

home = f"""<div class="screen" data-name="01 Início"><div class="hero">
<div class="status" style="padding:0;color:#fff"><span>9:41</span><span>●●● ▮</span></div>
<div class="row"><img src="{LW}" width="84"><div class="sp"></div><div class="ic" style="background:rgba(255,255,255,.15)">🔔</div>
<div style="width:8px"></div><div class="ic" style="background:#fac61d;color:#13263d;font-weight:800">R</div></div>
<div class="h1" style="margin-top:16px">Bom dia, Renan!</div><div class="sub">Para onde você quer ir?</div>
<div class="search">🔍 Digite um lugar ou passeio</div></div>
<div class="pad"><div class="grid4"><div class="sc"><i style="background:#e6eefb">🗺</i>Mapa</div>
<div class="sc"><i style="background:#fdf1cf">🎟</i>Cupons</div><div class="sc"><i style="background:#e3f3ea">▣</i>Check-in</div>
<div class="sc"><i style="background:#eee8fb">📅</i>Reservas</div></div>
<div class="pass"><div class="row"><b style="font-size:16px">Meu passaporte</b><div class="sp"></div>›</div>
<div style="font-size:40px;font-weight:800">150 <span style="font-size:18px">pontos</span></div><div class="bar"><b></b></div>
<div style="margin-top:8px;font-size:15px;font-weight:600">Faltam 350 pts para o próximo nível</div></div>
<div class="title">Passeios em destaque</div><div class="hscroll">
<div class="tour"><img src="{ph['lagoa_boat']}"><div>Passeio às Lagoas<small>4 horas · R$ 120</small></div></div>
<div class="tour"><img src="{ph['sunset']}"><div>Pôr do sol nas dunas<small>3 horas · R$ 90</small></div></div></div></div>
{nav('Início')}</div>"""

ROUTE = 'M80 600 C140 520 170 470 210 420 S300 330 300 250'
mapa = f"""<div class="screen" data-name="02 Mapa e rota"><div class="map"></div>
<svg style="position:absolute;inset:0" width="390" height="844"><path d="{ROUTE}" stroke="#fff" stroke-width="11" fill="none" stroke-linecap="round"/>
<path d="{ROUTE}" stroke="#1a73e8" stroke-width="7" fill="none" stroke-linecap="round"/>
<circle cx="80" cy="600" r="9" fill="#1a73e8" stroke="#fff" stroke-width="3"/><circle cx="300" cy="250" r="12" fill="#c53b36" stroke="#fff" stroke-width="3"/></svg>
<div style="position:absolute;top:54px;left:20px;right:20px"><div class="search" style="margin:0">🔍 Buscar no mapa <span class="sp"></span>🎙</div></div>
<div style="position:absolute;top:124px;left:20px;display:flex;gap:8px"><span class="chip">🏛 Cultura</span>
<span class="chip" style="background:#14775a;color:#fff;border-color:#14775a">🌳 Natureza</span><span class="chip">🏖 Praias</span></div>
<div style="position:absolute;right:20px;top:184px;display:flex;flex-direction:column;gap:8px">
<div class="fab" style="background:#0b3a66;color:#fff">3D</div><div class="fab">🧭</div><div class="fab">◎</div><div class="fab">≋</div></div>
<div class="card" style="position:absolute;left:12px;right:12px;bottom:102px"><div class="row">
<img src="{ph['rest']}" style="width:72px;height:72px;border-radius:14px;object-fit:cover">
<div style="margin-left:12px"><b style="font-size:18px">Casa do Mangue</b><div style="color:#556677;font-size:14px">🍴 Comer · Barreirinhas</div>
<div style="font-size:14px">★ 4,7 (342) <b style="color:#14775a">$$</b></div></div><div class="sp"></div>
<div class="ic" style="background:#f3f5f7;width:44px;height:44px">✕</div></div>
<div style="background:#eef4fd;border-radius:14px;padding:12px;margin-top:12px"><b style="font-size:24px;color:#0b57d0">19 min</b>
<span style="font-weight:600"> 14 km · via MA-402</span><div style="color:#556677;font-size:14px;margin-top:4px">◉ Partida: Sua localização ✎</div></div>
<div class="row" style="gap:8px;margin-top:12px"><div class="btn primary sp">➤ Iniciar navegação</div><div class="btn outline" style="width:60px">3D</div></div></div>
{nav('Mapa')}</div>"""

NAVR = 'M195 840 L195 420 L300 300'
navegacao = f"""<div class="screen" data-name="03 Navegação"><div class="map"></div>
<svg style="position:absolute;inset:0" width="390" height="844"><path d="{NAVR}" stroke="#0b57d0" stroke-width="13" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<path d="{NAVR}" stroke="#4c8df6" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="195" cy="560" r="12" fill="#1a73e8" stroke="#fff" stroke-width="4"/></svg>
<div style="position:absolute;top:54px;left:12px;right:12px"><div style="background:#0b3a66;color:#fff;border-radius:22px 22px 0 0;padding:16px;display:flex;gap:12px;align-items:center">
<span style="font-size:46px">↰</span><div><b style="font-size:28px">277 m</b><div style="font-size:18px;font-weight:600">Vire à esquerda na Rua Antônio Rodrigues</div></div></div>
<div style="background:#082c4e;color:#fff;border-radius:0 0 22px 22px;padding:8px 16px;font-size:14px">Depois ↱ Vire à direita na Rua Inácio Lins</div></div>
<div style="position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:22px 22px 0 0;padding:16px 20px 30px;box-shadow:0 -4px 24px rgba(19,38,61,.15)">
<div class="row"><div><b style="font-size:30px;color:#14775a">36 min</b><div style="font-weight:600">11 km · chegada às 08:02</div></div><div class="sp"></div>
<div class="ic" style="background:#f3f5f7">☰</div></div>
<div class="btn outline" style="margin-top:16px;color:#c53b36;border-color:#c53b36">✕ Encerrar navegação</div></div></div>"""

cupons = f"""<div class="screen" data-name="04 Cupons">{STATUS_DARK}<div class="pad" style="padding-top:4px">
<div class="h1">Cupons</div><div style="color:#556677">Descontos em parceiros MaraPass.</div>
<div style="margin-top:14px;border-radius:22px;padding:20px;color:#fff;background:linear-gradient(135deg,#0b3a66,#0f5a6e)">
<div>💳 <b>Benefícios MaraPass</b></div><div style="font-size:34px;font-weight:800;margin-top:10px">R$ 45,00</div>
<div style="opacity:.8;font-size:14px">economia estimada com cupons usados</div>
<div class="row" style="margin-top:14px;gap:10px"><div class="sp"><b style="font-size:20px">2</b><div style="font-size:12px;opacity:.8">cupons ativos</div></div>
<div class="sp"><b style="font-size:20px">1</b><div style="font-size:12px;opacity:.8">usados</div></div>
<div class="sp"><b style="font-size:20px">150</b><div style="font-size:12px;opacity:.8">pontos · 1 carimbo</div></div></div></div>
<div class="row" style="margin:14px 0;background:#fff;border-radius:14px;border:1px solid #dce2e8">
<div class="btn navy sp" style="height:48px">Disponíveis (6)</div><div class="btn sp" style="height:48px">Usados (1)</div></div>
<div class="ticket"><img src="{ph['p4']}"><div><small style="font-weight:800;color:#556677">HOSPEDAGEM</small>
<div style="font-size:20px;font-weight:800;color:#14775a">20% de desconto</div><b>Pousada Vila Lençóis</b>
<div class="row" style="margin-top:6px"><span style="font-size:14px;color:#556677">Até 30/11/2026</span><div class="sp"></div>
<span class="pill" style="background:#dbeafe;color:#2563eb">Disponível</span></div></div></div>
<div class="ticket"><img src="{ph['fish']}"><div><small style="font-weight:800;color:#556677">GASTRONOMIA</small>
<div style="font-size:20px;font-weight:800;color:#14775a">R$ 50 de desconto</div><b>Restaurante o Buriti</b>
<div class="row" style="margin-top:6px"><span style="font-size:13px;color:#556677">Cód. ••••42AB</span><div class="sp"></div>
<span class="pill" style="background:#e3f3ea;color:#14775a">▣ Resgatar</span></div></div></div></div>
{nav('Cupons')}</div>"""

passaporte = f"""<div class="screen" data-name="05 Passaporte">{STATUS_DARK}<div class="pad" style="padding-top:4px">
<div style="border-radius:22px;padding:20px;color:#fff;background:linear-gradient(135deg,#0b3a66,#14775a)">
<div class="row"><b>📘 PASSAPORTE MARAPASS</b><div class="sp"></div>Renan</div>
<div class="row" style="margin-top:14px"><div style="width:96px;height:96px;border-radius:50%;border:8px solid rgba(255,255,255,.2);border-top-color:#fac61d;display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:800">150</div>
<div style="margin-left:16px"><div style="opacity:.8">Seu nível</div><b style="font-size:24px">Viajante</b>
<div style="color:#fac61d;font-weight:700">Faltam 350 pts para Explorador</div></div></div></div>
<div class="btn yellow" style="margin-top:14px">Registrar visita ▣</div><div class="btn outline" style="margin-top:8px">📅 Minhas reservas</div>
<div class="row" style="gap:8px;margin:16px 0"><span class="chip" style="background:#0b3a66;color:#fff">Conquistas</span>
<span class="chip">Carimbos</span><span class="chip">Cidades</span><span class="chip">Extrato</span></div>
<div class="card"><div class="row"><div class="ic" style="background:#dcfce7">✔</div><div style="margin-left:10px" class="sp">
<b>Visita: Passeio às Lagoas</b><div style="font-size:13px;color:#556677">14:32 · Barreirinhas · Lençóis</div></div>
<div style="text-align:right"><b style="color:#16a34a">+50</b><div style="font-size:12px;color:#556677">Saldo 150</div></div></div></div></div>
{nav('Passaporte')}</div>"""

rows = ''.join(
    f'<div class="row" style="padding:14px 16px;border-bottom:1px solid #eef1f4"><span class="ic" style="width:40px;height:40px;background:#f3f5f7">{i}</span>'
    f'<b style="margin-left:12px">{t}</b><div class="sp"></div>›</div>'
    for i, t in [('📅', 'Minhas reservas'), ('🎟', 'Meus cupons'), ('🔒', 'Política de privacidade'), ('🏪', 'Área do parceiro')])
perfil = f"""<div class="screen" data-name="06 Perfil"><div style="background:linear-gradient(135deg,#0b3a66,#0e4f80);color:#fff;padding:54px 20px 24px;border-radius:0 0 28px 28px">
<div class="row"><span>‹ Voltar</span><div class="sp"></div>✎</div><div class="row" style="margin-top:16px">
<div class="ic" style="width:64px;height:64px;background:#fac61d;color:#13263d;font-size:26px;font-weight:800">R</div>
<div style="margin-left:14px"><b style="font-size:22px">Renan</b><div style="opacity:.85;font-size:14px">Viajante · 150 pts</div></div></div></div>
<div class="pad"><div class="row" style="gap:8px"><div class="card sp" style="padding:14px"><b style="font-size:22px;color:#0b3a66">3</b><div style="font-size:13px;color:#556677">lugares visitados</div></div>
<div class="card sp" style="padding:14px"><b style="font-size:22px;color:#0b3a66">5</b><div style="font-size:13px;color:#556677">rotas traçadas</div></div>
<div class="card sp" style="padding:14px"><b style="font-size:22px;color:#0b3a66">1</b><div style="font-size:13px;color:#556677">carimbos</div></div></div>
<div style="margin:18px 0 8px;font-weight:800;color:#556677;font-size:13px">MINHA VIAGEM</div><div class="card" style="padding:0">{rows}</div></div></div>"""

html = ('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>MaraPass — telas para o Figma</title>'
        f'<style>{CSS}</style></head><body>{home}{mapa}{navegacao}{cupons}{passaporte}{perfil}</body></html>')
open('design/marapass-telas.html', 'w', encoding='utf-8').write(html)
print(len(html) // 1024, 'KB')
