import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const page = await Deno.readTextFile(new URL("./site.html", import.meta.url));
Deno.serve(async (req: Request) => {
 if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed",{status:405,headers:{"Allow":"GET, HEAD"}});
 const responseHeaders = {
   "Content-Type":"text/html; charset=utf-8",
   "Cache-Control":"no-store, no-cache, must-revalidate",
   "X-Content-Type-Options":"nosniff",
   "Referrer-Policy":"strict-origin-when-cross-origin",
   "Permissions-Policy":"geolocation=(self)",
   "X-Frame-Options":"SAMEORIGIN"
 };
 return new Response(req.method==="HEAD"?null:page,{status:200,headers:responseHeaders});
});