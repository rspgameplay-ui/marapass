import {useEffect, useRef, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {createPortal} from 'react-dom';
import {Map as LibreMap, Marker, AttributionControl,
  type GeoJSONSource, type StyleSpecification} from 'maplibre-gl';
import {Coffee, BedDouble, Fuel, MapPin, Navigation, Tag} from 'lucide-react';
import style from './marapass-style.json';
import 'maplibre-gl/dist/maplibre-gl.css';
import './screen.css';

type Point = [number, number];
type Place = {id:string; name:string; category:string; point:Point; coupon:boolean; ahead:string};
type Frame = {type:'marapass.3d.frame'; vehicle:Point|null; bearing:number|null; follow:boolean;
  route?:Point[]; places:Place[]; satellite:boolean;
  focus?:{point:Point; revision:number}; nautical:boolean};
const baseStyle = style as StyleSpecification;
const poiIcons = {gastronomy:Coffee, lodging:BedDouble, services:Fuel};
function send(type:string, id?:string) {
  window.parent.postMessage(JSON.stringify({type, id}), location.origin);
}
function diagnostic(stage:'frame'|'camera'|'render'|'contextLost'|'error') {
  window.parent.postMessage(JSON.stringify({type:'marapass.3d.diagnostic',stage}),location.origin);
}

function vehicleElement(nautical: boolean) {
  const pin = document.createElement('div');
  pin.setAttribute('role', 'img');
  pin.setAttribute('aria-label', nautical ? 'Posição na travessia' : 'Seu veículo');
  pin.className = nautical ? 'boat-marker' : 'vehicle-marker';
  if (nautical) {
    pin.textContent = '⛵';
    return pin;
  }
  for (const part of ['body', 'glass', 'roof', 'headlights', 'taillights']) {
    const detail = document.createElement('span');
    detail.className = 'car-' + part;
    pin.appendChild(detail);
  }
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
    let firstFrame=true, firstCamera=true;
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
        traveler.setLngLat(frame.vehicle).setRotation(
          nautical || frame.follow ? 0 : bearing-map.getBearing(),
        );
        if(frame.follow) {
          const cameraKey=JSON.stringify([frame.vehicle,bearing,map.getContainer().clientHeight]);
          if(!following || cameraKey!==lastCamera) {
            if(firstCamera){firstCamera=false;diagnostic('camera');}
            lastCamera=cameraKey;
            const camera={center:frame.vehicle,bearing,pitch:62,zoom:16.8,
              padding:{top:Math.round(map.getContainer().clientHeight*.40),bottom:0,left:0,right:0}};
            if (following) map.easeTo({...camera,duration:440});
            else map.jumpTo(camera);
          }
        } else if(frame.focus && frame.focus.revision!==focusRevision) {
          map.easeTo({center:frame.focus.point,zoom:Math.max(map.getZoom(),15),duration:500});

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
        zoom:16,pitch:65,maxPitch:75,maxZoom:19,attributionControl:false,
        pixelRatio:Math.min(window.devicePixelRatio || 1,1.5),
        maxTileCacheSize:64,maxTileCacheZoomLevels:3});
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
      cancelAnimationFrame(animation);
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
