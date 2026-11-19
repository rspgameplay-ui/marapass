// Map CMS adapter. No privileged keys. Every command is reauthorized in PostgreSQL.
export function createMapModule(supabase) {
 const uuid=()=>{if(crypto.randomUUID)return crypto.randomUUID();const b=crypto.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;const h=[...b].map(v=>v.toString(16).padStart(2,'0')).join('');return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;};
 const $=id=>document.getElementById(id);
 const statusNames={draft:'Rascunho',review:'Em revisão',published:'Publicado',archived:'Arquivado'};
 const validGoogleId=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{8,255}$/.test(value);
 const categories={destination:'Destino',services:'Serviços úteis',nature:'Natureza',culture:'Cultura',gastronomy:'Gastronomia',lodging:'Hospedagem',tours:'Passeios',events:'Eventos',crafts:'Artesanato',photography:'Fotografia',residential:'Condomínios',tourist_transport:'Transporte turístico'};
 const fields={name:'Nome',municipalityId:'Município',cat:'Categoria',description:'Descrição',address:'Endereço / acesso',lat:'Latitude',lng:'Longitude',hours:'Horários',website:'Site',phone:'Telefone público',whatsapp:'WhatsApp',sourceUrl:'Fonte',photoUrl:'Foto autorizada (URL)',tags:'Palavras-chave',referenceLocation:'Localização de referência',googlePlaceId:'Identificador Google do local (opcional)'};
 const root=$('workspaceMap');
 root.innerHTML=`<div class="map-heading"><div><div class="overline">MARAPASS · GESTÃO TERRITORIAL</div><h2>Mapa e conteúdo</h2><p>Prepare com cuidado. Confira a prévia. Publique para todos os dispositivos.</p></div><div class="action-row"><button id="mapTeam" class="secondary">Permissões</button><button id="mapReload" class="secondary">Atualizar</button><button id="mapNew" class="primary">+ Novo ponto</button></div></div>
 <div class="map-flow" aria-label="Fluxo editorial"><span>01 <b>Cadastro compartilhado</b></span><span>02 <b>Prévia e publicação</b></span><span>03 <b>Histórico preservado</b></span></div>
 <p id="mapMessage" class="status" role="status" aria-live="polite">Conectando ao catálogo…</p>
 <div class="map-workspace"><aside class="card map-sidebar"><h3>Seu catálogo editorial</h3><p class="hint">Os rascunhos ficam na central. Visitantes recebem somente publicações.</p><label for="mapSearch">Buscar nome ou município</label><input id="mapSearch" type="search" placeholder="Ex.: São Luís"><label for="mapStatus">Situação</label><select id="mapStatus"><option value="">Todas</option><option value="draft">Rascunho</option><option value="review">Em revisão</option><option value="published">Publicado</option><option value="archived">Arquivado</option></select><div id="mapList" aria-live="polite"></div><div class="action-row"><button id="mapPrev" class="secondary">Anterior</button><span id="mapPage"></span><button id="mapNext" class="secondary">Próxima</button></div><hr><h3>Referências do Maranhão</h3><p class="hint">Busque na base IBGE/OSM já utilizada pelo mapa. A edição manterá o identificador original.</p><label for="mapReference">Nome ou município</label><input id="mapReference" type="search" placeholder="Pesquisar referências"><div id="mapReferenceList"></div></aside>
 <section class="card map-editor"><div class="module-header"><div><div class="overline" id="mapState">NOVO RASCUNHO</div><h3 id="mapTitle">Escolha um ponto ou crie um cadastro</h3></div><button id="mapHistory" class="secondary" disabled>Histórico</button></div><p class="hint" id="mapVersion">Nenhum dado será publicado ao salvar.</p>
 <form id="mapForm"><div class="map-fields"><div class="span-2"><label for="map_name">Nome *</label><input id="map_name" required minlength="3" maxlength="160"></div><div><label for="map_municipalityId">Município *</label><select id="map_municipalityId" required></select></div><div><label for="map_kind">Tipo de cadastro</label><select id="map_kind"><option value="point">Ponto de interesse</option><option value="attraction">Atrativo</option><option value="company">Empresa / serviço</option></select></div><div><label for="map_cat">Categoria</label><select id="map_cat"></select></div><div><label for="map_referenceLocation">Precisão da localização</label><select id="map_referenceLocation"><option value="true">Referência — entrada não confirmada</option><option value="false">Entrada / ponto de acesso conferido</option></select></div><div><label for="map_lat">Latitude *</label><input id="map_lat" type="number" step="any" min="-10.3" max="-1" required></div><div><label for="map_lng">Longitude *</label><input id="map_lng" type="number" step="any" min="-48.6" max="-41.7" required></div><div class="span-2"><label for="map_description">Descrição</label><textarea id="map_description" maxlength="5000" rows="4"></textarea></div></div>
 <p class="hint">Confira o ponto de acesso e o município. As coordenadas não são verificadas automaticamente em campo.</p><details><summary>Informações práticas e fontes</summary><div id="mapExtra" class="map-fields"></div></details>
 <label for="mapReason">Motivo da alteração *</label><input id="mapReason" required minlength="5" maxlength="500" placeholder="Ex.: conferir acesso e atualizar horários">
 <p class="hint">Empresa mapeada não recebe selo de parceiro nem cupom. A homologação comercial continua no módulo Parceiros.</p><div class="action-row map-sticky"><button id="mapSave" type="submit" class="primary">Salvar rascunho</button><button id="mapPreview" type="button" class="secondary">Conferir prévia</button><button id="mapSubmit" type="button" class="secondary">Enviar para revisão</button><button id="mapArchive" type="button" class="secondary">Arquivar</button></div></form></section></div>
 <dialog id="mapPreviewDialog" class="admin-dialog map-preview-dialog"><div class="module-header"><div><div class="overline">PRÉVIA PRIVADA · NÃO PUBLICADA</div><h2>Confira antes de publicar</h2></div><button id="mapClosePreview" class="secondary">Fechar</button></div><div id="mapPreviewMap" class="map-preview-map"></div><p id="mapPreviewMapStatus" class="hint"></p><div id="mapPreviewCard" class="map-preview-card"></div><h3>Alterações nesta versão</h3><div id="mapDiff" class="table-scroller"></div><label for="mapPublishReason">Motivo da publicação *</label><input id="mapPublishReason" minlength="5" maxlength="500" placeholder="Ex.: informações conferidas para publicação"><p class="hint">A publicação substitui a versão pública deste identificador. O aplicativo conectado busca atualizações em cerca de 30 segundos com conexão; sem conexão, mantém o último catálogo recebido.</p><p id="mapPublishMessage" role="status" aria-live="polite"></p><div class="action-row"><button id="mapPublish" class="primary">Publicar esta versão</button></div></dialog>
 <dialog id="mapHistoryDialog" class="admin-dialog map-history-dialog"><div class="module-header"><h2>Histórico do ponto</h2><button id="mapCloseHistory" class="secondary">Fechar</button></div><p class="hint">Restaurar cria um rascunho. A versão pública muda somente após conferir a prévia e publicar.</p><div id="mapHistoryList"></div><div class="action-row"><button id="mapHistoryPrev" class="secondary">Anterior</button><button id="mapHistoryNext" class="secondary">Próxima</button></div></dialog>
 <dialog id="mapTeamDialog" class="admin-dialog map-history-dialog"><div class="module-header"><h2>Permissões do mapa</h2><button id="mapCloseTeam" class="secondary">Fechar</button></div><p class="hint">Administrador: gestão completa pela equipe administrativa existente. Editor: cria e envia para revisão nos municípios atribuídos. Revisor: publica e arquiva no território atribuído. MFA obrigatório para todos.</p><div id="mapTeamList"></div><form id="mapTeamForm"><label for="mapMemberId">E-mail da conta MaraPass confirmada</label><input id="mapMemberId" required type="email" placeholder="pessoa@empresa.com.br"><label for="mapMemberRole">Perfil</label><select id="mapMemberRole"><option value="editor">Editor territorial</option><option value="reviewer">Revisor</option></select><label for="mapMemberCities">Municípios atribuídos (Ctrl / ⌘ para selecionar vários)</label><select id="mapMemberCities" multiple size="7"></select><p class="hint">Revisor sem seleção: todo o estado. Editor precisa de pelo menos um município. Essa permissão não concede acesso a finanças, cupons ou parceiros.</p><label for="mapMemberActive">Acesso</label><select id="mapMemberActive"><option value="true">Ativo</option><option value="false">Revogado</option></select><label for="mapMemberReason">Motivo *</label><input id="mapMemberReason" required minlength="5" maxlength="500"><div class="action-row"><button class="primary" type="submit">Salvar permissão</button><button id="mapMemberNew" class="secondary" type="button">Nova atribuição</button></div></form><p id="mapTeamMessage" role="status"></p><h3>Últimas alterações de acesso</h3><div id="mapPermissionHistory"></div></dialog>`;
 let access={}, municipalities=[],references=null,current=null,dirty=false,locked=false,offset=0,historyOffset=0,preview=null,map=null,previewListener=null,teamRows=[];
 const retries=new Map();
 const text=(tag,value,cls)=>{const e=document.createElement(tag);e.textContent=String(value??'—');if(cls)e.className=cls;return e;};
 const date=v=>new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short',timeZone:'America/Fortaleza'}).format(new Date(v));
 const notice=(message,error=false)=>{ $('mapMessage').textContent=message;$('mapMessage').className='status '+(error?'error':'success'); };
 async function rpc(action,args={}){
  const {data,error}=await supabase.rpc('map_content_command',{p_action:action,p_args:args});
  if(error)throw new Error(error.message||'Não foi possível confirmar a operação. Atualize e tente novamente.');return data;
 }
 async function mutate(action,args){
  const key=JSON.stringify([action,args]);
  if(!retries.has(key))retries.set(key,{...args,request_id:uuid()});
  const result=await rpc(action,retries.get(key));retries.delete(key);return result;
 }
 const canPublish=()=>['admin','reviewer'].includes(access.role);
 function controls(){
  for(const b of root.querySelectorAll('button,input,select,textarea'))b.disabled=locked;
  $('mapTeam').hidden=access.role!=='admin';
  $('mapHistory').disabled=locked||!current?.revision;
  $('mapPreview').disabled=locked||dirty||!current?.revision;
  $('mapSubmit').disabled=locked||dirty||current?.status!=='draft';
  $('mapArchive').disabled=locked||dirty||!canPublish()||!current?.revision||current.status==='archived';
  $('mapPublish').disabled=locked||!canPublish()||!preview||!['draft','review'].includes(preview.document.status)||(access.role==='reviewer'&&preview.document.status!=='review');
  $('mapVersion').textContent=current?.revision?`Versão de trabalho ${current.revision} · ${statusNames[current.status]} · versão pública ${current.published_revision??'ainda não publicada'}${dirty?' · alterações não salvas':''}`:'Novo ponto. Salve um rascunho para habilitar a prévia.';
 }
 async function run(fn){if(locked)return;locked=true;controls();try{await fn();}catch(e){notice(e.message,true);for(const id of ['mapPublishMessage','mapTeamMessage'])$(id).textContent=e.message;}finally{locked=false;controls();}}
 function confirmDiscard(){return !dirty||window.confirm('Há alterações não salvas. Descartar e continuar?');}
 function fill(doc){
  current=doc;preview=null;dirty=false;
  const c=doc.content||{};
  for(const key of Object.keys(fields)){if($('map_'+key))$('map_'+key).value=String(c[key]??(key==='referenceLocation'?true:''));}
  $('map_kind').value=doc.kind||'attraction';$('map_cat').value=c.cat||'culture';
  if(!c.municipalityId)$('map_municipalityId').value=[...$('map_municipalityId').options].find(o=>o.textContent==='São Luís')?.value||$('map_municipalityId').options[0]?.value||'';
  $('mapReason').value='';$('mapTitle').textContent=c.name||'Novo ponto no Maranhão';$('mapState').textContent=statusNames[doc.status]||'Novo rascunho';controls();
 }
 function collect(){
  const c={id:current?.id||uuid()};
  for(const key of Object.keys(fields))c[key]=key==='lat'||key==='lng'?Number($('map_'+key).value):key==='referenceLocation'?$('map_'+key).value==='true':$('map_'+key).value.trim()||null;
  if(c.googlePlaceId&&!validGoogleId(c.googlePlaceId))throw new Error('Identificador Google inválido. Use somente o ID retornado pela consulta oficial.');
  c.description=c.description||'';c.city=municipalities.find(m=>m.id===c.municipalityId)?.name;
  return c;
 }
 async function list(){
  const rows=await rpc('list',{query:$('mapSearch').value.trim(),status:$('mapStatus').value,offset});
  $('mapList').replaceChildren();
  if(!rows.length)$('mapList').append(text('p','Nenhum cadastro nesta consulta. Crie um ponto ou escolha uma referência abaixo.','muted'));
  for(const row of rows.slice(0,50)){
   const b=text('button','', 'map-record');b.type='button';b.append(text('strong',row.content.name),text('span',`${row.content.city} · ${statusNames[row.status]} · v${row.revision}`));
   b.onclick=()=>{if(confirmDiscard())run(async()=>{const doc=await rpc('get',{id:row.id});if(!doc?.id)throw new Error('Cadastro não encontrado.');fill(doc);});};$('mapList').append(b);
  }
  $('mapPage').textContent=String(offset/50+1);$('mapPrev').hidden=offset===0;$('mapNext').hidden=rows.length<=50;
 }
 async function loadSources(){
  if(municipalities.length)return;
  const r=await fetch('./data/municipalities.json');if(!r.ok)throw new Error('Diretório de municípios indisponível.');municipalities=await r.json();
  for(const id of ['map_municipalityId','mapMemberCities']){
   $(id).replaceChildren();for(const m of municipalities){if(id==='map_municipalityId'&&access.role!=='admin'&&access.municipalities?.length&&!access.municipalities.includes(m.id))continue;
    const o=text('option',m.name);o.value=m.id;$(id).append(o);}
  }
 }
 async function searchReferences(){
  if(!references){const rr=await Promise.all([fetch('./data/places.json'),fetch('./data/condominiums.json')]);if(rr.some(r=>!r.ok))throw new Error('Referências indisponíveis.');const [base,extra]=await Promise.all(rr.map(r=>r.json()));references=[...base,...extra.places];}
  const normalize=v=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const q=normalize($('mapReference').value.trim());$('mapReferenceList').replaceChildren();if(q.length<3)return;
  const rows=references.filter(r=>normalize(r.name+' '+r.city).includes(q)).filter(r=>access.role==='admin'||!access.municipalities?.length||access.municipalities.includes(r.municipalityId)).slice(0,12);
  for(const row of rows){const b=text('button',`${row.name} · ${row.city}`,'map-reference secondary');b.onclick=()=>{if(confirmDiscard())run(async()=>{
   const existing=await rpc('get',{id:row.id});if(existing?.id){fill(existing);return;}
   const safe={};for(const k of [...Object.keys(fields),'id','city','area','dataSource','checkedAt'])if(row[k]!=null)safe[k]=row[k];
   fill({id:row.id,content:safe,kind:row.cat==='residential'?'point':'attraction',status:'draft',revision:0});dirty=true;controls();notice('Referência carregada. Confira os dados e salve o rascunho compartilhado.');
  });};$('mapReferenceList').append(b);}
  if(!rows.length)$('mapReferenceList').append(text('p','Nenhuma referência encontrada nesta busca. Você pode cadastrar um novo ponto.','muted'));
 }
 async function showPreview(){
  preview=await rpc('preview',{id:current.id});const d=preview.document,c=d.content;
  $('mapPreviewCard').replaceChildren(text('span',categories[c.cat]||c.cat,'overline'),text('h2',c.name),text('p',c.city),text('p',c.description));
  for(const key of ['address','hours','phone','whatsapp','website','sourceUrl'])if(c[key])$('mapPreviewCard').append(text('p',`${fields[key]}: ${c[key]}`));
  if(c.photoUrl){const img=document.createElement('img');img.src=c.photoUrl;img.alt=c.name;img.referrerPolicy='no-referrer';img.className='map-photo';img.onerror=()=>img.replaceWith(text('p','Imagem indisponível. Confira a URL e a autorização de uso.','hint'));$('mapPreviewCard').prepend(img);}
  $('mapPreviewCard').append(text('p',`${c.lat}, ${c.lng} · ${c.referenceLocation?'Referência: entrada não confirmada':'Ponto de acesso conferido pela equipe'}`,'hint'));
  $('mapDiff').replaceChildren();const table=document.createElement('table');const head=document.createElement('tr');for(const title of ['Campo','Publicado agora','Nesta prévia'])head.append(text('th',title));table.append(head);
  const old=preview.published?.content||references?.find(r=>r.id===d.id)||{};
  const display=(key,value)=>key==='cat'?(categories[value]||'—'):key==='municipalityId'?(municipalities.find(m=>m.id===value)?.name||'—'):typeof value==='boolean'?(value?'Sim':'Não'):(value??'—');
  for(const [key,label] of Object.entries(fields)){if((old[key]??null)!==(c[key]??null)){const tr=document.createElement('tr');tr.append(text('td',label),text('td',display(key,old[key])),text('td',display(key,c[key])));table.append(tr);}}
  $('mapDiff').append(table);$('mapPublishReason').value='';$('mapPublishMessage').textContent='';$('mapPreviewDialog').showModal();controls();
  $('mapPreviewMapStatus').textContent='Coordenadas do rascunho salvo. Confira o acesso no local antes de marcar a entrada como verificada.';
  if(map){map.remove();map=null;}
  if(previewListener)window.removeEventListener('message',previewListener);
  const info=document.createElement('p');info.className='map-preview-frame';
  info.textContent='A prévia visual no mapa foi desativada na versão única do app. Confira as coordenadas e o acesso real no local antes de publicar.';
  previewListener=null;$('mapPreviewMap').replaceChildren(info);map=null;

 }
 async function history(){
  const rows=await rpc('history',{id:current.id,offset:historyOffset});$('mapHistoryList').replaceChildren();
  for(const v of rows.slice(0,50)){
   const e=document.createElement('article');e.className='map-version';e.append(text('strong',`v${v.revision} · ${statusNames[v.status]} · ${date(v.created_at)}`),text('p',`${v.reason} · responsável ${v.actor_label||v.actor}`),text('p',v.content.name));
   const details=document.createElement('details');details.append(text('summary','Ver conteúdo desta versão'));const pre=text('pre',JSON.stringify(v.content,null,2));details.append(pre);e.append(details);
   const b=text('button','Restaurar como rascunho','secondary');b.onclick=()=>run(async()=>{if(!confirmDiscard())return;const reason=window.prompt('Motivo da restauração (mínimo 5 caracteres)');if(!reason)return;
    const latest=await mutate('restore',{id:current.id,expected_revision:current.revision,restore_revision:v.revision,reason});fill(latest);$('mapHistoryDialog').close();await list();notice(`Versão ${v.revision} restaurada como rascunho v${latest.revision}. Confira a prévia antes de publicar.`);
   });e.append(b);$('mapHistoryList').append(e);
  }
  $('mapHistoryPrev').hidden=historyOffset===0;$('mapHistoryNext').hidden=rows.length<=50;
 }
 async function team(){
  const result=await rpc('members');teamRows=result.members;$('mapTeamList').replaceChildren();
  for(const m of result.members){const b=text('button',`${m.email||m.user_id} · ${m.role==='editor'?'Editor territorial':'Revisor'} · ${m.is_active?'ativo':'revogado'}`,'map-record');b.onclick=()=>{ $('mapMemberId').value=m.email;$('mapMemberId').readOnly=true;$('mapMemberRole').value=m.role;$('mapMemberActive').value=String(m.is_active);for(const o of $('mapMemberCities').options)o.selected=m.municipality_codes.includes(o.value);};$('mapTeamList').append(b);}
  $('mapPermissionHistory').replaceChildren();for(const event of result.history)$('mapPermissionHistory').append(text('p',`${date(event.created_at)} · ${event.reason} · responsável ${event.actor} · conta ${event.member_id}`));
 }
 for(const [key,label] of Object.entries(fields))if(!$("map_"+key)){
  const wrap=document.createElement('div');const l=text('label',label);l.htmlFor='map_'+key;const input=document.createElement('input');input.id='map_'+key;if(key==='googlePlaceId'){input.pattern='[A-Za-z0-9_-]{8,255}';input.title='Identificador opaco do local, sem URL';}
 input.maxLength=key==='googlePlaceId'?255:['website','photoUrl','sourceUrl'].includes(key)?2000:500;if(['website','photoUrl','sourceUrl'].includes(key))input.type='url';wrap.append(l,input);$('mapExtra').append(wrap);
 }
 const googleNote=text('p','Guarde apenas o identificador. Fotos, notas e avaliações do Google são consultadas no componente oficial, sem importação para o catálogo.','hint');$('mapExtra').append(googleNote);
 const googleButton=text('button','Conferir correspondência no Google','secondary');googleButton.type='button';$('mapExtra').append(googleButton);
 const googleDialog=document.createElement('dialog');googleDialog.className='admin-dialog map-preview-dialog';
 const googleClose=text('button','Fechar consulta','secondary');googleClose.type='button';googleClose.onclick=()=>googleDialog.close();
 const googleFrame=document.createElement('iframe');googleFrame.title='Conferir identificador Google';googleFrame.setAttribute('sandbox','allow-scripts allow-popups allow-popups-to-escape-sandbox');googleFrame.style.cssText='width:100%;height:65vh;border:0';
 googleDialog.append(googleClose,googleFrame);root.append(googleDialog);
 let googleTarget=null;
 googleButton.onclick=()=>{
  if($('map_municipalityId').value!=='2101707'){notice('O piloto Google está disponível apenas para Barreirinhas.',true);return;}
  const name=$('map_name').value.trim();if(!name){notice('Informe o nome do local antes de conferir.',true);return;}
  googleTarget=current?.id;
  const url=new URL('/google_places/',location.origin);url.searchParams.set('mode','link');url.searchParams.set('record',googleTarget||'');url.searchParams.set('q',name);
  googleFrame.src=url.href;googleDialog.showModal();
 };
 googleDialog.addEventListener('close',()=>{googleTarget=null;googleFrame.src='about:blank';});
 window.addEventListener('message',event=>{
  const d=event.data;
  if(event.origin!=='null'||event.source!==googleFrame.contentWindow||!googleDialog.open||!googleTarget||current?.id!==googleTarget||d?.type!=='marapass.google-place'||d.recordId!==googleTarget||!validGoogleId(d.placeId))return;
  $('map_googlePlaceId').value=d.placeId;$('map_googlePlaceId').dispatchEvent(new Event('input',{bubbles:true}));googleDialog.close();notice('ID associado ao rascunho. Salve, confira a prévia e publique para atualizar o mapa.');
 });
 for(const [key,label] of Object.entries(categories)){const o=text('option',label);o.value=key;$('map_cat').append(o);}
 $('mapPreviewDialog').addEventListener('close',()=>{if(map){map.remove();map=null;}if(previewListener){window.removeEventListener('message',previewListener);previewListener=null;}});
 $('mapForm').addEventListener('input',()=>{dirty=true;preview=null;controls();});
 $('mapForm').onsubmit=e=>{e.preventDefault();if(!$('mapForm').reportValidity())return;run(async()=>{const content=collect();const doc=await mutate('save',{id:content.id,expected_revision:current?.revision||0,content,kind:$('map_kind').value,reason:$('mapReason').value.trim()});fill(doc);await list();notice('Rascunho salvo no cadastro compartilhado. O mapa público continua na versão anterior.');});};
 $('mapNew').onclick=()=>{if(confirmDiscard())fill({id:uuid(),content:{},revision:0,status:'draft',kind:'attraction'});};
 $('mapReload').onclick=()=>run(async()=>{if(!confirmDiscard())return;if(current?.revision)fill(await rpc('get',{id:current.id}));await list();notice('Catálogo atualizado.');});
 $('mapPreview').onclick=()=>run(showPreview);
 $('mapClosePreview').onclick=()=>{$('mapPreviewDialog').close();if(map){map.remove();map=null;}if(previewListener){window.removeEventListener('message',previewListener);previewListener=null;}};
 $('mapPublish').onclick=()=>run(async()=>{const reason=$('mapPublishReason').value.trim();if(reason.length<5)throw new Error('Informe o motivo da publicação.');
  const doc=await mutate('publish',{id:preview.document.id,expected_revision:preview.document.revision,preview_id:preview.preview_id,reason});fill(doc);$('mapPreviewDialog').close();await list();notice(`Versão ${doc.revision} publicada. O mapa conectado recebe a atualização em cerca de 30 segundos com conexão.`);
 });
 $('mapSubmit').onclick=()=>run(async()=>{const reason=$('mapReason').value.trim();const doc=await mutate('submit',{id:current.id,expected_revision:current.revision,reason});fill(doc);await list();notice('Enviado para revisão. A versão pública permanece disponível.');});
 $('mapArchive').onclick=()=>run(async()=>{if(!window.confirm('Arquivar este ponto e retirá-lo do mapa público? O histórico será preservado.'))return;
  const doc=await mutate('archive',{id:current.id,expected_revision:current.revision,reason:$('mapReason').value.trim()});fill(doc);await list();notice('Ponto arquivado. A retirada será sincronizada com os mapas conectados.');
 });
 let timer;for(const id of ['mapSearch','mapStatus'])$(id).oninput=()=>{clearTimeout(timer);timer=setTimeout(()=>run(async()=>{offset=0;await list();}),350);};
 $('mapReference').oninput=()=>{clearTimeout(timer);timer=setTimeout(()=>run(searchReferences),350);};
 $('mapPrev').onclick=()=>run(async()=>{offset=Math.max(0,offset-50);await list();});$('mapNext').onclick=()=>run(async()=>{offset+=50;await list();});
 $('mapHistory').onclick=()=>run(async()=>{historyOffset=0;await history();$('mapHistoryDialog').showModal();});
 $('mapCloseHistory').onclick=()=>$('mapHistoryDialog').close();$('mapHistoryPrev').onclick=()=>run(async()=>{historyOffset=Math.max(0,historyOffset-50);await history();});$('mapHistoryNext').onclick=()=>run(async()=>{historyOffset+=50;await history();});
 $('mapTeam').onclick=()=>run(async()=>{await team();$('mapTeamDialog').showModal();});$('mapCloseTeam').onclick=()=>$('mapTeamDialog').close();
 $('mapMemberNew').onclick=()=>{$('mapTeamForm').reset();$('mapMemberId').readOnly=false;};
 $('mapTeamForm').onsubmit=e=>{e.preventDefault();run(async()=>{const id=$('mapMemberId').value.trim();const old=teamRows.find(m=>m.email?.toLowerCase()===id.toLowerCase());await mutate('grant',{email:id,role:$('mapMemberRole').value,municipalities:[...$('mapMemberCities').selectedOptions].map(o=>o.value),active:$('mapMemberActive').value==='true',expected_updated_at:old?.updated_at||null,reason:$('mapMemberReason').value.trim()});await team();$('mapTeamMessage').textContent='Permissão salva e auditada. A mudança vale na próxima operação da conta.';});};
 window.addEventListener('beforeunload',event=>{if(dirty){event.preventDefault();event.returnValue='';}});
 controls();
 return {
  async open(){await run(async()=>{access=await rpc('access');if(!access.ready)throw new Error('Confirme o segundo fator e suas permissões.');await loadSources();if(!current)fill({id:uuid(),content:{},revision:0,status:'draft',kind:'attraction'});await list();notice(`Cadastro compartilhado conectado · ${access.role==='admin'?'Administrador':access.role==='editor'?'Editor territorial':'Revisor'}.`);controls();});},
  reset(){access={};current=null;preview=null;dirty=false;references=null;municipalities=[];teamRows=[];retries.clear();for(const id of ['mapList','mapReferenceList','mapHistoryList','mapTeamList','mapPermissionHistory','mapPreviewCard','mapDiff'])$(id).replaceChildren();for(const d of root.querySelectorAll('dialog'))d.close();$('mapForm').reset();$('mapTeamForm').reset();if(map){map.remove();map=null;}if(previewListener){window.removeEventListener('message',previewListener);previewListener=null;}controls();}
 };
}
