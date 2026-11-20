
-- MARAPASS / ETAPA 2B
-- Backend service_role apenas. Identidade p_actor deve ser extraída pelo Edge Function
-- de sessão autenticada; nunca confiar em UUID recebido do Flutter.
grant usage on schema private to service_role;
grant select,insert on private.audit_events to service_role;
grant execute on all functions in schema private to service_role;

create function private.assert_admin(p_actor uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if p_actor is null or not exists (
    select 1 from public.staff_members s
    where s.user_id=p_actor and s.is_active and s.staff_role='admin'
  ) then
    raise exception 'administrator not authorized';
  end if;
end $$;

create function private.assert_partner_manager(p_partner uuid,p_actor uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if p_actor is null or not exists (
    select 1 from public.partners p
    where p.id=p_partner and p.status='approved'
    and (p.owner_user_id=p_actor
      or exists (select 1 from public.partner_members m
        where m.partner_id=p.id and m.user_id=p_actor
        and m.is_active and m.member_role='manager'))
  ) then
    raise exception 'partner manager not authorized';
  end if;
end $$;

create function public.review_partner_application(
  p_application_id uuid,
  p_admin_user_id uuid,
  p_decision text,
  p_legal_name text default null,
  p_trade_name text default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare a public.partner_applications%rowtype; v_id uuid;
begin
  perform private.assert_admin(p_admin_user_id);
  if p_decision not in ('approved','rejected') then
    raise exception 'invalid partner decision';
  end if;
  select * into a from public.partner_applications
    where id=p_application_id for update;
  if not found then raise exception 'partner application not found'; end if;
  if a.status<>'pending' then
    if a.status=p_decision then return a.partner_id; end if;
    raise exception 'partner application already reviewed';
  end if;
  if p_decision='approved' then
    insert into public.partners
      (owner_user_id,legal_name,trade_name,contact_email,contact_phone,status)
    values(a.applicant_user_id,
      coalesce(nullif(trim(p_legal_name),''),a.business_name),
      coalesce(nullif(trim(p_trade_name),''),a.business_name),
      a.contact_email,a.contact_phone,'approved')
    returning id into v_id;
  end if;
  update public.partner_applications
    set status=p_decision,partner_id=v_id,reviewed_by_user_id=p_admin_user_id,
        reviewed_at=now()
    where id=a.id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('partner_application',a.id,'reviewed',p_admin_user_id,
    jsonb_build_object('decision',p_decision,'partner_id',v_id));
  return v_id;
end $$;

create function public.assign_partner_member(
  p_partner_id uuid,p_actor_user_id uuid,p_member_user_id uuid,
  p_member_role text,p_active boolean default true
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare v_member uuid;
begin
  if p_member_role not in ('manager','validator') or p_member_user_id is null then
    raise exception 'invalid partner member';
  end if;
  if not exists(select 1 from public.partners p
      where p.id=p_partner_id and p.status='approved'
      and (p.owner_user_id=p_actor_user_id
        or exists(select 1 from public.staff_members s
          where s.user_id=p_actor_user_id and s.is_active and s.staff_role='admin'))
  ) then raise exception 'only owner or administrator can assign members'; end if;
  insert into public.partner_members(partner_id,user_id,member_role,is_active)
  values(p_partner_id,p_member_user_id,p_member_role,p_active)
  on conflict(partner_id,user_id)
  do update set member_role=excluded.member_role,is_active=excluded.is_active
  returning id into v_member;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('partner_member',v_member,'permission_set',p_actor_user_id,
   jsonb_build_object('partner_id',p_partner_id,'member_role',p_member_role,'active',p_active));
  return v_member;
end $$;

create function public.create_partner_establishment(
  p_partner_id uuid,p_actor_user_id uuid,
  p_name text,p_category text,p_city text,p_description text default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare v_id uuid;
begin
  perform private.assert_partner_manager(p_partner_id,p_actor_user_id);
  if length(trim(coalesce(p_name,'')))<2 or length(trim(coalesce(p_city,'')))<2 then
    raise exception 'establishment name and city are required';
  end if;
  insert into public.establishments(partner_id,name,category,city,description,is_public)
  values(p_partner_id,trim(p_name),p_category,trim(p_city),p_description,false)
  returning id into v_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('establishment',v_id,'created_draft',p_actor_user_id,'{}');
  return v_id;
end $$;

create function public.review_establishment_publication(
  p_establishment_id uuid,p_admin_user_id uuid,p_publish boolean
) returns void
language plpgsql security invoker set search_path = ''
as $$
declare v_id uuid;
begin
  perform private.assert_admin(p_admin_user_id);
  update public.establishments e set is_public=p_publish
  from public.partners p
  where e.id=p_establishment_id and e.partner_id=p.id
    and e.is_active and p.status='approved'
  returning e.id into v_id;
  if v_id is null then raise exception 'establishment cannot be published'; end if;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('establishment',v_id,case when p_publish then 'published' else 'unpublished' end,
    p_admin_user_id,'{}');
end $$;

create function public.create_partner_experience(
  p_establishment_id uuid,p_actor_user_id uuid,p_title text,p_category text,
  p_capacity integer default null,p_booking_required boolean default false,
  p_price_from_cents integer default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare v_partner uuid;v_id uuid;
begin
  select partner_id into v_partner from public.establishments
    where id=p_establishment_id and is_active;
  if not found then raise exception 'establishment inactive or missing'; end if;
  perform private.assert_partner_manager(v_partner,p_actor_user_id);
  if length(trim(coalesce(p_title,'')))<3 then
    raise exception 'experience title is required';
  end if;
  insert into public.experiences(
    establishment_id,title,category,capacity,booking_required,price_from_cents,status)
  values(p_establishment_id,trim(p_title),p_category,p_capacity,
    coalesce(p_booking_required,false),p_price_from_cents,'draft')
  returning id into v_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('experience',v_id,'created_draft',p_actor_user_id,'{}');
  return v_id;
end $$;

create function public.set_experience_publication(
  p_experience_id uuid,p_actor_user_id uuid,p_publish boolean
) returns void
language plpgsql security invoker set search_path = ''
as $$
declare v_partner uuid;v_public boolean;v_id uuid;
begin
  select e.partner_id,e.is_public and e.is_active into v_partner,v_public
  from public.experiences x
  join public.establishments e on e.id=x.establishment_id
  where x.id=p_experience_id;
  if not found then raise exception 'experience not found'; end if;
  perform private.assert_partner_manager(v_partner,p_actor_user_id);
  if p_publish and not v_public then
    raise exception 'establishment must be approved before publication';
  end if;
  update public.experiences set status=case when p_publish then 'published' else 'paused' end
  where id=p_experience_id returning id into v_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('experience',v_id,case when p_publish then 'published' else 'paused' end,
    p_actor_user_id,'{}');
end $$;

create function public.create_partner_offer(
  p_establishment_id uuid,p_actor_user_id uuid,
  p_title text,p_discount_type text,p_discount_value numeric,
  p_experience_id uuid default null,
  p_starts_at timestamptz default null,p_ends_at timestamptz default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare v_partner uuid;v_id uuid;
begin
  select partner_id into v_partner from public.establishments
    where id=p_establishment_id and is_active;
  if not found then raise exception 'establishment not found'; end if;
  perform private.assert_partner_manager(v_partner,p_actor_user_id);
  if length(trim(coalesce(p_title,'')))<3 then raise exception 'offer title required'; end if;
  insert into public.offers(
    establishment_id,experience_id,title,discount_type,discount_value,
    starts_at,ends_at,is_published)
  values(p_establishment_id,p_experience_id,trim(p_title),p_discount_type,
    p_discount_value,p_starts_at,p_ends_at,false)
  returning id into v_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('offer',v_id,'created_draft',p_actor_user_id,'{}');
  return v_id;
end $$;

create function public.set_offer_publication(
  p_offer_id uuid,p_actor_user_id uuid,p_publish boolean
) returns void
language plpgsql security invoker set search_path = ''
as $$
declare o record;
begin
  select f.*,e.partner_id,e.is_active,e.is_public,x.status as experience_status
  into o from public.offers f
  join public.establishments e on e.id=f.establishment_id
  left join public.experiences x on x.id=f.experience_id
  where f.id=p_offer_id;
  if not found then raise exception 'offer not found'; end if;
  perform private.assert_partner_manager(o.partner_id,p_actor_user_id);
  if p_publish and (not o.is_active or not o.is_public
    or (o.experience_id is not null and o.experience_status <> 'published')
    or (o.ends_at is not null and o.ends_at <= now())) then
    raise exception 'offer or establishment not eligible for publication';
  end if;
  update public.offers set is_published=p_publish where id=p_offer_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('offer',p_offer_id,case when p_publish then 'published' else 'unpublished' end,
    p_actor_user_id,'{}');
end $$;

create function public.create_experience_slot(
  p_experience_id uuid,p_actor_user_id uuid,p_starts_at timestamptz,
  p_ends_at timestamptz,p_capacity integer
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare v_partner uuid; v_experience_cap integer; v_id uuid;
begin
  select e.partner_id,x.capacity into v_partner,v_experience_cap
    from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    where x.id=p_experience_id and e.is_active and x.status='published';
  if not found then raise exception 'experience unavailable'; end if;
  perform private.assert_partner_manager(v_partner,p_actor_user_id);
  if p_starts_at<=now() or p_ends_at<=p_starts_at or
     p_capacity is null or p_capacity not between 1 and 500 or
     (v_experience_cap is not null and p_capacity>v_experience_cap) then
    raise exception 'invalid slot schedule or capacity';
  end if;
  insert into public.experience_slots(experience_id,starts_at,ends_at,capacity)
  values(p_experience_id,p_starts_at,p_ends_at,p_capacity)
  returning id into v_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('experience_slot',v_id,'created',p_actor_user_id,
    jsonb_build_object('capacity',p_capacity));
  return v_id;
end $$;

create function public.update_experience_slot(
  p_slot_id uuid,p_actor_user_id uuid,p_capacity integer,p_is_open boolean
) returns void
language plpgsql security invoker set search_path = ''
as $$
declare s public.experience_slots%rowtype;v_partner uuid;v_max integer;v_confirmed bigint;
begin
  select * into s from public.experience_slots where id=p_slot_id for update;
  if not found then raise exception 'slot not found'; end if;
  select e.partner_id,x.capacity into v_partner,v_max from public.experiences x
   join public.establishments e on e.id=x.establishment_id where x.id=s.experience_id;
  perform private.assert_partner_manager(v_partner,p_actor_user_id);
  select coalesce(sum(participants),0) into v_confirmed
    from public.reservations where slot_id=s.id and status='confirmed';
  if p_capacity is null or p_capacity not between 1 and 500
     or (v_max is not null and p_capacity>v_max)
     or p_capacity<v_confirmed then
    raise exception 'capacity cannot be less than confirmed participants';
  end if;
  update public.experience_slots set capacity=p_capacity,is_open=p_is_open where id=p_slot_id;
  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('experience_slot',p_slot_id,'updated',p_actor_user_id,
    jsonb_build_object('capacity',p_capacity,'open',p_is_open));
end $$;

-- Service only, never directly callable from an untrusted client.
do $$
declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'review_partner_application','assign_partner_member',
      'create_partner_establishment','review_establishment_publication',
      'create_partner_experience','set_experience_publication',
      'create_partner_offer','set_offer_publication',
      'create_experience_slot','update_experience_slot')
  loop
    execute format('revoke all on function %s from public,anon,authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;
;
