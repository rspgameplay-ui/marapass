import cities from './cities.json' with {type:'json'};
const ORIGINS=new Set(['https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site','http://terminal.local:4173']);
export function normalizeForecast(j,now=Date.now()){
 const meta=j?.properties?.meta;const source=Date.parse(meta?.updated_at);if(!Number.isFinite(source)||source>now+3600000||now-source>36*3600000)throw Error('stale_model');
 const points=(j.properties.timeseries||[]).filter(x=>Date.parse(x.time)>=now-3600000&&Date.parse(x.time)<=now+25*3600000).map(x=>{const v=x.data?.instant?.details||{};const h=x.data?.next_1_hours||x.data?.next_6_hours;const number=(k,min,max)=>Number.isFinite(v[k])&&v[k]>=min&&v[k]<=max?v[k]:null;return {time:x.time,temperature:number('air_temperature',-50,65),humidity:number('relative_humidity',0,100),windKmh:number('wind_speed',0,100)===null?null:Math.round(v.wind_speed*36)/10,windFrom:number('wind_from_direction',0,360),gustKmh:number('wind_speed_of_gust',0,150)===null?null:Math.round(v.wind_speed_of_gust*36)/10,cloudCover:number('cloud_area_fraction',0,100),rainMm:Number.isFinite(h?.details?.precipitation_amount)?h.details.precipitation_amount:null,rainHours:x.data?.next_1_hours?1:x.data?.next_6_hours?6:null,symbol:typeof h?.summary?.symbol_code==='string'?h.summary.symbol_code:'unknown'};}).filter(x=>x.temperature!==null||x.windKmh!==null);
 if(!points.length)throw Error('no_forecast');return {source:'MET Norway · ECMWF',sourceUrl:'https://api.met.no/',licenseUrl:'https://creativecommons.org/licenses/by/4.0/',modelUpdatedAt:meta.updated_at,points};
}
export async function handle(req,env=Deno.env,fetcher=fetch,now=Date.now()){
 const origin=req.headers.get('origin')||'';const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':ORIGINS.has(origin)?origin:'https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site','Vary':'Origin','Access-Control-Allow-Headers':'apikey,content-type','Access-Control-Allow-Methods':'GET,OPTIONS','X-Content-Type-Options':'nosniff'};const reply=(status,data,cache='no-store')=>new Response(JSON.stringify(data),{status,headers:{...headers,'Cache-Control':cache}});
 if(origin&&!ORIGINS.has(origin))return reply(403,{error:'origin_denied'});
 if(req.method!=='OPTIONS'&&![env.get('SUPABASE_ANON_KEY'),env.get('SUPABASE_PUBLISHABLE_KEY')].filter(Boolean).includes(req.headers.get('apikey')))return reply(401,{error:'project_key_required'});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});if(req.method!=='GET')return reply(405,{error:'method_not_allowed'});
 const code=new URL(req.url).searchParams.get('city');if(!code||!Object.hasOwn(cities,code))return reply(400,{error:'municipality_required'});
 const city=cities[code],base=env.get('SUPABASE_URL'),key=env.get('SUPABASE_SERVICE_ROLE_KEY');if(!base||!key)return reply(503,{error:'not_configured'});
 const rest=async(path,method='GET',data)=>{const r=await fetcher(base+'/rest/v1/'+path,{method,headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},...(data===undefined?{}:{body:JSON.stringify(data)}),signal:AbortSignal.timeout(8000)});if(!r.ok)throw Error('cache_failure');return method==='PATCH'?null:r.json();};
 let saved;try{
  const rows=await rest('map_environment_cache?city_code=eq.'+code+'&select=payload,expires_at,locked_until,fetched_at');saved=rows?.[0];
  const output=(payload,stale=false)=>reply(200,{...payload,city:{code,...city},stale,fetchedAt:saved?.fetched_at||new Date(now).toISOString()},stale?'public, max-age=60':'public, max-age=600');
  if(saved?.payload&&Date.parse(saved.expires_at)>now)return output(saved.payload);
  const claimed=await rest('rpc/claim_map_environment','POST',{p_code:code});
  if(!claimed){if(saved?.payload&&now-Date.parse(saved.fetched_at)<6*3600000)return output(saved.payload,true);return reply(503,{error:'temporarily_unavailable'});}
  try{
   const r=await fetcher('https://api.met.no/weatherapi/locationforecast/2.0/compact?lat='+city.lat+'&lon='+city.lng,{headers:{'User-Agent':'MaraPassMapa/0.7 (+https://marapass.com)','Accept':'application/json'},signal:AbortSignal.timeout(12000)});
   if(!r.ok)throw Error('provider_unavailable');const payload=normalizeForecast(await r.json(),now);saved={fetched_at:new Date(now).toISOString()};
   await rest('map_environment_cache?city_code=eq.'+code,'PATCH',{payload,expires_at:new Date(now+3*3600000).toISOString(),locked_until:new Date(0).toISOString(),fetched_at:saved.fetched_at});return output(payload);
  }catch{
   await rest('map_environment_cache?city_code=eq.'+code,'PATCH',{locked_until:new Date(now+5*60000).toISOString()});
   if(saved?.payload&&now-Date.parse(saved.fetched_at)<6*3600000)return output(saved.payload,true);return reply(503,{error:'weather_unavailable'});
  }
 }catch{return reply(503,{error:'weather_unavailable'});}
}
if(typeof Deno!=='undefined')Deno.serve(req=>handle(req));

