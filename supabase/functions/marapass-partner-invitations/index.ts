import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * MaraPass / Partner acceptance via verified Supabase Auth.
 * A login link alone never approves a commercial account.
 */
const cors = {
 "Access-Control-Allow-Origin": "*",
 "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
 "Access-Control-Allow-Methods": "POST, OPTIONS"
};
const headers = {...cors,"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"};
const respond=(status:number,data:Record<string,unknown>)=>
 new Response(JSON.stringify(data),{status,headers});
const uuid=(x:unknown):x is string=>
 typeof x==="string" &&
 /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(x);
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return respond(405,{error:"method_not_allowed"});
 const authorization=req.headers.get("authorization")||"";
 if(!/^Bearer [^\s]+$/i.test(authorization))return respond(401,{error:"unauthenticated"});
 let body:Record<string,unknown>;
 try {
   const raw=await req.text();
   if(raw.length>2048)return respond(413,{error:"request_too_large"});
   body=JSON.parse(raw);
   if(!body || typeof body!=="object" || Array.isArray(body))throw new Error("invalid");
 }catch{return respond(400,{error:"invalid_request"});}
 if(body.action!=="list" && body.action!=="accept")return respond(400,{error:"unsupported_action"});
 if(body.action==="accept"&&!uuid(body.partnerId))return respond(400,{error:"invalid_partner_id"});
 const url=Deno.env.get("SUPABASE_URL");
 const anon=Deno.env.get("SUPABASE_ANON_KEY");
 const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return respond(503,{error:"not_configured"});
 try {
   const auth=await fetch(url+"/auth/v1/user",{
     headers:{apikey:anon,Authorization:authorization},
     signal:AbortSignal.timeout(9000)
   });
   if(!auth.ok)return respond(401,{error:"session_invalid"});
   const user=await auth.json();
   if(!uuid(user?.id)||!user?.email_confirmed_at||user?.is_anonymous)
     return respond(403,{error:"verified_email_required"});
   const rpc=body.action==="list"?"partner_list_my_invitations":"partner_accept_invitation";
   const args=body.action==="list"?{p_user_id:user.id}:{p_user_id:user.id,p_partner_id:body.partnerId};
   const result=await fetch(url+"/rest/v1/rpc/"+rpc,{
     method:"POST",
     headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},
     body:JSON.stringify(args),signal:AbortSignal.timeout(9000)
   });
   if(!result.ok)return respond(403,{error:"invitation_not_available_or_expired"});
   const data=await result.json();
   return respond(200,{success:true,...(body.action==="list"?{invitations:data}:{acceptance:data})});
 }catch{
   return respond(503,{error:"invitation_service_unavailable"});
 }
});