const params = new URLSearchParams(location.search);
const record = (params.get('record') || '').slice(0,180);
const query = (params.get('q') || 'Atrativos').slice(0,160);
const placeId = params.get('place') || '';
const linking = params.get('mode') === 'link';
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,255}$/.test(value);
const $ = id => document.getElementById(id);
$('heading').textContent = query;
const external = new URL('https://www.google.com/maps/search/');
external.searchParams.set('api','1');external.searchParams.set('query',`${query}, Barreirinhas, Maranhão`);
if(validId(placeId))external.searchParams.set('query_place_id',placeId);
$('external').href=external;
const config=window.MaraPassGoogleConfig||{enabled:false,apiKey:''};
let selection, loading=false;
try {
 if(config.enabled===true && /^AIza[\w-]{20,100}$/.test(config.apiKey||'')) {
  $('status').textContent='Consulta integrada disponível. Carregue os dados somente quando quiser consultar este lugar.';
  $('load').hidden=false;
 } else $('status').textContent='A consulta Google integrada ainda não foi ativada neste piloto. As informações locais do MaraPass continuam disponíveis. Você pode consultar o Google Maps pelo botão abaixo.';
} catch (_) {$('status').textContent='Não foi possível conferir a disponibilidade da consulta integrada. Tente novamente ou abra o Google Maps.';}
function loadSdk(){return new Promise((resolve,reject)=>{
 if(window.google?.maps?.importLibrary){resolve();return;}
 const script=document.createElement('script');
 const url=new URL('https://maps.googleapis.com/maps/api/js');
 url.searchParams.set('key',config.apiKey);url.searchParams.set('v','weekly');url.searchParams.set('loading','async');url.searchParams.set('callback','marapassGoogleReady');url.searchParams.set('language','pt-BR');url.searchParams.set('region','BR');
 window.marapassGoogleReady=resolve;window.gm_authFailure=()=>reject(Error('auth'));
 script.src=url;script.onerror=()=>reject(Error('network'));document.head.append(script);
 });}
function error(){loading=false;$('status').textContent='A consulta Google não pôde ser concluída. Confira a ativação do serviço, a restrição da chave ou a conexão. Nenhum dado do Google foi importado.';$('load').disabled=false;}
async function details(id){
 const detail=document.createElement('gmp-place-details');
 const request=document.createElement('gmp-place-details-place-request');request.setAttribute('place',id);
 // Official components render content and their attribution. Do not extract or persist it.
 detail.append(request,document.createElement('gmp-place-standard-content'));
 detail.addEventListener('gmp-error',error);$('detail').replaceChildren(detail);
}
$('load').onclick=async()=>{
 if(loading)return;loading=true;$('load').disabled=true;$('status').textContent='Carregando a consulta Google…';
 let timeout;
 try {
  await Promise.race([loadSdk().then(()=>google.maps.importLibrary('places')),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('timeout')),20000);})]);
  if(validId(placeId)) {await details(placeId);$('status').textContent='Ficha Google solicitada. A disponibilidade das informações depende do serviço.';}
  else {
   const search=document.createElement('gmp-place-search');search.setAttribute('selectable','');
   const request=document.createElement('gmp-place-text-search-request');request.textQuery=`${query}, Barreirinhas, Maranhão, Brasil`;request.maxResultCount=3;
   request.locationRestriction={south:-3.10,west:-43.15,north:-2.40,east:-42.50};
   search.append(document.createElement('gmp-place-standard-content'),request);
   search.addEventListener('gmp-error',error);
   search.addEventListener('gmp-load',()=>{$('status').textContent='Resultados do Google. Confira o local e selecione a ficha correspondente.';});
   search.addEventListener('gmp-select',event=>{const id=event.place?.id;if(!validId(id))return;selection=id;details(id);$('associate').hidden=!linking;$('use').disabled=false;});
   $('results').replaceChildren(search);
  }
 } catch (_) {error();} finally {clearTimeout(timeout);loading=false;}
};
$('use').onclick=()=>{
 if(!linking||!validId(selection)||!record||parent===window)return;
 parent.postMessage({type:'marapass.google-place',recordId:record,placeId:selection},location.origin);
 $('saved').textContent='ID enviado ao rascunho. Salve, confira a prévia e publique na central para compartilhar o vínculo.';
};
