alter table public.establishments add column public_profile jsonb not null default '{}'::jsonb check (jsonb_typeof(public_profile)='object' and octet_length(public_profile::text)<=12000);
alter table public.partner_applications add column business_profile jsonb not null default '{}'::jsonb check (jsonb_typeof(business_profile)='object' and octet_length(business_profile::text)<=12000);
alter table public.offers add column presentation jsonb not null default '{}'::jsonb check (jsonb_typeof(presentation)='object' and octet_length(presentation::text)<=12000);
alter table public.coupon_instances add column conditions_snapshot jsonb not null default '{}'::jsonb;
create table private.custom_offer_requests(actor_user_id uuid not null references auth.users(id),request_key uuid not null,offer_id uuid not null references public.offers(id),payload jsonb not null,primary key(actor_user_id,request_key));
alter table private.custom_offer_requests enable row level security;
revoke all on private.custom_offer_requests from public,anon,authenticated;
grant select,insert on private.custom_offer_requests to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('marapass-media','marapass-media',true,2097152,array['image/jpeg','image/png','image/webp']);

create function public.submit_business_profile(p_actor uuid,p_email text,p_profile jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid;begin
 if p_actor is null or length(p_profile->>'name') not between 2 and 160 or length(p_profile->>'city') not between 2 and 100 or length(p_profile->>'phone') not between 8 and 30 then raise exception 'invalid business profile';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('business-application:'||p_actor::text,0));
 select id into v_id from public.partner_applications where applicant_user_id=p_actor and status='pending' order by created_at desc limit 1;
 if v_id is null then
 insert into public.partner_applications(applicant_user_id,business_name,contact_email,contact_phone,city,state_code,business_profile) values(p_actor,p_profile->>'name',p_email,p_profile->>'phone',p_profile->>'city','MA',p_profile) returning id into v_id;
 else update public.partner_applications set business_name=p_profile->>'name',contact_phone=p_profile->>'phone',city=p_profile->>'city',business_profile=p_profile where id=v_id;end if;
 return v_id;end $$;

create function public.save_business_profile(p_actor uuid,p_partner_id uuid,p_establishment_id uuid,p_profile jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid:=p_establishment_id;begin
 perform private.assert_partner_manager(p_partner_id,p_actor);
 if length(p_profile->>'name') not between 2 and 160 or length(p_profile->>'city') not between 2 and 100 then raise exception 'invalid business profile';end if;
 if v_id is null then v_id:=public.create_partner_establishment(p_partner_id,p_actor,p_profile->>'name',p_profile->>'category',p_profile->>'city',p_profile->>'description');
 elsif not exists(select 1 from public.establishments where id=v_id and partner_id=p_partner_id and is_active) then raise exception 'establishment denied';end if;
 update public.establishments set name=p_profile->>'name',city=p_profile->>'city',category=p_profile->>'category',description=p_profile->>'description',street_address=p_profile->>'address',public_profile=p_profile where id=v_id;
 return v_id;end $$;

create function public.save_custom_offer(p_establishment_id uuid,p_actor_user_id uuid,p_request_key uuid,p_title text,p_discount_type text,p_discount_value numeric,p_terms text,p_starts_at timestamptz,p_ends_at timestamptz,p_max_issuances int,p_per_user_limit int,p_presentation jsonb,p_offer_id uuid default null) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid;v_partner uuid;v_old private.custom_offer_requests%rowtype;v_payload jsonb;v_offer public.offers%rowtype;begin
 select partner_id into v_partner from public.establishments where id=p_establishment_id and is_active;
 perform private.assert_partner_manager(v_partner,p_actor_user_id);
 if p_request_key is null or p_title is null or length(trim(p_title)) not between 3 and 160 or p_terms is null or length(trim(p_terms)) not between 10 and 3000 or p_discount_type is null or p_discount_type not in ('percent','fixed') or p_discount_value is null or p_discount_value<=0 or p_discount_value::text in ('NaN','Infinity','-Infinity') or (p_discount_type='percent' and p_discount_value>100) or p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at) or p_ends_at<=p_starts_at or p_max_issuances not between 1 and 100000 or p_per_user_limit not between 1 and 20 or p_presentation is null or jsonb_typeof(p_presentation)<>'object' then raise exception 'invalid offer details';end if;
 v_payload:=jsonb_build_object('offer',p_offer_id,'est',p_establishment_id,'title',p_title,'type',p_discount_type,'value',p_discount_value,'terms',p_terms,'start',p_starts_at,'end',p_ends_at,'stock',p_max_issuances,'limit',p_per_user_limit,'presentation',p_presentation);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('custom-offer:'||p_actor_user_id::text||':'||p_request_key::text,0));
 select * into v_old from private.custom_offer_requests where actor_user_id=p_actor_user_id and request_key=p_request_key;
 if found then if v_old.payload is distinct from v_payload then raise exception 'request payload changed';end if;return v_old.offer_id;end if;
 if p_offer_id is null then
 v_id:=public.create_partner_offer_once(p_establishment_id,p_actor_user_id,p_request_key,p_title,p_discount_type,p_discount_value,p_terms,p_starts_at,p_ends_at,p_max_issuances,p_per_user_limit);
 else
 select * into v_offer from public.offers where id=p_offer_id and establishment_id=p_establishment_id for update;
 if not found then raise exception 'offer unavailable';end if;
 if v_offer.is_published or exists(select 1 from public.coupon_instances where offer_id=p_offer_id) then raise exception 'offer locked for editing';end if;
 v_id:=p_offer_id;
 update public.offers set title=trim(p_title),description=trim(p_terms),discount_type=p_discount_type,discount_value=p_discount_value,starts_at=p_starts_at,ends_at=p_ends_at,max_issuances=p_max_issuances,per_user_limit=p_per_user_limit where id=v_id;
 end if;
 update public.offers set presentation=p_presentation where id=v_id;
 insert into private.custom_offer_requests values(p_actor_user_id,p_request_key,v_id,v_payload);
 return v_id;end $$;

create function private.capture_coupon_conditions() returns trigger language plpgsql security invoker set search_path='' as $$begin
 select jsonb_build_object('terms',o.description,'presentation',o.presentation,'establishment',e.name,'city',e.city,'address',e.street_address) into new.conditions_snapshot from public.offers o join public.establishments e on e.id=o.establishment_id where o.id=new.offer_id;
 return new;end $$;
create trigger coupon_conditions_on_issue before insert on public.coupon_instances for each row execute function private.capture_coupon_conditions();
create function private.enforce_coupon_minimum() returns trigger language plpgsql security invoker set search_path='' as $$declare v_min int;begin
 select coalesce((conditions_snapshot#>>'{presentation,minimumCents}')::int,0) into v_min from public.coupon_instances where id=new.coupon_instance_id;
 if v_min>0 and (new.transaction_amount_cents is null or new.transaction_amount_cents<v_min) then raise exception 'minimum purchase not reached';end if;
 return new;end $$;
create trigger coupon_minimum_on_redemption before insert on public.coupon_redemptions for each row execute function private.enforce_coupon_minimum();
revoke all on function public.submit_business_profile(uuid,text,jsonb),public.save_business_profile(uuid,uuid,uuid,jsonb),public.save_custom_offer(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,int,int,jsonb,uuid),private.capture_coupon_conditions(),private.enforce_coupon_minimum() from public,anon,authenticated;
grant execute on function public.submit_business_profile(uuid,text,jsonb),public.save_business_profile(uuid,uuid,uuid,jsonb),public.save_custom_offer(uuid,uuid,uuid,text,text,numeric,text,timestamptz,timestamptz,int,int,jsonb,uuid),private.capture_coupon_conditions(),private.enforce_coupon_minimum() to service_role;
create table private.coupon_media_uploads(actor_user_id uuid not null references auth.users(id),created_at timestamptz not null default now());
create index on private.coupon_media_uploads(actor_user_id,created_at);
alter table private.coupon_media_uploads enable row level security;
revoke all on private.coupon_media_uploads from public,anon,authenticated;
grant select,insert on private.coupon_media_uploads to service_role;
create function public.reserve_coupon_media(p_actor uuid) returns boolean language plpgsql security invoker set search_path='' as $$begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('media-upload:'||p_actor::text,0));
 if (select count(*) from private.coupon_media_uploads where actor_user_id=p_actor and created_at>now()-interval '1 day')>=30 then return false;end if;
 insert into private.coupon_media_uploads(actor_user_id) values(p_actor);return true;end $$;
revoke all on function public.reserve_coupon_media(uuid) from public,anon,authenticated;
grant execute on function public.reserve_coupon_media(uuid) to service_role;
;
