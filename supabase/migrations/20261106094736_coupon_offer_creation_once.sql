alter table public.offers add column if not exists creation_key uuid;
alter table public.offers add column if not exists created_by_user_id uuid references auth.users(id);
create unique index if not exists offers_creation_request on public.offers(created_by_user_id,creation_key);
create or replace function public.create_partner_offer_once(
 p_establishment_id uuid,p_actor_user_id uuid,p_request_key uuid,p_title text,
 p_discount_type text,p_discount_value numeric,p_terms text,p_starts_at timestamptz,p_ends_at timestamptz,
 p_max_issuances integer,p_per_user_limit integer
) returns uuid language plpgsql security invoker set search_path='' as $f$
declare v_old public.offers%rowtype; v_partner uuid; v_id uuid;
begin
 if p_actor_user_id is null or p_request_key is null or p_title is null
 or length(trim(p_title)) not between 3 and 160 or p_terms is null or length(trim(p_terms)) not between 10 and 3000
 or p_discount_type is null or p_discount_type not in ('percent','fixed') or p_discount_value is null or p_discount_value<=0
 or p_discount_value::text in ('NaN','Infinity','-Infinity')
 or (p_discount_type='percent' and p_discount_value>100)
 or p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at) or p_ends_at<=p_starts_at
 or p_max_issuances is null or p_max_issuances not between 1 and 100000
 or p_per_user_limit is null or p_per_user_limit not between 1 and 20 then raise exception 'invalid offer details'; end if;
 select partner_id into v_partner from public.establishments where id=p_establishment_id and is_active;
 if not found then raise exception 'establishment not found';end if;
 perform private.assert_partner_manager(v_partner,p_actor_user_id);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('offer-create:'||p_actor_user_id::text||':'||p_request_key::text,0));
 select * into v_old from public.offers where created_by_user_id=p_actor_user_id and creation_key=p_request_key;
 if found then
  if v_old.establishment_id is distinct from p_establishment_id or v_old.title is distinct from trim(p_title)
   or v_old.discount_type is distinct from p_discount_type or v_old.discount_value is distinct from p_discount_value
   or v_old.description is distinct from trim(p_terms) or v_old.starts_at is distinct from p_starts_at
   or v_old.ends_at is distinct from p_ends_at or v_old.max_issuances is distinct from p_max_issuances
   or v_old.per_user_limit is distinct from p_per_user_limit then raise exception 'request payload changed';end if;
  return v_old.id;
 end if;
 v_id:=public.create_partner_offer(p_establishment_id,p_actor_user_id,trim(p_title),p_discount_type,p_discount_value,null,p_starts_at,p_ends_at);
 update public.offers set description=trim(p_terms),max_issuances=p_max_issuances,per_user_limit=p_per_user_limit,creation_key=p_request_key,created_by_user_id=p_actor_user_id where id=v_id;
 return v_id;
end $f$;
revoke all on function public.create_partner_offer_once(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,integer,integer) from public,anon,authenticated;
grant execute on function public.create_partner_offer_once(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,integer,integer) to service_role;;
