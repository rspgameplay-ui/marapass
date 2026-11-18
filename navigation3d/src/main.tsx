import {useEffect, useRef, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {createPortal} from 'react-dom';
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import {setWorkerUrl, Map as LibreMap, Marker, AttributionControl, LngLatBounds,
  type GeoJSONSource, type StyleSpecification} from 'maplibre-gl';
import {Coffee, BedDouble, Fuel, MapPin, Navigation, Tag} from 'lucide-react';
import style from './marapass-style.json';
import 'maplibre-gl/dist/maplibre-gl.css';
import './screen.css';
import {addGravuras} from './engravings';

type Point = [number, number];
type Place = {id:string; name:string; category:string; point:Point; coupon:boolean; ahead:string};
type Frame = {type:'marapass.3d.frame'; vehicle:Point|null; bearing:number|null; follow:boolean; stale?:boolean;
  route?:Point[]; places:Place[]; satellite:boolean;
  focus?:{point:Point; revision:number}; nautical:boolean};
setWorkerUrl(workerUrl); // o Vite não copia o worker sozinho: sem isto o 3D nunca abre
const baseStyle = style as StyleSpecification;
const poiIcons = {gastronomy:Coffee, lodging:BedDouble, services:Fuel};
function send(type:string, id?:string) {
  window.parent.postMessage(JSON.stringify({type, id}), location.origin);
}
function diagnostic(stage:'frame'|'camera'|'render'|'contextLost'|'error') {
  window.parent.postMessage(JSON.stringify({type:'marapass.3d.diagnostic',stage}),location.origin);
}

const CAR_SVG = `<div class="veh-lean"><svg viewBox="0 0 40 76" width="34" height="65" aria-hidden="true">
<defs><linearGradient id="cg" x1="0" x2="1"><stop offset="0" stop-color="#0a6f82"/><stop offset=".5" stop-color="#19c4d8"/><stop offset="1" stop-color="#0a6f82"/></linearGradient>
<linearGradient id="cr" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#bfeff5"/></linearGradient></defs>
<path d="M20 3C31 3 35 11 35 22V54C35 65 31 73 20 73S5 65 5 54V22C5 11 9 3 20 3Z" fill="url(#cg)" stroke="#fff" stroke-width="2"/>
<path d="M10 27C10 22 14 19 20 19S30 22 30 27L28 34H12Z" fill="#12344c"/>
<path d="M12 53H28L30 58C30 61 26 63 20 63S10 61 10 58Z" fill="#12344c"/>
<rect x="11.500" y="35" width="17" height="17" rx="5" fill="url(#cr)"/>
<ellipse cx="4.500" cy="31" rx="2.500" ry="3.500" fill="#0a6f82"/><ellipse cx="35.500" cy="31" rx="2.500" ry="3.500" fill="#0a6f82"/>
<rect x="9" y="5" width="7" height="3" rx="1.500" fill="#fff6b8"/><rect x="24" y="5" width="7" height="3" rx="1.500" fill="#fff6b8"/>
<rect x="9" y="68" width="7" height="2.500" rx="1.200" fill="#ff5a4d"/><rect x="24" y="68" width="7" height="2.500" rx="1.200" fill="#ff5a4d"/></svg></div>`;
function vehicleElement(nautical: boolean) {
  const pin = document.createElement('div');
  pin.setAttribute('role', 'img');
  pin.setAttribute('aria-label', nautical ? 'Posição na travessia' : 'Seu veículo');
  pin.className = nautical ? 'boat-marker' : 'vehicle-marker';
  if (nautical) {
    pin.textContent = '⛵';
    return pin;
  }
  pin.innerHTML = CAR_SVG;
  return pin;
}

function Canvas() {
  const element=useRef<HTMLDivElement>(null);
  const received=useRef<Frame|null>(null);
  const [places,setPlaces]=useState<Place[]>([]);
  const [status,setStatus]=useState('Carregando mapa 3D…');
  const nodes=useRef(new globalThis.Map<string,HTMLDivElement>());
  const mapRef=useRef<LibreMap|null>(null);
  const markers=useRef(new globalThis.Map<string,Marker>());
  const placeKey=useRef('');
  useEffect(()=>{
    let map:LibreMap;
    let ready=false;
    let failed=false;
    let queued=false;
    let animation=0;
    let satellite: boolean|undefined;
    let focusRevision=-1;
    let following=false;
    let lastCamera='';
    let lastRoute:Point[]|undefined;
    let traveler:Marker|undefined;
    let nautical:boolean|undefined;
    let painted=false;
    let paintTimeout:number|undefined;
    let firstFrame=true, firstCamera=true, placed=false;
    const low=((navigator as any).deviceMemory||4)<=2||(navigator.hardwareConcurrency||4)<=4;
    // Câmera suavizada: a posição, o rumo, o zoom e a inclinação "perseguem" o alvo a cada quadro,
    // em vez de saltar a cada fix de GPS. Para sozinha quando chega, para economizar bateria.
    type Cam={p:Point;b:number;z:number;pt:number};
    let cur:Cam|undefined, tgt:Cam|undefined, loop=0, lastT=0, lastDraw=0, speed=0;
    let lastFix:{p:Point;t:number}|undefined;
    const meters=(a:Point,b:Point)=>{const k=111320,x=(b[0]-a[0])*k*Math.cos(a[1]*Math.PI/180),y=(b[1]-a[1])*k;return Math.hypot(x,y);};
    // Mais rápido = mapa mais aberto e menos inclinado (como o Waze).
    const zoomFor=(v:number)=>v<4?17.4:v<14?17.4-(v-4)*.09:v<28?16.5-(v-14)*.07:15.5;
    const reveal=()=>{
      if(placed)return;placed=true;
      const show=()=>{element.current&&(element.current.style.opacity='1');};
      map.once('idle',show);window.setTimeout(show,2500);
    };
    const place=(frame:Frame)=>{
      // Primeiro enquadramento: nunca mostra o ponto inicial fixo do estilo.
      const route=frame.route??lastRoute;
      if(frame.follow&&frame.vehicle){return;}
      if(route&&route.length>1){
        const b=route.reduce((a,c)=>a.extend(c),new LngLatBounds(route[0],route[0]));
        map.fitBounds(b,{padding:56,animate:false,maxZoom:15,pitch:50});
      } else if(frame.vehicle) map.jumpTo({center:frame.vehicle,zoom:15,pitch:50});
    };
    const step=(now:number)=>{
      loop=0;
      if(!cur||!tgt||failed||document.hidden)return;
      if(low&&now-lastDraw<33){loop=requestAnimationFrame(step);return;}
      const dt=Math.min(.1,Math.max(.001,(now-(lastT||now-16))/1000));lastT=now;lastDraw=now;
      const k=1-Math.exp(-dt/.28),kb=1-Math.exp(-dt/.35),kz=1-Math.exp(-dt/1.1);
      cur.p=[cur.p[0]+(tgt.p[0]-cur.p[0])*k,cur.p[1]+(tgt.p[1]-cur.p[1])*k];
      const db=((tgt.b-cur.b+540)%360)-180;cur.b+=db*kb;
      cur.z+=(tgt.z-cur.z)*kz;cur.pt+=(tgt.pt-cur.pt)*kz;
      traveler?.setLngLat(cur.p);
      const lean = traveler?.getElement().querySelector('.veh-lean') as HTMLElement | null;
      if (lean) lean.style.transform = `rotate(${Math.max(-14, Math.min(14, db * .9))}deg)`;
      map.jumpTo({center:cur.p,bearing:cur.b,zoom:cur.z,pitch:cur.pt,
        padding:{top:Math.round(map.getContainer().clientHeight*.40),bottom:0,left:0,right:0}});
      const done=Math.abs(tgt.p[0]-cur.p[0])<1e-8&&Math.abs(tgt.p[1]-cur.p[1])<1e-8&&Math.abs(db)<.03
        &&Math.abs(tgt.z-cur.z)<.003&&Math.abs(tgt.pt-cur.pt)<.05;
      if(!done&&following){loop=requestAnimationFrame(step);} else lastT=0;
    };
    const fail=()=>{
      if(failed)return;
      failed=true;
      clearTimeout(paintTimeout);
      setStatus('Abrindo a vista 2D…');
      send('marapass.3d.unavailable');
    };
    const timer=window.setTimeout(fail,16000);
    const checkPaint=()=>{
      if (failed || painted || !lastRoute || lastRoute.length<2) return;
      const routeVisible=map.queryRenderedFeatures({layers:['route-core']}).length>0;
      const roadsVisible=map.queryRenderedFeatures({
        layers:['road_minor','road_secondary_tertiary','road_trunk_primary',
          'road_motorway','road_service_track','road_link'],
      }).length>0;
      if (routeVisible && roadsVisible) {
        painted=true;
        clearTimeout(paintTimeout);
        setStatus('');
        diagnostic('render');
      }
    };
    const flush=()=>{
      queued=false;
      try {
      const frame=received.current;
      if (!frame || !ready || failed || document.hidden) return;
      if(firstFrame){firstFrame=false;diagnostic('frame');}
      if (frame.route && frame.route!==lastRoute) {
        lastRoute=frame.route;
        if (!painted && paintTimeout===undefined)
          paintTimeout=window.setTimeout(fail,6500);
        (map.getSource('route') as GeoJSONSource).setData(frame.route.length>1
          ? {type:'Feature',properties:{},geometry:{type:'LineString',coordinates:frame.route}}
          : {type:'FeatureCollection',features:[]});
      }
      if (satellite!==frame.satellite) {
        satellite=frame.satellite;
        map.setLayoutProperty('satellite','visibility',satellite?'visible':'none');
      }
      const visiblePlaces=frame.places.slice(0,window.innerWidth<600?2:4);
      const key=JSON.stringify(visiblePlaces);
      if(key!==placeKey.current){placeKey.current=key;setPlaces(visiblePlaces);}
      if (frame.vehicle) {
        const bearing=frame.bearing ?? map.getBearing();
        if (!traveler || nautical!==frame.nautical) {
          traveler?.remove();
          nautical=frame.nautical;
          traveler=new Marker({
            element:vehicleElement(nautical), rotationAlignment:'viewport', pitchAlignment:'viewport',
          }).setLngLat(frame.vehicle).addTo(map);
        }
        if(!frame.follow||!cur)traveler.setLngLat(frame.vehicle);
        traveler.setRotation(
          nautical || frame.follow ? 0 : bearing-map.getBearing(),
        );
        if(!frame.follow&&!placed){place(frame);reveal();}
        traveler.getElement().style.opacity=frame.stale?'0.45':'1';
        if(frame.follow) {
          const now=performance.now();
          if(lastFix){const dt=(now-lastFix.t)/1000;if(dt>.2){const v=Math.min(45,meters(lastFix.p,frame.vehicle)/dt);speed=speed*.6+v*.4;lastFix={p:frame.vehicle,t:now};}}
          else lastFix={p:frame.vehicle,t:now};
          tgt={p:frame.vehicle,b:bearing,z:zoomFor(speed),pt:speed>14?58:62};
          if(!following||!cur){
            if(firstCamera){firstCamera=false;diagnostic('camera');}
            // Entrada suave: parte da vista atual do mapa (ou do próprio carro, se for a primeira).
            cur=placed?{p:map.getCenter().toArray() as Point,b:map.getBearing(),z:map.getZoom(),pt:map.getPitch()}
              :{p:frame.vehicle,b:bearing,z:tgt.z,pt:tgt.pt};
            if(!placed){map.jumpTo({center:cur.p,bearing:cur.b,zoom:cur.z,pitch:cur.pt,
              padding:{top:Math.round(map.getContainer().clientHeight*.40),bottom:0,left:0,right:0}});reveal();}
          }
          following=true;
          if(!loop)loop=requestAnimationFrame(step);
        } else if(frame.focus && frame.focus.revision!==focusRevision) {
          map.easeTo({center:frame.focus.point,zoom:Math.max(map.getZoom(),15),duration:900,easing:t=>t<.5?4*t*t*t:1-Math.pow(-2*t+2,3)/2});

        }
      }
      focusRevision=frame.focus?.revision??-1;
      following=frame.follow;
      map.triggerRepaint();
      } catch { fail(); }
    };
    const listen=(event:MessageEvent)=>{
      if(event.origin!==location.origin || event.source!==window.parent || typeof event.data!=='string')return;
      let next:Frame;
      try{next=JSON.parse(event.data);}catch{return;}
      if(next.type!=='marapass.3d.frame' || failed)return;
      if(!next.route && received.current?.route) next.route=received.current.route;
      received.current=next;
      if(!queued){queued=true;animation=requestAnimationFrame(flush);}
    };
    window.addEventListener('message',listen);
    const visibility=()=>{if(document.hidden)map?.stop();else flush();};
    const contextLost=()=>{diagnostic('contextLost');fail();};
    document.addEventListener('visibilitychange',visibility);
    try {
      map=new LibreMap({container:element.current!,style:baseStyle,center:[-44.359,-2.965],
        zoom:16,pitch:60,maxPitch:75,maxZoom:19,attributionControl:false,
        pixelRatio:low?1:Math.min(window.devicePixelRatio || 1,1.5),canvasContextAttributes:{antialias:!low},fadeDuration:low?0:120,
        maxTileCacheSize:low?32:64,maxTileCacheZoomLevels:3});
      element.current!.style.opacity='0';element.current!.style.transition='opacity .45s ease';
      mapRef.current=map;
      map.once('error',()=>diagnostic('error'));
      map.on('rotate',()=>{
        const frame=received.current;
        if (traveler && frame && !frame.follow && !frame.nautical && frame.bearing!==null)
          traveler.setRotation(frame.bearing-map.getBearing());
      });
      map.on('render',checkPaint);
      map.addControl(new AttributionControl({compact:true}),'bottom-left');
      map.on('style.load',()=>{
        try {
          void addGravuras(map);
          window.setTimeout(reveal,3500);
          ready=true;
          clearTimeout(timer);
          send('marapass.3d.ready');
          flush();
        } catch {fail();}
      });
      for(const name of ['dragstart','zoomstart','rotatestart','pitchstart'] as const)
        map.on(name,event=>{if(event.originalEvent){following=false;send('marapass.3d.gesture');}});
      map.getCanvas().addEventListener('webglcontextlost',contextLost,{once:true});
    } catch {fail();}
    return ()=>{
      clearTimeout(timer);
      clearTimeout(paintTimeout);
      cancelAnimationFrame(animation);cancelAnimationFrame(loop);
      window.removeEventListener('message',listen);
      document.removeEventListener('visibilitychange',visibility);
      map?.getCanvas().removeEventListener('webglcontextlost',contextLost);
      traveler?.remove();
      for(const marker of markers.current.values())marker.remove();
      markers.current.clear();
      map?.remove();
      received.current=null;
      nodes.current.clear();
      mapRef.current=null;
    };
  },[]);
  useEffect(()=>{
    const map=mapRef.current;
    if(!map)return;
    const current=new Set(places.map(p=>p.id));
    for(const [id,marker] of markers.current)
      if(!current.has(id)){marker.remove();markers.current.delete(id);nodes.current.delete(id);}
    for(const p of places){
      const existing=markers.current.get(p.id);
      if(existing)existing.setLngLat(p.point);
      else {
        const node=nodes.current.get(p.id);
        if(node)markers.current.set(p.id,new Marker({element:node,anchor:'bottom'}).setLngLat(p.point).addTo(map));
      }
    }
  },[places]);
  return <main className="size-full">
    <div className="size-full" ref={element}/>
    {status && <p className="status" role="status"><Navigation size={16}/>{status}</p>}
    {places.map(p=>{
      const Icon=p.coupon?Tag:poiIcons[p.category as keyof typeof poiIcons]??MapPin;
      let node=nodes.current.get(p.id);
      if(!node){node=document.createElement('div');nodes.current.set(p.id,node);}
      return createPortal(
        <button type="button" onClick={()=>send('marapass.3d.place',p.id)} className="poi" aria-label={p.name}>
          <i><Icon size={16}/></i><span><b>{p.name}</b><small>{p.ahead}</small></span>
        </button>,node,p.id);
    })}
  </main>;
}
createRoot(document.getElementById('root')!).render(<Canvas/>);
