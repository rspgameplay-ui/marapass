import { coordinates, whatsapp, mapUrl, profilePhoto } from './company-profile.js';
import { createMapModule } from './map-content.js';
import { createMvpModule } from './mvp-admin.js';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.95.0';

// Esta é a chave PUBLICÁVEL do projeto, apropriada para o frontend.
// NUNCA inclua service_role/sb_secret no navegador.
const PROJECT_URL = 'https://nwwxobiqynawxxnbvubz.supabase.co';
const PUBLISHABLE_KEY = '__SUPABASE_PUBLISHABLE_KEY__';
const redirectContainsRecovery = window.location.hash.includes('type=recovery') || new URLSearchParams(window.location.search).get('type') === 'recovery';
const supabase = createClient(PROJECT_URL, PUBLISHABLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: true },
});
const mapModule = createMapModule(supabase);
const mvpModule = createMvpModule(supabase, document.getElementById('workspaceApp'));
const $ = (id) => document.getElementById(id);
const toggle = (id, active) => $(id).classList.toggle('hidden', !active);
const status = (message, kind = '') => {
  $('status').textContent = message;
  $('status').className = `status ${kind}`;
};
const sections = ['loginSection', 'requestRecoverySection', 'changePasswordSection', 'mfaSection', 'dashboardSection'];
const section = (name) => { if(name !== 'dashboardSection') mapModule.reset(); sections.forEach((id) => toggle(id, id === name)); };
let busy = false;
let factorId = null;
let currentTab = 'applications';
let displaySequence = 0;
let activeWorkspace = 'today';
let fullTableNote = '';

const tabs = {
  applications: { table:'partner_applications', heads:['Empresa', 'Contato', 'Cidade', 'Situação', 'Data'], keys:['business_name', 'contact_email', 'city', 'status', 'created_at'], select:'id,business_name,contact_email,city,status,created_at' },
  partners: { table:'partners', heads:['Nome fantasia', 'Razão social', 'E-mail de contato', 'WhatsApp', 'Responsável', 'Situação', 'Data'], keys:['trade_name', 'legal_name', 'contact_email', 'contact_phone', 'owner_user_id', 'status', 'created_at'], select:'id,trade_name,legal_name,contact_email,contact_phone,owner_user_id,status,created_at' },
  establishments: { table:'establishments', heads:['Estabelecimento', 'Categoria', 'Cidade', 'Publicação', 'Data'], keys:['name', 'category', 'city', 'is_public', 'created_at'], select:'id,name,category,city,is_public,created_at,latitude,longitude' },
  experiences: { table:'experiences', heads:['Experiência', 'Categoria', 'Situação', 'Reserva obrigatória', 'Data'], keys:['title', 'category', 'status', 'booking_required', 'created_at'], select:'title,category,status,booking_required,created_at' },
  offers: { table:'offers', heads:['Oferta', 'Tipo', 'Desconto', 'Publicada', 'Data'], keys:['title', 'discount_type', 'discount_value', 'is_published', 'created_at'], select:'title,discount_type,discount_value,is_published,created_at' },
  reservations: { table:'reservations', heads:['Data da reserva', 'Participantes', 'Situação', 'Criada em'], keys:['scheduled_at', 'participants', 'status', 'created_at'], select:'scheduled_at,participants,status,created_at' },
  coupons: { table:'coupon_instances', heads:['Oferta', 'Situação', 'Emitido em', 'Validade'], keys:['offer_title_snapshot', 'status', 'issued_at', 'expires_at'], select:'offer_title_snapshot,status,issued_at,expires_at', order:'issued_at' },
};
function textCell(row, value, kind = 'td', className = '') {
  const item = document.createElement(kind);
  if (className) item.className = className;
  item.textContent = String(value);
  row.appendChild(item);
}
function formatValue(key, value) {
  if (key === 'owner_user_id') return value ? 'Vinculado' : 'Pendente de vínculo';
  if (key === 'status' && typeof value === 'string') return ({pending:'Pendente',approved:'Aprovado',rejected:'Rejeitado',suspended:'Suspenso',requested:'Solicitada',confirmed:'Confirmada',cancelled:'Cancelada',completed:'Concluída',issued:'Emitido',redeemed:'Utilizado',no_show:'Ausência'})[value] || value;
  if (value === null || value === undefined) return '—';
  if (['created_at', 'issued_at', 'expires_at', 'scheduled_at'].includes(key)) {
    return new Intl.DateTimeFormat('pt-BR', {dateStyle:'short', timeStyle:'short', timeZone:'America/Sao_Paulo'}).format(new Date(value));
  }
  if (typeof value === 'boolean') return value ? 'Sim' : 'Não';
  return String(value);
}
// V8 / Administração orientada a tarefas, usando somente dados já autorizados pelo Supabase.
function setWorkspace(workspace, tabName) {
  if (!['today','partners','catalog','bookings','coupons','map','app'].includes(workspace)) return;
  activeWorkspace = workspace;
  toggle('workspaceOverview', workspace === 'today');
  toggle('workspaceTable', workspace !== 'today' && workspace !== 'map' && workspace !== 'app');
  toggle('workspaceMap', workspace === 'map');
  toggle('workspaceApp', workspace === 'app');
  if(workspace === 'map') mapModule.open();
  if(workspace === 'app') mvpModule.open();
  document.querySelectorAll('[data-workspace]').forEach(button => {
    const active = button.dataset.workspace === workspace;
    button.classList.toggle('active',active);
    if (active) button.setAttribute('aria-current','page');
    else button.removeAttribute('aria-current');
  });
  if (workspace !== 'today' && workspace !== 'map' && workspace !== 'app') {
    const route = tabName || {partners:'partners',catalog:'establishments',bookings:'reservations',coupons:'coupons'}[workspace];
    if (route) loadTab(route);
  }
}
function priorityRow(title, detail, route, label, urgency=false) {
  const row=document.createElement('div');row.className='priority-row';
  const sign=document.createElement('div');sign.className='priority-sign'+(urgency?' urgent':'');
  sign.textContent=urgency?'!':'✓';
  const content=document.createElement('div');content.className='priority-content';
  const strong=document.createElement('strong');strong.textContent=title;
  const small=document.createElement('p');small.textContent=detail;
  content.append(strong,small);row.append(sign,content);
  if (route) {
    const btn=document.createElement('button');btn.type='button';btn.className='text-action';
    btn.textContent=label||'Abrir';
    btn.addEventListener('click',()=>setWorkspace(route, title.includes('solicitação')?'applications':null));row.append(btn);
  }
  return row;
}
function readinessStep(number,title,detail,completed) {
  const row=document.createElement('div');row.className='readiness-row';
  const point=document.createElement('div');point.className='readiness-point'+(completed?' done':'');point.textContent=completed?'✓':String(number);
  const txt=document.createElement('div');const name=document.createElement('strong');name.textContent=title;
  const caption=document.createElement('span');caption.textContent=detail;
  txt.append(name,caption);row.append(point,txt);return row;
}
async function updateOperationalOverview(data) {
  const pending=Number(data.applications_pending||0);
  const approved=Number(data.partners_approved||0);
  const experiences=Number(data.experiences_published||0);
  const offers=Number(data.offers_published||0);
  const requested=Number(data.reservations_requested||0);
  const list=$('priorityList');list.replaceChildren();
  if(pending>0)list.append(priorityRow(`${pending} solicitação(ões) pendente(s)`, 'Cadastros aguardando conferência e decisão administrativa.','partners','Revisar',true));
  if(requested>0)list.append(priorityRow(`${requested} reserva(s) solicitada(s)`, 'Verifique as reservas e coordene a confirmação com o parceiro.','bookings','Ver reservas',true));
  if(approved===0){list.append(priorityRow('Preparar a primeira empresa', 'Cadastre uma empresa e vincule um responsável verificado.','partners','Ver parceiros',false));}
  else if(experiences===0)list.append(priorityRow('Iniciar o catálogo de experiências','Há parceiro aprovado, mas nenhuma experiência publicada.','catalog','Ver catálogo'));
  else if(offers===0)list.append(priorityRow('Preparar a primeira oferta','Há experiências publicadas, mas nenhuma oferta ativa.','catalog','Ver catálogo'));
  if(!pending&&!requested&&approved>0&&experiences>0&&offers>0){list.append(priorityRow('Não há pendências nesses indicadores','Continue acompanhando as reservas e a qualidade dos anúncios.',null,null,false));}
  const steps=$('readinessSteps');steps.replaceChildren();
  steps.append(readinessStep(1,'Empresa e responsável','Cadastrar empresa e validar quem poderá administrá-la.',approved>0));
  steps.append(readinessStep(2,'Catálogo publicado','Criar experiências reais com dados, imagens e disponibilidade.',experiences>0));
  steps.append(readinessStep(3,'Oferta ativa','Configurar ofertas e condições para o turista.',offers>0));
  steps.append(readinessStep(4,'Primeiras reservas','Acompanhar reservas reais e confirmação operacional.',Number(data.reservations_confirmed||0)>0));
  const schedule=$('upcomingBookings');schedule.replaceChildren();
  try {
    const {data:next,error}=await supabase.from('reservations')
      .select('scheduled_at,participants,status')
      .gte('scheduled_at',new Date().toISOString())
      .order('scheduled_at',{ascending:true}).limit(3);
    if(error)throw error;
    if(!next?.length){const p=document.createElement('p');p.className='empty-message';p.textContent='Nenhuma reserva futura cadastrada. Quando houver reservas, elas aparecerão aqui.';schedule.append(p);}
    else next.forEach(item=>{
      const row=document.createElement('div');row.className='agenda-row';
      const time=document.createElement('div');time.className='agenda-date';time.textContent=formatValue('scheduled_at',item.scheduled_at);
      const detail=document.createElement('div');detail.textContent=`${item.participants} participante(s) · ${item.status}`;
      row.append(time,detail);schedule.append(row);
    });
  } catch {
    const p=document.createElement('p');p.className='empty-message';p.textContent='Não foi possível consultar a agenda agora. As demais informações continuam disponíveis.';schedule.append(p);
  }
}
function filterVisibleRows() {
  const term=$('tableSearch').value.trim().toLocaleLowerCase('pt-BR');
  let shown=0;
  for (const row of $('tableBody').querySelectorAll('tr')) {
    const match=!term || row.textContent.toLocaleLowerCase('pt-BR').includes(term);
    row.hidden=!match;
    if(match)shown++;
  }
  $('tableNote').textContent=fullTableNote+(term?` · ${shown} linha(s) correspondem à pesquisa local`:'');
}
$('tableSearch').addEventListener('input',filterVisibleRows);
$('clearTableSearch').addEventListener('click',()=>{$('tableSearch').value='';filterVisibleRows();$('tableSearch').focus();});
$('quickCreateCompany').addEventListener('click',()=> $('createCompanyButton').click());
document.querySelectorAll('[data-workspace]').forEach(b=>b.addEventListener('click',()=>setWorkspace(b.dataset.workspace)));
document.querySelectorAll('[data-route]').forEach(b=>b.addEventListener('click',()=>setWorkspace(b.dataset.route)));
function setBusy(value) {
  busy = value;
  for (const id of ['loginButton', 'verifyButton', 'refreshButton', 'restartMfa']) $(id).disabled = value;
}
async function accessContext() {
  const {data, error} = await supabase.rpc('my_access_context');
  if (error) throw new Error('Não foi possível consultar as permissões de acesso.');
  const ctx = Array.isArray(data) ? data[0] : data;
  const {data:mapAccess}=await supabase.rpc('map_content_command',{p_action:'access',p_args:{}});
  ctx.map_role=mapAccess?.role;ctx.map_ready=mapAccess?.ready;
  if (!ctx?.admin_role && !ctx.map_role) throw new Error('Esta conta não possui permissão administrativa ou territorial no MaraPass.');
  return ctx;
}
async function loadDashboard() {
  const ctx = await accessContext();
  if (!ctx.admin_console_ready && !ctx.map_ready) throw new Error('É necessário confirmar o segundo fator antes de consultar o painel.');
  document.querySelectorAll('[data-workspace]').forEach(b=>b.hidden=!ctx.admin_role&&b.dataset.workspace!=='map');
  if(!ctx.admin_role){section('dashboardSection');setWorkspace('map');status('Acesso territorial autenticado com MFA.','success');return;}
  // Dupla proteção: função PostgreSQL também verifica role e JWT aal2.
  const {data, error} = await supabase.rpc('marapass_admin_overview');
  if (error) throw new Error('O banco bloqueou a consulta. Confira sua sessão e o MFA.');
  $('appMetric').textContent = data.applications_pending ?? '—';
  $('partnerMetric').textContent = data.partners_approved ?? '—';
  $('expMetric').textContent = data.experiences_published ?? '—';
  $('reservationMetric').textContent = data.reservations_requested ?? '—';
  section('dashboardSection');
  status('Administrador autenticado com MFA. Informações consultadas no Supabase.', 'success');
  await loadTab(currentTab);
  setWorkspace(activeWorkspace);
  // Read-only prioritization; a failed agenda query must never block core admin tasks.
  await updateOperationalOverview(data);
}
async function loadTab(name) {
  const config = tabs[name];
  if (!config) return;
  currentTab = name;
  $('tableSearch').value = '';
  const seq = ++displaySequence;
  document.querySelectorAll('[data-tab]').forEach(button => {
    const active = button.dataset.tab === name;
    button.classList.toggle('selected', active);
    button.setAttribute('aria-pressed', String(active));
  });
  const header = $('tableHeaders'); header.replaceChildren();
  const headingRow = document.createElement('tr');
  config.heads.forEach(h => textCell(headingRow, h, 'th'));
  if (name === 'partners') textCell(headingRow, 'Convite', 'th');
  if (name === 'applications' || name === 'establishments' || name === 'partners') textCell(headingRow, 'Ações', 'th');
  header.appendChild(headingRow);
  const tbody = $('tableBody'); tbody.replaceChildren();
  let loading = document.createElement('tr');textCell(loading, 'Carregando…', 'td','empty');tbody.appendChild(loading);
  const {data,error} = await supabase.from(config.table)
    .select(config.select).order(config.order ?? 'created_at', {ascending:false}).limit(40);
  if (seq !== displaySequence) return;
  tbody.replaceChildren();
  if (error) {
    const tr=document.createElement('tr');textCell(tr, 'Sem permissão para esta consulta ou erro de carregamento.', 'td', 'empty');tbody.appendChild(tr);
    status('O Supabase não autorizou a consulta a este módulo.', 'error');return;
  }
  const invitationByPartner = new Map();
  let invitationLookupOk = true;
  if (name==='partners') {
    // Consultation allowed only to administrators with a real AAL2 session.
    const {data: invitations, error: invitationError} = await supabase.from('partner_invitations')
      .select('partner_id,status,expires_at,sent_at,accepted_at,send_count')
      .order('created_at',{ascending:false}).limit(1000);
    if (seq !== displaySequence) return;
    if (invitationError) {
      invitationLookupOk=false;
      status('Não foi possível consultar os convites. Confira a permissão MFA antes de enviar novos e-mails.','error');
    } else (invitations || []).forEach(inv => invitationByPartner.set(inv.partner_id, inv));
  }
  if (!data?.length) {
    const tr=document.createElement('tr');textCell(tr, 'Ainda não há registros neste módulo.', 'td', 'empty');tbody.appendChild(tr);
  } else {
    data.forEach(item => {
      const row=document.createElement('tr');
      config.keys.forEach(k=>textCell(row,formatValue(k,item[k])));
      const invitation = name==='partners' ? invitationByPartner.get(item.id) : null;
      if (name === 'partners') {
        const cell=document.createElement('td');
        const tag=document.createElement('span');tag.className='invite-tag';
        const expired=invitation?.expires_at && new Date(invitation.expires_at).getTime()<Date.now() && invitation.status==='sent';
        tag.textContent= !invitationLookupOk ? 'Consulta indisponível' : !invitation ? 'Não convidado' : expired ? 'Link expirado' :
          ({prepared:'Preparando', sent:'Convite enviado',failed:'Falha no envio',accepted:'E-mail confirmado',revoked:'Revogado'})[invitation.status] ?? 'Em análise';
        tag.dataset.status = invitation?.status || 'none';
        cell.appendChild(tag);row.appendChild(cell);
      }
      if (name === 'applications' || name === 'establishments' || name === 'partners') {
        const actions=document.createElement('td'); actions.className='row-actions';
        if (name === 'applications' && item.status === 'pending') {
          const approve=actionButton('Aprovar', 'primary', () => prepareAction({action:'review_partner_application',applicationId:item.id,decision:'approved',label:item.business_name}));
          const deny=actionButton('Rejeitar', 'outline', () => prepareAction({action:'review_partner_application',applicationId:item.id,decision:'rejected',label:item.business_name}));
          actions.append(approve,deny);
        } else if (name === 'establishments') {
          if (item.latitude != null && item.longitude != null) {
            const link=document.createElement('a');
            link.href=mapUrl(item.latitude,item.longitude); link.target='_blank'; link.rel='noopener noreferrer';
            link.textContent='Ver no mapa'; actions.append(link);
          }
          const publish=!item.is_public;
          actions.append(actionButton(publish ? 'Publicar' : 'Ocultar', publish ? 'primary':'outline', () => prepareAction({action:'set_establishment_publication',establishmentId:item.id,publish,label:item.name})));
        } else if (name === 'partners') {
          if(!invitationLookupOk){ actions.textContent='Atualize para verificar'; }
          else if (item.status==='pending' && !item.owner_user_id && invitation?.status!=='revoked') {
            const resend=invitation?.status==='sent'||invitation?.status==='failed'||invitation?.status==='prepared';
            const b=actionButton(resend?'Reenviar convite':'Enviar convite','primary',
              ()=>prepareAction({action:'send_partner_invitation',partnerId:item.id,label:item.trade_name}));
            actions.appendChild(b);
          } else if(item.status==='pending' && item.owner_user_id && invitation?.status==='accepted') {
            actions.appendChild(actionButton('Ativar parceiro','primary',
              ()=>prepareAction({action:'activate_invited_partner',partnerId:item.id,label:item.trade_name})));
          } else if(item.status==='approved') {
            actions.textContent='Parceiro ativo';
          } else {
            actions.textContent='Aguardando validação';
          }
          actions.append(actionButton('Ver foto','outline',()=>showPartnerPhoto(item)));
        } else actions.textContent='Decisão registrada';
        row.appendChild(actions);
      }
      tbody.appendChild(row);
    });
  }
  fullTableNote = `${data?.length ?? 0} registro(s) exibido(s) · Máximo de 40 · Ações aprovadas com MFA e auditoria.`;
  filterVisibleRows();
}
// V5: MFA state machine. Never cache TOTP secrets or codes in storage.
const mfaStatus = { phase: 'idle' }; // idle | enrolling | challenging | confirmed
function clearSensitiveMfaUI() {
  factorId = null;
  mfaStatus.phase = 'idle';
  $('code').value = '';
  $('secretValue').textContent = '';
  $('qrCode').removeAttribute('src');
  toggle('qrCode', false);
  toggle('secretWrapper', false);
  toggle('secretValue', false);
  toggle('restartMfa', false);
}
function verifiedTotp(list) {
  const factors = [...(list?.all ?? []), ...(list?.totp ?? [])];
  return factors.find(f => f.factor_type === 'totp' && f.status === 'verified')
    ?? factors.find(f => f.status === 'verified' && f.id && f.factor_type !== 'phone');
}
async function requireMfa() {
  clearSensitiveMfaUI();
  const ctx = await accessContext();
  if (ctx.admin_console_ready || ctx.map_ready) { await loadDashboard(); return; }
  section('mfaSection');
  $('mfaInfo').textContent = 'Preparando o segundo fator. Não use QR Codes de tentativas anteriores.';
  status('Consultando o status do autenticador no Supabase…');
  const {data, error} = await supabase.auth.mfa.listFactors();
  if (error) throw new Error('Não foi possível consultar o autenticador. Encerre a sessão e entre novamente.');
  const verified = verifiedTotp(data);
  if (verified) {
    factorId = verified.id;
    mfaStatus.phase = 'challenging';
    $('mfaInfo').textContent = 'Abra o autenticador que você já vinculou e digite o código atualizado de seis dígitos.';
    $('verifyButton').textContent = 'Confirmar código';
    status('Autenticador já cadastrado. Confirme o código atual para entrar no painel.');
    $('code').focus();
    return;
  }
  // A previous unverified key cannot be trusted: its QR Code appeared in chat.
  // Remove pending factors using the current user's authenticated Auth API,
  // never by direct SQL manipulation of auth.mfa_factors.
  const pending = (data?.all ?? []).filter(f =>
    f.factor_type === 'totp' && f.status === 'unverified' && typeof f.id === 'string'
  );
  for (const stale of pending) {
    status('Removendo configuração incompleta para emitir um QR Code novo…');
    const {error: removalError} = await supabase.auth.mfa.unenroll({factorId:stale.id});
    if (removalError) {
      throw new Error('Não foi possível descartar o fator pendente. Não use o QR Code anterior. Faça logout e tente novamente.');
    }
  }
  mfaStatus.phase = 'enrolling';
  status('Criando um novo autenticador protegido…');
  const friendlyName = `MaraPass Admin ${crypto.randomUUID().slice(0,8)}`;
  const {data:enrollment, error:enrollError} = await supabase.auth.mfa.enroll({
    factorType:'totp',friendlyName,
  });
  if (enrollError || !enrollment?.id || !enrollment?.totp?.qr_code) {
    throw new Error('Não foi possível criar o novo QR Code. Clique em Gerar novo QR Code ou encerre a sessão e entre novamente.');
  }
  factorId = enrollment.id;
  const rawQr = enrollment.totp.qr_code;
  $('qrCode').src = rawQr.startsWith('data:') ? rawQr :
    'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(rawQr);
  toggle('qrCode', true);
  const secret = enrollment.totp?.secret ?? '';
  $('secretValue').textContent = secret;
  toggle('secretWrapper', Boolean(secret));
  toggle('restartMfa', true);
  $('secretToggle').textContent = 'Mostrar chave manual';
  $('verifyButton').textContent = 'Ativar segundo fator';
  $('mfaInfo').textContent = 'Escaneie APENAS este novo QR Code com o aplicativo autenticador. Depois digite o código de seis dígitos abaixo, sem recarregar a página.';
  status('Novo QR Code gerado. Informe o código atualizado do celular para concluir o cadastro.');
  $('code').focus();
}
$('loginForm').addEventListener('submit', async event => {
  event.preventDefault();if (busy)return;setBusy(true);
  try {
    status('Autenticando pelo Supabase Auth…');
    const email=$('email').value.trim();
    const password=$('password').value;
    const {error}=await supabase.auth.signInWithPassword({email,password});
    $('password').value='';
    if(error)throw new Error(error.code === 'invalid_credentials' ? 'E-mail ou senha não conferem. Use Esqueci minha senha para recuperar o acesso.' : 'O Supabase não conseguiu autenticar. Confira a conexão e tente novamente.');
    await requireMfa();
  }catch(error){toggle('restartMfa',true);status(error.message ?? 'Erro na autenticação.','error');}
  finally{setBusy(false);}
});
// O navegador retorna ao MESMO domínio após o e-mail de recuperação.
// O URL precisa constar em Authentication > URL Configuration > Redirect URLs.
$('forgotPassword').addEventListener('click', () => {
  $('recoveryEmail').value = $('email').value.trim();
  section('requestRecoverySection');
  status('Solicite o link de recuperação pelo e-mail cadastrado.');
});
$('backToLogin').addEventListener('click', () => {
  section('loginSection');status('Entre com sua conta MaraPass.');
});
$('requestRecoveryForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy) return;
  busy = true;
  $('sendRecovery').disabled = true;
  try {
    // URL de retorno absoluta e exata: deve estar na allowlist de Auth Redirect URLs.
    const redirectTo = window.location.origin + '/';
    const {error} = await supabase.auth.resetPasswordForEmail($('recoveryEmail').value.trim(), { redirectTo });
    if (error) {
      if (error.status === 429) throw new Error('Muitas tentativas. Tente novamente mais tarde.');
      throw new Error('Não foi possível enviar o link. Confira a configuração de e-mail do Supabase.');
    }
    status('Se o e-mail estiver cadastrado, o Supabase enviará um link de recuperação. Confira sua caixa de entrada.', 'success');
  } catch (error) {
    status(error.message ?? 'Falha ao solicitar recuperação.', 'error');
  } finally {
    busy = false;
    $('sendRecovery').disabled = false;
  }
});

let passwordRecoverySession = false;
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'PASSWORD_RECOVERY' || (redirectContainsRecovery && session?.access_token)) {
    passwordRecoverySession = true;
    section('changePasswordSection');
    status('Link de recuperação reconhecido. Defina sua nova senha nesta página.', 'success');
  }
});
$('changePasswordForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy) return;
  const pass = $('newPassword').value;
  const confirm = $('confirmNewPassword').value;
  if (!passwordRecoverySession) {
    status('Acesse o link válido enviado pelo Supabase para trocar sua senha.', 'error');
    return;
  }
  if (pass.length < 12 || pass !== confirm) {
    status('Use pelo menos 12 caracteres e informe a mesma senha nos dois campos.', 'error');
    return;
  }
  busy = true;
  $('saveNewPassword').disabled = true;
  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) throw new Error('Seu link expirou. Solicite um novo link de recuperação.');
    // Com MFA ativo o Supabase só aceita trocar a senha em sessão AAL2: a sessão do
    // link de recuperação é AAL1, então confirmamos o código do autenticador antes.
    const {data: factorData} = await supabase.auth.mfa.listFactors();
    const totp = factorData?.totp?.find(f => f.status === 'verified');
    if (totp) {
      const mfaCode = $('recoveryMfaCode').value.trim();
      if (!/^[0-9]{6}$/.test(mfaCode)) throw new Error('Digite o código de seis dígitos do aplicativo autenticador.');
      const {error: mfaError} = await supabase.auth.mfa.challengeAndVerify({factorId: totp.id, code: mfaCode});
      if (mfaError) throw new Error('Código do autenticador inválido ou vencido. Gere um novo código e tente de novo.');
    }
    const {error} = await supabase.auth.updateUser({password: pass});
    if (error) throw new Error('Senha não atualizada. Verifique os requisitos de segurança e tente novamente.');
    $('recoveryMfaCode').value = '';
    $('newPassword').value = '';
    $('confirmNewPassword').value = '';
    passwordRecoverySession = false;
    await supabase.auth.signOut({scope:'local'});
    section('loginSection');
    status('Senha alterada! Entre novamente com sua nova senha.', 'success');
    // Elimina o fragmento de recuperação do histórico sem novas solicitações.
    history.replaceState(null, '', window.location.pathname);
  } catch (error) {
    status(error.message ?? 'Não foi possível alterar sua senha.', 'error');
  } finally {
    busy = false;
    $('saveNewPassword').disabled = false;
  }
});

$('verifyButton').addEventListener('click',async()=>{
  if(busy)return;
  const code=$('code').value.trim();
  if(!/^[0-9]{6}$/.test(code)){status('Digite um código de exatamente seis dígitos.','error');return;}
  if(!factorId){status('Nenhum fator ativo nesta tela. Clique em Gerar novo QR Code para recomeçar.','error');return;}
  setBusy(true);
  try{
    const {error}=await supabase.auth.mfa.challengeAndVerify({factorId,code});
    $('code').value='';
    if(error)throw new Error('Código recusado ou expirado. Confira o horário automático do celular, aguarde o próximo código e tente novamente.');
    mfaStatus.phase = 'confirmed';
    $('secretValue').textContent = '';
    $('qrCode').removeAttribute('src');
    await loadDashboard();
  }catch(error){status(error.message ?? 'Falha no segundo fator.','error');}
  finally{setBusy(false);}
});
$('restartMfa').addEventListener('click', async () => {
  if (busy) return;
  setBusy(true);
  try { await requireMfa(); }
  catch(error) { section('mfaSection');toggle('restartMfa',true);status(error.message ?? 'Falha ao reiniciar configuração do MFA.','error'); }
  finally { setBusy(false); }
});
$('secretToggle').addEventListener('click',()=>{
  const visible=$('secretValue').classList.contains('hidden');
  toggle('secretValue',visible);
  $('secretToggle').textContent=visible?'Ocultar chave manual':'Mostrar chave manual';
});
async function exit(){
  await supabase.auth.signOut({scope:'local'});
  displaySequence++;clearSensitiveMfaUI();
  $('password').value='';
  section('loginSection');status('Sessão encerrada.');
}
$('exitMfa').addEventListener('click',exit);
$('exitDashboard').addEventListener('click',exit);
$('refreshButton').addEventListener('click',async()=>{
  if(busy)return;setBusy(true);
  try{await loadDashboard();}catch(error){status(error.message ?? 'Não foi possível atualizar.','error');}
  finally{setBusy(false);}
});
document.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>{
  const target=b.dataset.tab;
  activeWorkspace=target==='applications'||target==='partners'?'partners':
    target==='reservations'?'bookings':target==='coupons'?'coupons':'catalog';
  setWorkspace(activeWorkspace,target);
}));

// V7: Cadastro direto auditado. A mesma tentativa mantém sua chave de idempotência
// durante eventuais reenvios; nunca armazenamos segredos de autenticação no navegador.
let companyRequestId = null;
const companyDialog = $('companyDialog');
function companyFeedback(message, kind='error') {
  const area=$('companyInlineStatus');
  area.textContent=message;
  area.dataset.kind=kind;
}
function cnpjValid(value) {
  const d=String(value||'').replace(/\D/g,'');
  if (!d) return true;
  if (d.length!==14 || /^(\d)\1{13}$/.test(d)) return false;
  const validate=(len, weights)=>{
    const sum=weights.reduce((acc,w,i)=>acc+Number(d[i])*w,0);
    const remainder=sum%11;
    return Number(d[len])===(remainder<2?0:11-remainder);
  };
  return validate(12,[5,4,3,2,9,8,7,6,5,4,3,2])
    && validate(13,[6,5,4,3,2,9,8,7,6,5,4,3,2]);
}
async function readOpsError(error,data) {
  let code = data?.error;
  let statusCode = error?.context?.status ?? null;
  if (error?.context?.json) {
    try { const body=await error.context.json(); code=body?.error??code; }
    catch { /* Sem resposta JSON: provável falha de rede ou gateway. */ }
  }
  const messages={
    company_duplicate:'Já existe uma empresa com este CNPJ. Confira a aba Parceiros antes de cadastrar novamente.',
    invalid_company_details:'Confira nome da empresa, e-mail, cidade, categoria e CNPJ. Alguns dados estão incorretos.',
    company_validation_failed:'O banco não aceitou os dados. Confira os campos e o formato do CNPJ.',
    admin_mfa_required:'Sua sessão não possui MFA ativo. Encerre a sessão e faça login novamente.',
    admin_not_authorized:'Seu perfil não possui autorização para cadastrar esta empresa.',
    invalid_session:'Sua sessão expirou. Entre novamente no painel.',
    unauthenticated:'Entre novamente no painel para continuar.',
    operation_not_applied:'Não foi possível concluir a operação. Confira a lista de Parceiros antes de tentar novamente.',
    invite_email_dispatch_failed:'Falha no envio. Confira SMTP e a URL de retorno autorizada no Supabase Auth.',
    invitation_not_available_or_cooldown:'Convite indisponível. Aguarde pelo menos 60 segundos entre tentativas.',
    server_unavailable:'Serviço temporariamente indisponível. Aguarde e tente novamente; a mesma solicitação não será duplicada.',
  };
  if (messages[code]) return messages[code];
  if (statusCode===401||statusCode===403) return 'Sua sessão expirou ou está sem MFA. Saia e entre novamente.';
  if (statusCode===409) return 'Cadastro em conflito. Verifique se o CNPJ já está registrado na aba Parceiros.';
  if (statusCode===422||statusCode===400) return 'Um dos dados não foi aceito. Confira os campos e tente novamente.';
  return 'Não foi possível confirmar o cadastro. Verifique a aba Parceiros; se necessário, tente novamente nesta tela.';
}
$('createCompanyButton').addEventListener('click', () => {
  if (busy || companyDialog.open) return;
  $('companyForm').reset();
  $('companyPreview').hidden=true;
  $('companyMap').hidden=true;
  companyRequestId=crypto.randomUUID();
  $('companyCity').value='Barreirinhas';
  companyFeedback('');
  companyDialog.showModal();
  $('companyLegal').focus();
});
$('companyCancel').addEventListener('click',()=>{if(!busy)companyDialog.close();});
companyDialog.addEventListener('cancel',event=>{if(busy)event.preventDefault();});
companyDialog.addEventListener('close',()=>{if(!busy){companyRequestId=null;companyFeedback('');}});
$('companyCoordinates').addEventListener('input',()=>{
  const point=coordinates($('companyCoordinates').value);
  $('companyMap').hidden=!point;
  if(point) $('companyMap').href=mapUrl(...point);
});
$('companyPhoto').addEventListener('change', async ()=>{
  const file=$('companyPhoto').files[0];
  $('companyPreview').hidden=true;
  if(!file) return;
  try {
    const src=await profilePhoto(file);
    if($('companyPhoto').files[0]!==file) return;
    $('companyPreview').src=src; $('companyPreview').hidden=false;
  } catch { companyFeedback('Não foi possível abrir a foto. Selecione um JPG, PNG ou WebP de até 8 MB.'); }
});
$('companyForm').addEventListener('submit',async event=>{
  event.preventDefault();
  if (busy) return;
  const form=$('companyForm');
  if (!form.reportValidity()) return;
  const file=$('companyPhoto').files[0];
  const point=coordinates($('companyCoordinates').value);
  const phone=whatsapp($('companyPhone').value);
  if (!point) {companyFeedback('Confira a latitude e a longitude copiadas do Google Maps.');return;}
  if (!phone) {companyFeedback('Informe o WhatsApp com DDD. Para outro país, inclua + e o código do país.');return;}
  const payload={
    requestId: companyRequestId || (companyRequestId=crypto.randomUUID()),
    legalName:$('companyLegal').value.trim(),
    tradeName:$('companyTrade').value.trim(),
    contactEmail:$('companyEmail').value.trim().toLowerCase(),
    contactPhone:phone,
    taxId:$('companyTax').value.replace(/\D/g,'')||null,
    city:$('companyCity').value.trim(),
    category:$('companyCategory').value,
  };
  if (payload.legalName.length<2 || payload.tradeName.length<2 || payload.city.length<2) {
    companyFeedback('Informe razão social, nome fantasia e cidade com pelo menos dois caracteres.');return;
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.contactEmail)) {
    companyFeedback('O e-mail informado parece incorreto. Confira o endereço.');return;
  }
  if (payload.taxId && !cnpjValid(payload.taxId)) {
    companyFeedback('CNPJ inválido. Confira os 14 dígitos e os números verificadores, ou deixe o campo em branco.');return;
  }
  if (!$('companyAcknowledge').checked) {
    companyFeedback('Confirme que entendeu as condições do cadastro.');return;
  }
  setBusy(true);
  $('companySave').disabled=true;
  $('companyCancel').disabled=true;
  $('companySave').textContent='Salvando…';
  companyFeedback('Verificando sua autorização e gravando os dados com segurança…','info');
  let saved=false;
  try {
    const ctx=await accessContext();
    if (!ctx?.admin_console_ready) throw new Error('Sua sessão está sem MFA. Saia e entre novamente antes de salvar.');
    const photo=await profilePhoto(file);
    const {data:registration,error}=await supabase.rpc('admin_register_company_profile',{
      p_request_key:payload.requestId,p_legal_name:payload.legalName,p_trade_name:payload.tradeName,
      p_contact_email:payload.contactEmail,p_city:payload.city,p_category:payload.category,
      p_whatsapp:phone,p_tax_id:payload.taxId,p_latitude:point[0],p_longitude:point[1],p_photo:photo.split(',')[1]
    }).abortSignal(AbortSignal.timeout(20000));
    if (error || !registration?.partner_id) throw new Error(error?.message || 'Falha ao confirmar cadastro.');
    saved=true;
    companyDialog.close();
    companyRequestId=null;
    form.reset();
    currentTab='partners';
    activeWorkspace='partners';
    status('Empresa salva com sucesso! O estabelecimento foi criado como rascunho privado. O responsável ainda precisa ser vinculado.','success');
    // A atualização da lista não faz parte da transação: se falhar, o cadastro
    // permanece salvo e não pode ser apresentado como erro de gravação.
    try { await loadDashboard();
      status(registration.already_registered
        ? 'Esse cadastro já havia sido concluído. Reutilizamos o registro original sem duplicá-lo.'
        : 'Empresa cadastrada com sucesso! Estabelecimento privado criado e operação auditada.', 'success');
    } catch {
      status('Empresa salva com sucesso. A lista não atualizou; clique em Atualizar para vê-la.','success');
    }
  } catch (err) {
    if (!saved) companyFeedback(
      err?.name==='AbortError'||err?.name==='TimeoutError'
        ? 'A conexão demorou demais. Confira a aba Parceiros e tente novamente nesta tela: a mesma solicitação não será duplicada.'
        : err.message||'Não foi possível confirmar. Confira a lista antes de tentar novamente.'
    );
  } finally {
    setBusy(false);
    $('companySave').disabled=false;
    $('companyCancel').disabled=false;
    $('companySave').textContent='Salvar empresa';
  }
});

// A alteração nunca é enviada diretamente a uma tabela: o backend revalida MFA
// e associa a decisão ao auth.uid verificado pelo Supabase Auth.
let queuedAction = null;
let photoRequest=0;
async function showPartnerPhoto(item) {
  const request=++photoRequest, dialog=$('partnerPhotoDialog'), image=$('partnerPhotoImage');
  image.hidden=true; image.removeAttribute('src');
  $('partnerPhotoTitle').textContent=item.trade_name;
  $('partnerPhotoStatus').textContent='Carregando foto…';
  dialog.showModal();
  try {
    const {data,error}=await supabase.rpc('admin_company_photo',{p_partner_id:item.id});
    if(request!==photoRequest || !dialog.open) return;
    if(error) throw error;
    $('partnerPhotoStatus').textContent=data?'':'Foto ainda não cadastrada.';
    if(data){image.src='data:image/jpeg;base64,'+data.replace(/\s/g,''); image.hidden=false;}
  } catch {
    if(request===photoRequest) $('partnerPhotoStatus').textContent='Não foi possível carregar a foto.';
  }
}
function actionButton(label, klass, onClick) {
  const button=document.createElement('button');
  button.type='button'; button.className=klass; button.textContent=label;
  button.addEventListener('click',onClick);
  return button;
}
function prepareAction(details) {
  if (busy) return;
  queuedAction=details;
  const approved=details.action==='review_partner_application' && details.decision==='approved';
  const declined=details.action==='review_partner_application' && details.decision==='rejected';
  const sendInvite=details.action==='send_partner_invitation';
  const activate=details.action==='activate_invited_partner';
  const verb=sendInvite?'Enviar convite por e-mail':activate?'Ativar parceiro':approved?'Aprovar parceiro':declined?'Rejeitar solicitação':details.publish?'Publicar estabelecimento':'Ocultar estabelecimento';
  $('actionDialogTitle').textContent=verb;
  $('actionMessage').textContent=sendInvite
    ? `Confirme o envio de um convite de acesso para o e-mail registrado de ${details.label}. O convite NÃO aprova a empresa; a pessoa deverá confirmar o e-mail e aceitar a vinculação. O envio depende da configuração de e-mails no Supabase Auth.`
    : activate
    ? `Ativar comercialmente ${details.label}? A conta do responsável já deve ter aceitado o convite e confirmado o e-mail. O estabelecimento continuará privado até ser publicado em separado.`
    : `Você está prestes a ${verb.toLowerCase()}: ${details.label}. A decisão será registrada no histórico de auditoria do MaraPass.`;
  toggle('approvalNames',approved);
  $('legalName').value='';$('tradeName').value='';
  $('confirmAction').textContent=verb;
  $('actionDialog').showModal();
}
$('cancelAction').addEventListener('click',()=>{$('actionDialog').close();queuedAction=null;});
$('actionDialog').addEventListener('close',()=>{queuedAction=null;});
$('actionForm').addEventListener('submit',async event=>{
  event.preventDefault();
  if (busy || !queuedAction) return;
  const details={...queuedAction};
  if (details.action==='review_partner_application' && details.decision==='approved') {
    details.legalName=$('legalName').value.trim() || null;
    details.tradeName=$('tradeName').value.trim() || null;
  }
  delete details.label;
  setBusy(true);$('confirmAction').disabled=true;
  try {
    const check=await accessContext();
    if (!check.admin_console_ready) throw new Error('Sessão administrativa sem MFA. Entre novamente e confirme seu código.');
    const {data,error}=await supabase.functions.invoke('marapass-admin-ops',{body:details});
    if (error || !data?.success) {
      const explanation=await readOpsError(error,data);
      throw new Error(data?.error==='invite_email_dispatch_failed'
        ? 'O Supabase recusou enviar o convite. Confira as configurações de SMTP, limites de e-mail e URL de retorno; a empresa continua pendente.'
        : data?.error==='invitation_not_available_or_cooldown'
        ? 'Convite não disponível agora. Aguarde um minuto entre os envios ou confira se a empresa já tem responsável.'
        : data?.error==='invite_record_confirmation_failed'
        ? 'O provedor aceitou a tentativa de envio, mas não foi possível confirmar o registro. Atualize a lista antes de reenviar.'
        : explanation);
    }
    $('actionDialog').close();queuedAction=null;
    await loadDashboard();
    status(details.action==='send_partner_invitation'
      ? 'Solicitação de envio aceita pelo Supabase Auth. A entrega depende do serviço de e-mail; acompanhe a confirmação na aba Parceiros.'
      : details.action==='activate_invited_partner'
      ? 'Parceiro ativado após confirmar o e-mail e aceitar o vínculo. O estabelecimento permanece privado até publicação.'
      : 'Operação concluída e registrada na auditoria.','success');
  }catch(error){status(error.message||'Não foi possível aplicar a operação.','error');}
  finally{setBusy(false);$('confirmAction').disabled=false;}
});

$('mapGlobalExit').onclick=async()=>{mapModule.reset();await supabase.auth.signOut({scope:'local'});section('loginSection');status('Sessão encerrada.');};
