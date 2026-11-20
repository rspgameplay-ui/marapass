create or replace function private.map_command(p_action text, p_args jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
<<map_ctx>>
declare
 actor uuid:=auth.uid(); role_name text; scopes text[]; ready boolean;
 doc private.map_documents%rowtype; old_member private.map_members%rowtype;
 v private.map_versions%rowtype; response jsonb; request_key uuid; fingerprint text;
 receipt private.map_requests%rowtype; next_content jsonb; city_name text; code text;
 doc_id text; expected integer; action_name text; reason text; preview_key uuid; target uuid;
 member_codes text[]; page_size integer:=50; page_offset integer;
 k text; i record;
begin
 if actor is null or not exists(
  select 1 from auth.sessions s join auth.users u on u.id=s.user_id
  where s.user_id=actor and s.id::text=auth.jwt()->>'session_id'
   and (s.not_after is null or s.not_after>now()) and u.deleted_at is null
   and (u.banned_until is null or u.banned_until<now())
 ) then raise exception 'Sessão inválida. Entre novamente.' using errcode='42501'; end if;
 if exists(select 1 from public.staff_members s where s.user_id=actor and s.is_active and s.staff_role='admin') then
  role_name:='admin'; scopes:='{}';
 else
  select m.role,m.municipality_codes into role_name,scopes from private.map_members m where m.user_id=actor and m.is_active;
 end if;
 ready:=coalesce(auth.jwt()->>'aal','aal1')='aal2';
 if p_action='access' then
  return jsonb_build_object('role',role_name,'ready',ready and role_name is not null,'municipalities',coalesce(to_jsonb(scopes),'[]'));
 end if;
 if role_name is null or not ready then raise exception 'Permissão de mapa e segundo fator são obrigatórios.' using errcode='42501'; end if;
 page_offset:=greatest(0,least(coalesce((p_args->>'offset')::integer,0),100000));
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into response from (
   select d.* from private.map_documents d
   where (role_name='admin' or cardinality(scopes)=0 or d.municipality_code::text=any(scopes))
    and (coalesce(p_args->>'query','')='' or d.content->>'name' ilike '%'||(p_args->>'query')||'%' or d.content->>'city' ilike '%'||(p_args->>'query')||'%')
    and (coalesce(p_args->>'status','')='' or d.status=p_args->>'status')
   order by d.updated_at desc,d.id limit page_size+1 offset page_offset
  ) q;
  return response;
 end if;
 if p_action='members' then
  if role_name<>'admin' then raise exception 'Somente administrador.' using errcode='42501'; end if;
  return jsonb_build_object(
   'members',(select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('email',u.email)),'[]') from private.map_members m join auth.users u on u.id=m.user_id),
   'history',(select coalesce(jsonb_agg(to_jsonb(q)),'[]') from (select * from private.map_permission_events order by id desc limit 50 offset page_offset) q));
 end if;
 if p_action in ('save','submit','publish','archive','restore','grant') then
  request_key:=(p_args->>'request_id')::uuid;
  if request_key is null then raise exception 'Identificador da operação obrigatório.';end if;
  fingerprint:=md5(p_action||p_args::text);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||request_key::text,0));
  select * into receipt from private.map_requests where map_requests.actor=map_ctx.actor and request_id=request_key;
  if found then
   if receipt.fingerprint<>fingerprint then raise exception 'Identificador reutilizado em outra operação.';end if;
   return receipt.response;
  end if;
  reason:=trim(coalesce(p_args->>'reason',''));
  if length(reason) not between 5 and 500 then raise exception 'Informe o motivo da alteração (5 a 500 caracteres).';end if;
 end if;
 if p_action='grant' then
  if role_name<>'admin' then raise exception 'Somente administrador.' using errcode='42501';end if;
  target:=(p_args->>'user_id')::uuid;
  if target is null then select id into target from auth.users where lower(email)=lower(trim(p_args->>'email')) and email_confirmed_at is not null and deleted_at is null;end if;
  if not exists(select 1 from auth.users where id=target and email_confirmed_at is not null and deleted_at is null) then raise exception 'Conta confirmada não encontrada.';end if;
  if coalesce(p_args->>'role','') not in ('editor','reviewer') then raise exception 'Perfil inválido.';end if;
  select coalesce(array_agg(value),'{}') into member_codes from jsonb_array_elements_text(p_args->'municipalities');
  if p_args->>'role'='editor' and cardinality(member_codes)=0 then raise exception 'Editor precisa de municípios atribuídos.';end if;
  if exists(select 1 from unnest(member_codes) c where not exists(select 1 from public.municipalities m where m.ibge_code::text=c)) then raise exception 'Município inválido.';end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mapmember:'||target::text,0));
  select * into old_member from private.map_members where user_id=target for update;
  if (p_args->>'expected_updated_at')::timestamptz is distinct from old_member.updated_at then raise exception 'Permissão mudou. Atualize a lista antes de editar.' using errcode='40001';end if;
  insert into private.map_members(user_id,role,municipality_codes,is_active) values(target,p_args->>'role',member_codes,(p_args->>'active')::boolean)
  on conflict(user_id) do update set role=excluded.role,municipality_codes=excluded.municipality_codes,is_active=excluded.is_active,updated_at=now();
  select to_jsonb(m) into response from private.map_members m where user_id=target;
  insert into private.map_permission_events(actor,member_id,before_value,after_value,reason) values(actor,target,to_jsonb(old_member),response,reason);
 else
  doc_id:=p_args->>'id';
  if doc_id is null or length(doc_id) not between 1 and 180 then raise exception 'Identificador inválido.';end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mapdoc:'||doc_id,0));
  select * into doc from private.map_documents where id=doc_id for update;
  if doc.id is not null and not (role_name='admin' or cardinality(scopes)=0 or doc.municipality_code::text=any(scopes)) then
   raise exception 'Município fora da sua permissão.' using errcode='42501';end if;
  if p_action='get' then return to_jsonb(doc);end if;
  if p_action='history' then
   return (select coalesce(jsonb_agg(to_jsonb(q)),'[]') from(select hv.*,coalesce(nullif(p.display_name,''),u.email,hv.actor::text) as actor_label from private.map_versions hv left join public.profiles p on p.id=hv.actor left join auth.users u on u.id=hv.actor where hv.document_id=doc_id order by hv.revision desc limit 51 offset page_offset) q);
  end if;
  if p_action='preview' then
   if doc.id is null then raise exception 'Salve o rascunho antes da prévia.';end if;
   insert into private.map_previews(actor,document_id,revision) values(actor,doc.id,doc.revision) returning id into preview_key;
   return jsonb_build_object('preview_id',preview_key,'document',to_jsonb(doc),'published',(select to_jsonb(p) from public.map_publications p where p.id=doc_id));
  end if;
  if p_action not in ('save','submit','publish','archive','restore') then raise exception 'Operação inválida.';end if;
  expected:=(p_args->>'expected_revision')::integer;
  if expected is null or coalesce(doc.revision,0)<>expected then raise exception 'Este ponto mudou. Atualize a lista e revise a versão mais recente.' using errcode='40001';end if;
  if p_action='save' then
   next_content:=p_args->'content'; code:=next_content->>'municipalityId';
   if jsonb_typeof(next_content)<>'object' or pg_column_size(next_content)>24000 then raise exception 'Conteúdo inválido.';end if;
   if exists(select 1 from jsonb_object_keys(next_content) f where f not in ('id','name','city','lat','lng','cat','description','area','municipalityId','dataSource','checkedAt','address','website','hours','tags','sourceUrl','photoUrl','phone','whatsapp','referenceLocation')) then raise exception 'Campo não permitido; parceiros e ofertas usam o cadastro comercial.';end if;
   select name into city_name from public.municipalities where ibge_code::text=code;
   if city_name is null or not (role_name='admin' or cardinality(scopes)=0 or code=any(scopes)) then raise exception 'Município inválido ou sem permissão.' using errcode='42501';end if;
   if next_content->>'id' is distinct from doc_id or jsonb_typeof(next_content->'name') is distinct from 'string'
    or length(trim(next_content->>'name')) not between 3 and 160
    or jsonb_typeof(next_content->'description') is distinct from 'string' or length(next_content->>'description')>5000
    or jsonb_typeof(next_content->'lat') is distinct from 'number' or jsonb_typeof(next_content->'lng') is distinct from 'number'
    or not ((next_content->>'lat')::numeric between -10.3 and -1 and (next_content->>'lng')::numeric between -48.6 and -41.7)
    or coalesce(next_content->>'cat','') not in ('destination','services','nature','culture','gastronomy','lodging','tours','events','crafts','photography','tourist_transport')
    or coalesce(p_args->>'kind','') not in ('point','attraction','company') then raise exception 'Revise nome, categoria, descrição e coordenadas do Maranhão.';end if;
   if next_content?'referenceLocation' and jsonb_typeof(next_content->'referenceLocation') not in ('boolean','null') then raise exception 'Precisão inválida.';end if;
   for i in select * from jsonb_each(next_content) loop
    if i.key not in ('lat','lng','referenceLocation') and jsonb_typeof(i.value) not in ('string','null') then raise exception 'Tipo de campo inválido.';end if;
    if i.key in ('website','sourceUrl','photoUrl') and i.value<>'null'::jsonb and (length(i.value#>>'{}')>2000 or (i.value#>>'{}') !~ '^https://[^[:space:]/]+[^[:space:]]*$') then raise exception 'Use links HTTPS válidos.';end if;
    if i.key in ('phone','whatsapp') and i.value<>'null'::jsonb and coalesce(i.value#>>'{}','')<>'' and (i.value#>>'{}') !~ '^\+?[0-9 ()-]{8,25}$' then raise exception 'Telefone inválido.';end if;
   end loop;
   next_content:=next_content||jsonb_build_object('city',city_name,'dataSource','MaraPass • conteúdo editorial','checkedAt',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'referenceLocation',coalesce((next_content->>'referenceLocation')::boolean,true));
   insert into private.map_documents(id,municipality_code,content,kind) values(doc_id,code,next_content,p_args->>'kind')
   on conflict(id) do update set content=excluded.content,municipality_code=excluded.municipality_code,kind=excluded.kind,status='draft',revision=map_documents.revision+1,updated_at=now()
   returning * into doc;
  else
   if doc.id is null then raise exception 'Ponto não encontrado.';end if;
   if p_action in ('publish','archive') and role_name not in ('admin','reviewer') then raise exception 'Apenas revisor ou administrador pode publicar ou arquivar.' using errcode='42501';end if;
   if p_action='publish' then
    if doc.status not in ('draft','review') or (role_name='reviewer' and doc.status<>'review') then raise exception 'Envie o rascunho para revisão antes de publicar.';end if;
    if not exists(select 1 from private.map_previews where id=(p_args->>'preview_id')::uuid and map_previews.actor=map_ctx.actor and document_id=doc_id and revision=doc.revision and created_at>now()-interval '30 minutes') then raise exception 'Abra a prévia atual antes de publicar.';end if;
    update private.map_documents set status='published',revision=revision+1,published_revision=revision+1,updated_at=now() where id=doc_id returning * into doc;
    insert into public.map_publications(id,content,is_visible,revision) values(doc.id,doc.content,true,doc.revision)
    on conflict(id) do update set content=excluded.content,is_visible=true,revision=excluded.revision,published_at=now();
   elsif p_action='archive' then
    if doc.status='archived' then raise exception 'Ponto já arquivado.';end if;
    update private.map_documents set status='archived',revision=revision+1,published_revision=revision+1,updated_at=now() where id=doc_id returning * into doc;
    insert into public.map_publications(id,content,is_visible,revision) values(doc.id,null,false,doc.revision)
    on conflict(id) do update set content=null,is_visible=false,revision=excluded.revision,published_at=now();
   elsif p_action='submit' then
    if doc.status<>'draft' then raise exception 'Somente rascunhos podem ir para revisão.';end if;
    update private.map_documents set status='review',revision=revision+1,updated_at=now() where id=doc_id returning * into doc;
   elsif p_action='restore' then
    select * into v from private.map_versions where document_id=doc_id and revision=(p_args->>'restore_revision')::integer;
    if not found then raise exception 'Versão anterior não encontrada.';end if;
    if not (role_name='admin' or cardinality(scopes)=0 or v.content->>'municipalityId'=any(scopes)) then raise exception 'Versão fora da sua permissão.' using errcode='42501';end if;
    update private.map_documents set content=v.content,kind=v.kind,municipality_code=v.content->>'municipalityId',status='draft',revision=revision+1,updated_at=now() where id=doc_id returning * into doc;
   end if;
  end if;
  insert into private.map_versions(document_id,revision,content,kind,status,action,actor,reason) values(doc.id,doc.revision,doc.content,doc.kind,doc.status,p_action,actor,reason);
  response:=to_jsonb(doc);
 end if;
 insert into private.map_requests(actor,request_id,fingerprint,response) values(actor,request_key,fingerprint,response);
 return response;
end $$;
;
