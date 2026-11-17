// Aba "App MaraPass": cadastros de parceiro, ofertas, placas com QR e check-ins
// do app novo. Tudo passa por mvp_admin_command, que exige administrador + MFA.
import QRCode from 'https://esm.sh/qrcode@1.5.4';

const el = (tag, attrs = {}, ...kids) => {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') n.className = v;
    else if (k.startsWith('on')) n.addEventListener(k.slice(2), v);
    else n.setAttribute(k, v);
  }
  for (const k of kids) n.append(k instanceof Node ? k : document.createTextNode(k ?? ''));
  return n;
};
const fmt = (d) => d ? new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—';

export function createMvpModule(supabase, root) {
  let tab = 'requests';
  const call = async (action, args = {}) => {
    const { data, error } = await supabase.rpc('mvp_admin_command', { p_action: action, p_args: args });
    if (error) throw new Error(error.message || 'O banco recusou a operação.');
    return data;
  };
  const msg = el('div', { class: 'status', role: 'status', 'aria-live': 'polite' });
  const metrics = el('div', { class: 'mvp-metrics' });
  const body = el('div', { class: 'mvp-body' });
  const tabs = el('div', { class: 'tabs', role: 'group', 'aria-label': 'App MaraPass' });
  const names = { requests: 'Cadastros de parceiro', offers: 'Ofertas', places: 'Placas e QR', checkins: 'Check-ins' };
  for (const [k, v] of Object.entries(names)) {
    tabs.append(el('button', { type: 'button', class: 'tab', 'data-mvp': k, onclick: () => { tab = k; render(); } }, v));
  }
  root.replaceChildren(
    el('div', { class: 'heading' },
      el('div', { class: 'overline' }, 'APP MARAPASS'),
      el('h2', {}, 'Parceiros, ofertas, placas e visitas do app'),
      el('p', { class: 'muted' }, 'Aprove cadastros e ofertas, imprima placas com QR seguro e acompanhe os check-ins validados no servidor.')),
    metrics, tabs, msg, body);

  const say = (t, kind = '') => { msg.textContent = t; msg.className = `status ${kind}`; };

  async function loadMetrics() {
    const m = await call('overview');
    const items = [
      ['Cadastros pendentes', m.pedidos_parceiro], ['Parceiros', m.parceiros], ['Ofertas em análise', m.ofertas_analise],
      ['Ofertas ativas', m.ofertas_ativas], ['Check-ins hoje', m.checkins_hoje], ['Check-ins no total', m.checkins_total],
      ['Cupons ativados', m.cupons_ativados], ['Cupons usados', m.cupons_usados], ['Usuários', m.usuarios],
    ];
    metrics.replaceChildren(...items.map(([l, v]) => el('div', { class: 'metric' }, el('span', {}, l), el('strong', {}, String(v ?? '—')))));
  }

  function table(heads, rows) {
    const t = el('table', { class: 'mvp-table' });
    t.append(el('thead', {}, el('tr', {}, ...heads.map((h) => el('th', {}, h)))));
    const tb = el('tbody');
    if (!rows.length) tb.append(el('tr', {}, el('td', { colspan: String(heads.length), class: 'empty' }, 'Nada por aqui ainda.')));
    rows.forEach((r) => tb.append(r));
    t.append(tb);
    return el('div', { class: 'table-scroller' }, t);
  }

  async function renderRequests() {
    const list = await call('partner_requests');
    return table(['Negócio', 'Contato', 'Cidade', 'Cadastur', 'Enviado', 'Situação', 'Ações'], list.map((r) => {
      const act = el('td');
      if (r.status !== 'aprovado') act.append(el('button', { type: 'button', class: 'primary small', onclick: () => decide(r, true) }, 'Aprovar'));
      if (r.status !== 'recusado') act.append(el('button', { type: 'button', class: 'secondary small', onclick: () => decide(r, false) }, r.status === 'aprovado' ? 'Remover acesso' : 'Recusar'));
      return el('tr', {}, el('td', {}, r.business), el('td', {}, `${r.email ?? ''} · ${r.phone}`), el('td', {}, r.city),
        el('td', {}, r.cadastur ?? '—'), el('td', {}, fmt(r.created_at)), el('td', {}, el('span', { class: `pill ${r.status}` }, r.status)), act);
    }));
  }
  async function decide(r, approve) {
    const note = approve ? '' : (prompt('Motivo (o parceiro vê esta mensagem):', '') ?? '');
    try { await call('decide_partner', { user_id: r.user_id, approve, note }); say(approve ? `${r.business} aprovado.` : `${r.business} atualizado.`, 'success'); render(); }
    catch (e) { say(e.message, 'error'); }
  }

  async function renderOffers() {
    const list = await call('offers');
    return table(['Oferta', 'Benefício', 'Parceiro', 'Validade', 'Emitidos / usados', 'Situação', 'Ações'], list.map((o) => {
      const act = el('td');
      if (o.status !== 'Ativa') act.append(el('button', { type: 'button', class: 'primary small', onclick: () => setOffer(o, 'Ativa') }, 'Ativar'));
      if (o.status === 'Ativa') act.append(el('button', { type: 'button', class: 'secondary small', onclick: () => setOffer(o, 'Pausada') }, 'Pausar'));
      if (o.status === 'Em análise') act.append(el('button', { type: 'button', class: 'secondary small', onclick: () => setOffer(o, 'Recusada') }, 'Recusar'));
      if (o.status === 'Ativa') act.append(el('button', { type: 'button', class: 'secondary small', onclick: () => showQr(`marapass:offer:po:${o.id}`, o.title, `oferta-${o.id}`) }, 'QR do balcão'));
      return el('tr', {}, el('td', {}, o.title), el('td', {}, o.benefit), el('td', {}, o.email ?? '—'), el('td', {}, o.valid_until ?? '—'),
        el('td', {}, `${o.issued} / ${o.used}`), el('td', {}, el('span', { class: 'pill' }, o.status)), act);
    }));
  }
  async function setOffer(o, status) {
    const reason = status === 'Ativa' ? '' : (prompt('Motivo (opcional):', '') ?? '');
    try { await call('set_offer', { id: o.id, status, reason }); say(`Oferta "${o.title}": ${status}.`, 'success'); render(); }
    catch (e) { say(e.message, 'error'); }
  }

  async function renderPlaces() {
    const list = await call('places');
    const box = el('div');
    box.append(el('p', { class: 'muted' }, 'O QR destas placas leva o token secreto: o check-in vale sem GPS. Imprima em A6, plastifique e fixe no local. Não compartilhe a imagem por mensagem.'));
    box.append(table(['Código', 'Local', 'Raio do GPS', 'Check-ins', 'Ações'], list.map((p) => {
      const radius = el('input', { type: 'number', min: '50', max: '20000', step: '50', value: String(p.radius_m), 'aria-label': `Raio de ${p.code} em metros`, class: 'radius' });
      return el('tr', {}, el('td', {}, p.code), el('td', {}, p.item_key),
        el('td', {}, radius, el('button', { type: 'button', class: 'secondary small', onclick: async () => {
          try { await call('set_radius', { item_key: p.item_key, radius_m: Number(radius.value) }); say(`Raio de ${p.code}: ${radius.value} m.`, 'success'); }
          catch (e) { say(e.message, 'error'); }
        } }, 'Salvar')),
        el('td', {}, String(p.checkins)),
        el('td', {}, el('button', { type: 'button', class: 'primary small', onclick: () => showQr(`marapass:plate:${p.code}:${p.token}`, `${p.code} · ${p.item_key}`, `placa-${p.code}`) }, 'Placa com QR')));
    })));
    return box;
  }

  async function renderCheckins() {
    const list = await call('checkins');
    const label = { placa: 'QR da placa', gps: 'GPS', codigo: 'Código + GPS', legado: 'Anterior' };
    return table(['Quando', 'Local', 'Cidade', 'Como', 'Distância', 'Nota'], list.map((c) =>
      el('tr', {}, el('td', {}, fmt(c.created_at)), el('td', {}, c.item_key), el('td', {}, c.cidade),
        el('td', {}, label[c.method] ?? c.method), el('td', {}, c.distance_m == null ? '—' : `${c.distance_m} m`), el('td', {}, c.rating ? '★'.repeat(c.rating) : '—'))));
  }

  async function showQr(data, title, file) {
    const url = await QRCode.toDataURL(data, { errorCorrectionLevel: 'M', margin: 2, width: 720, color: { dark: '#13263d', light: '#ffffff' } });
    const dlg = el('dialog', { class: 'qr-dialog' },
      el('h3', {}, title),
      el('img', { src: url, alt: `QR ${title}`, width: '320', height: '320' }),
      el('div', { class: 'action-row' },
        el('a', { class: 'primary', href: url, download: `${file}.png` }, 'Baixar PNG'),
        el('button', { type: 'button', class: 'secondary', onclick: () => { dlg.close(); dlg.remove(); } }, 'Fechar')));
    document.body.append(dlg);
    dlg.showModal();
  }

  async function render() {
    root.querySelectorAll('[data-mvp]').forEach((b) => b.classList.toggle('selected', b.dataset.mvp === tab));
    body.replaceChildren(el('p', { class: 'muted' }, 'Carregando…'));
    try {
      const view = await { requests: renderRequests, offers: renderOffers, places: renderPlaces, checkins: renderCheckins }[tab]();
      body.replaceChildren(view);
      await loadMetrics();
    } catch (e) {
      body.replaceChildren();
      say(e.message, 'error');
    }
  }

  return { open: render };
}
