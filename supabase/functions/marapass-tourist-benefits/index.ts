import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const cors = {
 "Access-Control-Allow-Origin": "*",
 "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info",
 "Access-Control-Allow-Methods":"OPTIONS, POST",
};
const common={...cors,"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"};
const respond=(status:number,data:Record<string,unknown>)=>
 new Response(JSON.stringify(data),{status,headers:common});
const uuid=(v:unknown):v is string=>
 typeof v==="string"&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return respond(405,{error:"method_not_allowed"});
 const bearer=req.headers.get("authorization")||"";
 if(!/^Bearer [^\s]+$/i.test(bearer))return respond(401,{error:"login_required"});
 let body:Record<string,unknown>;
 try{
  const raw=await req.text();
  if(raw.length>3500)return respond(413,{error:"payload_too_large"});
  const b=JSON.parse(raw);
  if(!b||typeof b!=="object"||Array.isArray(b))throw Error("invalid");
  body=b;
 }catch{return respond(400,{error:"invalid_request"});}
 const url=Deno.env.get("SUPABASE_URL");
 const anon=Deno.env.get("SUPABASE_ANON_KEY");
 const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return respond(503,{error:"backend_unavailable"});
 try{
  const auth=await fetch(url+"/auth/v1/user",{
    headers:{Authorization:bearer,apikey:anon},signal:AbortSignal.timeout(8000)
  });
  if(!auth.ok)return respond(401,{error:"invalid_session"});
  const user=await auth.json();
  if(!uuid(user?.id)||!user.email_confirmed_at||user.is_anonymous)
   return respond(403,{error:"confirmed_account_required"});
  let name:string;let params:Record<string,unknown>;
  switch(body.action){
   case "issue_coupon":
    if(!uuid(body.offerId)||typeof body.requestKey!=="string"||body.requestKey.length<16||body.requestKey.length>180
       ||(body.entitlementId!==null&&body.entitlementId!==undefined&&!uuid(body.entitlementId))
       ||(body.reservationId!==null&&body.reservationId!==undefined&&!uuid(body.reservationId)))
     return respond(400,{error:"invalid_coupon_request"});
    name="mp_issue_coupon_v2";
    params={p_offer_id:body.offerId,p_user_id:user.id,p_idempotency_key:body.requestKey,
      p_reservation_id:body.reservationId??null,p_passport_entitlement_id:body.entitlementId??null};
    break;
   case "activate_passport":
    if(!uuid(body.entitlementId))return respond(400,{error:"invalid_passport"});
    name="mp_activate_passport";params={p_user_id:user.id,p_entitlement_id:body.entitlementId};break;
   case "request_passport_cancellation":
    if(!uuid(body.orderId))return respond(400,{error:"invalid_passport_order"});
    name="mp_request_passport_cancellation";
    params={p_user_id:user.id,p_order_id:body.orderId,p_reason:typeof body.reason==="string"?body.reason.slice(0,2000):null};break;
   case "report_benefit_issue":
    if(!uuid(body.entitlementId)||!uuid(body.offerId) || typeof body.reason!=="string"
     ||!["fulfillment","equivalent","rescission_refund"].includes(String(body.remedy)))
     return respond(400,{error:"invalid_benefit_issue"});
    name="mp_report_passport_benefit_issue";
    params={p_user_id:user.id,p_entitlement_id:body.entitlementId,p_offer_id:body.offerId,
      p_reason:body.reason,p_remedy:body.remedy};break;
   default:return respond(400,{error:"unsupported_action"});
  }
  const result=await fetch(url+"/rest/v1/rpc/"+name,{
   method:"POST",headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},
   body:JSON.stringify(params),signal:AbortSignal.timeout(12000)
  });
  if(!result.ok)return respond(409,{error:"benefit_not_eligible_or_request_conflict"});
  const payload=await result.json();
  return respond(200,{success:true,...(body.action==="issue_coupon"?{couponId:payload}:{details:payload})});
 }catch{return respond(503,{error:"backend_unavailable"});}
});