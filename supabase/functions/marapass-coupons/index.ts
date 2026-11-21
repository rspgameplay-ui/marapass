// No client-controlled actor IDs. Auth is verified with Supabase Auth on every private request.
export async function handle(req, env = Deno.env, fetcher = fetch) {
 const origin=req.headers.get('origin')||'';
 const allowed=new Set(['https://marapass-cupons.dfamorim-10.chatgpt.site','http://terminal.local:4173']);
 const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Access-Control-Allow-Origin':allowed.has(origin)?origin:'https://marapass-cupons.dfamorim-10.chatgpt.site','Vary':'Origin','Access-Control-Allow-Headers':'authorization, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
 const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers});
 if(origin&&!allowed.has(origin))return reply(403,{error:'origin_denied'});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,{error:'method_not_allowed'});
 const base=env.get('SUPABASE_URL'),anon=env.get('SUPABASE_ANON_KEY'),service=env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!base||!anon||!service)return reply(503,{error:'server_not_ready'});
 const uuid=x=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(x);
 const key=x=>typeof x==='string'&&x.length>=16&&x.length<=180;
 try {
  if(!req.headers.get('content-type')?.includes('application/json'))return reply(415,{error:'json_required'});
  const declared=Number(req.headers.get('content-length')||0);if(declared>2900000)return reply(413,{error:'payload_too_large'});
  const raw=await req.text();if(raw.length>2900000)return reply(413,{error:'payload_too_large'});
  let b;try{b=JSON.parse(raw);}catch{return reply(400,{error:'invalid_request'});}
  if(!b||Array.isArray(b)||typeof b!=='object')return reply(400,{error:'invalid_request'});
  if(b.action!=='upload_image'&&raw.length>16000)return reply(413,{error:'payload_too_large'});
  const call=async(path,body,token=service)=>{
   const r=await fetcher(base+path,{method:body===undefined?'GET':'POST',headers:{apikey:token,Authorization:'Bearer '+token,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(12000)});
   let d=null;try{d=await r.json();}catch{};return {ok:r.ok,status:r.status,data:d};
  };
  if(b.action==='catalog'){
   const r=await call('/rest/v1/offers?select=id,title,description,discount_type,discount_value,starts_at,ends_at,max_issuances,per_user_limit,presentation,establishments!inner(name,city,public_profile,street_address)&order=created_at.desc&limit=100',undefined,anon);
   return r.ok?reply(200,{offers:r.data}):reply(503,{error:'catalog_unavailable'});
  }
  if(!['context','wallet','create_offer','update_offer','publish_offer','issue','inspect','redeem','upload_image','submit_business','save_profile'].includes(b.action))return reply(400,{error:'unsupported_action'});
  const bearer=req.headers.get('authorization')||'';if(!/^Bearer \S+$/i.test(bearer))return reply(401,{error:'login_required'});
  const a=await fetcher(base+'/auth/v1/user',{headers:{apikey:anon,Authorization:bearer},signal:AbortSignal.timeout(10000)});
  if(!a.ok)return reply(401,{error:'invalid_session'});
  const user=await a.json();if(!uuid(user?.id)||!user.email_confirmed_at||user.is_anonymous===true)return reply(403,{error:'confirmed_account_required'});
  const uid=user.id;
  if(user.factors?.some(f=>f.status==='verified')){
   let claims;try{claims=JSON.parse(atob(bearer.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));}catch{return reply(401,{error:'invalid_session'});}
   if(claims.aal!=='aal2')return reply(403,{error:'mfa_required'});
  }
  if(b.action==='upload_image'){
   if(typeof b.data!=='string'||!/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(b.data))return reply(400,{error:'invalid_image'});
   const [meta,encoded]=b.data.split(',');const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
   const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
   const png=bytes.slice(0,8).join(',')==='137,80,78,71,13,10,26,10';
   const webp=String.fromCharCode(...bytes.slice(0,4))==='RIFF'&&String.fromCharCode(...bytes.slice(8,12))==='WEBP';
   const mime=jpeg?'image/jpeg':png?'image/png':webp?'image/webp':null;
   if(!mime||!meta.startsWith('data:'+mime+';')||bytes.length>2097152||bytes.length<32)return reply(400,{error:'invalid_image'});
   const reserve=await call('/rest/v1/rpc/reserve_coupon_media',{p_actor:uid});
   if(!reserve.ok||reserve.data!==true)return reply(429,{error:'media_limit'});
   const path=uid+'/'+crypto.randomUUID()+'.'+(jpeg?'jpg':png?'png':'webp');
   const up=await fetcher(base+'/storage/v1/object/marapass-media/'+path,{method:'POST',headers:{apikey:service,Authorization:'Bearer '+service,'Content-Type':mime,'x-upsert':'false'},body:bytes,signal:AbortSignal.timeout(20000)});
   return up.ok?reply(200,{url:base+'/storage/v1/object/public/marapass-media/'+path}):reply(503,{error:'upload_failed'});
  }
  if(b.action==='submit_business'){
   const profile=cleanProfile(b.profile,base,uid);
   const r=await call('/rest/v1/rpc/submit_business_profile',{p_actor:uid,p_email:user.email,p_profile:profile});
   return r.ok?reply(200,{applicationId:r.data}):rpcError(r,reply);
  }
  // User-scoped reads keep existing RLS. Privileged reads below are explicitly scoped.
  if(b.action==='wallet'){
   const r=await call('/rest/v1/coupon_instances?select=id,display_code,status,expires_at,offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,conditions_snapshot,offers(establishments(name,city))&beneficiary_user_id=eq.'+uid+'&order=issued_at.desc&limit=100');
   return r.ok?reply(200,{coupons:r.data}):reply(503,{error:'wallet_unavailable'});
  }
  if(b.action==='issue'){
   if(!uuid(b.offerId)||!key(b.requestKey))return reply(400,{error:'invalid_request'});
   const offer=await call('/rest/v1/offers?select=id,establishments!inner(is_public)&id=eq.'+b.offerId);
   if(!offer.ok||!offer.data?.[0]?.establishments?.is_public)return reply(409,{error:'offer_unavailable'});
   const r=await call('/rest/v1/rpc/issue_coupon',{p_offer_id:b.offerId,p_user_id:uid,p_idempotency_key:b.requestKey,p_reservation_id:null});
   return r.ok?reply(200,{couponId:r.data}):rpcError(r,reply);
  }
  const owned=await call('/rest/v1/partners?select=id,trade_name&status=eq.approved&owner_user_id=eq.'+uid);
  const member=await call('/rest/v1/partner_members?select=partner_id,member_role,partners!inner(status)&is_active=eq.true&partners.status=eq.approved&user_id=eq.'+uid);
  if(!owned.ok||!member.ok)return reply(503,{error:'authorization_unavailable'});
  const roles=new Map((member.data||[]).map(m=>[m.partner_id,m.member_role]));for(const p of owned.data||[])roles.set(p.id,'owner');
  const ids=[...roles.keys()];
  const est=ids.length?await call('/rest/v1/establishments?select=id,partner_id,name,city,category,description,street_address,public_profile,is_active,is_public&partner_id=in.('+ids.join(',')+')&limit=200'):{ok:true,data:[]};
  if(!est.ok)return reply(503,{error:'authorization_unavailable'});
  if(b.action==='context'){
   const eids=est.data.map(e=>e.id);
   const offers=eids.length?await call('/rest/v1/offers?select=id,establishment_id,title,description,discount_type,discount_value,is_published,starts_at,ends_at,max_issuances,per_user_limit,presentation&establishment_id=in.('+eids.join(',')+')&order=created_at.desc&limit=200'):{ok:true,data:[]};
   if(!offers.ok)return reply(503,{error:'catalog_unavailable'});
   const apps=await call('/rest/v1/partner_applications?select=id,business_name,status,business_profile,review_notes&applicant_user_id=eq.'+uid+'&order=created_at.desc&limit=10');
   if(!apps.ok)return reply(503,{error:'service_unavailable'});
   return reply(200,{partners:owned.data,applications:apps.data,establishments:est.data.map(e=>({...e,role:roles.get(e.partner_id)})),offers:offers.data});
  }
  if(b.action==='save_profile'){
   const target=est.data.find(e=>e.id===b.establishmentId&&e.is_active);
   const partnerId=target?.partner_id||b.partnerId;
   if(!uuid(partnerId)||!['owner','manager'].includes(roles.get(partnerId))||(b.establishmentId&&!target))return reply(403,{error:'manager_required'});
   const profile=cleanProfile(b.profile,base,uid,target?.public_profile);
   const r=await call('/rest/v1/rpc/save_business_profile',{p_actor:uid,p_partner_id:partnerId,p_establishment_id:target?.id||null,p_profile:profile});
   return r.ok?reply(200,{establishmentId:r.data}):rpcError(r,reply);
  }
  if(!uuid(b.establishmentId))return reply(400,{error:'invalid_request'});
  const target=est.data.find(e=>e.id===b.establishmentId&&e.is_active);
  if(!target)return reply(403,{error:'establishment_denied'});
  const canManage=['owner','manager'].includes(roles.get(target.partner_id));
  if(['create_offer','update_offer'].includes(b.action)){
   if(!canManage)return reply(403,{error:'manager_required'});
   if(!uuid(b.requestKey)||typeof b.title!=='string'||typeof b.terms!=='string'||!['percent','fixed'].includes(b.discountType)||!Number.isFinite(b.discountValue)||!Number.isInteger(b.maxIssuances)||!Number.isInteger(b.perUserLimit)||!Number.isFinite(Date.parse(b.startsAt))||!Number.isFinite(Date.parse(b.endsAt)))return reply(400,{error:'invalid_request'});
   if(b.maxIssuances<1||b.maxIssuances>100000||b.perUserLimit<1||b.perUserLimit>20||b.perUserLimit>b.maxIssuances||b.discountValue<=0||(b.discountType==='percent'&&b.discountValue>100)||Date.parse(b.endsAt)<=Date.parse(b.startsAt))return reply(400,{error:'invalid_offer'});
   let presentation;
   if(b.presentation){
    let oldImage='';
    if(b.offerId){if(!uuid(b.offerId))return reply(400,{error:'invalid_request'});const old=await call('/rest/v1/offers?select=presentation&id=eq.'+b.offerId+'&establishment_id=eq.'+target.id);oldImage=old.data?.[0]?.presentation?.image||'';}
    presentation=cleanPresentation(b.presentation,base,uid,oldImage);
   }
   if(b.action==='update_offer'&&(!uuid(b.offerId)||!presentation))return reply(400,{error:'invalid_request'});
   const r=await call('/rest/v1/rpc/'+(presentation?'save_custom_offer':'create_partner_offer_once'),{p_establishment_id:target.id,p_actor_user_id:uid,p_request_key:b.requestKey,p_title:b.title,p_discount_type:b.discountType,p_discount_value:b.discountValue,p_terms:presentation?presentationTerms(presentation):b.terms,p_starts_at:b.startsAt,p_ends_at:b.endsAt,p_max_issuances:b.maxIssuances,p_per_user_limit:b.perUserLimit,...(presentation?{p_presentation:presentation,p_offer_id:b.action==='update_offer'?b.offerId:null}:{})});
   return r.ok?reply(200,{offerId:r.data}):rpcError(r,reply);
  }
  if(b.action==='publish_offer'){
   if(!canManage)return reply(403,{error:'manager_required'});
   if(!uuid(b.offerId)||typeof b.publish!=='boolean')return reply(400,{error:'invalid_request'});
   const offer=await call('/rest/v1/offers?select=id&id=eq.'+b.offerId+'&establishment_id=eq.'+target.id);
   if(!offer.ok||!offer.data?.length)return reply(404,{error:'offer_unavailable'});
   const r=await call('/rest/v1/rpc/set_offer_publication',{p_offer_id:b.offerId,p_actor_user_id:uid,p_publish:b.publish});
   return r.ok?reply(200,{published:b.publish}):rpcError(r,reply);
  }
  let filter;
  if(b.action==='inspect'){
   if(typeof b.code!=='string'||!/^MP-[A-F0-9]{12}$/.test(b.code))return reply(400,{error:'invalid_code'});
   filter='display_code=eq.'+b.code;
  }else{
   if(!uuid(b.couponId)||!key(b.requestKey)||(b.amountCents!==null&&(!Number.isSafeInteger(b.amountCents)||b.amountCents<0||b.amountCents>2147483647)))return reply(400,{error:'invalid_request'});
   filter='id=eq.'+b.couponId;
  }
  const found=await call('/rest/v1/coupon_instances?select=id,display_code,status,expires_at,offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,conditions_snapshot,offers!inner(establishment_id)&'+filter+'&offers.establishment_id=eq.'+target.id);
  if(!found.ok)return reply(503,{error:'lookup_unavailable'});
  const c=found.data?.[0];if(!c)return reply(404,{error:'coupon_not_found'});
  if(b.action==='inspect')return reply(200,{coupon:{...c,offers:undefined,expired:Date.parse(c.expires_at)<=Date.now()}});
  const r=await call('/rest/v1/rpc/redeem_coupon',{p_coupon_instance_id:c.id,p_validator_user_id:uid,p_idempotency_key:b.requestKey,p_transaction_amount_cents:b.amountCents});
  return r.ok?reply(200,{redemptionId:r.data}):rpcError(r,reply);
 } catch(e){return reply(e?.message==='invalid_customization'?400:503,{error:e?.message==='invalid_customization'?'invalid_customization':'service_unavailable'});}
}
function rpcError(r,reply){
 const message=r.data?.message||'';
 const errors=[['offer locked for editing','offer_locked'],['minimum purchase not reached','minimum_purchase'],['coupon not valid','coupon_unavailable'],['user offer limit','user_limit'],['issuance limit','stock_exhausted'],['offer unavailable','offer_unavailable'],['not eligible','publication_denied'],['payload changed','request_changed'],['idempotency key reused','request_changed'],['invalid offer details','invalid_offer']];
 return reply(409,{error:errors.find(([part])=>message.includes(part))?.[1]||'operation_not_applied'});
}
if(typeof Deno!=='undefined') Deno.serve(req=>handle(req));

function cleanText(x,max,required=false){if(typeof x!=='string'||x.trim().length>max||(required&&!x.trim()))throw Error('invalid_customization');return x.trim();}
function mediaUrl(x,base,uid,old=''){if(!x)return '';if(typeof x!=='string'||x.length>500||(!x.startsWith(base+'/storage/v1/object/public/marapass-media/'+uid+'/')&&x!==old)||!/^https:\/\//.test(x))throw Error('invalid_customization');return x;}
function socialUrl(x,host){if(!x)return '';let u;try{u=new URL(x);}catch{throw Error('invalid_customization');}if(u.protocol!=='https:'||u.username||u.password||x.length>300||(host&&!host.some(h=>u.hostname===h||u.hostname.endsWith('.'+h))))throw Error('invalid_customization');return u.href;}
function cleanProfile(p,base,uid,old={}){
 if(!p||Array.isArray(p)||typeof p!=='object')throw Error('invalid_customization');
 if(!Array.isArray(p.photos)||p.photos.length>3)throw Error('invalid_customization');
 const q={name:cleanText(p.name,160,true),city:cleanText(p.city,100,true),category:cleanText(p.category,80,true),address:cleanText(p.address,240,true),description:cleanText(p.description,1000,true),phone:cleanText(p.phone,30,true),instagram:socialUrl(p.instagram,['instagram.com']),facebook:socialUrl(p.facebook,['facebook.com','fb.com']),website:socialUrl(p.website),logo:mediaUrl(p.logo,base,uid,old.logo),photos:p.photos.map(x=>mediaUrl(x,base,uid,(old.photos||[]).includes(x)?x:''))};
 if(q.name.length<2||q.city.length<2||q.phone.length<8)throw Error('invalid_customization');return q;
}
function cleanPresentation(p,base,uid,old=''){
 if(!p||!Number.isSafeInteger(p.minimumCents)||p.minimumCents<0||p.minimumCents>100000000||typeof p.reservationRequired!=='boolean'||typeof p.combinable!=='boolean'||!['ocean','forest','sunset'].includes(p.theme))throw Error('invalid_customization');
 return {image:mediaUrl(p.image,base,uid,old),imageAlt:cleanText(p.imageAlt||'',160),included:cleanText(p.included,600,true),excluded:cleanText(p.excluded,600,true),howToUse:cleanText(p.howToUse,600,true),minimumCents:p.minimumCents,reservationRequired:p.reservationRequired,combinable:p.combinable,theme:p.theme};
}

function presentationTerms(p){const price=new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(p.minimumCents/100);return `Inclui: ${p.included}\nNão inclui / restrições: ${p.excluded}\nComo utilizar: ${p.howToUse}\nCompra mínima: ${p.minimumCents?price:'não exige'}.\nAgendamento: ${p.reservationRequired?'obrigatório, confirme com a empresa antes da visita':'não obrigatório; sujeito à disponibilidade informada'}.\nAcumula com outras promoções: ${p.combinable?'sim':'não'}.\nApresente o cupom antes de concluir a compra. Cada cupom permite uma utilização. Emissão limitada ao estoque e ao limite por turista. A validade do cupom será a menor entre o fim da oferta e 30 dias após a emissão.`;}
