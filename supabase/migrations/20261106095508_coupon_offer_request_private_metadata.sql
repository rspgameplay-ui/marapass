create table if not exists private.offer_creation_requests(
 actor_user_id uuid not null references auth.users(id), request_key uuid not null,
 offer_id uuid not null references public.offers(id), payload jsonb not null,
 primary key(actor_user_id,request_key)
);
alter table private.offer_creation_requests enable row level security;
revoke all on private.offer_creation_requests from public,anon,authenticated;
grant select,insert on private.offer_creation_requests to service_role;

create or replace function public.create_partner_offer_once(
 p_establishment_id uuid,p_actor_user_id uuid,p_request_key uuid,p_title text,
 p_discount_type text,p_discount_value numeric,p_terms text,p_starts_at timestamptz,p_ends_at timestamptz,
 p_max_issuances integer,p_per_user_limit integer
) returns uuid language plpgsql security invoker set search_path='' as $f$
declare v_old private.offer_creation_requests%rowtype; v_partner uuid; v_id uuid; v_payload jsonb;
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
 v_payload:=jsonb_build_object('establishment',p_establishment_id,'title',trim(p_title),'terms',trim(p_terms),'type',p_discount_type,'value',p_discount_value,'starts',p_starts_at,'ends',p_ends_at,'max',p_max_issuances,'user_limit',p_per_user_limit);
 select * into v_old from private.offer_creation_requests where actor_user_id=p_actor_user_id and request_key=p_request_key;
 if found then
  if v_old.payload is distinct from v_payload then raise exception 'request payload changed';end if;
  return v_old.offer_id;
 end if;
 v_id:=public.create_partner_offer(p_establishment_id,p_actor_user_id,trim(p_title),p_discount_type,p_discount_value,null,p_starts_at,p_ends_at);
 update public.offers set description=trim(p_terms),max_issuances=p_max_issuances,per_user_limit=p_per_user_limit where id=v_id;
 insert into private.offer_creation_requests(actor_user_id,request_key,offer_id,payload) values(p_actor_user_id,p_request_key,v_id,v_payload);
 return v_id;
end $f$;
revoke all on function public.create_partner_offer_once(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,integer,integer) from public,anon,authenticated;
grant execute on function public.create_partner_offer_once(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,integer,integer) to service_role;
-- Newly introduced public metadata was not used. Refuse cleanup if another caller populated it.
do $guard$ begin if exists(select 1 from public.offers where creation_key is not null or created_by_user_id is not null) then raise exception 'public creation metadata requires review';end if;end $guard$;
drop index if exists public.offers_creation_request;
alter table public.offers drop column creation_key, drop column created_by_user_id;
;
