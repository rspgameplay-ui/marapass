import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const page = await Deno.readTextFile(new URL("./site.html", import.meta.url));
Deno.serve(async (req: Request) => {
  if(req.method!=="GET" && req.method!=="HEAD")
    return new Response("Método não permitido",{status:405,headers:{"Allow":"GET, HEAD"}});
  return new Response(req.method==="HEAD"?null:page,{status:200,headers:{
    "Content-Type":"text/html; charset=utf-8",
    "Cache-Control":"no-store",
    "X-Content-Type-Options":"nosniff",
    "Referrer-Policy":"strict-origin-when-cross-origin",
    "Permissions-Policy":"geolocation=(self)",
    "X-Frame-Options":"SAMEORIGIN"
  }});
});