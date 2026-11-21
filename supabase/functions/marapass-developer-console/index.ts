import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const ORIGIN="https://marapass-admin-dev.pages.dev";
const cors={
 "Access-Control-Allow-Origin":ORIGIN,
 "Access-Control-Allow-Methods":"POST, OPTIONS",
 "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info",
 "Vary":"Origin"
};
const headers={...cors,"Content-Type":"application/json; charset=utf-8",
 "Cache-Control":"no-store", "X-Content-Type-Options":"nosniff"};
const respond=(status:number,data:Record<string,unknown>)=>new Response(JSON.stringify(data),{status,headers});
const tables:Record<string,{table:string;select:string;order:string;cols:string[]}> = {
 applications:{table:"partner_applications",select:"business_name,city,status,created_at",order:"created_at.desc",cols:["business_name","city","status","created_at"]},
 partners:{table:"partners",select:"trade_name,legal_name,status,created_at,owner_user_id",order:"created_at.desc",cols:["trade_name","legal_name","status","created_at","owner_user_id"]},
 establishments:{table:"establishments",select:"name,category,city,is_public,created_at",order:"created_at.desc",cols:["name","category","city","is_public","created_at"]},
 experiences:{table:"experiences",select:"title,category,status,booking_required,created_at",order:"created_at.desc",cols:["title","category","status","booking_required","created_at"]},
 offers:{table:"offers",select:"title,access_scope,discount_type,discount_value,minimum_purchase_cents,maximum_discount_cents,issue_until,is_published,created_at",order:"created_at.desc",cols:["title","access_scope","discount_type","discount_value","minimum_purchase_cents","maximum_discount_cents","issue_until","is_published","created_at"]},
 reservations:{table:"reservations",select:"scheduled_at,participants,status,created_at",order:"created_at.desc",cols:["scheduled_at","participants","status","created_at"]},
 passports:{table:"passport_products",select:"name,price_cents,validity_start_rule,is_published,created_at",order:"created_at.desc",cols:["name","price_cents","validity_start_rule","is_published","created_at"]},
 coupons:{table:"coupon_instances",select:"offer_title_snapshot,status,issued_at,expires_at",order:"issued_at.desc",cols:["offer_title_snapshot","status","issued_at","expires_at"]}
};
async function requestJson(url:string,key:string,bearer:string,init:RequestInit={}){
 const r=await fetch(url,{...init,headers:{"apikey":key,"Authorization":bearer,...(init.headers||{})},
 signal:AbortSignal.timeout(12000)});
 if(!r.ok)throw Error("upstream_error");
 return r.json();
}
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return respond(405,{error:"method_not_allowed"});
 if(req.headers.get("origin") && req.headers.get("origin")!==ORIGIN)
   return respond(403,{error:"origin_not_allowed"});
 const bearer=req.headers.get("authorization")||"";
 if(!/^Bearer [^\s]+$/i.test(bearer))return respond(401,{error:"login_required"});
 let body:{action?:string;tab?:string;page?:number;pageSize?:number};
 try{
  const raw=await req.text();if(raw.length>1024)throw Error("too_big");
  body=JSON.parse(raw);
  if(!body||typeof body!=="object"||Array.isArray(body))throw Error("bad");
 }catch{return respond(400,{error:"invalid_request"});}
 if(body.action!=="overview"&&body.action!=="list")return respond(400,{error:"unsupported_action"});
 if(body.action==="list"&&(typeof body.tab!=="string"||!tables[body.tab]))
    return respond(400,{error:"unsupported_tab"});
 const url=Deno.env.get("SUPABASE_URL");
 const anon=Deno.env.get("SUPABASE_ANON_KEY");
 const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return respond(503,{error:"not_configured"});
 try{
  const user=await requestJson(url+"/auth/v1/user",anon,bearer);
  if(!user?.id||!user.email_confirmed_at||user.is_anonymous)
   return respond(401,{error:"verified_login_required"});
  // PostgREST verifies signed JWT and assurance (aal2). Staff role must be active.
  const contexts=await requestJson(url+"/rest/v1/rpc/my_access_context",anon,bearer,{
   method:"POST",headers:{"Content-Type":"application/json"},body:"{}"
  });
  const ctx=Array.isArray(contexts)?contexts[0]:contexts;
  if(!ctx||ctx.user_id!==user.id||ctx.staff_role!=="developer"||ctx.mfa_verified!==true)
    return respond(403,{error:"developer_mfa_required"});
  const serviceBearer="Bearer "+service;
  if(body.action==="list"){
   const cfg=tables[body.tab!];
   // No overall query count or record cap: request successive pages as needed.
   // Per-page size is bounded to protect responsiveness and the Supabase project.
   const page=body.page===undefined?0:body.page;
   const pageSize=body.pageSize===undefined?50:body.pageSize;
   if(!Number.isSafeInteger(page)||page<0||!Number.isSafeInteger(pageSize)||pageSize<1||pageSize>100
      ||!Number.isSafeInteger((page+1)*pageSize))return respond(400,{error:"invalid_pagination"});
   const params=new URLSearchParams({
     select:cfg.select,order:cfg.order,limit:String(pageSize+1),offset:String(page*pageSize)
   });
   const rows=await requestJson(url+"/rest/v1/"+cfg.table+"?"+params,service,serviceBearer);
   if(!Array.isArray(rows))throw Error("upstream_schema");
   const hasMore=rows.length>pageSize;
   const safe=rows.slice(0,pageSize).map(row=>{
    const result:Record<string,unknown>={};
    for(const c of cfg.cols){
     // Ownership is only a boolean; UUID is never returned.
     result[c]=c==="owner_user_id"?(row[c]?"vinculado":null):row[c];
    }
    return result;
   });
   return respond(200,{
      data:safe,tab:body.tab,readOnly:true,page,pageSize,hasMore,
      nextPage:hasMore?page+1:null,
      unlimitedConsultations:true
    });
  }
  const metrics=[
   ["applications_pending","partner_applications","status=eq.pending"],
   ["partners_approved","partners","status=eq.approved"],
   ["experiences_published","experiences","status=eq.published"],
   ["offers_published","offers","is_published=eq.true"],
   ["reservations_requested","reservations","status=eq.requested"],
   ["reservations_confirmed","reservations","status=eq.confirmed"]
  ] as const;
  const out:Record<string,number>={};
  await Promise.all(metrics.map(async ([k,table,query])=>{
   const r=await fetch(url+"/rest/v1/"+table+"?select=id&"+query+"&limit=0",{
    headers:{"apikey":service,"Authorization":serviceBearer,"Prefer":"count=exact"},
    signal:AbortSignal.timeout(12000)});
   if(!r.ok)throw Error("upstream_count");
   const cr=r.headers.get("content-range")||"";
   const total=cr.split("/")[1];
   if(!total||!/^\d+$/.test(total))throw Error("upstream_count_missing");
   out[k]=Number(total);
  }));
  return respond(200,{data:out,readOnly:true});
 }catch{return respond(503,{error:"developer_preview_unavailable"});}
});