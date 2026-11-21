import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";
Deno.serve(async (req: Request) => {
 const headers={"Content-Type":"application/json","Cache-Control":"no-store"};
 if(req.method!=="POST") return new Response(JSON.stringify({error:"method_not_allowed"}),{status:405,headers});
 const auth=req.headers.get("Authorization");
 if(!auth?.startsWith("Bearer ")) return new Response(JSON.stringify({error:"authentication_required"}),{status:401,headers});
 const url=Deno.env.get("SUPABASE_URL");const key=Deno.env.get("SUPABASE_ANON_KEY");
 if(!url||!key) return new Response(JSON.stringify({error:"configuration_unavailable"}),{status:503,headers});
 const client=createClient(url,key,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error}=await client.auth.getUser(auth.slice(7));
 if(error||!user||user.is_anonymous) return new Response(JSON.stringify({error:"authentication_required"}),{status:401,headers});
 let input;try{input=await req.json()}catch{return new Response(JSON.stringify({error:"invalid_json"}),{status:400,headers})}
 const message=typeof input?.message==="string"?input.message.trim():"";
 if(!message||message.length>2000) return new Response(JSON.stringify({error:"invalid_message"}),{status:400,headers});
 return new Response(JSON.stringify({status:"foundation_ready",assistant_ready:false,message:"O assistente MaraPass está em preparação. Ainda não há consulta inteligente de passeios, cupons ou reservas habilitada.",destination:"Barreirinhas",source:"system_status"}),{status:200,headers});
});