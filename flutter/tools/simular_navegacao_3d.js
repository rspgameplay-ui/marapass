// Simulação headless da navegação 3D do MaraPass (rota e GPS falsos).
//
// Uso (com o build web servido, ex.: python3 -m http.server 8080 em build/web):
//   node flutter/tools/simular_navegacao_3d.js http://localhost:8080 rotulo
//   OUT_DIR=/caminho/capturas node ... (padrão: diretório temporário)
//
// Roteiro: rota simulada até Barreirinhas (resposta OSRM falsa), "Iniciar com
// meu GPS", 10 s dirigindo, 25 s sem sinal, alternância 2D/3D sem sinal,
// retorno do sinal e um erro passageiro POSITION_UNAVAILABLE. Ruas, relevo e
// Supabase são bloqueados/vazios; o WebGL é emulado. Mede montagens do iframe
// 3D e lê o diagnóstico (?gpsDiagnostics=1). NÃO substitui o teste em iPhone.
// O GPS é injetado na página: o emulador do Chromium (setGeolocation) emite um
// erro POSITION_UNAVAILABLE antes de cada posição e invalida o teste.
// Coordenadas de toque assumem viewport 390x844.
const { chromium } = require('playwright');
const [,, base, tag] = process.argv;
const OUT = (process.env.OUT_DIR || require('os').tmpdir()) + '/';
const R = 6371000, rad = d => d*Math.PI/180;
const hav = (a,b)=>{const dl=rad(b[1]-a[1]),dg=rad(b[0]-a[0]);const h=Math.sin(dl/2)**2+Math.cos(rad(a[1]))*Math.cos(rad(b[1]))*Math.sin(dg/2)**2;return 2*R*Math.asin(Math.sqrt(h));};
let routeCoords = null;
function osrm(url){
  const m = url.match(/driving\/([-\d.]+),([-\d.]+);([-\d.]+),([-\d.]+)/);
  const o=[+m[1],+m[2]], d=[+m[3],+m[4]], n=60;
  const coords=[...Array(n+1)].map((_,i)=>[o[0]+(d[0]-o[0])*i/n, o[1]+(d[1]-o[1])*i/n]);
  routeCoords = coords;
  const dist = hav(o,d), dur = dist/12;
  const half = Math.floor(n/2);
  const step=(type,mod,from,to,name)=>{const g=coords.slice(from,to+1);let len=0;for(let i=1;i<g.length;i++)len+=hav(g[i-1],g[i]);return {geometry:{type:'LineString',coordinates:g.length>1?g:[g[0],g[0]]},maneuver:{type,modifier:mod,location:g[0],bearing_before:0,bearing_after:90},name,mode:'driving',distance:len,duration:len/12};};
  const steps=[step('depart',undefined,0,half,'MA-402'),step('turn','right',half,n,'Rua Simulada'),step('arrive',undefined,n,n,'')];
  return {code:'Ok',waypoints:[{location:o,distance:3},{location:d,distance:4}],routes:[{geometry:{type:'LineString',coordinates:coords},distance:dist,duration:dur,weight:dur,legs:[{summary:'MA-402',distance:dist,duration:dur,steps}]}]};
}
(async () => {
  const b = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
  const start = {latitude:-2.7400, longitude:-42.8800, accuracy:8};
  const c = await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,geolocation:start,permissions:['geolocation'],locale:'pt-BR',serviceWorkers:'block'});
  await c.route(/^https?:\/\/(?!localhost|127\.0\.0\.1)/, async r => {
    const u=r.request().url();
    if (/\/route\/v1\/driving\//.test(u)) return r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(osrm(u))});
    if (/tiles\.openfreemap\.org\/planet$/.test(u)) return r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify({tilejson:'2.2.0',tiles:['https://tiles.openfreemap.org/mock/{z}/{x}/{y}.pbf'],minzoom:0,maxzoom:14})});
    if (/\/mock\/.*\.pbf$/.test(u)) return r.fulfill({status:200,contentType:'application/x-protobuf',headers:{'access-control-allow-origin':'*'},body:Buffer.alloc(0)});
    return r.fulfill({status:404,headers:{'access-control-allow-origin':'*'},body:''});
  });
  await c.addInitScript(() => {
    const W = new Map(); let id = 0; let cur = {lat:-2.7400, lng:-42.8800, acc:8};
    const pos = () => ({coords:{latitude:cur.lat,longitude:cur.lng,accuracy:cur.acc,altitude:null,altitudeAccuracy:null,heading:105,speed:12,toJSON(){return this}},timestamp:Date.now(),toJSON(){return this}});
    const geo = {
      getCurrentPosition(ok){ setTimeout(()=>ok(pos()),200); },
      watchPosition(ok,err){ const k=++id; W.set(k,{ok,err}); setTimeout(()=>W.has(k)&&ok(pos()),200); return k; },
      clearWatch(k){ W.delete(k); },
    };
    Object.defineProperty(navigator,'geolocation',{get:()=>geo});
    if(window.top!==window){ window.addEventListener('message',e=>{ if(typeof e.data==='string'&&e.data.includes('marapass.3d.frame')) try{window.top.__lastFrame=e.data;}catch{} }); }
    window.__gps = (lat,lng,acc=8)=>{ cur={lat,lng,acc}; for(const w of W.values()) w.ok(pos()); };
    window.__gpsError = (code)=>{ for(const w of W.values()) w.err&&w.err({code,message:'',PERMISSION_DENIED:1,POSITION_UNAVAILABLE:2,TIMEOUT:3}); };
    window.__watchers = ()=>W.size;
  });
  const p = await c.newPage(); 
  const log=[]; p.on('pageerror',e=>log.push('pageerror '+String(e).slice(0,160)));
  let frames3d=0; p.on('frameattached',f=>{ setTimeout(()=>{ if(f.url().includes('navigation-3d')) frames3d++; },300); });
  const t0=Date.now(); const T=()=>((Date.now()-t0)/1000).toFixed(0)+'s';
  await p.goto(base+'/?route=barreirinhas&gpsDiagnostics=1');
  await p.waitForTimeout(9000);
  await p.locator('flt-semantics-placeholder').click({force:true}).catch(()=>{});
  await p.waitForTimeout(1500);
  const calc=p.getByRole('button',{name:/Calcular rota/}); if(await calc.count()){await calc.first().click(); await p.waitForTimeout(4000);} await p.screenshot({path:OUT+tag+'-0-rota.png'});
  await p.mouse.click(195,734);
  console.log(T(),'clicou Iniciar com meu GPS');
  let i=0; const coord=k=>routeCoords[Math.min(k,routeCoords.length-1)];
  const drive=async secs=>{for(let s=0;s<secs;s++){const q=coord(i++);await p.evaluate(([a,b])=>window.__gps(a,b),[q[1],q[0]]);await p.waitForTimeout(1000);}};
  const iframes=()=>p.locator('iframe[src*="navigation-3d"]').count();
  await drive(10);
  console.log(T(),'após 10s dirigindo: iframes 3D no DOM =',await iframes());
  await p.screenshot({path:OUT+tag+'-1-navegando.png'});
  console.log(T(),'sinal cortado (sem novas posições) por 25s');
  await p.waitForTimeout(25000);
  console.log(T(),'durante perda de sinal: iframes 3D no DOM =',await iframes());
  await p.screenshot({path:OUT+tag+'-2-sem-sinal.png'});
  const bearingDuring = await p.evaluate(()=>window.__lastFrame&&JSON.parse(window.__lastFrame).bearing);
  const staleDuring = await p.evaluate(()=>window.__lastFrame&&JSON.parse(window.__lastFrame).stale);
  console.log(T(),'frame 3D sem sinal: bearing =',bearingDuring,' stale =',staleDuring);
  // alternar 2D -> 3D durante a perda de sinal (botão de camadas)
  const el=await p.evaluate(()=>{const e=document.elementFromPoint(348,682);return e?e.tagName:'none'});console.log('elemento sob o botão 2D/3D (esperado DIV):',el);
  const mid=await p.evaluate(()=>{const e=document.elementFromPoint(195,400);return e?e.tagName:'none'});console.log('elemento no meio do mapa 3D:',mid);
  await p.mouse.click(348,682); await p.waitForTimeout(1500);
  console.log(T(),'vista 2D sem sinal: iframes =',await iframes());
  await p.mouse.click(348,682); await p.waitForTimeout(2500);
  console.log(T(),'voltou ao 3D sem sinal: iframes =',await iframes());
  await p.screenshot({path:OUT+tag+'-2b-volta-3d-sem-sinal.png'});
  await drive(10);
  console.log(T(),'sinal voltou 10s: iframes 3D no DOM =',await iframes());
  await p.evaluate(()=>window.__gpsError(2));
  console.log(T(),'erro passageiro POSITION_UNAVAILABLE injetado');
  await drive(8);
  console.log(T(),'após erro passageiro: iframes 3D no DOM =',await iframes());
  await p.screenshot({path:OUT+tag+'-3-sinal-voltou.png'});
  const diag = JSON.parse(await p.evaluate(()=>sessionStorage.getItem('marapass.gps.diagnostics.v1'))||'[]');
  const first=diag[0]?.time||0;
  console.log('etapas:', diag.map(e=>`${e.stage}@${((e.time-first)/1000).toFixed(1)}`).join(' '));
  const cnt=s=>diag.filter(e=>e.stage===s).length;
  console.log(`RESUMO ${tag}: mapLoading=${cnt('mapLoading')} mapReady=${cnt('mapReady')} signalLost=${cnt('signalLost')} cameraReady=${cnt('cameraReady')} mapFailed=${cnt('mapFailed')} contextLost=${cnt('contextLost')} iframesCriados=${frames3d}`);
  if(log.length) console.log(log.slice(0,5).join('\n'));
  await b.close();
})();
