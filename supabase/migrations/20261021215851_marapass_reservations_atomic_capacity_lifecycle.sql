
-- MARAPASS / ETAPA 2C
-- Solicitação idempotente e decisão serializada por slot.
-- Somente backend com service_role (autor é derivado do JWT validado no servidor).

create function public.request_reservation(
  p_slot_id uuid,
  p_user_id uuid,
  p_participants integer,
  p_request_key text
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_old public.reservations%rowtype;
  v_slot public.experience_slots%rowtype;
  v_experience_status text;
  v_establishment_public boolean;
  v_establishment_active boolean;
  v_partner_status text;
  v_reserved bigint;
  v_id uuid;
begin
  if p_user_id is null or p_request_key is null
     or length(p_request_key) not between 16 and 180
     or p_participants is null or p_participants not between 1 and 30 then
    raise exception 'invalid reservation request';
  end if;
  if not exists(select 1 from auth.users u where u.id=p_user_id) then
    raise exception 'requesting user does not exist';
  end if;

  select * into v_old from public.reservations where request_key=p_request_key;
  if found then
    if v_old.user_id<>p_user_id or v_old.slot_id<>p_slot_id
      or v_old.participants<>p_participants then
      raise exception 'reservation idempotency key reused';
    end if;
    return v_old.id;
  end if;

  select * into v_slot from public.experience_slots
    where id=p_slot_id for update;
  if not found or not v_slot.is_open or v_slot.starts_at<=now() then
    raise exception 'slot not available';
  end if;
  select x.status,e.is_public,e.is_active,p.status
    into v_experience_status,v_establishment_public,v_establishment_active,v_partner_status
  from public.experiences x
  join public.establishments e on e.id=x.establishment_id
  join public.partners p on p.id=e.partner_id
  where x.id=v_slot.experience_id;
  if v_experience_status is distinct from 'published'
    or not coalesce(v_establishment_public,false)
    or not coalesce(v_establishment_active,false)
    or v_partner_status is distinct from 'approved' then
    raise exception 'experience not bookable';
  end if;
  select coalesce(sum(r.participants),0) into v_reserved
    from public.reservations r
    where r.slot_id=p_slot_id and r.status='confirmed';
  if v_reserved+p_participants>v_slot.capacity then
    raise exception 'insufficient available capacity';
  end if;

  insert into public.reservations(
    experience_id,slot_id,user_id,scheduled_at,participants,status,request_key)
  values(v_slot.experience_id,v_slot.id,p_user_id,v_slot.starts_at,
    p_participants,'requested',p_request_key)
  returning id into v_id;

  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('reservation',v_id,'requested',p_user_id,
    jsonb_build_object('slot_id',p_slot_id,'participants',p_participants));

  return v_id;
end $$;

create function public.decide_reservation(
  p_reservation_id uuid,
  p_actor_user_id uuid,
  p_decision text
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  r public.reservations%rowtype;
  s public.experience_slots%rowtype;
  v_partner uuid;
  v_authorized boolean;
  v_admin boolean;
  v_reserved bigint;
  v_now timestamptz := now();
begin
  if p_actor_user_id is null or p_decision not in
    ('confirmed','cancelled','completed','no_show') then
    raise exception 'invalid decision request';
  end if;

  select * into r from public.reservations
    where id=p_reservation_id for update;
  if not found then raise exception 'reservation not found'; end if;
  if r.status=p_decision then return r.id; end if;

  select * into s from public.experience_slots
    where id=r.slot_id for update;
  if not found then raise exception 'reservation slot unavailable'; end if;

  select e.partner_id into v_partner from public.experiences x
  join public.establishments e on e.id=x.establishment_id
  where x.id=r.experience_id;
  select exists(select 1 from public.staff_members a
    where a.user_id=p_actor_user_id and a.staff_role='admin' and a.is_active)
    into v_admin;
  select exists(
    select 1 from public.partners p where p.id=v_partner and p.status='approved'
      and (p.owner_user_id=p_actor_user_id
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=p_actor_user_id
          and m.is_active and m.member_role='manager'))
  ) into v_authorized;

  if p_decision='cancelled' then
    if r.status not in ('requested','confirmed') then
      raise exception 'reservation no longer cancellable';
    end if;
    if not(v_admin or v_authorized or r.user_id=p_actor_user_id) then
      raise exception 'cancellation not authorized';
    end if;
    if exists (
      select 1 from public.coupon_instances c
      where c.reservation_id=r.id and c.status='redeemed'
    ) then
      raise exception 'already redeemed coupon blocks cancellation';
    end if;

    update public.reservations set status='cancelled' where id=r.id;
    update public.coupon_instances set status='cancelled'
      where reservation_id=r.id and status='issued';

  elsif p_decision='confirmed' then
    if not(v_admin or v_authorized) then
      raise exception 'confirmation restricted to partner or admin';
    end if;
    if r.status <> 'requested' or not s.is_open or s.starts_at<=v_now then
      raise exception 'reservation no longer confirmable';
    end if;
    select coalesce(sum(participants),0) into v_reserved
      from public.reservations where slot_id=r.slot_id and status='confirmed';
    if v_reserved+r.participants>s.capacity then
      raise exception 'capacity exhausted; confirmation blocked';
    end if;
    update public.reservations set status='confirmed' where id=r.id;

  elsif p_decision in ('completed','no_show') then
    if not(v_admin or v_authorized) then
      raise exception 'completion restricted to partner or admin';
    end if;
    if r.status<>'confirmed' or s.starts_at>v_now then
      raise exception 'reservation cannot be completed before scheduled start';
    end if;
    update public.reservations set status=p_decision where id=r.id;
  end if;

  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values('reservation',r.id,p_decision,p_actor_user_id,
    jsonb_build_object('from',r.status,'slot_id',r.slot_id));
  return r.id;
end $$;

revoke all on function public.request_reservation(uuid,uuid,integer,text)
 from public,anon,authenticated;
revoke all on function public.decide_reservation(uuid,uuid,text)
 from public,anon,authenticated;
grant execute on function public.request_reservation(uuid,uuid,integer,text)
 to service_role;
grant execute on function public.decide_reservation(uuid,uuid,text)
 to service_role;
;
