-- MaraPass. Replay das migrações registradas no Supabase do projeto.
-- Requer os schemas gerenciados e os papéis padrão do Supabase.
-- Gerado de supabase/migrations (histórico idêntico ao banco). Não edite à mão.

-- 20261021214753 marapass_mvp_initial_core

-- MaraPass MVP / Primeira migração
-- Catálogo aberto; mutações financeiras e transacionais apenas por backend autorizado.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.partner_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_user_id uuid not null references auth.users(id),
  business_name text not null check (length(trim(business_name)) between 2 and 160),
  contact_email text not null,
  contact_phone text,
  city text,
  state_code char(2) default 'MA',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index partner_applications_one_pending_per_user
  on public.partner_applications(applicant_user_id) where status='pending';

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id),
  legal_name text not null,
  trade_name text not null,
  contact_email text,
  contact_phone text,
  tax_id text,
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.partner_members (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_role text not null check (member_role in ('manager','validator')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(partner_id,user_id)
);

create table public.establishments (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id),
  name text not null,
  description text,
  category text not null default 'services'
    check (category in ('tours','nature','culture','gastronomy','lodging','events','crafts','photography','tourist_transport','services')),
  city text not null,
  state_code char(2) not null default 'MA',
  street_address text,
  latitude numeric(10,7) check (latitude between -90 and 90),
  longitude numeric(10,7) check (longitude between -180 and 180),
  is_active boolean not null default true,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(partner_id,id)
);

create table public.experiences (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references public.establishments(id),
  title text not null,
  description text,
  category text not null check (category in ('tours','nature','culture','gastronomy','lodging','events','crafts','photography','tourist_transport')),
  price_from_cents integer check (price_from_cents >= 0),
  duration_minutes integer check (duration_minutes > 0),
  capacity integer check (capacity > 0),
  booking_required boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','paused')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(establishment_id,id)
);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references public.establishments(id),
  experience_id uuid,
  title text not null,
  description text,
  discount_type text not null check (discount_type in ('percent','fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  currency char(3) not null default 'BRL',
  starts_at timestamptz,
  ends_at timestamptz,
  max_issuances integer check (max_issuances > 0),
  per_user_limit integer not null default 1 check (per_user_limit between 1 and 20),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(establishment_id,experience_id)
    references public.experiences(establishment_id,id),
  check (discount_type <> 'percent' or discount_value <= 100),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references public.experiences(id),
  user_id uuid not null references auth.users(id),
  scheduled_at timestamptz not null,
  participants integer not null check (participants between 1 and 30),
  status text not null default 'requested'
    check (status in ('requested','confirmed','cancelled','completed','no_show')),
  partner_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.coupon_instances (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers(id),
  beneficiary_user_id uuid not null references auth.users(id),
  reservation_id uuid references public.reservations(id),
  issuance_key text not null unique check (length(issuance_key) between 16 and 180),
  display_code text not null unique,
  offer_title_snapshot text not null,
  discount_type_snapshot text not null check (discount_type_snapshot in ('percent','fixed')),
  discount_value_snapshot numeric(12,2) not null check (discount_value_snapshot > 0),
  status text not null default 'issued' check (status in ('issued','redeemed','cancelled')),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (expires_at > issued_at),
  check ((status='redeemed') = (redeemed_at is not null))
);

create table public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_instance_id uuid not null unique references public.coupon_instances(id),
  partner_id uuid not null,
  establishment_id uuid not null,
  validated_by_user_id uuid not null references auth.users(id),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 180),
  transaction_amount_cents integer check (transaction_amount_cents >= 0),
  validated_at timestamptz not null default now(),
  foreign key(partner_id,establishment_id)
    references public.establishments(partner_id,id)
);

create table public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  establishment_id uuid not null references public.establishments(id),
  reservation_id uuid references public.reservations(id),
  coupon_redemption_id uuid unique references public.coupon_redemptions(id),
  method text not null check (method in ('location','partner_sign','coupon')),
  checked_in_at timestamptz not null default now(),
  check ((method = 'coupon') = (coupon_redemption_id is not null))
);

create table private.audit_events (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id uuid not null,
  operation text not null,
  actor_user_id uuid,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Índices operacionais, relatórios e relações em RLS.
create index ix_partner_members_user on public.partner_members(user_id,partner_id);
create index ix_establishments_partner on public.establishments(partner_id);
create index ix_establishments_city_public on public.establishments(city) where is_public and is_active;
create index ix_experiences_establishment on public.experiences(establishment_id,status);
create index ix_offers_establishment on public.offers(establishment_id,is_published);
create index ix_offers_experience on public.offers(experience_id);
create index ix_reservations_user_date on public.reservations(user_id,scheduled_at desc);
create index ix_reservations_experience_date on public.reservations(experience_id,scheduled_at);
create index ix_coupon_offer_user on public.coupon_instances(offer_id,beneficiary_user_id);
create index ix_coupon_user_status on public.coupon_instances(beneficiary_user_id,status);
create index ix_redemptions_partner_date on public.coupon_redemptions(partner_id,validated_at desc);
create index ix_checkins_user_date on public.checkins(user_id,checked_in_at desc);
create index ix_audit_entity_date on private.audit_events(entity_type,entity_id,created_at desc);

-- Triggers de atualização e histórico; sem código privilegiado exposto.
create function private.touch_updated_at() returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end $$;

create function private.record_coupon_audit() returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if tg_table_name = 'coupon_instances' then
    if tg_op = 'INSERT' then
      insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
      values ('coupon_instance',new.id,'issued',new.beneficiary_user_id,
        jsonb_build_object('offer_id',new.offer_id));
    elsif old.status is distinct from new.status then
      insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
      values ('coupon_instance',new.id,'status_changed',null,
        jsonb_build_object('from',old.status,'to',new.status));
    end if;
  elsif tg_table_name = 'coupon_redemptions' and tg_op='INSERT' then
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values ('coupon_redemption',new.id,'validated',new.validated_by_user_id,
      jsonb_build_object('coupon_instance_id',new.coupon_instance_id,'partner_id',new.partner_id));
  elsif tg_table_name = 'checkins' and tg_op='INSERT' then
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values ('checkin',new.id,'checked_in',new.user_id,
      jsonb_build_object('method',new.method,'coupon_redemption_id',new.coupon_redemption_id));
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles','partner_applications','partners',
    'establishments','experiences','offers','reservations','coupon_instances']
  loop
    execute format('create trigger %I before update on public.%I
      for each row execute function private.touch_updated_at()', 'touch_'||t,t);
  end loop;
end $$;
create trigger audit_coupon_issue after insert on public.coupon_instances
for each row execute function private.record_coupon_audit();
create trigger audit_coupon_status after update of status on public.coupon_instances
for each row execute function private.record_coupon_audit();
create trigger audit_coupon_redemption after insert on public.coupon_redemptions
for each row execute function private.record_coupon_audit();
create trigger audit_coupon_checkin after insert on public.checkins
for each row execute function private.record_coupon_audit();

-- RLS negado por padrão em TODAS as tabelas.
do $$
declare t text;
begin
  foreach t in array array['profiles','partner_applications','partners','partner_members',
    'establishments','experiences','offers','reservations','coupon_instances',
    'coupon_redemptions','checkins']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon,authenticated', t);
  end loop;
end $$;
alter table private.audit_events enable row level security;
revoke all on private.audit_events from public,anon,authenticated;

-- Perfil do próprio usuário, sem campo de role controlável pelo cliente.
grant select,insert,update on public.profiles to authenticated;
create policy profiles_read_own on public.profiles for select to authenticated
using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated
with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Pedido de cadastro pelo app, aprovação somente pelo servidor.
grant select,insert on public.partner_applications to authenticated;
create policy partner_applications_read_own on public.partner_applications
for select to authenticated using (applicant_user_id=(select auth.uid()));
create policy partner_applications_insert_own on public.partner_applications
for insert to authenticated with check (
  applicant_user_id=(select auth.uid()) and status='pending' and review_notes is null
);

-- Equipes: leitura da própria associação; gravação exclusiva de backend.
grant select on public.partner_members,public.partners to authenticated;
create policy member_read_self on public.partner_members for select to authenticated
using (user_id=(select auth.uid()));
create policy partner_read_associated on public.partners for select to authenticated
using (
  owner_user_id=(select auth.uid())
  or exists(select 1 from public.partner_members pm
    where pm.partner_id=partners.id and pm.user_id=(select auth.uid()) and pm.is_active)
);

-- Catálogo de estabelecimentos/experiências/ofertas visível a visitantes.
grant select on public.establishments,public.experiences,public.offers to anon,authenticated;
create policy establishments_public on public.establishments
for select to anon,authenticated using (is_public and is_active);
create policy establishments_partner on public.establishments
for select to authenticated using (
  exists (select 1 from public.partners p where p.id=partner_id
    and (p.owner_user_id=(select auth.uid())
      or exists(select 1 from public.partner_members m
        where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);
create policy experiences_public on public.experiences
for select to anon,authenticated using (
  status='published' and exists(
    select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy experiences_partner on public.experiences
for select to authenticated using (
  exists(select 1 from public.establishments e
    where e.id=establishment_id and exists(
      select 1 from public.partners p where p.id=e.partner_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))))
);
create policy offers_public on public.offers
for select to anon,authenticated using (
  is_published
  and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy offers_partner on public.offers for select to authenticated
using (
  exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and
      (p.owner_user_id=(select auth.uid())
       or exists(select 1 from public.partner_members m
         where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);

-- Transações: leitura somente do beneficiário ou responsável pelo estabelecimento.
-- Nenhum INSERT/UPDATE/DELETE concedido ao aplicativo.
grant select on public.reservations,public.coupon_instances,
  public.coupon_redemptions,public.checkins to authenticated;
create policy reservations_read_user_or_partner on public.reservations
for select to authenticated using (
  user_id=(select auth.uid())
  or exists(
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    join public.partners p on p.id=e.partner_id
    where x.id=experience_id and
      (p.owner_user_id=(select auth.uid())
       or exists(select 1 from public.partner_members m
         where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);
create policy coupons_read_owner_or_partner on public.coupon_instances
for select to authenticated using (
  beneficiary_user_id=(select auth.uid())
  or exists(
    select 1 from public.offers o
    join public.establishments e on e.id=o.establishment_id
    join public.partners p on p.id=e.partner_id
    where o.id=offer_id and
      (p.owner_user_id=(select auth.uid())
       or exists(select 1 from public.partner_members m
         where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);
create policy redemptions_read_user_or_partner on public.coupon_redemptions
for select to authenticated using (
  exists(select 1 from public.coupon_instances ci
    where ci.id=coupon_instance_id and ci.beneficiary_user_id=(select auth.uid()))
  or exists(select 1 from public.partners p where p.id=partner_id and
    (p.owner_user_id=(select auth.uid())
      or exists(select 1 from public.partner_members m
        where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);
create policy checkins_read_user_or_partner on public.checkins
for select to authenticated using (
  user_id=(select auth.uid())
  or exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and
      (p.owner_user_id=(select auth.uid())
       or exists(select 1 from public.partner_members m
         where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active)))
);

-- Operações exclusivamente por backend (Edge Function com chave secreta).
-- Transações e emissão, nunca por UPDATE direto no Flutter.
create function public.issue_coupon(
  p_offer_id uuid, p_user_id uuid, p_idempotency_key text,
  p_reservation_id uuid default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_offer record;
  v_old public.coupon_instances%rowtype;
  v_id uuid;
  v_code text;
  v_expiry timestamptz;
begin
  if p_user_id is null or length(p_idempotency_key) not between 16 and 180 then
    raise exception 'invalid issuance request';
  end if;
  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;
  if found then
    if v_old.offer_id<>p_offer_id or v_old.beneficiary_user_id<>p_user_id
       or v_old.reservation_id is distinct from p_reservation_id then
      raise exception 'idempotency key reused with another request';
    end if;
    return v_old.id;
  end if;
  select o.*, e.partner_id, e.is_active, p.status as partner_status
    into v_offer
    from public.offers o
    join public.establishments e on e.id=o.establishment_id
    join public.partners p on p.id=e.partner_id
    where o.id=p_offer_id
    for update of o;
  if not found or not v_offer.is_published or not v_offer.is_active
      or v_offer.partner_status<>'approved'
      or (v_offer.starts_at is not null and v_offer.starts_at>now())
      or (v_offer.ends_at is not null and v_offer.ends_at<=now()) then
    raise exception 'offer unavailable';
  end if;
  if v_offer.max_issuances is not null
    and (select count(*) from public.coupon_instances where offer_id=p_offer_id)
          >=v_offer.max_issuances then
    raise exception 'offer issuance limit reached';
  end if;
  if (select count(*) from public.coupon_instances
        where offer_id=p_offer_id and beneficiary_user_id=p_user_id)
      >=v_offer.per_user_limit then
    raise exception 'user offer limit reached';
  end if;
  if p_reservation_id is not null and not exists (
    select 1 from public.reservations r
    where r.id=p_reservation_id and r.user_id=p_user_id
      and r.status='confirmed' and r.experience_id=v_offer.experience_id
  ) then
    raise exception 'invalid linked reservation';
  end if;
  v_code := 'MP-' || upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,12));
  v_expiry := least(coalesce(v_offer.ends_at,now()+interval '30 days'),
                    now()+interval '30 days');
  insert into public.coupon_instances(
    offer_id, beneficiary_user_id,reservation_id,issuance_key,display_code,
    offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,expires_at)
  values(p_offer_id,p_user_id,p_reservation_id,p_idempotency_key,v_code,
    v_offer.title,v_offer.discount_type,v_offer.discount_value,v_expiry)
  returning id into v_id;
  return v_id;
end $$;

create function public.redeem_coupon(
  p_coupon_instance_id uuid, p_validator_user_id uuid,
  p_idempotency_key text, p_transaction_amount_cents integer default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_old public.coupon_redemptions%rowtype;
  v_coupon public.coupon_instances%rowtype;
  v_partner_id uuid;
  v_establishment_id uuid;
  v_partner_status text;
  v_establishment_active boolean;
  v_redemption_id uuid;
begin
  if p_validator_user_id is null or length(p_idempotency_key) not between 16 and 180
     or (p_transaction_amount_cents is not null and p_transaction_amount_cents<0) then
    raise exception 'invalid validation request';
  end if;
  select * into v_old from public.coupon_redemptions where idempotency_key=p_idempotency_key;
  if found then
    if v_old.coupon_instance_id<>p_coupon_instance_id
      or v_old.validated_by_user_id<>p_validator_user_id then
      raise exception 'idempotency key reused with different validation';
    end if;
    return v_old.id;
  end if;
  select * into v_coupon from public.coupon_instances
    where id=p_coupon_instance_id for update;
  if not found or v_coupon.status<>'issued' or v_coupon.expires_at<=now() then
    raise exception 'coupon not valid for redemption';
  end if;
  select e.partner_id,e.id,p.status,e.is_active
    into v_partner_id,v_establishment_id,v_partner_status,v_establishment_active
    from public.offers o
    join public.establishments e on e.id=o.establishment_id
    join public.partners p on p.id=e.partner_id
    where o.id=v_coupon.offer_id;
  if v_partner_status<>'approved' or not v_establishment_active or
     not exists(
       select 1 from public.partners p
       where p.id=v_partner_id and (
         p.owner_user_id=p_validator_user_id
         or exists(select 1 from public.partner_members m
           where m.partner_id=p.id and m.user_id=p_validator_user_id
           and m.is_active and m.member_role in ('manager','validator'))
       )
     ) then
    raise exception 'partner or validator unauthorized';
  end if;
  insert into public.coupon_redemptions(
    coupon_instance_id,partner_id,establishment_id,validated_by_user_id,
    idempotency_key,transaction_amount_cents)
  values(p_coupon_instance_id,v_partner_id,v_establishment_id,
    p_validator_user_id,p_idempotency_key,p_transaction_amount_cents)
  returning id into v_redemption_id;

  update public.coupon_instances
    set status='redeemed', redeemed_at=now()
    where id=p_coupon_instance_id;

  insert into public.checkins(
    user_id,establishment_id,reservation_id,coupon_redemption_id,method)
  values(v_coupon.beneficiary_user_id,v_establishment_id,
    v_coupon.reservation_id,v_redemption_id,'coupon');
  return v_redemption_id;
end $$;

-- Segurança das RPCs: só service_role consegue executar.
revoke all on function public.issue_coupon(uuid,uuid,text,uuid) from public,anon,authenticated;
revoke all on function public.redeem_coupon(uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function public.issue_coupon(uuid,uuid,text,uuid) to service_role;
grant execute on function public.redeem_coupon(uuid,uuid,text,integer) to service_role;
revoke all on all functions in schema private from public,anon,authenticated;
;

-- 20261021214821 restrict_rls_auto_enable_execution

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;;

-- 20261021215600 marapass_partner_catalog_reservation_foundation

-- MARAPASS MVP / ETAPA 2A
-- RBAC institucional, sessões de serviços e vínculo inequívoco da reserva com horário.
create table public.staff_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  staff_role text not null check (staff_role in ('admin','operator')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.experience_slots (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references public.experiences(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null check (capacity between 1 and 500),
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (experience_id, starts_at),
  unique (id, experience_id)
);
create index experience_slots_experience_start on public.experience_slots(experience_id, starts_at) where is_open;

alter table public.partner_applications
  add column partner_id uuid unique references public.partners(id),
  add column reviewed_by_user_id uuid references auth.users(id),
  add column reviewed_at timestamptz,
  add constraint partner_review_consistency check (
    (status = 'pending' and partner_id is null and reviewed_by_user_id is null and reviewed_at is null)
    or (status = 'approved' and partner_id is not null and reviewed_by_user_id is not null and reviewed_at is not null)
    or (status = 'rejected' and partner_id is null and reviewed_by_user_id is not null and reviewed_at is not null)
  );

alter table public.reservations
  add column slot_id uuid not null references public.experience_slots(id),
  add column request_key text not null unique,
  add constraint reservation_request_key_valid check (length(request_key) between 16 and 180);
create index reservations_slot_status on public.reservations(slot_id, status);

create function private.reservation_slot_guard() returns trigger
language plpgsql security invoker set search_path = ''
as $$
declare s record;
begin
  select experience_id, starts_at into s from public.experience_slots where id=new.slot_id;
  if not found
    or new.experience_id is distinct from s.experience_id
    or new.scheduled_at is distinct from s.starts_at then
    raise exception 'reservation experience, slot and scheduled time must match';
  end if;
  return new;
end $$;
create trigger guard_reservation_slot
  before insert or update of slot_id,experience_id,scheduled_at
  on public.reservations for each row execute function private.reservation_slot_guard();

create trigger touch_experience_slots
  before update on public.experience_slots
  for each row execute function private.touch_updated_at();

-- Secure exposure: public listable schedules; employee registry only self-readable.
alter table public.staff_members enable row level security;
alter table public.experience_slots enable row level security;
revoke all on public.staff_members, public.experience_slots from public, anon, authenticated;
grant select on public.staff_members to authenticated;
grant select on public.experience_slots to anon, authenticated;
grant select, insert, update, delete on public.staff_members, public.experience_slots to service_role;

create policy staff_read_self on public.staff_members
for select to authenticated using (user_id=(select auth.uid()));

create policy slots_public on public.experience_slots
for select to anon,authenticated
using (is_open and starts_at>now() and exists (
  select 1 from public.experiences x
  join public.establishments e on e.id=x.establishment_id
  join public.partners p on p.id=e.partner_id
  where x.id=experience_id and x.status='published'
    and e.is_public and e.is_active and p.status='approved'
));

create policy slots_partner on public.experience_slots
for select to authenticated using (
  exists(select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    join public.partners p on p.id=e.partner_id
    where x.id=experience_id and
      (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid())
          and m.is_active)))
);

-- Don't expose administrative functions by default.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
;

-- 20261021215748 marapass_partner_catalog_operational_rpcs

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

-- 20261021215851 marapass_reservations_atomic_capacity_lifecycle

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

-- 20261021220014 marapass_catalog_visibility_and_fk_indexes

-- MARAPASS / ETAPA 2D -- índices para FKs e publicação condicionada.
create index if not exists checkins_establishment_fk_idx on public.checkins(establishment_id);
create index if not exists checkins_reservation_fk_idx on public.checkins(reservation_id);
create index if not exists coupon_instances_reservation_fk_idx on public.coupon_instances(reservation_id);
create index if not exists redemptions_partner_establishment_fk_idx
  on public.coupon_redemptions(partner_id,establishment_id);
create index if not exists redemptions_validator_fk_idx
  on public.coupon_redemptions(validated_by_user_id);
create index if not exists offers_establishment_experience_fk_idx
  on public.offers(establishment_id,experience_id);
create index if not exists partner_applications_reviewer_fk_idx
  on public.partner_applications(reviewed_by_user_id);
create index if not exists partners_owner_fk_idx on public.partners(owner_user_id);

drop policy if exists establishments_public on public.establishments;
create policy establishments_public on public.establishments for select
to anon,authenticated using (
  is_public and is_active
  and exists(select 1 from public.partners p
    where p.id=partner_id and p.status='approved')
);

drop policy if exists experiences_public on public.experiences;
create policy experiences_public on public.experiences for select
to anon,authenticated using (
  status='published'
  and exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and e.is_active and e.is_public
      and p.status='approved')
);

drop policy if exists offers_public on public.offers;
create policy offers_public on public.offers for select
to anon,authenticated using (
  is_published
  and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and e.is_active and e.is_public
      and p.status='approved')
);
;

-- 20261021220159 fix_reissued_coupon_after_reservation_cancel

create or replace function public.issue_coupon(
  p_offer_id uuid, p_user_id uuid, p_idempotency_key text,
  p_reservation_id uuid default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_offer record;
  v_old public.coupon_instances%rowtype;
  v_id uuid;
  v_code text;
  v_expiry timestamptz;
begin
  if p_user_id is null or length(p_idempotency_key) not between 16 and 180 then
    raise exception 'invalid issuance request';
  end if;
  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;
  if found then
    if v_old.offer_id<>p_offer_id or v_old.beneficiary_user_id<>p_user_id
       or v_old.reservation_id is distinct from p_reservation_id then
      raise exception 'idempotency key reused with another request';
    end if;
    return v_old.id;
  end if;
  select o.*,e.partner_id,e.is_active,p.status as partner_status into v_offer
    from public.offers o
    join public.establishments e on e.id=o.establishment_id
    join public.partners p on p.id=e.partner_id
    where o.id=p_offer_id
    for update of o;
  if not found or not v_offer.is_published or not v_offer.is_active
      or v_offer.partner_status<>'approved'
      or (v_offer.starts_at is not null and v_offer.starts_at>now())
      or (v_offer.ends_at is not null and v_offer.ends_at<=now()) then
    raise exception 'offer unavailable';
  end if;
  if v_offer.max_issuances is not null
    and (select count(*) from public.coupon_instances where offer_id=p_offer_id)
          >= v_offer.max_issuances then
    raise exception 'offer issuance limit reached';
  end if;
  -- Cancelled issuances remain in audit history, but do not block the
  -- customer's new issuance when a linked reservation was cancelled.
  if (select count(*) from public.coupon_instances
        where offer_id=p_offer_id and beneficiary_user_id=p_user_id
          and status<>'cancelled') >= v_offer.per_user_limit then
    raise exception 'user offer limit reached';
  end if;
  if p_reservation_id is not null and not exists (
    select 1 from public.reservations r
    where r.id=p_reservation_id and r.user_id=p_user_id
      and r.status='confirmed' and r.experience_id=v_offer.experience_id
  ) then
    raise exception 'invalid linked reservation';
  end if;
  v_code := 'MP-' || upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,12));
  v_expiry := least(coalesce(v_offer.ends_at,now()+interval '30 days'),
                    now()+interval '30 days');
  insert into public.coupon_instances(
    offer_id,beneficiary_user_id,reservation_id,issuance_key,display_code,
    offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,expires_at)
  values(p_offer_id,p_user_id,p_reservation_id,p_idempotency_key,v_code,
    v_offer.title,v_offer.discount_type,v_offer.discount_value,v_expiry)
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.issue_coupon(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.issue_coupon(uuid,uuid,text,uuid) to service_role;
;

-- 20261021220429 marapass_guest_catalog_and_partner_privacy

-- MARAPASS / ETAPA 2E
-- Read-only guest experience, with internal partner records inaccessible to anon.
drop policy if exists establishments_public on public.establishments;
drop policy if exists establishments_partner on public.establishments;
create policy establishments_anon on public.establishments
for select to anon using (is_active and is_public);
create policy establishments_authenticated on public.establishments
for select to authenticated using (
  (is_active and is_public)
  or exists(
    select 1 from public.partners p where p.id=partner_id
    and (p.owner_user_id=(select auth.uid())
      or exists(select 1 from public.partner_members m
        where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists experiences_public on public.experiences;
drop policy if exists experiences_partner on public.experiences;
create policy experiences_anon on public.experiences
for select to anon using (
  status='published' and exists (
    select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy experiences_authenticated on public.experiences
for select to authenticated using (
  (status='published' and exists (
    select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public))
  or exists (
    select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists offers_public on public.offers;
drop policy if exists offers_partner on public.offers;
create policy offers_anon on public.offers
for select to anon using (
  is_published and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy offers_authenticated on public.offers
for select to authenticated using (
  (is_published and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public))
  or exists(
    select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists slots_public on public.experience_slots;
drop policy if exists slots_partner on public.experience_slots;
create policy slots_anon on public.experience_slots
for select to anon using (
  is_open and starts_at>now() and exists(
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    where x.id=experience_id and x.status='published'
      and e.is_active and e.is_public)
);
create policy slots_authenticated on public.experience_slots
for select to authenticated using (
  (is_open and starts_at>now() and exists(
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    where x.id=experience_id and x.status='published'
      and e.is_active and e.is_public))
  or exists (
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    join public.partners p on p.id=e.partner_id
    where x.id=experience_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

create function private.hide_catalog_for_suspended_partner() returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if old.status is distinct from new.status and new.status <> 'approved' then
    update public.establishments set is_public=false
      where partner_id=new.id and is_public;
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values('partner',new.id,'catalog_unpublished_by_status',null,
      jsonb_build_object('status',new.status));
  end if;
  return new;
end $$;
create trigger hide_partner_catalog_on_suspension
after update of status on public.partners
for each row execute function private.hide_catalog_for_suspended_partner();
grant execute on function private.hide_catalog_for_suspended_partner() to service_role;
revoke execute on function private.hide_catalog_for_suspended_partner() from public,anon,authenticated;
;

-- 20261022143040 marapass_auth_profile_and_manual_admin_bootstrap

-- MaraPass 2026 / Auth onboarding and controlled first administrator bootstrap.
-- Authentication itself is managed by Supabase Auth.
-- No JWT role is inferred from user-editable metadata.

create function private.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id,display_name)
  values (new.id, '')
  on conflict(id) do nothing;
  return new;
end;
$$;

revoke all on function private.create_profile_for_auth_user() from public,anon,authenticated,service_role;

create trigger marapass_auth_profile_created
after insert on auth.users
for each row
execute function private.create_profile_for_auth_user();

create function private.audit_staff_role()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid;
  v_new jsonb;
  v_old jsonb;
begin
  v_user := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  v_old := case when tg_op = 'INSERT' then null else
    jsonb_build_object('role',old.staff_role,'active',old.is_active) end;
  v_new := case when tg_op = 'DELETE' then null else
    jsonb_build_object('role',new.staff_role,'active',new.is_active) end;
  if tg_op <> 'UPDATE' or v_new is distinct from v_old then
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values (
      'staff_member',v_user,lower(tg_op),null,
      jsonb_build_object('before',v_old,'after',v_new)
    );
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

revoke all on function private.audit_staff_role() from public,anon,authenticated;
grant execute on function private.audit_staff_role() to service_role;

create trigger marapass_staff_role_audit
after insert or update or delete on public.staff_members
for each row execute function private.audit_staff_role();

-- Deliberately NOT exposed through the Data API. Only run manually from
-- privileged SQL Editor after the designated person's email is verified.
create function private.grant_first_administrator(p_verified_email text)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if p_verified_email is null
    or length(trim(p_verified_email))<6 then
    raise exception 'provide verified account email';
  end if;

  -- Serializes one-time bootstrap even if two operators submit concurrently.
  perform pg_catalog.pg_advisory_xact_lock(82354112, 10222026);

  if exists(select 1 from public.staff_members where staff_role='admin') then
    raise exception 'initial administrator is already assigned';
  end if;

  select u.id into v_user
    from auth.users u
    where lower(u.email)=lower(trim(p_verified_email))
      and u.email_confirmed_at is not null
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until<now());
  if v_user is null then
    raise exception 'confirmed, active Auth account not found';
  end if;

  insert into public.profiles(id,display_name) values(v_user,'')
  on conflict(id) do nothing;

  insert into public.staff_members(user_id,staff_role,is_active)
  values(v_user,'admin',true)
  on conflict(user_id) do update set staff_role='admin',is_active=true;

  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values(
    'staff_member',v_user,'first_admin_bootstrap',null,
    jsonb_build_object('method','confirmed_email_with_privileged_sql_editor')
  );

  return v_user;
end $$;

revoke all on function private.grant_first_administrator(text)
from public,anon,authenticated,service_role;

-- Client-safe role discovery, NEVER privileged role assignment.
create function public.my_access_context()
returns table(
  user_id uuid,
  staff_role text,
  admin_role boolean,
  partner_owner boolean,
  partner_manager boolean,
  partner_validator boolean,
  mfa_verified boolean,
  admin_console_ready boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
select
  (select auth.uid()) as user_id,
  s.staff_role,
  (s.staff_role='admin' and s.is_active) as admin_role,
  exists(select 1 from public.partners p
    where p.owner_user_id=(select auth.uid()) and p.status='approved') as partner_owner,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='manager') as partner_manager,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='validator') as partner_validator,
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as mfa_verified,
  coalesce(s.staff_role='admin' and s.is_active,false)
    and coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as admin_console_ready
from (select 1) base
left join public.staff_members s
  on s.user_id=(select auth.uid())
where (select auth.uid()) is not null;
$$;

revoke all on function public.my_access_context()
from public,anon,authenticated;
grant execute on function public.my_access_context() to authenticated;

comment on function private.grant_first_administrator(text)
is 'One-time manual bootstrap; verified email required. Not executable via API, service_role, anon, or authenticated.';

comment on function public.my_access_context()
is 'Reads the current session access status without assigning roles. admin_console_ready requires MFA aal2, and privileged backend operations must verify MFA independently.';
;

-- 20261023005108 marapass_admin_dashboard_readonly_aal2_rls

-- MaraPass: painel administrativo de consulta com RLS exigindo MFA aal2.
-- Na fase inicial, nenhuma operação de escrita é exposta ao navegador.
create policy admin_read_applications_aal2 on public.partner_applications for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_partners_aal2 on public.partners for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_establishments_aal2 on public.establishments for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_experiences_aal2 on public.experiences for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_offers_aal2 on public.offers for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_reservations_aal2 on public.reservations for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_coupon_instances_aal2 on public.coupon_instances for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);

create function public.marapass_admin_overview()
returns jsonb
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or coalesce((select auth.jwt()->>'aal'),'aal1')<>'aal2'
    or not exists (select 1 from public.staff_members s
      where s.user_id=(select auth.uid()) and s.is_active and s.staff_role='admin') then
     raise exception 'admin mfa verification required' using errcode='42501';
  end if;
  return jsonb_build_object(
     'applications_pending',(select count(*) from public.partner_applications where status='pending'),
     'partners_approved',(select count(*) from public.partners where status='approved'),
     'establishments_public',(select count(*) from public.establishments where is_public and is_active),
     'experiences_published',(select count(*) from public.experiences where status='published'),
     'offers_published',(select count(*) from public.offers where is_published),
     'reservations_requested',(select count(*) from public.reservations where status='requested'),
     'reservations_confirmed',(select count(*) from public.reservations where status='confirmed'),
     'coupons_issued',(select count(*) from public.coupon_instances where status='issued')
  );
end $$;

revoke all on function public.marapass_admin_overview() from public,anon,authenticated;
grant execute on function public.marapass_admin_overview() to authenticated;
comment on function public.marapass_admin_overview() is
  'Leitura restrita a staff.admin ativo com JWT aal2; sem direitos de escrita.';
;

-- 20261027175726 marapass_admin_direct_company_registration

ALTER TABLE public.partners ALTER COLUMN owner_user_id DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS partners_tax_id_unique ON public.partners(tax_id) WHERE tax_id IS NOT NULL;
ALTER TABLE public.partners ADD CONSTRAINT partners_tax_id_digits CHECK(tax_id IS NULL OR tax_id ~ '^[0-9]{14}$');
CREATE TABLE public.partner_direct_registrations(
 partner_id uuid PRIMARY KEY REFERENCES public.partners(id) ON DELETE CASCADE,
 establishment_id uuid NOT NULL UNIQUE REFERENCES public.establishments(id),
 registered_by_user_id uuid NOT NULL REFERENCES auth.users(id),
 registration_source text NOT NULL DEFAULT 'admin' CHECK(registration_source='admin'),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.partner_direct_registrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.partner_direct_registrations FROM public, anon, authenticated;
GRANT SELECT ON public.partner_direct_registrations TO authenticated;
CREATE POLICY partner_direct_registrations_admin_aal2 ON public.partner_direct_registrations FOR SELECT TO authenticated
USING ((auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid()) AND s.is_active AND s.staff_role='admin'));
CREATE FUNCTION public.admin_register_direct_company(
 p_admin_user_id uuid,p_legal_name text,p_trade_name text,p_contact_email text,
 p_city text,p_category text,p_contact_phone text DEFAULT NULL,p_tax_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_partner uuid;v_establishment uuid;v_tax_id text;v_email text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_legal_name IS NULL OR length(trim(p_legal_name)) NOT BETWEEN 2 AND 160
    OR p_trade_name IS NULL OR length(trim(p_trade_name)) NOT BETWEEN 2 AND 160
    OR p_city IS NULL OR length(trim(p_city)) NOT BETWEEN 2 AND 120 THEN
  RAISE EXCEPTION 'invalid company or city name';
 END IF;
 v_email:=lower(trim(coalesce(p_contact_email,'')));
 IF length(v_email) NOT BETWEEN 5 AND 254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  THEN RAISE EXCEPTION 'invalid contact email';
 END IF;
 IF p_category IS NULL OR p_category NOT IN (
 'tours','nature','culture','gastronomy','lodging','events','crafts','photography','tourist_transport','services')
  THEN RAISE EXCEPTION 'invalid category';END IF;
 IF p_contact_phone IS NOT NULL AND length(trim(p_contact_phone))>32 THEN
  RAISE EXCEPTION 'invalid phone';END IF;
 v_tax_id:=NULLIF(regexp_replace(coalesce(p_tax_id,''),'[^0-9]','','g'),'');
 IF v_tax_id IS NOT NULL AND length(v_tax_id)<>14 THEN RAISE EXCEPTION 'invalid CNPJ';END IF;
 INSERT INTO public.partners(owner_user_id,legal_name,trade_name,contact_email,contact_phone,tax_id,status)
 VALUES(NULL,trim(p_legal_name),trim(p_trade_name),v_email,NULLIF(trim(coalesce(p_contact_phone,'')),''),v_tax_id,'pending')
 RETURNING id INTO v_partner;
 INSERT INTO public.establishments(partner_id,name,category,city,state_code,is_active,is_public)
 VALUES(v_partner,trim(p_trade_name),p_category,trim(p_city),'MA',true,false)
 RETURNING id INTO v_establishment;
 INSERT INTO public.partner_direct_registrations(partner_id,establishment_id,registered_by_user_id)
 VALUES(v_partner,v_establishment,p_admin_user_id);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner',v_partner,'admin_direct_registration',p_admin_user_id,
 jsonb_build_object('establishment_id',v_establishment,'status','pending','owner_linked',false,'source','admin'));
 RETURN jsonb_build_object('partner_id',v_partner,'establishment_id',v_establishment,
 'partner_status','pending','establishment_public',false,'owner_linked',false);
END $$;
REVOKE ALL ON FUNCTION public.admin_register_direct_company(uuid,text,text,text,text,text,text,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_register_direct_company(uuid,text,text,text,text,text,text,text) TO service_role;
CREATE INDEX partner_direct_registrations_actor ON public.partner_direct_registrations(registered_by_user_id);
;

-- 20261027181622 marapass_admin_company_idempotent_registration

-- MaraPass: retry-safe administrative registration; the legacy function is retained
-- as private service-only operational primitive.
ALTER TABLE public.partner_direct_registrations ADD COLUMN IF NOT EXISTS request_key uuid;
CREATE UNIQUE INDEX IF NOT EXISTS partner_direct_registration_request_key_unique
 ON public.partner_direct_registrations(registered_by_user_id,request_key)
 WHERE request_key IS NOT NULL;

CREATE FUNCTION public.admin_register_direct_company_once(
 p_admin_user_id uuid,
 p_legal_name text,
 p_trade_name text,
 p_contact_email text,
 p_city text,
 p_category text,
 p_contact_phone text,
 p_tax_id text,
 p_request_key uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_existing record;
 v_registration jsonb;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_request_key IS NULL THEN RAISE EXCEPTION 'idempotency key required'; END IF;
 -- Serialize parallel retries of the same user intent.
 PERFORM pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(p_admin_user_id::text || ':' || p_request_key::text, 0)
 );
 SELECT d.partner_id,d.establishment_id,p.status,p.owner_user_id,e.is_public
   INTO v_existing
   FROM public.partner_direct_registrations d
   JOIN public.partners p ON p.id=d.partner_id
   JOIN public.establishments e ON e.id=d.establishment_id
   WHERE d.registered_by_user_id=p_admin_user_id AND d.request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object(
     'partner_id',v_existing.partner_id,
     'establishment_id',v_existing.establishment_id,
     'partner_status',v_existing.status,
     'establishment_public',v_existing.is_public,
     'owner_linked',v_existing.owner_user_id IS NOT NULL,
     'already_registered',true);
 END IF;

 v_registration:=public.admin_register_direct_company(
   p_admin_user_id,p_legal_name,p_trade_name,p_contact_email,p_city,
   p_category,p_contact_phone,p_tax_id);
 UPDATE public.partner_direct_registrations
 SET request_key=p_request_key
 WHERE partner_id=(v_registration->>'partner_id')::uuid
   AND registered_by_user_id=p_admin_user_id;
 RETURN v_registration || jsonb_build_object('already_registered',false);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_register_direct_company_once(uuid,text,text,text,text,text,text,text,uuid)
 FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_register_direct_company_once(uuid,text,text,text,text,text,text,text,uuid)
 TO service_role;
;

-- 20261027185402 marapass_partner_verified_invitations_lifecycle

-- MaraPass / convites de parceiros: sem acesso automático pela mera indicação de e-mail.
CREATE TABLE public.partner_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid NOT NULL UNIQUE REFERENCES public.partners(id) ON DELETE CASCADE,
  email text NOT NULL,
  status text NOT NULL DEFAULT 'prepared'
    CHECK(status IN ('prepared','sent','failed','accepted','revoked')),
  requested_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  send_requested_at timestamptz,
  sent_at timestamptz,
  expires_at timestamptz,
  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id),
  send_count integer NOT NULL DEFAULT 0 CHECK(send_count BETWEEN 0 AND 10000),
  dispatch_method text CHECK(dispatch_method IS NULL OR dispatch_method IN ('invite','magiclink')),
  CONSTRAINT partner_invitation_accepted_consistency CHECK (
    (status='accepted' AND accepted_at IS NOT NULL AND accepted_by IS NOT NULL)
    OR (status <> 'accepted' AND accepted_at IS NULL AND accepted_by IS NULL)
  )
);
CREATE INDEX partner_invitation_email_state_idx ON public.partner_invitations(lower(email),status);
ALTER TABLE public.partner_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.partner_invitations FROM public,anon,authenticated;
GRANT SELECT ON public.partner_invitations TO authenticated;
CREATE POLICY partner_invitations_admin_read ON public.partner_invitations FOR SELECT
TO authenticated USING (
  (select auth.jwt()->>'aal')='aal2'
  AND EXISTS(SELECT 1 FROM public.staff_members s
    WHERE s.user_id=(select auth.uid()) AND s.is_active AND s.staff_role='admin')
);
CREATE FUNCTION public.admin_prepare_partner_invitation(p_admin_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE p public.partners%rowtype;i public.partner_invitations%rowtype; v_mail text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR p.status <> 'pending' OR p.owner_user_id IS NOT NULL THEN
   RAISE EXCEPTION 'partner not eligible for invitation';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.partner_direct_registrations d WHERE d.partner_id=p.id) THEN
   RAISE EXCEPTION 'only directly registered companies can be invited through this flow';
 END IF;
 v_mail:=lower(trim(coalesce(p.contact_email,'')));
 IF v_mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
  RAISE EXCEPTION 'invalid invite contact email';
 END IF;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p.id FOR UPDATE;
 IF FOUND THEN
   IF i.status='accepted' OR i.status='revoked' THEN
     RAISE EXCEPTION 'invitation already accepted or revoked';
   END IF;
   IF i.send_requested_at IS NOT NULL AND i.send_requested_at > now()-interval '60 seconds' THEN
     RAISE EXCEPTION 'invitation rate limited';
   END IF;
   IF i.email<>v_mail THEN
     RAISE EXCEPTION 'contact email changed after invitation; require manual review';
   END IF;
   UPDATE public.partner_invitations SET status='prepared',updated_at=now(),
     send_requested_at=now(), expires_at=now()+interval '7 days',
     send_count=send_count+1
     WHERE id=i.id RETURNING * INTO i;
 ELSE
   INSERT INTO public.partner_invitations
     (partner_id,email,requested_by,send_requested_at,expires_at,send_count)
   VALUES(p.id,v_mail,p_admin_user_id,now(),now()+interval '7 days',1)
   RETURNING * INTO i;
 END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,'dispatch_prepared',p_admin_user_id,
  jsonb_build_object('partner_id',p.id,'send_count',i.send_count));
 RETURN jsonb_build_object('invitation_id',i.id,'partner_id',p.id,
   'email',i.email,'trade_name',p.trade_name);
END $$;

CREATE FUNCTION public.admin_record_partner_invitation_dispatch(
 p_admin_user_id uuid,p_invitation_id uuid,p_success boolean,p_method text
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE i public.partner_invitations%rowtype;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO i FROM public.partner_invitations WHERE id=p_invitation_id FOR UPDATE;
 IF NOT FOUND OR i.status<>'prepared' THEN RAISE EXCEPTION 'invitation not prepared'; END IF;
 IF p_success AND p_method NOT IN ('invite','magiclink') THEN
   RAISE EXCEPTION 'invalid dispatch method';
 END IF;
 UPDATE public.partner_invitations SET status=CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
   sent_at=CASE WHEN p_success THEN now() ELSE sent_at END,
   dispatch_method=CASE WHEN p_success THEN p_method ELSE NULL END,
   updated_at=now()
 WHERE id=i.id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,CASE WHEN p_success THEN 'sent' ELSE 'send_failed' END,
   p_admin_user_id,jsonb_build_object('partner_id',i.partner_id,'method',p_method));
 RETURN jsonb_build_object('status',CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
  'partner_id',i.partner_id);
END $$;

-- Service RPC called only after Auth has verified the caller's signed JWT.
-- Identity EMAIL is read from auth.users, never supplied as form text.
CREATE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text;
BEGIN
 SELECT lower(email) INTO v_mail FROM auth.users WHERE id=p_user_id
 AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL
 AND (banned_until IS NULL OR banned_until<now());
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 RETURN coalesce((
 SELECT jsonb_agg(jsonb_build_object('partner_id',p.id,'trade_name',p.trade_name,
   'status',i.status,'expires_at',i.expires_at,'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;

CREATE FUNCTION public.partner_accept_invitation(p_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text; i public.partner_invitations%rowtype;p public.partners%rowtype;
BEGIN
 SELECT lower(email) INTO v_mail FROM auth.users WHERE id=p_user_id
 AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL
 AND (banned_until IS NULL OR banned_until<now());
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'partner not found';END IF;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR lower(i.email)<>v_mail THEN
   RAISE EXCEPTION 'no matching invitation for verified email';
 END IF;
 IF i.status='accepted' AND i.accepted_by=p_user_id AND p.owner_user_id=p_user_id THEN
   RETURN jsonb_build_object('partner_id',p.id,'status','accepted','already_accepted',true);
 END IF;
 IF i.status<>'sent' OR i.expires_at<=now() OR p.owner_user_id IS NOT NULL OR p.status<>'pending' THEN
   RAISE EXCEPTION 'invitation unavailable or expired';
 END IF;
 UPDATE public.partners SET owner_user_id=p_user_id,updated_at=now() WHERE id=p.id;
 UPDATE public.partner_invitations SET status='accepted',accepted_at=now(),
 accepted_by=p_user_id,updated_at=now() WHERE id=i.id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,'accepted_by_verified_user',p_user_id,
 jsonb_build_object('partner_id',p.id,'owner_linked',true));
 RETURN jsonb_build_object('partner_id',p.id,'status','accepted',
   'partner_status','pending','already_accepted',false);
END $$;

CREATE FUNCTION public.admin_activate_invited_partner(p_admin_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE p public.partners%rowtype;i public.partner_invitations%rowtype;v_verified boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR p.id IS NULL OR i.status<>'accepted' OR p.owner_user_id IS NULL
   OR i.accepted_by IS DISTINCT FROM p.owner_user_id THEN
  RAISE EXCEPTION 'partner owner has not accepted verified invitation';
 END IF;
 SELECT EXISTS(SELECT 1 FROM auth.users u
   WHERE u.id=p.owner_user_id AND lower(u.email)=lower(i.email)
     AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
     AND (u.banned_until IS NULL OR u.banned_until<now())) INTO v_verified;
 IF NOT v_verified THEN RAISE EXCEPTION 'partner owner email unverified';END IF;
 IF p.status NOT IN ('pending','approved') THEN
   RAISE EXCEPTION 'partner cannot be activated';
 END IF;
 IF p.status='pending' THEN
   UPDATE public.partners SET status='approved',updated_at=now() WHERE id=p.id;
   INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
   VALUES('partner',p.id,'activated_after_invitation',p_admin_user_id,
      jsonb_build_object('owner_user_id',p.owner_user_id,'invitation_id',i.id));
 END IF;
 RETURN jsonb_build_object('partner_id',p.id,'status','approved','owner_verified',true);
END $$;

REVOKE ALL ON FUNCTION public.admin_prepare_partner_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_record_partner_invitation_dispatch(uuid,uuid,boolean,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_accept_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_prepare_partner_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_record_partner_invitation_dispatch(uuid,uuid,boolean,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_accept_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) TO service_role;
;

-- 20261027185901 marapass_partner_invitation_live_activation_status

CREATE OR REPLACE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text;
BEGIN
 SELECT lower(email) INTO v_mail FROM auth.users WHERE id=p_user_id
 AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL
 AND (banned_until IS NULL OR banned_until<now());
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 RETURN coalesce((
 SELECT jsonb_agg(jsonb_build_object('partner_id',p.id,'trade_name',p.trade_name,
   'status',i.status,'partner_status',p.status,'expires_at',i.expires_at,
   'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
;

-- 20261027190155 marapass_private_verified_auth_email_service_bridge

CREATE FUNCTION private.verified_auth_email(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT lower(u.email) FROM auth.users u WHERE u.id=p_user_id
 AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
 AND (u.banned_until IS NULL OR u.banned_until < now()) LIMIT 1
$$;
REVOKE ALL ON FUNCTION private.verified_auth_email(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.verified_auth_email(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text;
BEGIN
 v_mail:=private.verified_auth_email(p_user_id);
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 RETURN coalesce((
 SELECT jsonb_agg(jsonb_build_object('partner_id',p.id,'trade_name',p.trade_name,
   'status',i.status,'partner_status',p.status,'expires_at',i.expires_at,
   'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.partner_accept_invitation(p_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text; i public.partner_invitations%rowtype;p public.partners%rowtype;
BEGIN
 v_mail:=private.verified_auth_email(p_user_id);
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'partner not found';END IF;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR lower(i.email)<>v_mail THEN
   RAISE EXCEPTION 'no matching invitation for verified email';
 END IF;
 IF i.status='accepted' AND i.accepted_by=p_user_id AND p.owner_user_id=p_user_id THEN
   RETURN jsonb_build_object('partner_id',p.id,'status','accepted','already_accepted',true);
 END IF;
 IF i.status<>'sent' OR i.expires_at<=now() OR p.owner_user_id IS NOT NULL OR p.status<>'pending' THEN
   RAISE EXCEPTION 'invitation unavailable or expired';
 END IF;
 UPDATE public.partners SET owner_user_id=p_user_id,updated_at=now() WHERE id=p.id;
 UPDATE public.partner_invitations SET status='accepted',accepted_at=now(),
 accepted_by=p_user_id,updated_at=now() WHERE id=i.id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,'accepted_by_verified_user',p_user_id,
 jsonb_build_object('partner_id',p.id,'owner_linked',true));
 RETURN jsonb_build_object('partner_id',p.id,'status','accepted',
   'partner_status','pending','already_accepted',false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_activate_invited_partner(p_admin_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE p public.partners%rowtype;i public.partner_invitations%rowtype;v_verified boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR p.id IS NULL OR i.status<>'accepted' OR p.owner_user_id IS NULL
   OR i.accepted_by IS DISTINCT FROM p.owner_user_id THEN
  RAISE EXCEPTION 'partner owner has not accepted verified invitation';
 END IF;
 SELECT (private.verified_auth_email(p.owner_user_id) = lower(i.email)) INTO v_verified;
 IF NOT coalesce(v_verified,false) THEN RAISE EXCEPTION 'partner owner email unverified';END IF;
 IF p.status NOT IN ('pending','approved') THEN
   RAISE EXCEPTION 'partner cannot be activated';
 END IF;
 IF p.status='pending' THEN
   UPDATE public.partners SET status='approved',updated_at=now() WHERE id=p.id;
   INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
   VALUES('partner',p.id,'activated_after_invitation',p_admin_user_id,
      jsonb_build_object('owner_user_id',p.owner_user_id,'invitation_id',i.id));
 END IF;
 RETURN jsonb_build_object('partner_id',p.id,'status','approved','owner_verified',true);
END $$;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_accept_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_accept_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) TO service_role;
;

-- 20261029000339 marapass_tourism_territory_foundation

begin;

create extension if not exists postgis with schema extensions;

create table public.tourism_poles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null
    check (length(trim(name)) between 2 and 120),
  description text,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'inactive')),
  valid_from date,
  valid_to date,
  official_source text,
  official_source_url text,
  source_checked_at date,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create table public.municipalities (
  ibge_code char(7) primary key
    check (ibge_code ~ '^[0-9]{7}$'),
  name text not null
    check (length(trim(name)) between 2 and 120),
  state_code char(2) not null default 'MA'
    check (state_code = 'MA'),
  boundary extensions.geometry(MultiPolygon, 4326),
  boundary_source text,
  boundary_source_url text,
  boundary_version text,
  boundary_as_of date,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (boundary is null or extensions.st_isvalid(boundary)),
  check (not is_published or boundary is not null)
);

create table public.pole_municipalities (
  pole_id uuid not null
    references public.tourism_poles(id) on delete restrict,
  municipality_ibge_code char(7) not null
    references public.municipalities(ibge_code) on delete restrict,
  valid_from date not null default current_date,
  valid_to date,
  is_active boolean not null default true,
  source text,
  created_at timestamptz not null default now(),
  primary key (pole_id, municipality_ibge_code, valid_from),
  check (valid_to is null or valid_to >= valid_from)
);

create index tourism_poles_active_order_idx
  on public.tourism_poles (display_order, slug)
  where status = 'active';

create index municipalities_boundary_gix
  on public.municipalities using gist (boundary);

create index pole_municipalities_by_municipality_idx
  on public.pole_municipalities
    (municipality_ibge_code, is_active, valid_from, valid_to);

create index pole_municipalities_by_pole_idx
  on public.pole_municipalities
    (pole_id, is_active, valid_from, valid_to);

alter table public.tourism_poles enable row level security;
alter table public.municipalities enable row level security;
alter table public.pole_municipalities enable row level security;

revoke all on public.tourism_poles from public, anon, authenticated;
revoke all on public.municipalities from public, anon, authenticated;
revoke all on public.pole_municipalities from public, anon, authenticated;

grant select on public.tourism_poles to anon, authenticated;
grant select, insert, update, delete
  on public.tourism_poles to authenticated;

grant select on public.municipalities to anon, authenticated;
grant select, insert, update, delete
  on public.municipalities to authenticated;

grant select on public.pole_municipalities to anon, authenticated;
grant select, insert, update, delete
  on public.pole_municipalities to authenticated;

create policy tourism_poles_public_read
  on public.tourism_poles
  for select to anon, authenticated
  using (
    status = 'active'
    and (valid_from is null or valid_from <= current_date)
    and (valid_to is null or valid_to >= current_date)
  );

create policy tourism_poles_admin_manage
  on public.tourism_poles
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

create policy municipalities_public_read
  on public.municipalities
  for select to anon, authenticated
  using (is_published);

create policy municipalities_admin_manage
  on public.municipalities
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

create policy pole_municipalities_public_read
  on public.pole_municipalities
  for select to anon, authenticated
  using (
    is_active
    and valid_from <= current_date
    and (valid_to is null or valid_to >= current_date)
    and exists (
      select 1
      from public.tourism_poles p
      where p.id = pole_id
        and p.status = 'active'
        and (p.valid_from is null or p.valid_from <= current_date)
        and (p.valid_to is null or p.valid_to >= current_date)
    )
    and exists (
      select 1
      from public.municipalities m
      where m.ibge_code = municipality_ibge_code
        and m.is_published
    )
  );

create policy pole_municipalities_admin_manage
  on public.pole_municipalities
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

commit;;

-- 20261030181803 marapass_map_shared_editorial_workflow

insert into public.municipalities(ibge_code,name,state_code,is_published) values
('2100105','Afonso Cunha','MA',false),
('2100204','Alcântara','MA',false),
('2100303','Aldeias Altas','MA',false),
('2100402','Altamira do Maranhão','MA',false),
('2100436','Alto Alegre do Maranhão','MA',false),
('2100477','Alto Alegre do Pindaré','MA',false),
('2100501','Alto Parnaíba','MA',false),
('2100550','Amapá do Maranhão','MA',false),
('2100600','Amarante do Maranhão','MA',false),
('2100709','Anajatuba','MA',false),
('2100808','Anapurus','MA',false),
('2100832','Apicum-Açu','MA',false),
('2100873','Araguanã','MA',false),
('2100907','Araioses','MA',false),
('2100956','Arame','MA',false),
('2101004','Arari','MA',false),
('2101103','Axixá','MA',false),
('2100055','Açailândia','MA',false),
('2101202','Bacabal','MA',false),
('2101251','Bacabeira','MA',false),
('2101301','Bacuri','MA',false),
('2101350','Bacurituba','MA',false),
('2101400','Balsas','MA',false),
('2101608','Barra do Corda','MA',false),
('2101707','Barreirinhas','MA',false),
('2101509','Barão de Grajaú','MA',false),
('2101772','Bela Vista do Maranhão','MA',false),
('2101731','Belágua','MA',false),
('2101806','Benedito Leite','MA',false),
('2101905','Bequimão','MA',false),
('2101939','Bernardo do Mearim','MA',false),
('2101970','Boa Vista do Gurupi','MA',false),
('2102002','Bom Jardim','MA',false),
('2102036','Bom Jesus das Selvas','MA',false),
('2102077','Bom Lugar','MA',false),
('2102101','Brejo','MA',false),
('2102150','Brejo de Areia','MA',false),
('2102200','Buriti','MA',false),
('2102309','Buriti Bravo','MA',false),
('2102325','Buriticupu','MA',false),
('2102358','Buritirana','MA',false),
('2102374','Cachoeira Grande','MA',false),
('2102408','Cajapió','MA',false),
('2102507','Cajari','MA',false),
('2102556','Campestre do Maranhão','MA',false),
('2102705','Cantanhede','MA',false),
('2102754','Capinzal do Norte','MA',false),
('2102804','Carolina','MA',false),
('2102903','Carutapera','MA',false),
('2103000','Caxias','MA',false),
('2103109','Cedral','MA',false),
('2103125','Central do Maranhão','MA',false),
('2103174','Centro Novo do Maranhão','MA',false),
('2103158','Centro do Guilherme','MA',false),
('2103208','Chapadinha','MA',false),
('2103257','Cidelândia','MA',false),
('2103307','Codó','MA',false),
('2103406','Coelho Neto','MA',false),
('2103505','Colinas','MA',false),
('2103554','Conceição do Lago-Açu','MA',false),
('2103604','Coroatá','MA',false),
('2103703','Cururupu','MA',false),
('2102606','Cândido Mendes','MA',false),
('2103752','Davinópolis','MA',false),
('2103802','Dom Pedro','MA',false),
('2103901','Duque Bacelar','MA',false),
('2104008','Esperantinópolis','MA',false),
('2104057','Estreito','MA',false),
('2104073','Feira Nova do Maranhão','MA',false),
('2104081','Fernando Falcão','MA',false),
('2104099','Formosa da Serra Negra','MA',false),
('2104107','Fortaleza dos Nogueiras','MA',false),
('2104206','Fortuna','MA',false),
('2104305','Godofredo Viana','MA',false),
('2104404','Gonçalves Dias','MA',false),
('2104503','Governador Archer','MA',false),
('2104552','Governador Edison Lobão','MA',false),
('2104602','Governador Eugênio Barros','MA',false),
('2104628','Governador Luiz Rocha','MA',false),
('2104651','Governador Newton Bello','MA',false),
('2104677','Governador Nunes Freire','MA',false),
('2104800','Grajaú','MA',false),
('2104701','Graça Aranha','MA',false),
('2104909','Guimarães','MA',false),
('2105005','Humberto de Campos','MA',false),
('2105104','Icatu','MA',false),
('2105203','Igarapé Grande','MA',false),
('2105153','Igarapé do Meio','MA',false),
('2105302','Imperatriz','MA',false),
('2105351','Itaipava do Grajaú','MA',false),
('2105401','Itapecuru Mirim','MA',false),
('2105427','Itinga do Maranhão','MA',false),
('2105450','Jatobá','MA',false),
('2105476','Jenipapo dos Vieiras','MA',false),
('2105609','Joselândia','MA',false),
('2105500','João Lisboa','MA',false),
('2105658','Junco do Maranhão','MA',false),
('2105906','Lago Verde','MA',false),
('2105708','Lago da Pedra','MA',false),
('2105807','Lago do Junco','MA',false),
('2105948','Lago dos Rodrigues','MA',false),
('2105963','Lagoa Grande do Maranhão','MA',false),
('2105922','Lagoa do Mato','MA',false),
('2105989','Lajeado Novo','MA',false),
('2106003','Lima Campos','MA',false),
('2106102','Loreto','MA',false),
('2106201','Luís Domingues','MA',false),
('2106300','Magalhães de Almeida','MA',false),
('2106326','Maracaçumé','MA',false),
('2106359','Marajá do Sena','MA',false),
('2106375','Maranhãozinho','MA',false),
('2106409','Mata Roma','MA',false),
('2106508','Matinha','MA',false),
('2106607','Matões','MA',false),
('2106631','Matões do Norte','MA',false),
('2106672','Milagres do Maranhão','MA',false),
('2106706','Mirador','MA',false),
('2106755','Miranda do Norte','MA',false),
('2106805','Mirinzal','MA',false),
('2107001','Montes Altos','MA',false),
('2106904','Monção','MA',false),
('2107100','Morros','MA',false),
('2107209','Nina Rodrigues','MA',false),
('2107258','Nova Colinas','MA',false),
('2107308','Nova Iorque','MA',false),
('2107357','Nova Olinda do Maranhão','MA',false),
('2107407','Olho d''Água das Cunhãs','MA',false),
('2107456','Olinda Nova do Maranhão','MA',false),
('2107605','Palmeirândia','MA',false),
('2107704','Paraibano','MA',false),
('2107803','Parnarama','MA',false),
('2107902','Passagem Franca','MA',false),
('2108009','Pastos Bons','MA',false),
('2108058','Paulino Neves','MA',false),
('2108108','Paulo Ramos','MA',false),
('2107506','Paço do Lumiar','MA',false),
('2108207','Pedreiras','MA',false),
('2108256','Pedro do Rosário','MA',false),
('2108306','Penalva','MA',false),
('2108405','Peri Mirim','MA',false),
('2108454','Peritoró','MA',false),
('2108504','Pindaré-Mirim','MA',false),
('2108603','Pinheiro','MA',false),
('2108702','Pio XII','MA',false),
('2108801','Pirapemas','MA',false),
('2109007','Porto Franco','MA',false),
('2109056','Porto Rico do Maranhão','MA',false),
('2108900','Poção de Pedras','MA',false),
('2109106','Presidente Dutra','MA',false),
('2109205','Presidente Juscelino','MA',false),
('2109239','Presidente Médici','MA',false),
('2109270','Presidente Sarney','MA',false),
('2109304','Presidente Vargas','MA',false),
('2109403','Primeira Cruz','MA',false),
('2109452','Raposa','MA',false),
('2109502','Riachão','MA',false),
('2109551','Ribamar Fiquene','MA',false),
('2109601','Rosário','MA',false),
('2109700','Sambaíba','MA',false),
('2109759','Santa Filomena do Maranhão','MA',false),
('2109809','Santa Helena','MA',false),
('2109908','Santa Inês','MA',false),
('2110005','Santa Luzia','MA',false),
('2110039','Santa Luzia do Paruá','MA',false),
('2110104','Santa Quitéria do Maranhão','MA',false),
('2110203','Santa Rita','MA',false),
('2110237','Santana do Maranhão','MA',false),
('2110278','Santo Amaro do Maranhão','MA',false),
('2110302','Santo Antônio dos Lopes','MA',false),
('2111722','Satubinha','MA',false),
('2111748','Senador Alexandre Costa','MA',false),
('2111763','Senador La Rocque','MA',false),
('2111789','Serrano do Maranhão','MA',false),
('2111904','Sucupira do Norte','MA',false),
('2111953','Sucupira do Riachão','MA',false),
('2110401','São Benedito do Rio Preto','MA',false),
('2110500','São Bento','MA',false),
('2110609','São Bernardo','MA',false),
('2110658','São Domingos do Azeitão','MA',false),
('2110708','São Domingos do Maranhão','MA',false),
('2110856','São Francisco do Brejão','MA',false),
('2110906','São Francisco do Maranhão','MA',false),
('2110807','São Félix de Balsas','MA',false),
('2111201','São José de Ribamar','MA',false),
('2111250','São José dos Basílios','MA',false),
('2111003','São João Batista','MA',false),
('2111029','São João do Carú','MA',false),
('2111052','São João do Paraíso','MA',false),
('2111078','São João do Soter','MA',false),
('2111102','São João dos Patos','MA',false),
('2111300','São Luís','MA',false),
('2111409','São Luís Gonzaga do Maranhão','MA',false),
('2111508','São Mateus do Maranhão','MA',false),
('2111532','São Pedro da Água Branca','MA',false),
('2111573','São Pedro dos Crentes','MA',false),
('2111607','São Raimundo das Mangabeiras','MA',false),
('2111631','São Raimundo do Doca Bezerra','MA',false),
('2111672','São Roberto','MA',false),
('2111706','São Vicente Ferrer','MA',false),
('2111805','Sítio Novo','MA',false),
('2112001','Tasso Fragoso','MA',false),
('2112100','Timbiras','MA',false),
('2112209','Timon','MA',false),
('2112233','Trizidela do Vale','MA',false),
('2112274','Tufilândia','MA',false),
('2112308','Tuntum','MA',false),
('2112407','Turiaçu','MA',false),
('2112456','Turilândia','MA',false),
('2112506','Tutóia','MA',false),
('2112605','Urbano Santos','MA',false),
('2112704','Vargem Grande','MA',false),
('2112803','Viana','MA',false),
('2112852','Vila Nova dos Martírios','MA',false),
('2113009','Vitorino Freire','MA',false),
('2112902','Vitória do Mearim','MA',false),
('2114007','Zé Doca','MA',false),
('2100154','Água Doce do Maranhão','MA',false)
on conflict(ibge_code) do nothing;
-- Additive map CMS. Apply with Supabase apply_migration, not with the public client.
create table private.map_members (
 user_id uuid primary key references auth.users(id), role text not null check(role in ('editor','reviewer')),
 municipality_codes text[] not null default '{}', is_active boolean not null default true,
 updated_at timestamptz not null default now()
);
create table private.map_documents (
 id text primary key check(length(id) between 1 and 180), municipality_code char(7) not null references public.municipalities(ibge_code),
 content jsonb not null, kind text not null check(kind in ('point','attraction','company')),
 status text not null default 'draft' check(status in ('draft','review','published','archived')),
 revision integer not null default 1, published_revision integer, updated_at timestamptz not null default now()
);
create table private.map_versions (
 document_id text not null references private.map_documents(id), revision integer not null,
 content jsonb not null, kind text not null, status text not null, action text not null,
 actor uuid not null references auth.users(id), reason text not null, created_at timestamptz not null default now(),
 primary key(document_id,revision)
);
create index map_documents_municipality_idx on private.map_documents(municipality_code,updated_at desc,id);
create index map_versions_actor_idx on private.map_versions(actor);
create table private.map_requests (
 actor uuid not null references auth.users(id), request_id uuid not null, fingerprint text not null,
 response jsonb not null, created_at timestamptz not null default now(), primary key(actor,request_id)
);
create table private.map_previews (
 id uuid primary key default gen_random_uuid(), actor uuid not null references auth.users(id),
 document_id text not null references private.map_documents(id), revision integer not null,
 created_at timestamptz not null default now()
);
create index map_previews_document_idx on private.map_previews(document_id);
create index map_previews_actor_idx on private.map_previews(actor);
create table private.map_permission_events (
 id bigint generated always as identity primary key, actor uuid not null references auth.users(id),
 member_id uuid not null references auth.users(id), before_value jsonb, after_value jsonb,
 reason text not null, created_at timestamptz not null default now()
);
create index map_permission_actor_idx on private.map_permission_events(actor);
create index map_permission_member_idx on private.map_permission_events(member_id);
create table public.map_publications (
 id text primary key, content jsonb, is_visible boolean not null, revision integer not null,
 published_at timestamptz not null default now(),
 check ((is_visible and content is not null) or (not is_visible and content is null))
);
alter table public.map_publications enable row level security;
create policy map_public_read on public.map_publications for select to anon,authenticated using(true);
revoke all on public.map_publications from anon,authenticated;
grant select on public.map_publications to anon,authenticated;
-- Private tables are not exposed; no direct client mutations or audit rewrites.
alter table private.map_members enable row level security;
alter table private.map_documents enable row level security;
alter table private.map_versions enable row level security;
alter table private.map_requests enable row level security;
alter table private.map_previews enable row level security;
alter table private.map_permission_events enable row level security;
revoke all on private.map_members,private.map_documents,private.map_versions,private.map_requests,private.map_previews,private.map_permission_events from public,anon,authenticated;

-- Definer confined to private schema: atomic commands need private state/audit writes.
-- Identity, live session, MFA, membership and both old/new territory checked on every call.
create function private.map_command(p_action text, p_args jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
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
   'members',(select coalesce(jsonb_agg(to_jsonb(m)),'[]') from private.map_members m),
   'history',(select coalesce(jsonb_agg(to_jsonb(q)),'[]') from (select * from private.map_permission_events order by id desc limit 50 offset page_offset) q));
 end if;
 if p_action in ('save','submit','publish','archive','restore','grant') then
  request_key:=(p_args->>'request_id')::uuid;
  if request_key is null then raise exception 'Identificador da operação obrigatório.';end if;
  fingerprint:=md5(p_action||p_args::text);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||request_key::text,0));
  select * into receipt from private.map_requests where map_requests.actor=map_command.actor and request_id=request_key;
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
   return (select coalesce(jsonb_agg(to_jsonb(q)),'[]') from(select * from private.map_versions where document_id=doc_id order by revision desc limit 51 offset page_offset) q);
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
    if not exists(select 1 from private.map_previews where id=(p_args->>'preview_id')::uuid and map_previews.actor=map_command.actor and document_id=doc_id and revision=doc.revision and created_at>now()-interval '30 minutes') then raise exception 'Abra a prévia atual antes de publicar.';end if;
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
revoke all on function private.map_command(text,jsonb) from public,anon,authenticated;
grant usage on schema private to authenticated;
grant execute on function private.map_command(text,jsonb) to authenticated;
create function public.map_content_command(p_action text,p_args jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$select private.map_command(p_action,p_args)$$;
revoke all on function public.map_content_command(text,jsonb) from public,anon,authenticated;
grant execute on function public.map_content_command(text,jsonb) to authenticated;
notify pgrst,'reload schema';
;

-- 20261030181932 marapass_map_command_scope_fix

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
   'members',(select coalesce(jsonb_agg(to_jsonb(m)),'[]') from private.map_members m),
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
   return (select coalesce(jsonb_agg(to_jsonb(q)),'[]') from(select * from private.map_versions where document_id=doc_id order by revision desc limit 51 offset page_offset) q);
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

-- 20261030182501 marapass_map_team_labels_and_private_policies

create policy map_private_no_direct_access on private.map_members for all to anon,authenticated using(false) with check(false);
create policy map_private_no_direct_access on private.map_documents for all to anon,authenticated using(false) with check(false);
create policy map_private_no_direct_access on private.map_versions for all to anon,authenticated using(false) with check(false);
create policy map_private_no_direct_access on private.map_requests for all to anon,authenticated using(false) with check(false);
create policy map_private_no_direct_access on private.map_previews for all to anon,authenticated using(false) with check(false);
create policy map_private_no_direct_access on private.map_permission_events for all to anon,authenticated using(false) with check(false);
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
   return (select coalesce(jsonb_agg(to_jsonb(q)),'[]') from(select v.*,coalesce(nullif(p.display_name,''),u.email,v.actor::text) as actor_label from private.map_versions v left join public.profiles p on p.id=v.actor left join auth.users u on u.id=v.actor where v.document_id=doc_id order by v.revision desc limit 51 offset page_offset) q);
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

-- 20261030182517 marapass_map_history_actor_label_fix

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

-- 20261102223629 map_editorial_google_place_id

DO $guard$ BEGIN IF md5(pg_get_functiondef('private.map_command(text,jsonb)'::regprocedure)) <> '1e5bbff9d9a2478e5746a93801aec9b1' THEN RAISE EXCEPTION 'Map function changed; review before updating'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION private.map_command(p_action text, p_args jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
   if exists(select 1 from jsonb_object_keys(next_content) f where f not in ('id','name','city','lat','lng','cat','description','area','municipalityId','dataSource','checkedAt','address','website','hours','tags','sourceUrl','photoUrl','phone','whatsapp','referenceLocation','googlePlaceId')) then raise exception 'Campo não permitido; parceiros e ofertas usam o cadastro comercial.';end if;
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
   if next_content->>'googlePlaceId' is not null and (next_content->>'googlePlaceId') !~ '^[A-Za-z0-9_-]{8,255}$' then raise exception 'Identificador Google inválido.';end if;
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
end $function$;
NOTIFY pgrst, 'reload schema';;

-- 20261103002152 assistant_chat_foundation

create table if not exists public.assistant_conversations (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, destination text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()); create table if not exists public.assistant_messages (id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.assistant_conversations(id) on delete cascade, sender text not null check(sender in ('user','assistant','system')), body text not null check(char_length(body)<=12000), created_at timestamptz not null default now()); create index if not exists assistant_messages_conversation_created_idx on public.assistant_messages(conversation_id,created_at); alter table public.assistant_conversations enable row level security; alter table public.assistant_messages enable row level security; create policy assistant_conversations_read on public.assistant_conversations for select to authenticated using (user_id=(select auth.uid())); create policy assistant_conversations_create on public.assistant_conversations for insert to authenticated with check (user_id=(select auth.uid())); create policy assistant_conversations_update on public.assistant_conversations for update to authenticated using (user_id=(select auth.uid())) with check(user_id=(select auth.uid())); create policy assistant_messages_read on public.assistant_messages for select to authenticated using (exists(select 1 from public.assistant_conversations c where c.id=conversation_id and c.user_id=(select auth.uid()))); create policy assistant_messages_user_insert on public.assistant_messages for insert to authenticated with check(sender='user' and exists(select 1 from public.assistant_conversations c where c.id=conversation_id and c.user_id=(select auth.uid())));;

-- 20261103002203 assistant_restrict_anonymous_sessions

alter policy assistant_conversations_read on public.assistant_conversations using (user_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false); alter policy assistant_conversations_create on public.assistant_conversations with check (user_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false); alter policy assistant_conversations_update on public.assistant_conversations using (user_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false) with check(user_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false); alter policy assistant_messages_read on public.assistant_messages using (coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false and exists(select 1 from public.assistant_conversations c where c.id=conversation_id and c.user_id=(select auth.uid()))); alter policy assistant_messages_user_insert on public.assistant_messages with check (sender='user' and coalesce((select auth.jwt()->>'is_anonymous')::boolean,false)=false and exists(select 1 from public.assistant_conversations c where c.id=conversation_id and c.user_id=(select auth.uid())));;

-- 20261103111443 map_tourism_attractions_and_partner_read_model

create table if not exists public.map_attractions (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 description text,
 municipality_ibge_code char(7) references public.municipalities(ibge_code),
 category text not null default 'atrativo',
 latitude numeric(10,7),
 longitude numeric(10,7),
 source_name text,
 source_url text,
 verified_at timestamptz,
 publication_status text not null default 'draft' check (publication_status in ('draft','published','archived')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint map_attractions_coordinates check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);
create index if not exists map_attractions_municipality_idx on public.map_attractions(municipality_ibge_code,publication_status);
alter table public.map_attractions enable row level security;
revoke all on public.map_attractions from anon, authenticated;
grant select on public.map_attractions to anon, authenticated;
drop policy if exists map_attractions_public_read on public.map_attractions;
create policy map_attractions_public_read on public.map_attractions for select to anon,authenticated using (publication_status='published' and verified_at is not null and latitude is not null and longitude is not null);
create or replace view public.map_partner_points with (security_invoker=true) as
select e.id,e.name,e.category,e.city,e.latitude,e.longitude,e.description
from public.establishments e
where e.is_active=true and e.is_public=true and e.latitude is not null and e.longitude is not null;
revoke all on public.map_partner_points from public,anon,authenticated;
grant select on public.map_partner_points to anon,authenticated;
;

-- 20261103183635 barreirinhas_map_pilot_safe_fields_and_demo_offers

alter table public.map_attractions
 add column if not exists external_ref text,
 add column if not exists access_mode text not null default 'guided',
 add column if not exists navigation_warning text,
 add column if not exists coordinate_quality text not null default 'reference',
 add column if not exists partner_segments text[] not null default '{}';
create unique index if not exists map_attractions_external_ref_unique on public.map_attractions (external_ref) where external_ref is not null;
create table if not exists public.map_demo_offers (
 id uuid primary key default gen_random_uuid(),
 attraction_id uuid not null references public.map_attractions(id) on delete cascade,
 title text not null,
 benefit_label text not null,
 segment text not null,
 terms text not null default 'Demonstração sem valor comercial; não pode ser emitido ou resgatado.',
 starts_at timestamptz not null default now(),
 ends_at timestamptz not null default '2027-02-01T00:00:00Z',
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 constraint map_demo_offers_window check(ends_at>starts_at)
);
create unique index if not exists map_demo_offers_attr_title_unique on public.map_demo_offers(attraction_id,title);
create index if not exists map_demo_offers_active_idx on public.map_demo_offers(is_active,ends_at);
alter table public.map_demo_offers enable row level security;
revoke all on public.map_demo_offers from anon,authenticated;
grant select on public.map_demo_offers to anon,authenticated;
drop policy if exists map_demo_offers_public_read on public.map_demo_offers;
create policy map_demo_offers_public_read on public.map_demo_offers for select to anon,authenticated
 using(is_active=true and now() >= starts_at and now()<ends_at and exists (
 select 1 from public.map_attractions a where a.id=attraction_id
 and a.publication_status='published' and a.verified_at is not null
 ));
;

-- 20261106013340 coupon_idempotency_serialization_and_payload

do $patch$
declare d text;
begin
 d := pg_get_functiondef('public.issue_coupon(uuid,uuid,text,uuid)'::regprocedure);
 d := replace(d,'if p_user_id is null or length(p_idempotency_key) not between 16 and 180 then','if p_user_id is null or length(coalesce(p_idempotency_key, '''')) not between 16 and 180 then');
 d := replace(d,'  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;', E'  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''coupon-issue:'' || p_idempotency_key, 0));\n  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;');
 execute d;
 d := pg_get_functiondef('public.redeem_coupon(uuid,uuid,text,integer)'::regprocedure);
 d := replace(d,'if p_validator_user_id is null or length(p_idempotency_key) not between 16 and 180','if p_validator_user_id is null or length(coalesce(p_idempotency_key, '''')) not between 16 and 180');
 d := replace(d,'  select * into v_old from public.coupon_redemptions where idempotency_key=p_idempotency_key;', E'  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''coupon-redeem:'' || p_idempotency_key, 0));\n  select * into v_old from public.coupon_redemptions where idempotency_key=p_idempotency_key;');
 d := replace(d,'or v_old.validated_by_user_id<>p_validator_user_id then',E'or v_old.validated_by_user_id<>p_validator_user_id\n      or v_old.transaction_amount_cents is distinct from p_transaction_amount_cents then');
 execute d;
end $patch$;;

-- 20261106094736 coupon_offer_creation_once

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

-- 20261106095508 coupon_offer_request_private_metadata

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

-- 20261107090856 partner_profiles_custom_coupons

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

-- 20261107091056 business_profile_category_mapping

create or replace function public.save_business_profile(p_actor uuid,p_partner_id uuid,p_establishment_id uuid,p_profile jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid:=p_establishment_id;begin
 perform private.assert_partner_manager(p_partner_id,p_actor);
 if length(p_profile->>'name') not between 2 and 160 or length(p_profile->>'city') not between 2 and 100 then raise exception 'invalid business profile';end if;
 if v_id is null then v_id:=public.create_partner_establishment(p_partner_id,p_actor,p_profile->>'name',case p_profile->>'category' when 'Passeios' then 'tours' when 'Gastronomia' then 'gastronomy' when 'Hospedagem' then 'lodging' when 'Cultura' then 'culture' when 'Natureza' then 'nature' when 'Artesanato' then 'crafts' when 'Transporte turístico' then 'tourist_transport' when 'Eventos' then 'events' when 'Fotografia' then 'photography' else 'services' end,p_profile->>'city',p_profile->>'description');
 elsif not exists(select 1 from public.establishments where id=v_id and partner_id=p_partner_id and is_active) then raise exception 'establishment denied';end if;
 update public.establishments set name=p_profile->>'name',city=p_profile->>'city',category=case p_profile->>'category' when 'Passeios' then 'tours' when 'Gastronomia' then 'gastronomy' when 'Hospedagem' then 'lodging' when 'Cultura' then 'culture' when 'Natureza' then 'nature' when 'Artesanato' then 'crafts' when 'Transporte turístico' then 'tourist_transport' when 'Eventos' then 'events' when 'Fotografia' then 'photography' else 'services' end,description=p_profile->>'description',street_address=p_profile->>'address',public_profile=p_profile where id=v_id;
 return v_id;end $$;;

-- 20261107181827 map_environment_cache

create table public.map_environment_cache(city_code text primary key check(city_code ~ '^21[0-9]{5}$'),payload jsonb,expires_at timestamptz not null default '-infinity',locked_until timestamptz not null default '-infinity',fetched_at timestamptz);
alter table public.map_environment_cache enable row level security;
revoke all on public.map_environment_cache from public,anon,authenticated;
grant select,insert,update on public.map_environment_cache to service_role;
create function public.claim_map_environment(p_code text) returns boolean language sql security invoker set search_path='' as $$
 with claim as (insert into public.map_environment_cache(city_code,locked_until) values(p_code,now()+interval '1 minute') on conflict(city_code) do update set locked_until=now()+interval '1 minute' where public.map_environment_cache.expires_at<=now() and public.map_environment_cache.locked_until<=now() returning 1) select exists(select 1 from claim);
$$;
revoke all on function public.claim_map_environment(text) from public,anon,authenticated;
grant execute on function public.claim_map_environment(text) to service_role;
;

-- 20261108134340 map_residential_category

-- Extend only the editorial category allowlist. Preserve function body, ACL and search_path.
do $migration$
declare definition text;
begin
 definition := pg_get_functiondef('private.map_command(text,jsonb)'::regprocedure);
 if position('''residential''' in definition)>0 then return; end if;
 if position('''crafts'',''photography'',''tourist_transport''' in definition)=0 then raise exception 'Unexpected category validation; no change applied.'; end if;
 execute replace(definition,'''crafts'',''photography'',''tourist_transport''','''crafts'',''photography'',''residential'',''tourist_transport''');
end $migration$;;

-- 20261108165320 map_public_offer_calendar

create or replace function private.map_offer_calendar(p_day date,p_city text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare day_start timestamptz; day_end timestamptz; result jsonb;
begin
 if p_day is null or p_day<(now() at time zone 'America/Fortaleza')::date or p_day>(now() at time zone 'America/Fortaleza')::date+366 then raise exception 'Escolha uma data entre hoje e os próximos 366 dias.';end if;
 if p_city is null or length(trim(p_city)) not between 2 and 100 then raise exception 'Informe o município.';end if;
 day_start:=p_day::timestamp at time zone 'America/Fortaleza'; day_end:=(p_day+1)::timestamp at time zone 'America/Fortaleza';
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into result from (
 select o.id as offer_id,o.title,o.starts_at,o.ends_at,e.id as establishment_id,e.name,e.city,e.category,e.latitude as lat,e.longitude as lng,e.street_address as address
 from public.offers o join public.establishments e on e.id=o.establishment_id
 where o.is_published and e.is_active and e.is_public and e.state_code='MA' and lower(e.city)=lower(trim(p_city))
 and (o.starts_at is null or o.starts_at<day_end) and (o.ends_at is null or o.ends_at>day_start)
 and (o.max_issuances is null or o.max_issuances>(select count(*) from public.coupon_instances c where c.offer_id=o.id))
 and e.latitude is not null and e.longitude is not null
 order by e.name,o.id limit 101
 ) q;
 return jsonb_build_object('day',p_day,'timezone','America/Fortaleza','offers',result,'checked_at',now(),'notice','Vigência publicada. Dias, horários, regras e estoque precisam ser confirmados na emissão.');
end $fn$;
revoke all on function private.map_offer_calendar(date,text) from public,anon,authenticated;
grant execute on function private.map_offer_calendar(date,text) to anon,authenticated;
grant usage on schema private to anon;
create or replace function public.map_offer_calendar(p_day date,p_city text)
returns jsonb language sql security invoker set search_path='' as $fn$select private.map_offer_calendar(p_day,p_city)$fn$;
revoke all on function public.map_offer_calendar(date,text) from public;
grant execute on function public.map_offer_calendar(date,text) to anon,authenticated;
notify pgrst,'reload schema';;

-- 20261108165543 map_offer_calendar_filters

create or replace function private.map_offer_calendar(p_day date,p_city text,p_category text default null,p_term text default '')
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare day_start timestamptz; day_end timestamptz; result jsonb;
begin
 if p_day is null or p_day<(now() at time zone 'America/Fortaleza')::date or p_day>(now() at time zone 'America/Fortaleza')::date+366 then raise exception 'Escolha uma data entre hoje e os próximos 366 dias.';end if;
 if p_city is null or length(trim(p_city)) not between 2 and 100 then raise exception 'Informe o município.';end if;
 day_start:=p_day::timestamp at time zone 'America/Fortaleza'; day_end:=(p_day+1)::timestamp at time zone 'America/Fortaleza';
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into result from (
 select o.id as offer_id,o.title,o.starts_at,o.ends_at,e.id as establishment_id,e.name,e.city,e.category,e.latitude as lat,e.longitude as lng,e.street_address as address
 from public.offers o join public.establishments e on e.id=o.establishment_id
 where o.is_published and e.is_active and e.is_public and e.state_code='MA' and lower(e.city)=lower(trim(p_city))
 and (p_category is null or e.category=p_category) and length(coalesce(p_term,''))<=160 and (coalesce(p_term,'')='' or strpos(lower(e.name||' '||o.title),lower(p_term))>0)
 and (o.starts_at is null or o.starts_at<day_end) and (o.ends_at is null or o.ends_at>day_start)
 and (o.max_issuances is null or o.max_issuances>(select count(*) from public.coupon_instances c where c.offer_id=o.id))
 and e.latitude is not null and e.longitude is not null
 order by e.name,o.id limit 101
 ) q;
 return jsonb_build_object('day',p_day,'timezone','America/Fortaleza','offers',result,'checked_at',now(),'notice','Vigência publicada. Dias, horários, regras e estoque precisam ser confirmados na emissão.');
end $fn$;
revoke all on function private.map_offer_calendar(date,text,text,text) from public,anon,authenticated;
grant execute on function private.map_offer_calendar(date,text,text,text) to anon,authenticated;
grant usage on schema private to anon;
create or replace function public.map_offer_calendar(p_day date,p_city text,p_category text default null,p_term text default '')
returns jsonb language sql security invoker set search_path='' as $fn$select private.map_offer_calendar(p_day,p_city,p_category,p_term)$fn$;
revoke all on function public.map_offer_calendar(date,text,text,text) from public;
grant execute on function public.map_offer_calendar(date,text,text,text) to anon,authenticated;
notify pgrst,'reload schema';;

-- 20261111002950 marapass_v10_commercial_disclosures_passport_contracts

-- MaraPass V10. Commercial disclosure and passport contract foundation.
ALTER TABLE public.offers
 ADD COLUMN IF NOT EXISTS access_scope text NOT NULL DEFAULT 'public',
 ADD COLUMN IF NOT EXISTS eligible_items text,
 ADD COLUMN IF NOT EXISTS calculation_base text,
 ADD COLUMN IF NOT EXISTS minimum_purchase_cents integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS maximum_discount_cents integer,
 ADD COLUMN IF NOT EXISTS fixed_use_policy text NOT NULL DEFAULT 'single_use_no_change',
 ADD COLUMN IF NOT EXISTS issue_until timestamptz,
 ADD COLUMN IF NOT EXISTS convert_until timestamptz,
 ADD COLUMN IF NOT EXISTS use_until timestamptz,
 ADD COLUMN IF NOT EXISTS advance_booking_required boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS commercial_terms_version integer NOT NULL DEFAULT 1,
 ADD COLUMN IF NOT EXISTS disclosure_extra text;

ALTER TABLE public.offers
 ADD CONSTRAINT mp_offer_access_scope CHECK(access_scope IN ('public','passport')),
 ADD CONSTRAINT mp_offer_minimum CHECK(minimum_purchase_cents>=0),
 ADD CONSTRAINT mp_offer_maximum CHECK(maximum_discount_cents IS NULL OR maximum_discount_cents>0),
 ADD CONSTRAINT mp_offer_nominal_policy CHECK(fixed_use_policy='single_use_no_change'),
 ADD CONSTRAINT mp_offer_deadline_sequence CHECK(
   (issue_until IS NULL OR convert_until IS NULL OR issue_until<=convert_until)
   AND (convert_until IS NULL OR use_until IS NULL OR convert_until<=use_until)),
 ADD CONSTRAINT mp_offer_complete_publication CHECK(
   NOT is_published OR (
     length(trim(coalesce(eligible_items,'')))>=3
     AND length(trim(coalesce(calculation_base,'')))>=3
     AND issue_until IS NOT NULL
     AND convert_until IS NOT NULL
     AND use_until IS NOT NULL
     AND (access_scope='public' OR access_scope='passport')
     AND (discount_type<>'fixed' OR fixed_use_policy='single_use_no_change')
   )
 );

CREATE TABLE public.passport_products (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 160),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 15 AND 6000),
 price_cents integer NOT NULL CHECK(price_cents>=100),
 currency char(3) NOT NULL DEFAULT 'BRL' CHECK(currency='BRL'),
 validity_start_rule text NOT NULL CHECK(validity_start_rule IN ('purchase','activation','fixed')),
 duration_days integer CHECK(duration_days BETWEEN 1 AND 730),
 fixed_starts_at timestamptz,
 fixed_ends_at timestamptz,
 activation_deadline_days integer CHECK(activation_deadline_days BETWEEN 1 AND 365),
 booking_explanation text NOT NULL DEFAULT 'O agendamento depende das regras e disponibilidade de cada oferta.',
 included_benefits_explanation text NOT NULL DEFAULT '',
 legal_terms text NOT NULL DEFAULT 'A compra à distância observa o art. 49 do CDC, sem renúncia automática pelo acesso ou emissão de cupom.',
 is_published boolean NOT NULL DEFAULT false,
 terms_version integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (
  (validity_start_rule='fixed' AND fixed_starts_at IS NOT NULL AND fixed_ends_at>fixed_starts_at AND duration_days IS NULL)
   OR
  (validity_start_rule IN ('purchase','activation') AND duration_days IS NOT NULL AND fixed_starts_at IS NULL AND fixed_ends_at IS NULL)
 ),
 CHECK (
  validity_start_rule<>'activation' OR activation_deadline_days IS NOT NULL
 )
);
CREATE TABLE public.passport_product_benefits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 product_id uuid NOT NULL REFERENCES public.passport_products(id) ON DELETE RESTRICT,
 offer_id uuid NOT NULL REFERENCES public.offers(id) ON DELETE RESTRICT,
 issue_window_days integer NOT NULL CHECK(issue_window_days BETWEEN 1 AND 730),
 convert_window_days integer NOT NULL CHECK(convert_window_days BETWEEN 1 AND 730),
 use_window_days integer NOT NULL CHECK(use_window_days BETWEEN 1 AND 730),
 max_per_holder integer NOT NULL DEFAULT 1 CHECK(max_per_holder BETWEEN 1 AND 20),
 booking_required boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(product_id,offer_id),
 CHECK(issue_window_days<=convert_window_days AND convert_window_days<=use_window_days)
);
CREATE TABLE public.passport_orders (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 buyer_user_id uuid NOT NULL REFERENCES auth.users(id),
 product_id uuid NOT NULL REFERENCES public.passport_products(id) ON DELETE RESTRICT,
 purchase_intent_key uuid NOT NULL,
 price_cents integer NOT NULL CHECK(price_cents>=0),
 currency char(3) NOT NULL DEFAULT 'BRL' CHECK(currency='BRL'),
 status text NOT NULL DEFAULT 'pending_payment' CHECK(status IN ('pending_payment','paid','cancel_requested','refunded','cancelled')),
 terms_snapshot jsonb NOT NULL CHECK(jsonb_typeof(terms_snapshot)='object'),
 payment_provider text,
 provider_payment_reference text,
 payment_confirmed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(buyer_user_id,purchase_intent_key),
 UNIQUE(provider_payment_reference),
 CHECK(status NOT IN ('paid','cancel_requested','refunded') OR payment_confirmed_at IS NOT NULL),
 CHECK(status NOT IN ('paid','cancel_requested','refunded') OR provider_payment_reference IS NOT NULL)
);
CREATE TABLE public.passport_entitlements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL UNIQUE REFERENCES public.passport_orders(id) ON DELETE RESTRICT,
 user_id uuid NOT NULL REFERENCES auth.users(id),
 product_id uuid NOT NULL REFERENCES public.passport_products(id),
 status text NOT NULL DEFAULT 'pending_activation'
   CHECK(status IN ('pending_activation','active','expired','revoked_refund')),
 purchased_at timestamptz NOT NULL,
 activated_at timestamptz,
 valid_from timestamptz,
 valid_until timestamptz,
 CHECK(valid_until IS NULL OR valid_from IS NULL OR valid_until>valid_from)
);
CREATE TABLE public.passport_entitlement_benefits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 entitlement_id uuid NOT NULL REFERENCES public.passport_entitlements(id) ON DELETE RESTRICT,
 offer_id uuid NOT NULL REFERENCES public.offers(id) ON DELETE RESTRICT,
 terms_snapshot jsonb NOT NULL CHECK(jsonb_typeof(terms_snapshot)='object'),
 issue_until timestamptz,
 convert_until timestamptz,
 use_until timestamptz,
 max_issuances integer NOT NULL CHECK(max_issuances BETWEEN 1 AND 20),
 booking_required boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(entitlement_id,offer_id),
 CHECK(issue_until IS NULL OR convert_until IS NULL OR issue_until<=convert_until),
 CHECK(convert_until IS NULL OR use_until IS NULL OR convert_until<=use_until)
);
CREATE TABLE public.passport_cancellation_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL REFERENCES public.passport_orders(id),
 buyer_user_id uuid NOT NULL REFERENCES auth.users(id),
 reason text,
 status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','under_review','refunded','resolved')),
 statutory_withdrawal boolean NOT NULL DEFAULT false,
 requested_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 resolution_notes text,
 UNIQUE(order_id)
);
CREATE TABLE public.passport_benefit_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 entitlement_id uuid NOT NULL REFERENCES public.passport_entitlements(id),
 offer_id uuid NOT NULL REFERENCES public.offers(id),
 reported_by uuid NOT NULL REFERENCES auth.users(id),
 reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 4 AND 2000),
 requested_remedy text CHECK(requested_remedy IN ('fulfillment','equivalent','rescission_refund')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','under_review','resolved')),
 resolution_notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 resolved_at timestamptz
);

ALTER TABLE public.coupon_instances
 ADD COLUMN IF NOT EXISTS passport_entitlement_id uuid REFERENCES public.passport_entitlements(id),
 ADD COLUMN IF NOT EXISTS eligible_base_cents integer,
 ADD COLUMN IF NOT EXISTS applied_discount_cents integer;

ALTER TABLE public.coupon_redemptions
 ADD COLUMN IF NOT EXISTS applied_discount_cents integer,
 ADD COLUMN IF NOT EXISTS eligible_base_cents integer;

ALTER TABLE public.coupon_instances
 ADD CONSTRAINT mp_coupon_eligible_base CHECK(eligible_base_cents IS NULL OR eligible_base_cents>=0),
 ADD CONSTRAINT mp_coupon_applied_value CHECK(applied_discount_cents IS NULL OR applied_discount_cents>=0);
ALTER TABLE public.coupon_redemptions
 ADD CONSTRAINT mp_redemption_discount CHECK(applied_discount_cents IS NULL OR applied_discount_cents>=0),
 ADD CONSTRAINT mp_redemption_base CHECK(eligible_base_cents IS NULL OR eligible_base_cents>=0);

DO $block$
DECLARE t text;
BEGIN
 FOR t IN SELECT unnest(ARRAY[
 'passport_products','passport_product_benefits','passport_orders',
 'passport_entitlements','passport_entitlement_benefits',
 'passport_cancellation_requests','passport_benefit_incidents'])
 LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t); END LOOP;
END $block$;
REVOKE ALL ON public.passport_products,public.passport_product_benefits,
 public.passport_orders,public.passport_entitlements,public.passport_entitlement_benefits,
 public.passport_cancellation_requests,public.passport_benefit_incidents FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.passport_products,public.passport_product_benefits TO anon,authenticated;
CREATE POLICY mp_passports_public_catalog ON public.passport_products FOR SELECT TO anon,authenticated
USING(is_published);
CREATE POLICY mp_passport_benefits_public_catalog ON public.passport_product_benefits FOR SELECT TO anon,authenticated
USING(EXISTS(SELECT 1 FROM public.passport_products p WHERE p.id=product_id AND p.is_published));
GRANT SELECT ON public.passport_orders,public.passport_entitlements,public.passport_entitlement_benefits,
 public.passport_cancellation_requests TO authenticated;
CREATE POLICY mp_my_passport_orders ON public.passport_orders FOR SELECT TO authenticated
USING(buyer_user_id=(SELECT auth.uid()));
CREATE POLICY mp_my_passport_entitlements ON public.passport_entitlements FOR SELECT TO authenticated
USING(user_id=(SELECT auth.uid()));
CREATE POLICY mp_my_passport_entitlement_benefits ON public.passport_entitlement_benefits FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.passport_entitlements e WHERE e.id=entitlement_id AND e.user_id=(SELECT auth.uid())));
CREATE POLICY mp_my_passport_cancellations ON public.passport_cancellation_requests FOR SELECT TO authenticated
USING(buyer_user_id=(SELECT auth.uid()));
CREATE INDEX passport_orders_buyer ON public.passport_orders(buyer_user_id,created_at DESC);
CREATE INDEX passport_benefits_offer ON public.passport_product_benefits(offer_id);
CREATE INDEX passport_entitlement_benefits_offer ON public.passport_entitlement_benefits(offer_id);
CREATE INDEX coupon_passport_entitlement_idx ON public.coupon_instances(passport_entitlement_id);
;

-- 20261111003059 marapass_v10_offer_immutable_terms_and_discount_engine

-- Immutable commercial terms once exposed; no unilateral withdrawal of
-- benefits attached to a paid passport or to an already issued coupon.
CREATE FUNCTION private.mp_guard_offer_contract()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.is_published OR EXISTS(SELECT 1 FROM public.passport_product_benefits WHERE offer_id=OLD.id)
     OR EXISTS(SELECT 1 FROM public.coupon_instances WHERE offer_id=OLD.id)
  THEN RAISE EXCEPTION 'offer may not be deleted; withdraw through a lawful resolution process';END IF;
  RETURN OLD;
 END IF;

 IF OLD.is_published AND
  (
    NEW.title IS DISTINCT FROM OLD.title
    OR NEW.description IS DISTINCT FROM OLD.description
    OR NEW.discount_type IS DISTINCT FROM OLD.discount_type
    OR NEW.discount_value IS DISTINCT FROM OLD.discount_value
    OR NEW.currency IS DISTINCT FROM OLD.currency
    OR NEW.access_scope IS DISTINCT FROM OLD.access_scope
    OR NEW.eligible_items IS DISTINCT FROM OLD.eligible_items
    OR NEW.calculation_base IS DISTINCT FROM OLD.calculation_base
    OR NEW.minimum_purchase_cents IS DISTINCT FROM OLD.minimum_purchase_cents
    OR NEW.maximum_discount_cents IS DISTINCT FROM OLD.maximum_discount_cents
    OR NEW.fixed_use_policy IS DISTINCT FROM OLD.fixed_use_policy
    OR NEW.issue_until IS DISTINCT FROM OLD.issue_until
    OR NEW.convert_until IS DISTINCT FROM OLD.convert_until
    OR NEW.use_until IS DISTINCT FROM OLD.use_until
    OR NEW.advance_booking_required IS DISTINCT FROM OLD.advance_booking_required
    OR NEW.per_user_limit IS DISTINCT FROM OLD.per_user_limit
    OR NEW.max_issuances IS DISTINCT FROM OLD.max_issuances
  ) THEN
   RAISE EXCEPTION 'published commercial terms are immutable; create a new offer/version';
 END IF;
 IF OLD.is_published AND NOT NEW.is_published AND EXISTS (
   SELECT 1 FROM public.passport_entitlement_benefits eb
   JOIN public.passport_entitlements e ON e.id=eb.entitlement_id
   WHERE eb.offer_id=OLD.id AND e.status IN ('active','pending_activation')
 ) THEN
   RAISE EXCEPTION 'paid passport benefit cannot be silently removed';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_offer_contract_before_update_delete
BEFORE UPDATE OR DELETE ON public.offers
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_offer_contract();

CREATE FUNCTION private.mp_guard_passport_terms()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.is_published OR EXISTS(SELECT 1 FROM public.passport_orders WHERE product_id=OLD.id)
  THEN RAISE EXCEPTION 'published/contracted passport cannot be deleted'; END IF;
  RETURN OLD;
 END IF;
 IF OLD.is_published AND (
  NEW.name IS DISTINCT FROM OLD.name OR NEW.description IS DISTINCT FROM OLD.description
  OR NEW.price_cents IS DISTINCT FROM OLD.price_cents
  OR NEW.validity_start_rule IS DISTINCT FROM OLD.validity_start_rule
  OR NEW.duration_days IS DISTINCT FROM OLD.duration_days
  OR NEW.fixed_starts_at IS DISTINCT FROM OLD.fixed_starts_at
  OR NEW.fixed_ends_at IS DISTINCT FROM OLD.fixed_ends_at
  OR NEW.activation_deadline_days IS DISTINCT FROM OLD.activation_deadline_days
  OR NEW.booking_explanation IS DISTINCT FROM OLD.booking_explanation
  OR NEW.included_benefits_explanation IS DISTINCT FROM OLD.included_benefits_explanation
  OR NEW.legal_terms IS DISTINCT FROM OLD.legal_terms
 ) THEN RAISE EXCEPTION 'published passport terms are immutable; create a new version'; END IF;
 IF OLD.is_published AND NOT NEW.is_published AND EXISTS (
   SELECT 1 FROM public.passport_orders o WHERE o.product_id=OLD.id AND o.status='paid'
 ) THEN RAISE EXCEPTION 'passport with paid orders cannot be withdrawn without remedy';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_passport_terms_before_update_delete
BEFORE UPDATE OR DELETE ON public.passport_products
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_terms();

CREATE FUNCTION private.mp_guard_passport_benefit_config()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.product_id ELSE NEW.product_id END;
 IF EXISTS(SELECT 1 FROM public.passport_products p WHERE p.id=v_id AND p.is_published)
    OR EXISTS(SELECT 1 FROM public.passport_orders o WHERE o.product_id=v_id)
 THEN RAISE EXCEPTION 'cannot change benefits of published or contracted passport; create a new version'; END IF;
 IF TG_OP='INSERT' OR TG_OP='UPDATE' THEN
   IF NOT EXISTS(SELECT 1 FROM public.offers o WHERE o.id=NEW.offer_id AND o.access_scope='passport')
   THEN RAISE EXCEPTION 'passport benefit requires passport-exclusive offer'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE TRIGGER mp_guard_passport_benefit_config_before_write
BEFORE INSERT OR UPDATE OR DELETE ON public.passport_product_benefits
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_benefit_config();

CREATE FUNCTION private.mp_guard_publish_passport()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.is_published AND NOT OLD.is_published THEN
  IF NOT EXISTS (
   SELECT 1 FROM public.passport_product_benefits pb JOIN public.offers o ON o.id=pb.offer_id
   WHERE pb.product_id=NEW.id AND o.is_published AND o.access_scope='passport'
  ) THEN RAISE EXCEPTION 'passport requires published benefits before publication'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_publish_passport_before_update
BEFORE UPDATE OF is_published ON public.passport_products
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_publish_passport();

CREATE FUNCTION public.mp_calculate_coupon_discount(
 p_discount_type text,p_discount_value numeric,p_eligible_base_cents integer,
 p_minimum_purchase_cents integer,p_maximum_discount_cents integer
)
RETURNS integer LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_discount integer;
BEGIN
 IF p_eligible_base_cents IS NULL OR p_eligible_base_cents<0 OR p_discount_value<=0
   OR p_discount_type NOT IN ('percent','fixed') OR p_minimum_purchase_cents<0
   OR (p_maximum_discount_cents IS NOT NULL AND p_maximum_discount_cents<=0)
 THEN RAISE EXCEPTION 'invalid discount calculation'; END IF;
 IF p_eligible_base_cents<p_minimum_purchase_cents THEN RETURN 0; END IF;
 v_discount:=CASE WHEN p_discount_type='percent'
  THEN round(p_eligible_base_cents::numeric*p_discount_value/100)::int
  ELSE round(p_discount_value*100)::int END;
 RETURN least(p_eligible_base_cents,v_discount,coalesce(p_maximum_discount_cents,2147483647));
END $$;
REVOKE ALL ON FUNCTION public.mp_calculate_coupon_discount(text,numeric,integer,integer,integer)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_calculate_coupon_discount(text,numeric,integer,integer,integer)
 TO service_role;
;

-- 20261111003215 marapass_v10_coupon_issuance_and_redemption_rules

-- New issuance pipeline: immutable snapshot, passport entitlement, issuance
-- and conversion deadlines and same instance through validation.
CREATE FUNCTION public.mp_issue_coupon_v2(
 p_offer_id uuid,p_user_id uuid,p_idempotency_key text,
 p_reservation_id uuid DEFAULT NULL,p_passport_entitlement_id uuid DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_offer record;
 v_old public.coupon_instances%rowtype;
 v_benefit public.passport_entitlement_benefits%rowtype;
 v_id uuid;
 v_code text;
 v_issuance_until timestamptz;
 v_conversion_until timestamptz;
 v_use_until timestamptz;
 v_snapshot jsonb;
BEGIN
 IF p_user_id IS NULL OR length(coalesce(p_idempotency_key,'')) NOT BETWEEN 16 AND 180
 THEN RAISE EXCEPTION 'invalid issuance request';END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coupon-issue:'||p_idempotency_key,0));
 SELECT * INTO v_old FROM public.coupon_instances WHERE issuance_key=p_idempotency_key;
 IF FOUND THEN
  IF v_old.offer_id<>p_offer_id OR v_old.beneficiary_user_id<>p_user_id
    OR v_old.reservation_id IS DISTINCT FROM p_reservation_id
    OR v_old.passport_entitlement_id IS DISTINCT FROM p_passport_entitlement_id
  THEN RAISE EXCEPTION 'idempotency key reused with another issuance';END IF;
  RETURN v_old.id;
 END IF;
 SELECT o.*, e.partner_id,e.is_active,p.status partner_status
 INTO v_offer FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE o.id=p_offer_id FOR UPDATE OF o;

 IF NOT FOUND OR NOT v_offer.is_published OR NOT v_offer.is_active
   OR v_offer.partner_status<>'approved'
   OR (v_offer.starts_at IS NOT NULL AND v_offer.starts_at>now())
   OR (v_offer.ends_at IS NOT NULL AND v_offer.ends_at<=now()) THEN
  RAISE EXCEPTION 'offer unavailable';
 END IF;
 v_issuance_until:=v_offer.issue_until;
 v_conversion_until:=v_offer.convert_until;
 v_use_until:=v_offer.use_until;
 IF v_offer.access_scope='passport' THEN
  IF p_passport_entitlement_id IS NULL THEN RAISE EXCEPTION 'paid passport required'; END IF;
  SELECT b.* INTO v_benefit FROM public.passport_entitlement_benefits b
   JOIN public.passport_entitlements e ON e.id=b.entitlement_id
   JOIN public.passport_orders ord ON ord.id=e.order_id
   WHERE b.entitlement_id=p_passport_entitlement_id
     AND b.offer_id=p_offer_id
     AND e.user_id=p_user_id
     AND e.status='active'
     AND e.valid_from<=now() AND e.valid_until>now()
     AND ord.status='paid' AND ord.payment_confirmed_at IS NOT NULL
     AND b.issue_until>now();
  IF NOT FOUND THEN RAISE EXCEPTION 'eligible active paid passport not found'; END IF;
  v_issuance_until:=least(v_issuance_until,v_benefit.issue_until);
  v_conversion_until:=least(v_conversion_until,v_benefit.convert_until);
  v_use_until:=least(v_use_until,v_benefit.use_until);
  IF (SELECT count(*) FROM public.coupon_instances ci
   WHERE ci.offer_id=p_offer_id AND ci.passport_entitlement_id=p_passport_entitlement_id
      AND ci.status<>'cancelled')>=v_benefit.max_issuances THEN
     RAISE EXCEPTION 'passport benefit issuance limit reached'; END IF;
 ELSIF p_passport_entitlement_id IS NOT NULL THEN
  RAISE EXCEPTION 'public coupon does not require paid passport';
 END IF;
 IF v_issuance_until IS NULL OR v_issuance_until<=now()
   OR v_conversion_until IS NULL OR v_conversion_until<=now()
   OR v_use_until IS NULL OR v_use_until<=now() THEN
  RAISE EXCEPTION 'offer benefit window expired';
 END IF;
 IF v_offer.max_issuances IS NOT NULL AND
   (SELECT count(*) FROM public.coupon_instances WHERE offer_id=p_offer_id)>=v_offer.max_issuances
 THEN RAISE EXCEPTION 'offer issuance limit reached'; END IF;
 IF (SELECT count(*) FROM public.coupon_instances
     WHERE offer_id=p_offer_id AND beneficiary_user_id=p_user_id AND status<>'cancelled'
    )>=v_offer.per_user_limit THEN
   RAISE EXCEPTION 'user offer limit reached';END IF;
 IF p_reservation_id IS NOT NULL AND NOT EXISTS (
   SELECT 1 FROM public.reservations r
   WHERE r.id=p_reservation_id AND r.user_id=p_user_id
     AND r.status='confirmed' AND r.experience_id=v_offer.experience_id
 ) THEN RAISE EXCEPTION 'invalid linked reservation';END IF;

 v_snapshot:=jsonb_build_object(
  'offer_id',v_offer.id,'commercial_terms_version',v_offer.commercial_terms_version,
  'access_scope',v_offer.access_scope,'eligible_items',v_offer.eligible_items,
  'calculation_base',v_offer.calculation_base,
  'minimum_purchase_cents',v_offer.minimum_purchase_cents,
  'maximum_discount_cents',v_offer.maximum_discount_cents,
  'fixed_use_policy',v_offer.fixed_use_policy,
  'issuing_deadline',v_issuance_until,
  'conversion_deadline',v_conversion_until,
  'use_deadline',v_use_until,
  'advance_booking_required',v_offer.advance_booking_required,
  'disclosure_extra',v_offer.disclosure_extra,
  'nominal_not_cash',true,
  'passport_no_individual_issuance_charge',v_offer.access_scope='passport'
 );
 v_code:='MP-'||upper(substr(encode(extensions.gen_random_bytes(10),'hex'),1,16));
 INSERT INTO public.coupon_instances(
  offer_id,beneficiary_user_id,reservation_id,issuance_key,display_code,
  offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,expires_at,
  conditions_snapshot,passport_entitlement_id
 )
 VALUES(
  p_offer_id,p_user_id,p_reservation_id,p_idempotency_key,v_code,
  v_offer.title,v_offer.discount_type,v_offer.discount_value,v_conversion_until,
  v_snapshot,p_passport_entitlement_id
 ) RETURNING id INTO v_id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.mp_issue_coupon_v2(uuid,uuid,text,uuid,uuid)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_issue_coupon_v2(uuid,uuid,text,uuid,uuid)
TO service_role;

-- Keep existing service signature but route all calls through new checks.
CREATE OR REPLACE FUNCTION public.issue_coupon(
 p_offer_id uuid,p_user_id uuid,p_idempotency_key text,p_reservation_id uuid DEFAULT NULL
) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=''
AS $$
 SELECT public.mp_issue_coupon_v2(p_offer_id,p_user_id,p_idempotency_key,p_reservation_id,NULL::uuid)
$$;
REVOKE ALL ON FUNCTION public.issue_coupon(uuid,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.issue_coupon(uuid,uuid,text,uuid) TO service_role;

-- Validation calculates the *actual* applied discount against eligible
-- transaction base; a nominal coupon cannot turn into cash or be reused.
CREATE OR REPLACE FUNCTION public.redeem_coupon(
 p_coupon_instance_id uuid,p_validator_user_id uuid,p_idempotency_key text,
 p_transaction_amount_cents integer DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_old public.coupon_redemptions%rowtype;
 v_coupon public.coupon_instances%rowtype;
 v_partner_id uuid;
 v_establishment_id uuid;
 v_partner_status text;
 v_establishment_active boolean;
 v_redemption_id uuid;
 v_min integer;
 v_max integer;
 v_discount integer;
BEGIN
 IF p_validator_user_id IS NULL
   OR length(coalesce(p_idempotency_key,'')) NOT BETWEEN 16 AND 180
   OR p_transaction_amount_cents IS NULL OR p_transaction_amount_cents<0
 THEN RAISE EXCEPTION 'eligible purchase base and valid request are required'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coupon-redeem:'||p_idempotency_key,0));
 SELECT * INTO v_old FROM public.coupon_redemptions WHERE idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_old.coupon_instance_id<>p_coupon_instance_id
     OR v_old.validated_by_user_id<>p_validator_user_id
     OR v_old.transaction_amount_cents IS DISTINCT FROM p_transaction_amount_cents THEN
    RAISE EXCEPTION 'validation idempotency key reused with another transaction';END IF;
  RETURN v_old.id;
 END IF;
 SELECT * INTO v_coupon FROM public.coupon_instances WHERE id=p_coupon_instance_id FOR UPDATE;
 IF NOT FOUND OR v_coupon.status<>'issued' OR v_coupon.expires_at<=now() THEN
  RAISE EXCEPTION 'coupon not valid for conversion';END IF;
 SELECT e.partner_id,e.id,p.status,e.is_active INTO
 v_partner_id,v_establishment_id,v_partner_status,v_establishment_active
 FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id WHERE o.id=v_coupon.offer_id;
 IF v_partner_status<>'approved' OR NOT v_establishment_active OR NOT EXISTS(
  SELECT 1 FROM public.partners p WHERE p.id=v_partner_id AND(
   p.owner_user_id=p_validator_user_id OR EXISTS(
   SELECT 1 FROM public.partner_members m WHERE m.partner_id=p.id
     AND m.user_id=p_validator_user_id AND m.is_active
     AND m.member_role IN ('manager','validator'))
  )
 ) THEN RAISE EXCEPTION 'partner or validator unauthorized'; END IF;
 v_min:=COALESCE((v_coupon.conditions_snapshot->>'minimum_purchase_cents')::int,0);
 v_max:=(v_coupon.conditions_snapshot->>'maximum_discount_cents')::int;
 v_discount:=public.mp_calculate_coupon_discount(
  v_coupon.discount_type_snapshot,v_coupon.discount_value_snapshot,
  p_transaction_amount_cents,v_min,v_max);
 IF v_discount<=0 THEN RAISE EXCEPTION 'purchase not eligible for discount';END IF;
 INSERT INTO public.coupon_redemptions(
  coupon_instance_id,partner_id,establishment_id,validated_by_user_id,idempotency_key,
  transaction_amount_cents,eligible_base_cents,applied_discount_cents
 ) VALUES(
  p_coupon_instance_id,v_partner_id,v_establishment_id,p_validator_user_id,
  p_idempotency_key,p_transaction_amount_cents,p_transaction_amount_cents,v_discount
 ) RETURNING id INTO v_redemption_id;
 UPDATE public.coupon_instances SET status='redeemed',redeemed_at=now(),
   eligible_base_cents=p_transaction_amount_cents,applied_discount_cents=v_discount
 WHERE id=p_coupon_instance_id;
 INSERT INTO public.checkins(
 user_id,establishment_id,reservation_id,coupon_redemption_id,method)
 VALUES(v_coupon.beneficiary_user_id,v_establishment_id,v_coupon.reservation_id,v_redemption_id,'coupon');
 RETURN v_redemption_id;
END $$;
REVOKE ALL ON FUNCTION public.redeem_coupon(uuid,uuid,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_coupon(uuid,uuid,text,integer) TO service_role;
;

-- 20261111003412 marapass_v10_admin_commercial_config_rpc

CREATE FUNCTION public.mp_admin_create_offer(
 p_admin_user_id uuid,p_data jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_offer uuid; v_est uuid;
 v_type text; v_access text; v_title text;
 v_value numeric; v_publish boolean;
 v_issue timestamptz;v_convert timestamptz;v_use timestamptz;
 v_min integer;v_max integer;
 v_partner_status text;v_est_active boolean;v_est_public boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>12000
 THEN RAISE EXCEPTION 'invalid offer payload';END IF;
 v_est:=(p_data->>'establishment_id')::uuid;
 SELECT p.status,e.is_active,e.is_public INTO v_partner_status,v_est_active,v_est_public
 FROM public.establishments e JOIN public.partners p ON p.id=e.partner_id WHERE e.id=v_est;
 IF NOT FOUND OR NOT v_est_active THEN RAISE EXCEPTION 'establishment not available';END IF;
 v_type:=p_data->>'discount_type';v_access:=p_data->>'access_scope';
 v_title:=trim(coalesce(p_data->>'title',''));v_value:=(p_data->>'discount_value')::numeric;
 v_publish:=coalesce((p_data->>'publish')::boolean,false);
 v_issue:=(p_data->>'issue_until')::timestamptz;
 v_convert:=(p_data->>'convert_until')::timestamptz;
 v_use:=(p_data->>'use_until')::timestamptz;
 v_min:=coalesce((p_data->>'minimum_purchase_cents')::int,0);
 v_max:=(p_data->>'maximum_discount_cents')::int;
 IF length(v_title) NOT BETWEEN 3 AND 160
   OR v_type NOT IN ('percent','fixed')
   OR v_access NOT IN ('public','passport')
   OR v_value IS NULL OR v_value<=0
   OR (v_type='percent' AND v_value>100)
   OR v_min<0 OR (v_max IS NOT NULL AND v_max<=0)
   OR length(trim(coalesce(p_data->>'eligible_items','')))<3
   OR length(trim(coalesce(p_data->>'calculation_base','')))<3
   OR v_issue IS NULL OR v_convert IS NULL OR v_use IS NULL
   OR v_issue<=now() OR v_convert<v_issue OR v_use<v_convert
 THEN RAISE EXCEPTION 'incomplete or inconsistent commercial conditions';END IF;
 IF v_publish AND (v_partner_status<>'approved' OR NOT v_est_public) THEN
   RAISE EXCEPTION 'partner and establishment must be approved/published';
 END IF;
 INSERT INTO public.offers (
  establishment_id,title,description,discount_type,discount_value,currency,
  is_published,access_scope,eligible_items,calculation_base,minimum_purchase_cents,
  maximum_discount_cents,fixed_use_policy,issue_until,convert_until,use_until,
  advance_booking_required,disclosure_extra,per_user_limit,max_issuances
 ) VALUES (
  v_est,v_title,NULLIF(trim(coalesce(p_data->>'description','')),''),
  v_type,v_value,'BRL',v_publish,v_access,
  trim(p_data->>'eligible_items'),trim(p_data->>'calculation_base'),
  v_min,v_max,'single_use_no_change',v_issue,v_convert,v_use,
  coalesce((p_data->>'advance_booking_required')::boolean,false),
  NULLIF(trim(coalesce(p_data->>'disclosure_extra','')),''),
  coalesce((p_data->>'per_user_limit')::int,1),
  (p_data->>'max_issuances')::int
 ) RETURNING id INTO v_offer;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('offer',v_offer,CASE WHEN v_publish THEN 'created_published' ELSE 'created_draft' END,
 p_admin_user_id,jsonb_build_object('access_scope',v_access,'rules_version',1));
 RETURN jsonb_build_object('offer_id',v_offer,'published',v_publish);
END $$;

CREATE FUNCTION public.mp_admin_create_passport_draft(
 p_admin_user_id uuid,p_data jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;v_rule text;v_duration integer;v_from timestamptz;v_until timestamptz;
 v_activation integer;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>12000
 THEN RAISE EXCEPTION 'invalid passport payload';END IF;
 v_rule:=p_data->>'validity_start_rule';
 v_duration:=(p_data->>'duration_days')::int;
 v_from:=(p_data->>'fixed_starts_at')::timestamptz;
 v_until:=(p_data->>'fixed_ends_at')::timestamptz;
 v_activation:=(p_data->>'activation_deadline_days')::int;
 INSERT INTO public.passport_products(
  name,description,price_cents,validity_start_rule,duration_days,
  fixed_starts_at,fixed_ends_at,activation_deadline_days,
  booking_explanation,included_benefits_explanation,legal_terms,is_published
 )VALUES(
  trim(p_data->>'name'),trim(p_data->>'description'),
  (p_data->>'price_cents')::int,v_rule,
  CASE WHEN v_rule='fixed' THEN NULL ELSE v_duration END,
  CASE WHEN v_rule='fixed' THEN v_from ELSE NULL END,
  CASE WHEN v_rule='fixed' THEN v_until ELSE NULL END,
  CASE WHEN v_rule='activation' THEN v_activation ELSE NULL END,
  coalesce(nullif(trim(p_data->>'booking_explanation'),''),
    'Consulte a disponibilidade e a exigência de agendamento de cada parceiro.'),
  coalesce(p_data->>'included_benefits_explanation',''),
  'O direito de arrependimento nas contratações à distância seguirá o art. 49 do CDC, sem renúncia pelo mero acesso ou emissão de cupom.',
  false
 ) RETURNING id INTO v_id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',v_id,'created_draft',p_admin_user_id,'{}');
 RETURN jsonb_build_object('product_id',v_id,'published',false);
END $$;

CREATE FUNCTION public.mp_admin_attach_passport_benefit(
 p_admin_user_id uuid,p_product_id uuid,p_offer_id uuid,p_issue_days integer,
 p_convert_days integer,p_use_days integer,p_max_per_holder integer,
 p_booking_required boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF NOT EXISTS(SELECT 1 FROM public.passport_products WHERE id=p_product_id AND NOT is_published)
 OR NOT EXISTS(SELECT 1 FROM public.offers o JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE o.id=p_offer_id AND o.is_published AND o.access_scope='passport'
 AND e.is_public AND e.is_active AND p.status='approved') THEN
 RAISE EXCEPTION 'draft passport and active exclusive offer required';END IF;
 INSERT INTO public.passport_product_benefits(
  product_id,offer_id,issue_window_days,convert_window_days,use_window_days,
  max_per_holder,booking_required
 ) VALUES(p_product_id,p_offer_id,p_issue_days,p_convert_days,p_use_days,
 p_max_per_holder,p_booking_required)
 RETURNING id INTO v_id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'benefit_attached',p_admin_user_id,
 jsonb_build_object('offer_id',p_offer_id,'benefit_id',v_id));
 RETURN jsonb_build_object('benefit_id',v_id,'product_id',p_product_id);
END $$;
CREATE FUNCTION public.mp_admin_publish_passport(
 p_admin_user_id uuid,p_product_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_count integer;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT count(*) INTO v_count FROM public.passport_product_benefits pb
 JOIN public.offers o ON o.id=pb.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE pb.product_id=p_product_id AND o.is_published AND o.access_scope='passport'
 AND e.is_active AND e.is_public AND p.status='approved';
 IF v_count=0 THEN RAISE EXCEPTION 'a published exclusive offer is required';END IF;
 UPDATE public.passport_products SET is_published=true,updated_at=now()
 WHERE id=p_product_id AND NOT is_published;
 IF NOT FOUND THEN RAISE EXCEPTION 'passport not in draft state';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'published',p_admin_user_id,
 jsonb_build_object('benefit_count',v_count));
 RETURN jsonb_build_object('product_id',p_product_id,'published',true);
END $$;

CREATE POLICY mp_admin_read_all_passports ON public.passport_products FOR SELECT TO authenticated
USING((SELECT auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid())
 AND s.is_active AND s.staff_role='admin'));
CREATE POLICY mp_admin_read_all_passport_benefits ON public.passport_product_benefits FOR SELECT TO authenticated
USING((SELECT auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid())
 AND s.is_active AND s.staff_role='admin'));

REVOKE ALL ON FUNCTION public.mp_admin_create_offer(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_create_passport_draft(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_attach_passport_benefit(uuid,uuid,uuid,integer,integer,integer,integer,boolean) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_publish_passport(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_create_offer(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_create_passport_draft(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_attach_passport_benefit(uuid,uuid,uuid,integer,integer,integer,integer,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_publish_passport(uuid,uuid) TO service_role;
;

-- 20261111003616 marapass_v10_passport_checkout_rights_refund_requests

-- Freezes the checkout contract and offers a traceable cancellation path.
CREATE FUNCTION public.mp_prepare_passport_order(
 p_user_id uuid,p_product_id uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_product public.passport_products%rowtype;v_existing public.passport_orders%rowtype;
 v_snapshot jsonb;v_benefits jsonb;v_order uuid;
BEGIN
 IF p_user_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'user and intent key required';END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(
 pg_catalog.hashtextextended('passport-order:'||p_user_id::text||':'||p_request_key::text,0));
 SELECT * INTO v_existing FROM public.passport_orders
 WHERE buyer_user_id=p_user_id AND purchase_intent_key=p_request_key;
 IF FOUND THEN
  IF v_existing.product_id<>p_product_id THEN RAISE EXCEPTION 'reused checkout key';END IF;
  RETURN jsonb_build_object('order_id',v_existing.id,'status',v_existing.status,
   'price_cents',v_existing.price_cents,'terms_snapshot',v_existing.terms_snapshot,
   'payment_enabled',false,'already_prepared',true);
 END IF;
 SELECT * INTO v_product FROM public.passport_products WHERE id=p_product_id AND is_published;
 IF NOT FOUND OR (v_product.validity_start_rule='fixed' AND v_product.fixed_ends_at<=now())
 THEN RAISE EXCEPTION 'passport not available';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
 'offer_id',o.id,'offer_title',o.title,'partner',p.trade_name,
 'establishment',e.name,'eligible_items',o.eligible_items,
 'base',o.calculation_base,'discount_type',o.discount_type,
 'discount_value',o.discount_value,'minimum_purchase_cents',o.minimum_purchase_cents,
 'maximum_discount_cents',o.maximum_discount_cents,
 'fixed_use_policy',o.fixed_use_policy,'advance_booking_required',o.advance_booking_required,
 'issue_window_days',b.issue_window_days,'convert_window_days',b.convert_window_days,
 'use_window_days',b.use_window_days,'limit',b.max_per_holder,'requires_booking',b.booking_required,
 'issue_until',o.issue_until,'convert_until',o.convert_until,'use_until',o.use_until
 ) ORDER BY o.title),'[]'::jsonb) INTO v_benefits
 FROM public.passport_product_benefits b JOIN public.offers o ON o.id=b.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id WHERE b.product_id=p_product_id;
 IF jsonb_array_length(v_benefits)=0 THEN RAISE EXCEPTION 'no passport benefits';END IF;
 v_snapshot:=jsonb_build_object(
  'product_id',v_product.id,'terms_version',v_product.terms_version,
  'name',v_product.name,'description',v_product.description,'price_cents',v_product.price_cents,
  'currency',v_product.currency,'validity_start_rule',v_product.validity_start_rule,
  'duration_days',v_product.duration_days,'fixed_starts_at',v_product.fixed_starts_at,
  'fixed_ends_at',v_product.fixed_ends_at,'activation_deadline_days',v_product.activation_deadline_days,
  'booking_explanation',v_product.booking_explanation,
  'included_benefits_explanation',v_product.included_benefits_explanation,
  'legal_terms',v_product.legal_terms,'benefits',v_benefits,
  'coupon_issuance_individually_free',true,
  'services_not_included_in_purchase',true,
  'right_of_withdrawal_no_automatic_waiver',true,
  'captured_at',now());
 INSERT INTO public.passport_orders(
  buyer_user_id,product_id,purchase_intent_key,price_cents,currency,status,terms_snapshot
 ) VALUES(p_user_id,p_product_id,p_request_key,v_product.price_cents,'BRL','pending_payment',v_snapshot)
 RETURNING id INTO v_order;
 RETURN jsonb_build_object('order_id',v_order,'status','pending_payment',
  'price_cents',v_product.price_cents,'terms_snapshot',v_snapshot,
  'payment_enabled',false,'already_prepared',false);
END $$;

CREATE FUNCTION public.mp_record_verified_passport_payment(
 p_order_id uuid,p_provider text,p_provider_reference text,p_verified_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE o public.passport_orders%rowtype;p public.passport_products%rowtype;
 v_entitlement uuid;v_from timestamptz;v_until timestamptz;v_status text;
BEGIN
 -- Service-role only; caller MUST verify and reconcile signed PSP webhook
 -- before invoking this function. There is no consumer endpoint for it.
 IF length(trim(coalesce(p_provider,'')))<2 OR length(trim(coalesce(p_provider_reference,'')))<8
 OR p_verified_at IS NULL OR p_verified_at>now()+interval '5 minutes' THEN
  RAISE EXCEPTION 'verified payment evidence required';END IF;
 SELECT * INTO o FROM public.passport_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'order not found';END IF;
 IF o.status='paid' THEN
  IF o.provider_payment_reference IS DISTINCT FROM p_provider_reference
  THEN RAISE EXCEPTION 'payment mismatch'; END IF;
  RETURN jsonb_build_object('order_id',o.id,'status','paid','already_recorded',true);
 END IF;
 IF o.status<>'pending_payment' THEN RAISE EXCEPTION 'order not pending payment';END IF;
 SELECT * INTO p FROM public.passport_products WHERE id=o.product_id;
 UPDATE public.passport_orders SET status='paid',payment_provider=p_provider,
 provider_payment_reference=p_provider_reference,payment_confirmed_at=p_verified_at,
 updated_at=now() WHERE id=o.id;
 v_from:=CASE p.validity_start_rule WHEN 'purchase' THEN p_verified_at
   WHEN 'fixed' THEN p.fixed_starts_at ELSE NULL END;
 v_until:=CASE p.validity_start_rule WHEN 'purchase' THEN p_verified_at+(p.duration_days||' days')::interval
   WHEN 'fixed' THEN p.fixed_ends_at ELSE NULL END;
 v_status:=CASE WHEN p.validity_start_rule='activation' THEN 'pending_activation' ELSE 'active' END;
 INSERT INTO public.passport_entitlements(
 order_id,user_id,product_id,status,purchased_at,valid_from,valid_until
 ) VALUES(o.id,o.buyer_user_id,o.product_id,v_status,p_verified_at,v_from,v_until)
 RETURNING id INTO v_entitlement;
 INSERT INTO public.passport_entitlement_benefits(
  entitlement_id,offer_id,terms_snapshot,issue_until,convert_until,use_until,
  max_issuances,booking_required
 )
 SELECT v_entitlement,b.offer_id,
   benefit.value,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.issue_window_days||' days')::interval,(benefit.value->>'issue_until')::timestamptz) END,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.convert_window_days||' days')::interval,(benefit.value->>'convert_until')::timestamptz) END,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.use_window_days||' days')::interval,(benefit.value->>'use_until')::timestamptz) END,
   b.max_per_holder,b.booking_required
 FROM public.passport_product_benefits b
 JOIN jsonb_array_elements(o.terms_snapshot->'benefits') AS benefit(value)
   ON benefit.value->>'offer_id'=b.offer_id::text
 WHERE b.product_id=o.product_id;
 RETURN jsonb_build_object('order_id',o.id,'status','paid',
 'entitlement_id',v_entitlement,'requires_activation',v_status='pending_activation');
END $$;

CREATE FUNCTION public.mp_activate_passport(
 p_user_id uuid,p_entitlement_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE e public.passport_entitlements%rowtype;p public.passport_products%rowtype;v_at timestamptz;
BEGIN
 SELECT * INTO e FROM public.passport_entitlements WHERE id=p_entitlement_id FOR UPDATE;
 IF NOT FOUND OR e.user_id<>p_user_id THEN RAISE EXCEPTION 'passport not owned by user';END IF;
 IF e.status='active' THEN RETURN jsonb_build_object('entitlement_id',e.id,'status','active','already_active',true);END IF;
 SELECT * INTO p FROM public.passport_products WHERE id=e.product_id;
 IF p.validity_start_rule<>'activation' OR e.status<>'pending_activation' THEN
  RAISE EXCEPTION 'passport cannot be activated';
 END IF;
 IF e.purchased_at+(p.activation_deadline_days||' days')::interval<now() THEN
  RAISE EXCEPTION 'activation deadline reached; request customer support';
 END IF;
 v_at:=now();
 UPDATE public.passport_entitlements SET status='active',valid_from=v_at,
 valid_until=v_at+(p.duration_days||' days')::interval,activated_at=v_at WHERE id=e.id;
 UPDATE public.passport_entitlement_benefits eb SET
 issue_until=least(v_at+(pb.issue_window_days||' days')::interval,
  (eb.terms_snapshot->>'issue_until')::timestamptz),
 convert_until=least(v_at+(pb.convert_window_days||' days')::interval,
  (eb.terms_snapshot->>'convert_until')::timestamptz),
 use_until=least(v_at+(pb.use_window_days||' days')::interval,
  (eb.terms_snapshot->>'use_until')::timestamptz)
 FROM public.passport_product_benefits pb WHERE pb.offer_id=eb.offer_id
 AND pb.product_id=e.product_id AND eb.entitlement_id=e.id;
 RETURN jsonb_build_object('entitlement_id',e.id,'status','active','already_active',false);
END $$;

CREATE FUNCTION public.mp_request_passport_cancellation(
 p_user_id uuid,p_order_id uuid,p_reason text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE o public.passport_orders%rowtype;r public.passport_cancellation_requests%rowtype;
 v_stat boolean;
BEGIN
 SELECT * INTO o FROM public.passport_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR o.buyer_user_id<>p_user_id THEN RAISE EXCEPTION 'order not owned by user';END IF;
 IF o.status IN ('refunded','cancelled') THEN
  RETURN jsonb_build_object('order_id',o.id,'status',o.status,'already_completed',true);
 END IF;
 SELECT * INTO r FROM public.passport_cancellation_requests WHERE order_id=o.id;
 IF FOUND THEN RETURN jsonb_build_object('request_id',r.id,'status',r.status,
   'statutory_withdrawal',r.statutory_withdrawal,'already_requested',true); END IF;
 v_stat:=o.payment_confirmed_at IS NOT NULL AND now()<=o.payment_confirmed_at+interval '7 days';
 INSERT INTO public.passport_cancellation_requests(order_id,buyer_user_id,reason,statutory_withdrawal)
 VALUES(o.id,p_user_id,nullif(left(coalesce(p_reason,''),2000),''),v_stat) RETURNING * INTO r;
 UPDATE public.passport_orders SET status=CASE WHEN status='pending_payment' THEN 'cancelled'
    ELSE 'cancel_requested' END,updated_at=now() WHERE id=o.id;
 RETURN jsonb_build_object('request_id',r.id,'status','requested',
 'statutory_withdrawal',v_stat,
 'refund_executed',false,'next_step','manual_or_provider_refund_review');
END $$;

CREATE FUNCTION public.mp_report_passport_benefit_issue(
 p_user_id uuid,p_entitlement_id uuid,p_offer_id uuid,p_reason text,p_remedy text
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 IF length(trim(coalesce(p_reason,''))) NOT BETWEEN 4 AND 2000
  OR p_remedy NOT IN ('fulfillment','equivalent','rescission_refund')
 THEN RAISE EXCEPTION 'describe issue and choose a remedy';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.passport_entitlements e
 JOIN public.passport_entitlement_benefits b ON b.entitlement_id=e.id
 WHERE e.id=p_entitlement_id AND b.offer_id=p_offer_id AND e.user_id=p_user_id)
 THEN RAISE EXCEPTION 'benefit not within the user contract';END IF;
 INSERT INTO public.passport_benefit_incidents(
 entitlement_id,offer_id,reported_by,reason,requested_remedy
 )VALUES(p_entitlement_id,p_offer_id,p_user_id,trim(p_reason),p_remedy) RETURNING id INTO v_id;
 RETURN jsonb_build_object('incident_id',v_id,'status','open');
END $$;

CREATE FUNCTION private.mp_guard_passport_order_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.buyer_user_id IS DISTINCT FROM OLD.buyer_user_id
 OR NEW.product_id IS DISTINCT FROM OLD.product_id
 OR NEW.price_cents IS DISTINCT FROM OLD.price_cents
 OR NEW.currency IS DISTINCT FROM OLD.currency
 OR NEW.terms_snapshot IS DISTINCT FROM OLD.terms_snapshot
 OR NEW.purchase_intent_key IS DISTINCT FROM OLD.purchase_intent_key THEN
 RAISE EXCEPTION 'checkout contract snapshot cannot be altered';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_freeze_order_contract BEFORE UPDATE ON public.passport_orders
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_order_snapshot();

DO $b$
DECLARE f text;
BEGIN
 FOR f IN SELECT unnest(ARRAY[
 'mp_prepare_passport_order(uuid,uuid,uuid)',
 'mp_record_verified_passport_payment(uuid,text,text,timestamptz)',
 'mp_activate_passport(uuid,uuid)',
 'mp_request_passport_cancellation(uuid,uuid,text)',
 'mp_report_passport_benefit_issue(uuid,uuid,uuid,text,text)'
 ]) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC,anon,authenticated',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role',f);
 END LOOP;
END $b$;
;

-- 20261111003920 marapass_v10_fix_coupon_snapshot_trigger_collision

CREATE OR REPLACE FUNCTION private.capture_coupon_conditions()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_presentation jsonb;
BEGIN
 SELECT jsonb_build_object(
   'terms',o.description,'presentation',o.presentation,
   'establishment',e.name,'city',e.city,'address',e.street_address
 ) INTO v_presentation FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id WHERE o.id=NEW.offer_id;
 -- Previous trigger overwrote the new immutable commercial snapshot.
 -- Keep commercial conditions authoritative while retaining display context.
 NEW.conditions_snapshot:=COALESCE(v_presentation,'{}'::jsonb)
   || COALESCE(NEW.conditions_snapshot,'{}'::jsonb);
 RETURN NEW;
END $$;

CREATE FUNCTION private.mp_guard_coupon_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.offer_id IS DISTINCT FROM OLD.offer_id
 OR NEW.beneficiary_user_id IS DISTINCT FROM OLD.beneficiary_user_id
 OR NEW.reservation_id IS DISTINCT FROM OLD.reservation_id
 OR NEW.passport_entitlement_id IS DISTINCT FROM OLD.passport_entitlement_id
 OR NEW.issuance_key IS DISTINCT FROM OLD.issuance_key
 OR NEW.display_code IS DISTINCT FROM OLD.display_code
 OR NEW.offer_title_snapshot IS DISTINCT FROM OLD.offer_title_snapshot
 OR NEW.discount_type_snapshot IS DISTINCT FROM OLD.discount_type_snapshot
 OR NEW.discount_value_snapshot IS DISTINCT FROM OLD.discount_value_snapshot
 OR NEW.conditions_snapshot IS DISTINCT FROM OLD.conditions_snapshot
 OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
 OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
 THEN RAISE EXCEPTION 'issued coupon identity and commercial conditions are immutable';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_coupon_snapshot_before_update
BEFORE UPDATE ON public.coupon_instances FOR EACH ROW
EXECUTE FUNCTION private.mp_guard_coupon_snapshot();
;

-- 20261111005321 marapass_v10_precheckout_guarantee_all_benefits

CREATE OR REPLACE FUNCTION public.mp_admin_publish_passport(p_admin_user_id uuid, p_product_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_count integer;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT count(*) INTO v_count FROM public.passport_product_benefits pb
 JOIN public.offers o ON o.id=pb.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE pb.product_id=p_product_id AND o.is_published AND o.access_scope='passport'
 AND e.is_active AND e.is_public AND p.status='approved';
 IF v_count=0 THEN RAISE EXCEPTION 'a published exclusive offer is required';END IF;
 IF v_count<>(SELECT count(*) FROM public.passport_product_benefits WHERE product_id=p_product_id)
 THEN RAISE EXCEPTION 'all included benefits and partners must be available before publication';END IF;
 UPDATE public.passport_products SET is_published=true,updated_at=now()
 WHERE id=p_product_id AND NOT is_published;
 IF NOT FOUND THEN RAISE EXCEPTION 'passport not in draft state';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'published',p_admin_user_id,
 jsonb_build_object('benefit_count',v_count));
 RETURN jsonb_build_object('product_id',p_product_id,'published',true);
END $function$;
CREATE OR REPLACE FUNCTION public.mp_prepare_passport_order(p_user_id uuid, p_product_id uuid, p_request_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_product public.passport_products%rowtype;v_existing public.passport_orders%rowtype;
 v_snapshot jsonb;v_benefits jsonb;v_order uuid;
BEGIN
 IF p_user_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'user and intent key required';END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(
 pg_catalog.hashtextextended('passport-order:'||p_user_id::text||':'||p_request_key::text,0));
 SELECT * INTO v_existing FROM public.passport_orders
 WHERE buyer_user_id=p_user_id AND purchase_intent_key=p_request_key;
 IF FOUND THEN
  IF v_existing.product_id<>p_product_id THEN RAISE EXCEPTION 'reused checkout key';END IF;
  RETURN jsonb_build_object('order_id',v_existing.id,'status',v_existing.status,
   'price_cents',v_existing.price_cents,'terms_snapshot',v_existing.terms_snapshot,
   'payment_enabled',false,'already_prepared',true);
 END IF;
 SELECT * INTO v_product FROM public.passport_products WHERE id=p_product_id AND is_published;
 IF NOT FOUND OR (v_product.validity_start_rule='fixed' AND v_product.fixed_ends_at<=now())
 THEN RAISE EXCEPTION 'passport not available';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
 'offer_id',o.id,'offer_title',o.title,'partner',p.trade_name,
 'establishment',e.name,'eligible_items',o.eligible_items,
 'base',o.calculation_base,'discount_type',o.discount_type,
 'discount_value',o.discount_value,'minimum_purchase_cents',o.minimum_purchase_cents,
 'maximum_discount_cents',o.maximum_discount_cents,
 'fixed_use_policy',o.fixed_use_policy,'advance_booking_required',o.advance_booking_required,
 'issue_window_days',b.issue_window_days,'convert_window_days',b.convert_window_days,
 'use_window_days',b.use_window_days,'limit',b.max_per_holder,'requires_booking',b.booking_required,
 'issue_until',o.issue_until,'convert_until',o.convert_until,'use_until',o.use_until
 ) ORDER BY o.title),'[]'::jsonb) INTO v_benefits
 FROM public.passport_product_benefits b JOIN public.offers o ON o.id=b.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id WHERE b.product_id=p_product_id;
 IF jsonb_array_length(v_benefits)=0 THEN RAISE EXCEPTION 'no passport benefits';END IF;
 IF EXISTS (SELECT 1 FROM public.passport_product_benefits b
 JOIN public.offers o ON o.id=b.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE b.product_id=p_product_id
 AND (NOT o.is_published OR NOT e.is_active OR NOT e.is_public OR p.status<>'approved'
 OR o.convert_until<=now() OR o.issue_until<=now()))
 THEN RAISE EXCEPTION 'benefits unavailable; new checkout suspended without affecting existing paid contracts';END IF;
 v_snapshot:=jsonb_build_object(
  'product_id',v_product.id,'terms_version',v_product.terms_version,
  'name',v_product.name,'description',v_product.description,'price_cents',v_product.price_cents,
  'currency',v_product.currency,'validity_start_rule',v_product.validity_start_rule,
  'duration_days',v_product.duration_days,'fixed_starts_at',v_product.fixed_starts_at,
  'fixed_ends_at',v_product.fixed_ends_at,'activation_deadline_days',v_product.activation_deadline_days,
  'booking_explanation',v_product.booking_explanation,
  'included_benefits_explanation',v_product.included_benefits_explanation,
  'legal_terms',v_product.legal_terms,'benefits',v_benefits,
  'coupon_issuance_individually_free',true,
  'services_not_included_in_purchase',true,
  'right_of_withdrawal_no_automatic_waiver',true,
  'captured_at',now());
 INSERT INTO public.passport_orders(
  buyer_user_id,product_id,purchase_intent_key,price_cents,currency,status,terms_snapshot
 ) VALUES(p_user_id,p_product_id,p_request_key,v_product.price_cents,'BRL','pending_payment',v_snapshot)
 RETURNING id INTO v_order;
 RETURN jsonb_build_object('order_id',v_order,'status','pending_payment',
  'price_cents',v_product.price_cents,'terms_snapshot',v_snapshot,
  'payment_enabled',false,'already_prepared',false);
END $function$;;

-- 20261111014810 marapass_v11_developer_read_only_role_and_revocation

-- Role specialized for contracted developer review. No administrative writes.
ALTER TABLE public.staff_members DROP CONSTRAINT staff_members_staff_role_check;
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_staff_role_check
  CHECK (staff_role IN ('admin','operator','developer'));

CREATE OR REPLACE FUNCTION public.mp_admin_authorize_developer(
 p_admin_user_id uuid,p_developer_user_id uuid,p_email text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_email text;v_state boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_developer_user_id IS NULL OR p_admin_user_id=p_developer_user_id THEN
  RAISE EXCEPTION 'invalid developer account';END IF;
 SELECT lower(email), email_confirmed_at IS NOT NULL
 INTO v_email,v_state FROM auth.users WHERE id=p_developer_user_id;
 IF v_email IS NULL OR v_email<>lower(trim(p_email)) THEN
  RAISE EXCEPTION 'developer invite identity mismatch';END IF;
 IF EXISTS(SELECT 1 FROM public.staff_members WHERE user_id=p_developer_user_id)
 THEN RAISE EXCEPTION 'account already has an application role'; END IF;
 INSERT INTO public.staff_members(user_id,staff_role,is_active)
 VALUES(p_developer_user_id,'developer',true);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_invited',p_admin_user_id,
 jsonb_build_object('role','developer','read_only',true,'email_verified_at_invite',v_state));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'staff_role','developer',
 'read_only',true,'active',true);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
TO service_role;

CREATE OR REPLACE FUNCTION public.mp_admin_revoke_developer(
 p_admin_user_id uuid,p_developer_user_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 UPDATE public.staff_members SET is_active=false
 WHERE user_id=p_developer_user_id AND staff_role='developer' AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'developer access not active';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_revoked',p_admin_user_id,
 jsonb_build_object('staff_role','developer'));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'active',false);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_revoke_developer(uuid,uuid)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_revoke_developer(uuid,uuid)
TO service_role;
;

-- 20261111014919 marapass_v11_deactivated_developer_block_context

CREATE OR REPLACE FUNCTION public.my_access_context()
 RETURNS TABLE(user_id uuid, staff_role text, admin_role boolean, partner_owner boolean, partner_manager boolean, partner_validator boolean, mfa_verified boolean, admin_console_ready boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select
  (select auth.uid()) as user_id,
  CASE WHEN s.is_active THEN s.staff_role ELSE NULL END AS staff_role,
  (s.staff_role='admin' and s.is_active) as admin_role,
  exists(select 1 from public.partners p
    where p.owner_user_id=(select auth.uid()) and p.status='approved') as partner_owner,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='manager') as partner_manager,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='validator') as partner_validator,
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as mfa_verified,
  coalesce(s.staff_role='admin' and s.is_active,false)
    and coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as admin_console_ready
from (select 1) base
left join public.staff_members s
  on s.user_id=(select auth.uid())
where (select auth.uid()) is not null;
$function$;;

-- 20261111014941 marapass_v11_admin_list_developer_access

CREATE OR REPLACE FUNCTION public.mp_admin_list_developers(p_admin_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 RETURN COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
   'user_id',s.user_id,'email',u.email,
   'is_active',s.is_active,'created_at',s.created_at,
   'confirmed',u.email_confirmed_at IS NOT NULL
  ) ORDER BY s.created_at DESC)
  FROM public.staff_members s JOIN auth.users u ON u.id=s.user_id
  WHERE s.staff_role='developer'
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_list_developers(uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_list_developers(uuid) TO service_role;
;

-- 20261111015010 marapass_v11_private_account_lookup_for_developer_grants

CREATE FUNCTION private.mp_account_email(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$ SELECT lower(email) FROM auth.users WHERE id=p_user_id AND deleted_at IS NULL LIMIT 1 $$;
REVOKE ALL ON FUNCTION private.mp_account_email(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.mp_account_email(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.mp_admin_authorize_developer(
 p_admin_user_id uuid,p_developer_user_id uuid,p_email text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_email text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_developer_user_id IS NULL OR p_admin_user_id=p_developer_user_id THEN
  RAISE EXCEPTION 'invalid developer account';END IF;
 v_email:=private.mp_account_email(p_developer_user_id);
 IF v_email IS NULL OR v_email<>lower(trim(p_email)) THEN
  RAISE EXCEPTION 'developer invite identity mismatch';END IF;
 IF EXISTS(SELECT 1 FROM public.staff_members WHERE user_id=p_developer_user_id)
 THEN RAISE EXCEPTION 'account already has an application role'; END IF;
 INSERT INTO public.staff_members(user_id,staff_role,is_active)
 VALUES(p_developer_user_id,'developer',true);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_invited',p_admin_user_id,
 jsonb_build_object('role','developer','read_only',true));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'staff_role','developer',
 'read_only',true,'active',true);
END $$;

CREATE OR REPLACE FUNCTION public.mp_admin_list_developers(p_admin_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 RETURN COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
   'user_id',s.user_id,'email',private.mp_account_email(s.user_id),
   'is_active',s.is_active,'created_at',s.created_at
  ) ORDER BY s.created_at DESC)
  FROM public.staff_members s
  WHERE s.staff_role='developer'
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_list_developers(uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
 TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_list_developers(uuid) TO service_role;
;

-- 20261116011430 mvp_app_web_demo

-- App web do turista (homologação). Tabelas e funções isoladas com prefixo mvp_:
-- não alteram o catálogo público lido pelo app de mapa. Remover com DROP ... mvp_*.

create table public.mvp_partner_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.mvp_coupons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  cupom_key text not null check (length(cupom_key) between 1 and 40),
  code text not null unique,
  issued_at timestamptz not null default now(),
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete set null,
  amount_cents integer check (amount_cents is null or amount_cents >= 0)
);
create unique index mvp_coupons_one_active on public.mvp_coupons (user_id, cupom_key) where used_at is null;

create table public.mvp_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_key text not null check (length(item_key) between 1 and 60),
  item_title text not null check (length(item_title) between 1 and 160),
  day date not null,
  period text not null check (period in ('Manhã','Tarde')),
  people integer not null check (people between 1 and 20),
  status text not null default 'solicitada' check (status in ('solicitada','confirmada','recusada','cancelada','concluida')),
  cupom_key text,
  customer_name text,
  request_key text not null unique,
  history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mvp_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_key text not null check (length(item_key) between 1 and 60),
  polo text not null check (length(polo) between 1 and 40),
  cidade text not null check (length(cidade) between 1 and 80),
  day date not null default ((now() at time zone 'America/Fortaleza')::date),
  rating smallint check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  unique (user_id, item_key, day)
);

alter table public.mvp_partner_members enable row level security;
alter table public.mvp_coupons enable row level security;
alter table public.mvp_reservations enable row level security;
alter table public.mvp_checkins enable row level security;

create or replace function public.mvp_is_partner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.mvp_partner_members m where m.user_id = (select auth.uid()));
$$;

create policy mvp_members_own on public.mvp_partner_members for select to authenticated
  using (user_id = (select auth.uid()));
create policy mvp_coupons_read on public.mvp_coupons for select to authenticated
  using (user_id = (select auth.uid()) or public.mvp_is_partner());
create policy mvp_reservations_read on public.mvp_reservations for select to authenticated
  using (user_id = (select auth.uid()) or public.mvp_is_partner());
create policy mvp_checkins_read on public.mvp_checkins for select to authenticated
  using (user_id = (select auth.uid()));
-- Escritas só pelas funções abaixo (nenhuma policy de insert/update/delete).

create or replace function public.mvp_require_user() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return uid;
end $$;

create or replace function public.mvp_activate_coupon(p_cupom_key text) returns public.mvp_coupons
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_coupons; c text; tries int := 0;
begin
  select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
  if found then return r; end if;
  loop
    tries := tries + 1;
    c := 'MP-' || upper(substr(translate(encode(gen_random_bytes(6), 'base64'), '+/=0O1Il', ''), 1, 4));
    begin
      insert into public.mvp_coupons (user_id, cupom_key, code) values (uid, p_cupom_key, c) returning * into r;
      return r;
    exception when unique_violation then
      select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
      if found then return r; end if;
      if tries > 8 then raise; end if;
    end;
  end loop;
end $$;

create or replace function public.mvp_join_demo_partner() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user();
begin
  insert into public.mvp_partner_members (user_id) values (uid) on conflict do nothing;
end $$;

-- Validação atômica de uso único: dois atendentes ao mesmo tempo geram um só uso.
create or replace function public.mvp_validate_coupon(p_code text, p_amount_cents integer default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_coupons;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  select * into r from public.mvp_coupons where code = upper(trim(p_code)) for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if r.used_at is not null then return jsonb_build_object('ok', false, 'reason', 'used', 'cupom_key', r.cupom_key, 'used_at', r.used_at); end if;
  update public.mvp_coupons set used_at = now(), used_by = uid, amount_cents = p_amount_cents where id = r.id;
  return jsonb_build_object('ok', true, 'cupom_key', r.cupom_key);
end $$;

create or replace function public.mvp_request_reservation(p_item_key text, p_item_title text, p_day date, p_period text, p_people integer, p_request_key text, p_cupom_key text default null, p_customer_name text default null)
returns public.mvp_reservations
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  if p_day <= (now() at time zone 'America/Fortaleza')::date then raise exception 'day must be in the future' using errcode = '22023'; end if;
  select * into r from public.mvp_reservations where request_key = p_request_key;
  if found then
    if r.user_id <> uid then raise exception 'request key in use' using errcode = '42501'; end if;
    return r;
  end if;
  insert into public.mvp_reservations (user_id, item_key, item_title, day, period, people, cupom_key, customer_name, request_key, history)
  values (uid, p_item_key, p_item_title, p_day, p_period, p_people, p_cupom_key, left(p_customer_name, 60), p_request_key,
          jsonb_build_array('Pedido enviado em ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM')))
  returning * into r;
  return r;
end $$;

create or replace function public.mvp_update_reservation(p_id uuid, p_action text, p_day date default null, p_period text default null, p_people integer default null, p_reason text default null)
returns public.mvp_reservations
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  select * into r from public.mvp_reservations where id = p_id and user_id = uid for update;
  if not found then raise exception 'not found' using errcode = '42501'; end if;
  if r.status not in ('solicitada','confirmada') then raise exception 'reservation closed' using errcode = '22023'; end if;
  if p_action = 'reschedule' then
    if p_day is null or p_day <= (now() at time zone 'America/Fortaleza')::date then raise exception 'day must be in the future' using errcode = '22023'; end if;
    update public.mvp_reservations set day = p_day, period = p_period, status = 'solicitada', updated_at = now(),
      history = history || jsonb_build_array('Novo dia pedido: ' || to_char(p_day, 'DD/MM') || ' (' || p_period || ')') where id = p_id returning * into r;
  elsif p_action = 'people' then
    update public.mvp_reservations set people = p_people, updated_at = now(),
      history = history || jsonb_build_array('Participantes alterados para ' || p_people) where id = p_id returning * into r;
  elsif p_action = 'cancel' then
    update public.mvp_reservations set status = 'cancelada', updated_at = now(),
      history = history || jsonb_build_array('Cancelada: ' || left(coalesce(p_reason, 'sem motivo'), 120)) where id = p_id returning * into r;
  else
    raise exception 'invalid action' using errcode = '22023';
  end if;
  return r;
end $$;

create or replace function public.mvp_decide_reservation(p_id uuid, p_accept boolean) returns public.mvp_reservations
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  update public.mvp_reservations
     set status = case when p_accept then 'confirmada' else 'recusada' end, updated_at = now(),
         history = history || jsonb_build_array(case when p_accept then 'Confirmada pelo parceiro' else 'Recusada pelo parceiro' end)
   where id = p_id and status = 'solicitada' returning * into r;
  if not found then raise exception 'not pending' using errcode = '22023'; end if;
  return r;
end $$;

create or replace function public.mvp_checkin(p_item_key text, p_polo text, p_cidade text) returns public.mvp_checkins
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_checkins;
begin
  insert into public.mvp_checkins (user_id, item_key, polo, cidade) values (uid, p_item_key, p_polo, p_cidade)
  on conflict (user_id, item_key, day) do nothing returning * into r;
  if r.id is null then
    select * into r from public.mvp_checkins where user_id = uid and item_key = p_item_key and day = (now() at time zone 'America/Fortaleza')::date;
  end if;
  return r;
end $$;

create or replace function public.mvp_rate_checkin(p_id uuid, p_rating smallint) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user();
begin
  update public.mvp_checkins set rating = p_rating where id = p_id and user_id = uid;
end $$;

revoke all on function public.mvp_is_partner(), public.mvp_require_user(), public.mvp_activate_coupon(text), public.mvp_join_demo_partner(),
  public.mvp_validate_coupon(text, integer), public.mvp_request_reservation(text, text, date, text, integer, text, text, text),
  public.mvp_update_reservation(uuid, text, date, text, integer, text), public.mvp_decide_reservation(uuid, boolean),
  public.mvp_checkin(text, text, text), public.mvp_rate_checkin(uuid, smallint) from public, anon;
grant execute on function public.mvp_is_partner(), public.mvp_require_user(), public.mvp_activate_coupon(text), public.mvp_join_demo_partner(),
  public.mvp_validate_coupon(text, integer), public.mvp_request_reservation(text, text, date, text, integer, text, text, text),
  public.mvp_update_reservation(uuid, text, date, text, integer, text), public.mvp_decide_reservation(uuid, boolean),
  public.mvp_checkin(text, text, text), public.mvp_rate_checkin(uuid, smallint) to authenticated;
grant select on public.mvp_partner_members, public.mvp_coupons, public.mvp_reservations, public.mvp_checkins to authenticated;
revoke all on public.mvp_partner_members, public.mvp_coupons, public.mvp_reservations, public.mvp_checkins from anon;;

-- 20261116011452 mvp_hide_internal_helper

revoke execute on function public.mvp_require_user() from authenticated;;

-- 20261116011826 mvp_fix_coupon_code_random

create or replace function public.mvp_activate_coupon(p_cupom_key text) returns public.mvp_coupons
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_coupons; c text; tries int := 0;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if p_cupom_key is null or length(p_cupom_key) not between 1 and 40 then
    raise exception 'invalid coupon' using errcode = '22023';
  end if;
  select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
  if found then return r; end if;
  loop
    tries := tries + 1;
    c := 'MP-' || (select string_agg(substr(alphabet, 1 + (get_byte(b, i) % 32), 1), '')
                   from (select extensions.gen_random_bytes(4) b) x, generate_series(0, 3) i);
    begin
      insert into public.mvp_coupons (user_id, cupom_key, code) values (uid, p_cupom_key, c) returning * into r;
      return r;
    exception when unique_violation then
      select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
      if found then return r; end if;
      if tries > 8 then raise; end if;
    end;
  end loop;
end $$;;

-- 20261116012949 mvp_offers_and_tickets

-- Ofertas criadas na área do parceiro (demonstração) e atendimento com protocolo.
create table public.mvp_partner_offers (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(title) between 4 and 80),
  benefit text not null check (length(benefit) between 2 and 60),
  rules text not null default '' check (length(rules) <= 400),
  category text not null default 'passeio' check (category in ('passeio','gastronomia','hospedagem','cultura','natureza','evento','artesanato','fotografia','transporte')),
  issue_limit integer not null check (issue_limit between 1 and 10000),
  valid_until date not null,
  status text not null default 'Em análise' check (status in ('Em análise','Ativa','Pausada','Encerrada')),
  pause_reason text check (length(pause_reason) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mvp_tickets (
  id uuid primary key default gen_random_uuid(),
  protocol text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('Suporte','Sugestão','Avaliação','Reserva','Artesanato','Fotografia','Transfer')),
  subject text not null check (length(subject) between 1 and 120),
  body text not null check (length(body) between 1 and 1000),
  status text not null default 'Aberta' check (status in ('Aberta','Respondida','Encerrada')),
  replies jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.mvp_partner_offers enable row level security;
alter table public.mvp_tickets enable row level security;

-- Turistas logados veem ofertas ativas e válidas; parceiros veem todas.
create policy mvp_offers_read on public.mvp_partner_offers for select to authenticated
  using ((status = 'Ativa' and valid_until >= current_date) or public.mvp_is_partner());
create policy mvp_tickets_read on public.mvp_tickets for select to authenticated
  using (user_id = (select auth.uid()));

-- Cupons de ofertas do banco usam a chave 'po:<uuid>'.
alter table public.mvp_coupons drop constraint if exists mvp_coupons_cupom_key_check;
alter table public.mvp_coupons add constraint mvp_coupons_cupom_key_check check (length(cupom_key) between 1 and 45);

create or replace function public.mvp_create_offer(p_title text, p_benefit text, p_rules text, p_limit integer, p_until date, p_category text default 'passeio')
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  if p_until < current_date then raise exception 'date in the past' using errcode = '22023'; end if;
  insert into public.mvp_partner_offers (created_by, title, benefit, rules, issue_limit, valid_until, category)
  values (uid, trim(p_title), trim(p_benefit), coalesce(trim(p_rules), ''), p_limit, p_until, coalesce(p_category, 'passeio'))
  returning * into r;
  return r;
end $$;

-- Na homologação, o próprio parceiro de demonstração aprova (em produção: gestão MaraPass).
create or replace function public.mvp_set_offer_status(p_id uuid, p_status text, p_reason text default null)
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  if p_status not in ('Ativa','Pausada','Encerrada') then raise exception 'invalid status' using errcode = '22023'; end if;
  update public.mvp_partner_offers
     set status = p_status, pause_reason = case when p_status = 'Pausada' then left(p_reason, 120) else null end, updated_at = now()
   where id = p_id returning * into r;
  if not found then raise exception 'not found' using errcode = '22023'; end if;
  return r;
end $$;

-- Estatística de cada oferta (emitidos e usados), visível ao parceiro.
create or replace function public.mvp_offer_stats()
returns table (offer_id uuid, issued bigint, used bigint) language sql stable security definer set search_path = public as $$
  select o.id, count(c.id), count(c.used_at)
    from public.mvp_partner_offers o
    left join public.mvp_coupons c on c.cupom_key = 'po:' || o.id::text
   where public.mvp_is_partner()
   group by o.id;
$$;

-- Ativar cupom de oferta do banco: respeita status, validade e limite.
create or replace function public.mvp_activate_offer_coupon(p_offer_id uuid) returns public.mvp_coupons
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); o public.mvp_partner_offers; n bigint;
begin
  select * into o from public.mvp_partner_offers where id = p_offer_id for update;
  if not found or o.status <> 'Ativa' or o.valid_until < current_date then
    raise exception 'offer unavailable' using errcode = '22023';
  end if;
  if not exists (select 1 from public.mvp_coupons where user_id = uid and cupom_key = 'po:' || o.id::text and used_at is null) then
    select count(*) into n from public.mvp_coupons where cupom_key = 'po:' || o.id::text;
    if n >= o.issue_limit then raise exception 'issue limit reached' using errcode = '22023'; end if;
  end if;
  return public.mvp_activate_coupon('po:' || o.id::text);
end $$;

create or replace function public.mvp_open_ticket(p_kind text, p_subject text, p_body text) returns public.mvp_tickets
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_tickets; tries int := 0;
begin
  loop
    tries := tries + 1;
    begin
      insert into public.mvp_tickets (protocol, user_id, kind, subject, body)
      values ('P' || lpad(((get_byte(extensions.gen_random_bytes(3), 0) * 65536 + get_byte(extensions.gen_random_bytes(3), 1) * 256 + get_byte(extensions.gen_random_bytes(3), 2)) % 900000 + 100000)::text, 6, '0'),
              uid, p_kind, left(p_subject, 120), left(p_body, 1000))
      returning * into r;
      return r;
    exception when unique_violation then
      if tries > 8 then raise; end if;
    end;
  end loop;
end $$;

create or replace function public.mvp_reply_ticket(p_id uuid, p_text text) returns public.mvp_tickets
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_tickets;
begin
  update public.mvp_tickets set replies = replies || jsonb_build_array(left(p_text, 1000))
   where id = p_id and user_id = uid returning * into r;
  if not found then raise exception 'not found' using errcode = '42501'; end if;
  return r;
end $$;

revoke all on function public.mvp_create_offer(text,text,text,integer,date,text), public.mvp_set_offer_status(uuid,text,text),
  public.mvp_offer_stats(), public.mvp_activate_offer_coupon(uuid), public.mvp_open_ticket(text,text,text),
  public.mvp_reply_ticket(uuid,text) from public, anon;
grant execute on function public.mvp_create_offer(text,text,text,integer,date,text), public.mvp_set_offer_status(uuid,text,text),
  public.mvp_offer_stats(), public.mvp_activate_offer_coupon(uuid), public.mvp_open_ticket(text,text,text),
  public.mvp_reply_ticket(uuid,text) to authenticated;
grant select on public.mvp_partner_offers, public.mvp_tickets to authenticated;
revoke all on public.mvp_partner_offers, public.mvp_tickets from anon;;

-- 20261116094054 mvp_checkin_server_validation

create table if not exists public.mvp_places (
  item_key text primary key,
  code text not null unique,
  token text not null default encode(extensions.gen_random_bytes(9), 'hex'),
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null check (radius_m between 50 and 20000),
  created_at timestamptz not null default now()
);
alter table public.mvp_places enable row level security;
-- sem políticas: ninguém lê o token pelo app; só as funções abaixo.
revoke all on public.mvp_places from anon, authenticated;

alter table public.mvp_checkins add column if not exists method text not null default 'legado';
alter table public.mvp_checkins add column if not exists distance_m integer;

create or replace function public.mvp_distance_m(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns double precision language sql immutable set search_path = '' as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

drop function if exists public.mvp_checkin(text, text, text);

create or replace function public.mvp_checkin(
  p_item_key text, p_polo text, p_cidade text,
  p_method text, p_token text default null,
  p_lat double precision default null, p_lng double precision default null)
returns public.mvp_checkins
language plpgsql security definer set search_path to 'public' as $$
declare
  uid uuid := public.mvp_require_user();
  pl public.mvp_places;
  dist double precision;
  today date := (now() at time zone 'America/Fortaleza')::date;
  r public.mvp_checkins;
begin
  select * into pl from public.mvp_places where item_key = p_item_key;
  if pl.item_key is null then
    raise exception 'Local sem placa MaraPass cadastrada.' using errcode = 'P0001';
  end if;
  if p_lat is not null and p_lng is not null then
    dist := public.mvp_distance_m(p_lat, p_lng, pl.lat, pl.lng);
  end if;
  if p_method = 'placa' then
    if p_token is null or p_token <> pl.token then
      raise exception 'QR da placa inválido. Leia a placa original no local.' using errcode = 'P0001';
    end if;
  elsif p_method in ('gps', 'codigo') then
    if dist is null then
      raise exception 'Precisamos da sua localização para confirmar a visita.' using errcode = 'P0001';
    end if;
    if dist > pl.radius_m then
      raise exception 'Você está a % m do local. Chegue mais perto ou leia o QR da placa.', round(dist)::int using errcode = 'P0001';
    end if;
  else
    raise exception 'Forma de check-in desconhecida.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.mvp_checkins where user_id = uid and day = today) >= 20 then
    raise exception 'Limite de 20 visitas por dia atingido.' using errcode = 'P0001';
  end if;
  insert into public.mvp_checkins (user_id, item_key, polo, cidade, method, distance_m)
  values (uid, p_item_key, p_polo, p_cidade, p_method, round(dist)::int)
  on conflict (user_id, item_key, day) do nothing returning * into r;
  if r.id is null then
    select * into r from public.mvp_checkins where user_id = uid and item_key = p_item_key and day = today;
  end if;
  return r;
end $$;

revoke all on function public.mvp_checkin(text, text, text, text, text, double precision, double precision) from public, anon;
grant execute on function public.mvp_checkin(text, text, text, text, text, double precision, double precision) to authenticated;;

-- 20261116095402 mvp_delete_account_and_partner_approval

-- 1) Exclusão da própria conta (Apple/Google/LGPD)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if exists (select 1 from public.staff_members s where s.user_id = uid and s.is_active)
     or exists (select 1 from public.partner_members m where m.user_id = uid and m.is_active)
     or exists (select 1 from public.partners p where p.owner_user_id = uid)
     or exists (select 1 from public.mvp_partner_members m where m.user_id = uid) then
    raise exception 'Contas de parceiro são excluídas pelo suporte, para não apagar ofertas ativas.' using errcode = 'P0001';
  end if;
  delete from public.assistant_messages
    where conversation_id in (select id from public.assistant_conversations where user_id = uid);
  delete from public.assistant_conversations where user_id = uid;
  delete from public.mvp_partner_requests where user_id = uid;
  -- Cupons já usados ficam no histórico do parceiro, sem identificar a pessoa.
  update public.mvp_coupons set used_by = null where used_by = uid;
  delete from public.profiles where id = uid;
  begin
    delete from auth.users where id = uid;
  exception when foreign_key_violation then
    raise exception 'Sua conta tem registros do sistema anterior. Peça a exclusão pelo suporte.' using errcode = 'P0001';
  end;
end $$;

-- 2) Parceiro real: pedido + aprovação pela equipe MaraPass
create table if not exists public.mvp_partner_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  business text not null check (length(trim(business)) between 2 and 120),
  cadastur text,
  city text not null,
  phone text not null,
  status text not null default 'pendente' check (status in ('pendente','aprovado','recusado')),
  note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
alter table public.mvp_partner_requests enable row level security;
revoke all on public.mvp_partner_requests from anon, authenticated;
grant select on public.mvp_partner_requests to authenticated;
drop policy if exists "dono le o proprio pedido" on public.mvp_partner_requests;
create policy "dono le o proprio pedido" on public.mvp_partner_requests
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.mvp_request_partner(p_business text, p_cadastur text, p_city text, p_phone text)
returns public.mvp_partner_requests language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_requests;
begin
  insert into public.mvp_partner_requests (user_id, business, cadastur, city, phone)
  values (uid, trim(p_business), nullif(trim(p_cadastur), ''), trim(p_city), trim(p_phone))
  on conflict (user_id) do update set business = excluded.business, cadastur = excluded.cadastur,
    city = excluded.city, phone = excluded.phone,
    status = case when public.mvp_partner_requests.status = 'aprovado' then 'aprovado' else 'pendente' end,
    created_at = now()
  returning * into r;
  return r;
end $$;

-- Só a equipe (service role / SQL) aprova.
create or replace function public.mvp_decide_partner(p_user uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.mvp_partner_requests set status = case when p_approve then 'aprovado' else 'recusado' end,
    note = p_note, decided_at = now() where user_id = p_user;
  if p_approve then
    insert into public.mvp_partner_members (user_id) values (p_user) on conflict do nothing;
  else
    delete from public.mvp_partner_members where user_id = p_user;
  end if;
end $$;

-- Fim do atalho de demonstração (qualquer logado virava parceiro).
create or replace function public.mvp_join_demo_partner()
returns void language plpgsql security definer set search_path = public as $$
begin
  raise exception 'A área do parceiro agora exige cadastro aprovado pela equipe MaraPass.' using errcode = 'P0001';
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke all on function public.mvp_request_partner(text, text, text, text) from public, anon;
grant execute on function public.mvp_request_partner(text, text, text, text) to authenticated;
revoke all on function public.mvp_decide_partner(uuid, boolean, text) from public, anon, authenticated;;

-- 20261116095702 mvp_revoke_demo_partner

revoke all on function public.mvp_join_demo_partner() from public, anon, authenticated;;

-- 20261116101224 mvp_admin_command

-- Gestão do app MaraPass (MVP) pela Central Administrativa:
-- só administrador ativo com segundo fator (aal2).
create or replace function public.mvp_admin_command(p_action text, p_args jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid(); res jsonb;
begin
  perform private.assert_admin(uid);
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'Confirme o segundo fator (MFA) para gerenciar o app.' using errcode = 'P0001';
  end if;

  if p_action = 'overview' then
    return jsonb_build_object(
      'pedidos_parceiro', (select count(*) from mvp_partner_requests where status = 'pendente'),
      'parceiros', (select count(*) from mvp_partner_members),
      'ofertas_analise', (select count(*) from mvp_partner_offers where status = 'Em análise'),
      'ofertas_ativas', (select count(*) from mvp_partner_offers where status = 'Ativa'),
      'checkins_hoje', (select count(*) from mvp_checkins where day = (now() at time zone 'America/Fortaleza')::date),
      'checkins_total', (select count(*) from mvp_checkins),
      'cupons_ativados', (select count(*) from mvp_coupons),
      'cupons_usados', (select count(*) from mvp_coupons where used_at is not null),
      'reservas_pendentes', (select count(*) from mvp_reservations where status in ('pendente','Pendente','Aguardando')),
      'atendimentos_abertos', (select count(*) from mvp_tickets where status not in ('Resolvido','Fechado')),
      'usuarios', (select count(*) from auth.users where coalesce(is_anonymous,false) = false));
  elsif p_action = 'partner_requests' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('user_id', r.user_id, 'email', u.email, 'business', r.business, 'cadastur', r.cadastur,
        'city', r.city, 'phone', r.phone, 'status', r.status, 'note', r.note, 'created_at', r.created_at) x
      from mvp_partner_requests r join auth.users u on u.id = r.user_id) s;
    return res;
  elsif p_action = 'decide_partner' then
    perform public.mvp_decide_partner((p_args->>'user_id')::uuid, (p_args->>'approve')::boolean, nullif(p_args->>'note', ''));
    return jsonb_build_object('ok', true);
  elsif p_action = 'offers' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('id', o.id, 'title', o.title, 'benefit', o.benefit, 'rules', o.rules, 'category', o.category,
        'limit', o.issue_limit, 'valid_until', o.valid_until, 'status', o.status, 'email', u.email, 'created_at', o.created_at,
        'issued', (select count(*) from mvp_coupons c where c.cupom_key = 'po:' || o.id),
        'used', (select count(*) from mvp_coupons c where c.cupom_key = 'po:' || o.id and c.used_at is not null)) x
      from mvp_partner_offers o left join auth.users u on u.id = o.created_by) s;
    return res;
  elsif p_action = 'set_offer' then
    if p_args->>'status' not in ('Ativa', 'Recusada', 'Pausada', 'Em análise') then
      raise exception 'Status de oferta inválido.' using errcode = 'P0001';
    end if;
    update mvp_partner_offers set status = p_args->>'status', pause_reason = nullif(p_args->>'reason', ''), updated_at = now()
      where id = (p_args->>'id')::uuid;
    return jsonb_build_object('ok', true);
  elsif p_action = 'places' then
    select coalesce(jsonb_agg(jsonb_build_object('item_key', p.item_key, 'code', p.code, 'token', p.token,
      'lat', p.lat, 'lng', p.lng, 'radius_m', p.radius_m,
      'checkins', (select count(*) from mvp_checkins c where c.item_key = p.item_key)) order by p.code), '[]') into res
      from mvp_places p;
    return res;
  elsif p_action = 'set_radius' then
    update mvp_places set radius_m = (p_args->>'radius_m')::int where item_key = p_args->>'item_key';
    return jsonb_build_object('ok', true);
  elsif p_action = 'checkins' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('item_key', c.item_key, 'cidade', c.cidade, 'method', c.method, 'distance_m', c.distance_m,
        'rating', c.rating, 'created_at', c.created_at) x
      from mvp_checkins c order by c.created_at desc limit 100) s;
    return res;
  end if;
  raise exception 'Ação desconhecida.' using errcode = 'P0001';
end $$;
revoke all on function public.mvp_admin_command(text, jsonb) from public, anon;
grant execute on function public.mvp_admin_command(text, jsonb) to authenticated;;

-- 20261116102515 mvp_reservations_lodging_period

alter table public.mvp_reservations drop constraint mvp_reservations_period_check;
alter table public.mvp_reservations add constraint mvp_reservations_period_check
  check (period in ('Manhã', 'Tarde') or period ~ '^[0-9]{1,2} noites? · .{1,80}$');
do $$
declare d text;
begin
  select pg_get_functiondef('public.mvp_admin_command(text,jsonb)'::regprocedure) into d;
  d := replace(d, $q$status in ('pendente','Pendente','Aguardando')$q$, $q$status = 'solicitada'$q$);
  execute d;
end $$;;

-- 20261116145501 mvp_media_and_indexes

-- Mídia dinâmica
alter table public.mvp_partner_offers add column if not exists image_url text check (image_url is null or image_url ~ '^https://');
alter table public.mvp_partner_offers add column if not exists banner_url text check (banner_url is null or banner_url ~ '^https://');
alter table public.mvp_places add column if not exists image_url text check (image_url is null or image_url ~ '^https://');
alter table public.mvp_places add column if not exists banner_url text check (banner_url is null or banner_url ~ '^https://');

-- Bucket público de imagens (leitura por URL pública; 5 MB; só imagens)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marapass-assets', 'marapass-assets', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Parceiro aprovado envia e gerencia só a própria pasta: <user_id>/arquivo
drop policy if exists "marapass_assets_partner_insert" on storage.objects;
create policy "marapass_assets_partner_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.mvp_is_partner()));
drop policy if exists "marapass_assets_partner_update" on storage.objects;
create policy "marapass_assets_partner_update" on storage.objects for update to authenticated
  using (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "marapass_assets_partner_delete" on storage.objects;
create policy "marapass_assets_partner_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Índices das consultas do app e do painel
create index if not exists mvp_checkins_user_created_idx on public.mvp_checkins (user_id, created_at desc);
create index if not exists mvp_checkins_day_idx on public.mvp_checkins (day);
create index if not exists mvp_checkins_item_idx on public.mvp_checkins (item_key);
create index if not exists mvp_coupons_user_idx on public.mvp_coupons (user_id, issued_at desc);
create index if not exists mvp_coupons_key_idx on public.mvp_coupons (cupom_key);
create index if not exists mvp_reservations_user_idx on public.mvp_reservations (user_id, day);
create index if not exists mvp_reservations_status_day_idx on public.mvp_reservations (status, day);
create index if not exists mvp_offers_status_until_idx on public.mvp_partner_offers (status, valid_until);
create index if not exists mvp_offers_creator_idx on public.mvp_partner_offers (created_by);
create index if not exists mvp_tickets_user_idx on public.mvp_tickets (user_id, created_at desc);
create index if not exists mvp_partner_requests_status_idx on public.mvp_partner_requests (status);;

-- 20261116150918 mvp_set_offer_image

create or replace function public.mvp_set_offer_image(p_id uuid, p_url text)
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); o public.mvp_partner_offers;
begin
  if p_url is not null and p_url not like 'https://nwwxobiqynawxxnbvubz.supabase.co/storage/v1/object/public/marapass-assets/' || uid::text || '/%' then
    raise exception 'A foto precisa ser enviada pelo app.' using errcode = 'P0001';
  end if;
  update public.mvp_partner_offers set image_url = p_url, updated_at = now()
    where id = p_id and created_by = uid returning * into o;
  if o.id is null then
    raise exception 'Oferta não encontrada nesta conta.' using errcode = 'P0001';
  end if;
  return o;
end $$;
revoke all on function public.mvp_set_offer_image(uuid, text) from public, anon;
grant execute on function public.mvp_set_offer_image(uuid, text) to authenticated;;

-- 20261117231908 mvp_coupon_commerce

-- Requer as tabelas e RPCs mvp_* da migração mvp_app_web_demo.
-- O parceiro do MVP é identificado pelo titular aprovado da oferta (created_by).
begin;
alter table public.mvp_partner_offers
  add column sale_terms jsonb,
  add column sale_approved boolean not null default false;
alter table public.mvp_coupons
  alter column user_id drop not null,
  add column sale jsonb,
  add column payment_reported_at timestamptz,
  add column sale_stage text not null default 'issued',
  add column fee_state text;
-- A checagem antiga não incluía o estado Recusada já utilizado pelo painel.
do $$ declare c name; begin
  select conname into c from pg_constraint where conrelid='public.mvp_partner_offers'::regclass and contype='c'
    and conkey=array[(select attnum from pg_attribute where attrelid='public.mvp_partner_offers'::regclass and attname='status')];
  if c is not null then execute format('alter table public.mvp_partner_offers drop constraint %I',c); end if;
end $$;
alter table public.mvp_partner_offers add constraint mvp_sale_offer_status check(status in
  ('Rascunho','Em análise','Ativa','Pausada','Encerrada','Recusada'));
create index if not exists mvp_coupon_offer_usage on public.mvp_coupons(cupom_key,user_id);

create table private.mvp_coupon_entries (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  kind text not null check (kind in ('conversion','refund')),
  reference text not null,
  paid_cents integer not null,
  fee_cents integer not null,
  points integer not null,
  reason text,
  actor uuid not null,
  at timestamptz not null default clock_timestamp(),
  unique(coupon_id,kind,reference),
  check ((kind='conversion' and paid_cents>=0 and fee_cents>=0 and points>=0)
      or (kind='refund' and paid_cents<0 and fee_cents<=0 and points<=0))
);
create unique index mvp_one_conversion on private.mvp_coupon_entries(coupon_id) where kind='conversion';
create table private.mvp_coupon_events (
  id bigint generated always as identity primary key,
  coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  kind text not null, actor uuid, detail jsonb not null default '{}',
  at timestamptz not null default clock_timestamp()
);
create index mvp_coupon_events_timeline on private.mvp_coupon_events(coupon_id,id);
alter table private.mvp_coupon_entries enable row level security;
alter table private.mvp_coupon_events enable row level security;
revoke all on private.mvp_coupon_entries,private.mvp_coupon_events from public,anon,authenticated;
revoke insert,update,delete,truncate on public.mvp_coupons,public.mvp_partner_offers from public,anon,authenticated;

create function private.mvp_sale_fee(amount integer) returns integer language sql immutable strict
set search_path='' as $$ select ((amount::bigint * 5 + 50) / 100)::integer $$;

-- Percentuais usam pontos-base (10% = 1000). Nominais e preços usam centavos.
create function public.mvp_set_sale_terms(p_offer_id uuid,p_price integer,p_kind text,p_discount integer,
  p_payment text,p_url text,p_points boolean default true,p_per_user integer default 1,p_window jsonb default '{}')
returns public.mvp_partner_offers language plpgsql security definer set search_path='' as $$
declare u uuid := public.mvp_require_user(); o public.mvp_partner_offers; cut integer; starts date; label text;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  if p_price is null or p_price not between 1 and 1000000000 or p_discount is null or p_discount<0 or
     p_kind is null or p_kind not in ('percent','fixed','promo') or (p_kind='percent' and p_discount>10000) or
     (p_kind in ('fixed','promo') and p_discount>p_price) or p_per_user is null or p_per_user not between 1 and 10000 or
     p_points is null or length(coalesce(trim(p_payment),''))>400 or length(coalesce(trim(p_url),''))>1000 or
     (nullif(trim(p_url),'') is not null and p_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?([/?#][^[:space:]]*)?$') or
     (nullif(trim(p_payment),'') is null and nullif(trim(p_url),'') is null)
    then raise exception 'Confira preço, desconto, limite e instruções de pagamento.'; end if;
  starts:=coalesce(nullif(p_window->>'from','')::date,(now() at time zone 'America/Fortaleza')::date);
  if length(coalesce(p_window->>'hours',''))>160 or (nullif(p_window->>'contact','') is not null and
      p_window->>'contact' !~ '^[1-9][0-9]{7,14}$') then raise exception 'Confira os horários e o contato.'; end if;
  cut := case when p_kind='promo' then p_price-p_discount when p_kind='fixed' then p_discount else ((p_price::bigint*p_discount+5000)/10000)::integer end;
  label:=case when p_kind='percent' then replace(trim_scale(p_discount::numeric/100)::text,'.',',')||'% de desconto'
    when p_kind='promo' then 'Preço promocional de R$ '||replace(to_char(p_discount::numeric/100,'FM999999990.00'),'.',',')
    else 'R$ '||replace(to_char(p_discount::numeric/100,'FM999999990.00'),'.',',')||' de desconto' end;
  update public.mvp_partner_offers set benefit=label,sale_terms=jsonb_build_object('price',p_price,'kind',p_kind,
    'discount',p_discount,'discount_cents',cut,'due',p_price-cut,'payment',trim(p_payment),'url',nullif(trim(p_url),''),
    'points',p_points,'per_user',p_per_user,'from',starts,'hours',p_window->>'hours','contact',p_window->>'contact'),sale_approved=false,status='Em análise',updated_at=now()
    where id=p_offer_id and created_by=u and valid_until>=starts returning * into o;
  if not found then raise exception 'Oferta indisponível.' using errcode='42501'; end if;
  return o;
end $$;

-- Cadastro e envio para aprovação devem ser uma única transação.
create function public.mvp_create_sale_offer(p_offer jsonb,p_terms jsonb) returns public.mvp_partner_offers
language plpgsql security definer set search_path='' as $$
declare o public.mvp_partner_offers; benefit text;
begin
  benefit:=case when p_terms->>'kind'='percent' then trim_scale((p_terms->>'discount')::numeric/100)::text||'% de desconto'
    else 'R$ '||replace(to_char((p_terms->>'discount')::numeric/100,'FM999999990.00'),'.',',')||' de desconto' end;
  o:=public.mvp_create_offer(p_offer->>'title',replace(benefit,'.',','),p_offer->>'rules',(p_offer->>'limit')::int,
    (p_offer->>'until')::date,p_offer->>'category');
  o:=public.mvp_set_sale_terms(o.id,(p_terms->>'price')::int,p_terms->>'kind',(p_terms->>'discount')::int,
    p_terms->>'payment',p_terms->>'url',(p_terms->>'points')::boolean,(p_terms->>'per_user')::int,coalesce(p_terms->'window','{}'));
  if coalesce((p_offer->>'draft')::boolean,false) then
    update public.mvp_partner_offers set status='Rascunho' where id=o.id returning * into o; end if;
  return o;
end $$;

-- Reutiliza o comando de aprovação da administração e o MFA já exigido por ele.
create function private.mvp_certify_sale() returns trigger language plpgsql set search_path='' as $$
begin
  if new.status='Ativa' and new.sale_terms is not null and not old.sale_approved then
    perform private.assert_admin(auth.uid());
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
    new.sale_approved:=true;
  end if;
  if new.status in ('Em análise','Recusada') then new.sale_approved:=false; end if;
  return new;
end $$;
create trigger mvp_certify_sale before update of status,sale_terms on public.mvp_partner_offers
  for each row execute function private.mvp_certify_sale();

create or replace function public.mvp_set_offer_status(p_id uuid,p_status text,p_reason text default null)
returns public.mvp_partner_offers language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); o public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() or p_status is null or p_status not in ('Ativa','Pausada','Encerrada') then
    raise exception 'Ação indisponível.' using errcode='42501'; end if;
  update public.mvp_partner_offers set status=p_status,pause_reason=case when p_status='Pausada' then left(p_reason,120) end,updated_at=now()
    where id=p_id and created_by=u and (p_status<>'Ativa' or (sale_approved and status='Pausada')) returning * into o;
  if not found then raise exception 'A oferta precisa de aprovação administrativa.'; end if;
  return o;
end $$;
drop policy if exists mvp_offers_read on public.mvp_partner_offers;
create policy mvp_offers_read on public.mvp_partner_offers for select using (
  (status='Ativa' and valid_until >= (now() at time zone 'America/Fortaleza')::date)
  or (created_by=(select auth.uid()) and (select public.mvp_is_partner())));
drop policy if exists mvp_coupons_read on public.mvp_coupons;
create policy mvp_coupons_read on public.mvp_coupons for select using (user_id=(select auth.uid()));
create or replace function public.mvp_offer_stats() returns table(offer_id uuid,issued bigint,used bigint)
language sql stable security definer set search_path='' as $$
  select o.id,count(c.id),count(c.used_at) from public.mvp_partner_offers o left join public.mvp_coupons c on c.cupom_key='po:'||o.id
  where o.created_by=(select auth.uid()) and (select public.mvp_is_partner()) group by o.id
$$;

create or replace function public.mvp_activate_offer_coupon(p_offer_id uuid) returns public.mvp_coupons
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); o public.mvp_partner_offers; c public.mvp_coupons;
  key text:='po:'||p_offer_id; total bigint; mine bigint; expiry timestamptz;
begin
  select * into o from public.mvp_partner_offers where id=p_offer_id for update;
  if not found then raise exception 'Oferta indisponível.'; end if;
  if u=o.created_by then raise exception 'O parceiro não pode emitir cupom da própria oferta.'; end if;
  select * into c from public.mvp_coupons where user_id=u and cupom_key=key and used_at is null and sale_stage not in ('cancelled','declined');
  if found then return c; end if;
  expiry:=(o.valid_until+1)::timestamp at time zone 'America/Fortaleza';
  if (now() at time zone 'America/Fortaleza')::date<(o.sale_terms->>'from')::date or o.status<>'Ativa' or not o.sale_approved or o.sale_terms is null or clock_timestamp()>=expiry or
     not exists(select 1 from public.mvp_partner_members where user_id=o.created_by)
    then raise exception 'Oferta indisponível.'; end if;
  select count(*),count(*) filter(where user_id=u) into total,mine from public.mvp_coupons where cupom_key=key and sale_stage not in ('cancelled','declined');
  if total>=o.issue_limit or mine>=(o.sale_terms->>'per_user')::int then raise exception 'Limite de emissão atingido.'; end if;
  insert into public.mvp_coupons(user_id,cupom_key,code,sale) values(u,key,'MP-'||upper(replace(gen_random_uuid()::text,'-','')),
    o.sale_terms||jsonb_build_object('offer',o.id,'owner',o.created_by,'title',o.title,'benefit',o.benefit,
      'rules',o.rules,'city',(select city from public.mvp_partner_requests where user_id=o.created_by),'category',o.category,'expires',expiry,'rate_bps',500)) returning * into c;
  insert into private.mvp_coupon_events(coupon_id,kind,actor) values(c.id,'issued',u);
  return c;
end $$;
create or replace function public.mvp_activate_coupon(p_cupom_key text) returns public.mvp_coupons
language plpgsql security definer set search_path='' as $$
begin
  if p_cupom_key ~ '^po:[0-9a-fA-F-]{36}$' then
    return public.mvp_activate_offer_coupon(substr(p_cupom_key,4)::uuid); end if;
  raise exception 'Cupom editorial de demonstração. Escolha uma oferta comercial aprovada.';
end $$;

create function public.mvp_report_payment(p_code text) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons;
begin
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and user_id=u and sale is not null for update;
  if not found then raise exception 'Cupom indisponível.'; end if;
  if c.sale_stage in ('cancelled','declined','disputed') then raise exception 'Cupom indisponível para informar pagamento.'; end if;
  if c.used_at is not null or c.payment_reported_at is not null then return; end if;
  if clock_timestamp()>=(c.sale->>'expires')::timestamptz then raise exception 'Cupom vencido.'; end if;
  update public.mvp_coupons set payment_reported_at=clock_timestamp() where id=c.id;
  insert into private.mvp_coupon_events(coupon_id,kind,actor) values(c.id,'payment_reported',u);
end $$;
-- O mesmo RPC recebe o código emitido pelo servidor nas telas de QR, link e painel.
create table private.mvp_coupon_lookup_limit(actor uuid primary key,minute timestamptz not null,n integer not null);
alter table private.mvp_coupon_lookup_limit enable row level security;
revoke all on private.mvp_coupon_lookup_limit from public,anon,authenticated;
create function public.mvp_confirm_receipt(p_code text,p_amount_cents integer,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; fee integer; pts integer; attempts integer;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  if p_channel is null or p_channel not in ('panel','whatsapp','qr') then raise exception 'Canal inválido.'; end if;
  insert into private.mvp_coupon_lookup_limit values(u,date_trunc('minute',clock_timestamp()),1) on conflict(actor) do update
    set minute=excluded.minute,n=case when excluded.minute=mvp_coupon_lookup_limit.minute then mvp_coupon_lookup_limit.n+1 else 1 end
    returning n into attempts;
  if attempts>30 then return jsonb_build_object('ok',false,'reason','rate_limited'); end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale->>'owner'=u::text for update;
  if not found then return jsonb_build_object('ok',false,'reason','unavailable'); end if;
  if c.user_id is null and c.used_at is null then return jsonb_build_object('ok',false,'reason','unavailable'); end if;
  if c.user_id=u then raise exception 'O titular do cupom não pode confirmar o próprio pagamento.'; end if;
  if p_amount_cents is null or p_amount_cents<0 then raise exception 'Informe o valor recebido.'; end if;
  if c.used_at is null and clock_timestamp()>=(c.sale->>'expires')::timestamptz then return jsonb_build_object('ok',false,'reason','expired'); end if;
  if c.sale_stage in ('cancelled','declined','disputed') then return jsonb_build_object('ok',false,'reason',c.sale_stage); end if;
  if p_amount_cents<>(c.sale->>'due')::integer then
    if c.used_at is null then
      update public.mvp_coupons set sale_stage='disputed' where id=c.id;
      insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,'amount_mismatch',u,
        jsonb_build_object('received',p_amount_cents,'from',c.sale_stage,'to','disputed','channel',p_channel)); end if;
    return jsonb_build_object('ok',false,'reason','amount_mismatch'); end if;
  if c.used_at is not null then return jsonb_build_object('ok',true,'already',true,'cupom_key',c.cupom_key); end if;
  if clock_timestamp()>=(c.sale->>'expires')::timestamptz then return jsonb_build_object('ok',false,'reason','expired'); end if;
  fee:=private.mvp_sale_fee(p_amount_cents);
  pts:=case when (c.sale->>'points')::boolean then p_amount_cents/100 else 0 end;
  insert into private.mvp_coupon_entries(coupon_id,kind,reference,paid_cents,fee_cents,points,actor)
    values(c.id,'conversion','original',p_amount_cents,fee,pts,u);
  update public.mvp_coupons set used_at=clock_timestamp(),used_by=u,amount_cents=p_amount_cents,fee_state='pending',sale_stage='converted' where id=c.id;
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,'converted',u,
    jsonb_build_object('from',c.sale_stage,'to','converted','channel',p_channel));
  return jsonb_build_object('ok',true,'cupom_key',c.cupom_key,'fee_cents',fee,'points',pts);
end $$;

create or replace function public.mvp_validate_coupon(p_code text,p_amount_cents integer default null) returns jsonb
language sql security definer set search_path='' as $$select public.mvp_confirm_receipt(p_code,p_amount_cents,'panel')$$;

create function public.mvp_refund_coupon(p_code text,p_amount integer,p_reference text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; old private.mvp_coupon_entries;
  balance integer; fee integer; pts integer; remaining integer;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale->>'owner'=u::text and used_at is not null for update;
  if not found then raise exception 'Conversão indisponível.'; end if;
  if p_amount is null or p_amount<=0 or length(coalesce(trim(p_reference),'')) not between 1 and 100
    or length(coalesce(trim(p_reason),'')) not between 1 and 300 then raise exception 'Confira valor, referência e motivo do estorno.'; end if;
  select * into old from private.mvp_coupon_entries where coupon_id=c.id and kind='refund' and reference=trim(p_reference);
  if found then
    if old.paid_cents<>-p_amount or old.reason<>trim(p_reason) then raise exception 'Referência já usada com outros dados.'; end if;
    return; end if;
  select sum(paid_cents),sum(fee_cents),sum(points) into balance,fee,pts from private.mvp_coupon_entries where coupon_id=c.id;
  remaining:=balance-p_amount;
  if remaining<0 then raise exception 'Estorno superior ao saldo.'; end if;
  insert into private.mvp_coupon_entries(coupon_id,kind,reference,paid_cents,fee_cents,points,reason,actor)
    values(c.id,'refund',trim(p_reference),-p_amount,private.mvp_sale_fee(remaining)-fee,
      (case when (c.sale->>'points')::boolean then remaining/100 else 0 end)-pts,trim(p_reason),u);
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail)
    values(c.id,'refunded',u,jsonb_build_object('reference',trim(p_reference),'amount',p_amount));
end $$;

create function private.mvp_sale_match(c public.mvp_coupons,f jsonb) returns boolean language sql stable set search_path='' as $$
  select (nullif(f->>'from','') is null or c.issued_at>=((f->>'from')::date::timestamp at time zone 'America/Fortaleza')) and
    (nullif(f->>'until','') is null or c.issued_at<(((f->>'until')::date+1)::timestamp at time zone 'America/Fortaleza')) and
    (nullif(f->>'owner','') is null or c.sale->>'owner'=f->>'owner') and
    (nullif(f->>'city','') is null or lower(c.sale->>'city')=lower(f->>'city')) and
    (nullif(f->>'category','') is null or c.sale->>'category'=f->>'category')
$$;
revoke all on function private.mvp_sale_match(public.mvp_coupons,jsonb) from public,anon,authenticated;
-- Cada página leva o estado e os lançamentos. Consultas da carteira nunca escutam outra conta.
create function public.mvp_coupon_statement(p_scope text default 'tourist',p_code text default null,
  p_before timestamptz default null,p_before_id uuid default null,p_limit integer default 50,p_filters jsonb default '{}')
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user();
begin
  if p_scope='admin' then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  elsif p_scope='partner' then
    if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  elsif p_scope is distinct from 'tourist' then raise exception 'Perfil inválido.'; end if;
  return query select jsonb_build_object('id',c.id,'code',c.code,'issued_at',c.issued_at,'sale',c.sale,
    'fee_state',c.fee_state,'stage',c.sale_stage,'state',case when c.sale_stage in ('cancelled','declined','disputed') then c.sale_stage
      when c.used_at is not null then case when coalesce(e.refunds,0)=0 then c.sale_stage
        when e.paid=0 then 'refunded' else 'partial_refund' end
      when c.user_id is null then 'cancelled'
      when (c.sale->>'expires')::timestamptz<=now() then 'expired'
      when c.payment_reported_at is not null then 'payment_reported' else c.sale_stage end,
    'paid',coalesce(e.paid,0),'fee',coalesce(e.fee,0),'points',coalesce(e.points,0),
    'entries',coalesce(e.items,'[]'::jsonb),'events',coalesce(h.items,'[]'::jsonb))
    from public.mvp_coupons c
    left join lateral (select sum(x.paid_cents) paid,sum(x.fee_cents) fee,sum(x.points) points,
      count(*) filter(where x.kind='refund') refunds,jsonb_agg(case when p_scope='tourist' then to_jsonb(x)-'actor'-'fee_cents' else to_jsonb(x) end order by x.at,x.id) items
      from private.mvp_coupon_entries x where x.coupon_id=c.id) e on true
    left join lateral (select jsonb_agg(case when p_scope='tourist' then jsonb_build_object('kind',x.kind,'at',x.at) else to_jsonb(x)-'coupon_id' end order by x.id) items
      from private.mvp_coupon_events x where x.coupon_id=c.id and (p_scope<>'tourist' or x.kind not like 'fee_%')) h on true
    where c.sale is not null and (p_scope='admin' or (p_scope='tourist' and c.user_id=u)
      or (p_scope='partner' and c.sale->>'owner'=u::text))
    and private.mvp_sale_match(c,p_filters) and (p_code is null or c.code=upper(trim(p_code)))
    and (p_before is null or (c.issued_at,c.id)<(p_before,p_before_id))
    order by c.issued_at desc,c.id desc limit greatest(1,least(coalesce(p_limit,50),100));
end $$;
create index mvp_coupon_sales_owner on public.mvp_coupons((sale->>'owner'),issued_at desc,id desc) where sale is not null;
create index mvp_coupon_sales_wallet on public.mvp_coupons(user_id,issued_at desc,id desc) where sale is not null;
create function public.mvp_coupon_points() returns table(coupon_id uuid,at timestamptz,points integer,kind text,reference text,title text,paid_cents integer)
language sql stable security definer set search_path='' as $$
  select c.id,e.at,e.points,e.kind,e.reference,c.sale->>'title',e.paid_cents from private.mvp_coupon_entries e
  join public.mvp_coupons c on c.id=e.coupon_id where c.user_id=public.mvp_require_user() order by e.at,e.id
$$;
-- O catálogo público mostra só as condições necessárias para escolher a oferta.
create function public.mvp_public_sales() returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',o.id,'title',o.title,'benefit',o.benefit,'rules',o.rules,'category',o.category,
    'valid_until',o.valid_until,'image_url',o.image_url,'status',o.status,'sale_approved',true,
    'sale_terms',o.sale_terms-'payment'-'url')
  from public.mvp_partner_offers o join public.mvp_partner_members m on m.user_id=o.created_by
  where o.status='Ativa' and o.sale_approved and (o.sale_terms->>'from')::date<=(now() at time zone 'America/Fortaleza')::date and o.valid_until>=(now() at time zone 'America/Fortaleza')::date
  order by o.created_at desc,o.id
$$;
revoke all on function public.mvp_public_sales() from public;
grant execute on function public.mvp_public_sales() to anon,authenticated;

-- A exclusão de conta já existente preserva a conversão e desvincula o turista.
create function private.mvp_anonymize_coupon() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update public.mvp_coupons set user_id=null where user_id=old.id and sale is not null;
  update private.mvp_coupon_events set actor=null where actor=old.id and kind in ('issued','payment_reported');
  return old;
end $$;
create trigger mvp_anonymize_coupon before delete on auth.users for each row execute function private.mvp_anonymize_coupon();
revoke all on function private.mvp_anonymize_coupon() from public,anon,authenticated;
create function public.mvp_admin_sale_terms() returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.assert_admin(public.mvp_require_user());
  if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  return query select jsonb_build_object('id',o.id,'owner',o.created_by,'partner',(select business from public.mvp_partner_requests where user_id=o.created_by),'terms',o.sale_terms) from public.mvp_partner_offers o where o.sale_terms is not null;
end $$;
do $$ declare f regprocedure; begin
  for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in
    ('mvp_admin_sale_terms','mvp_create_sale_offer','mvp_set_sale_terms','mvp_set_offer_status','mvp_offer_stats','mvp_activate_offer_coupon','mvp_activate_coupon',
     'mvp_report_payment','mvp_confirm_receipt','mvp_validate_coupon','mvp_refund_coupon','mvp_coupon_statement','mvp_coupon_points') loop
    execute format('revoke all on function %s from public,anon,authenticated',f);
    execute format('grant execute on function %s to authenticated',f);
  end loop;
end $$;
revoke all on function private.mvp_sale_fee(integer),private.mvp_certify_sale() from public,anon,authenticated;
commit;

-- 20261117232129 mvp_coupon_whatsapp

begin;
create table private.mvp_wa_consent (
  user_id uuid primary key references auth.users(id) on delete cascade, phone text not null,
  enabled boolean not null, changed_at timestamptz not null default now()
);
create table private.mvp_wa_permissions (
  id bigint generated always as identity primary key, user_id uuid,
  enabled boolean not null, source text not null, version text not null default 'cupom-v1', at timestamptz not null default now()
);
create table private.mvp_wa_queue (
  id uuid primary key default gen_random_uuid(), coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  user_id uuid, audience text not null check(audience in ('tourist','partner')),
  event text not null check(event in ('issued','converted')), consent_at timestamptz not null, state text not null default 'queued',
  attempts int not null default 0, next_at timestamptz not null default now(), lease uuid, lease_until timestamptz,
  provider_id text, last_error text, unique(coupon_id,event,audience)
);
create index mvp_wa_ready on private.mvp_wa_queue(next_at) where state in ('queued','sending','retry');
create table private.mvp_wa_callbacks (
  message_id text not null, status text not null, at timestamptz not null default now(), primary key(message_id,status)
);
alter table private.mvp_wa_consent enable row level security;
alter table private.mvp_wa_permissions enable row level security;
alter table private.mvp_wa_queue enable row level security;
alter table private.mvp_wa_callbacks enable row level security;
revoke all on private.mvp_wa_consent,private.mvp_wa_permissions,private.mvp_wa_queue,private.mvp_wa_callbacks from public,anon,authenticated;

create function private.mvp_forget_wa_contact() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update private.mvp_wa_queue set user_id=null,state=case when state in ('queued','retry','sending') then 'skipped' else state end,
    lease=null,lease_until=null where user_id=old.id;
  update private.mvp_wa_permissions set user_id=null where user_id=old.id;
  return old;
end $$;
create trigger mvp_forget_wa_contact before delete on auth.users for each row execute function private.mvp_forget_wa_contact();
revoke all on function private.mvp_forget_wa_contact() from public,anon,authenticated;
create function public.mvp_wa_opt(p_enabled boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); number text;
begin
  if p_enabled is null then raise exception 'Informe a preferência.'; end if;
  if p_enabled then
    select ltrim(phone,'+') into number from auth.users where id=u and phone_confirmed_at is not null;
    if number is null or number !~ '^[1-9][0-9]{7,14}$' then raise exception 'Confirme o telefone antes de autorizar.'; end if;
    insert into private.mvp_wa_consent(user_id,phone,enabled) values(u,number,true)
      on conflict(user_id) do update set phone=excluded.phone,enabled=true,changed_at=clock_timestamp()
      where not mvp_wa_consent.enabled or mvp_wa_consent.phone<>excluded.phone;
  else
    update private.mvp_wa_consent set enabled=false,changed_at=clock_timestamp() where user_id=u and enabled;
  end if;
  if found then insert into private.mvp_wa_permissions(user_id,enabled,source) values(u,p_enabled,'app'); end if;
  return p_enabled;
end $$;
create function public.mvp_wa_preference() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.mvp_wa_consent w join auth.users u on u.id=w.user_id
    where u.id=public.mvp_require_user() and w.enabled and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone)
$$;
create function private.mvp_queue_coupon() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.sale is not null then
    insert into private.mvp_wa_queue(coupon_id,user_id,audience,consent_at,event)
      select new.id,x.uid,x.role,w.changed_at,case when tg_op='INSERT' then 'issued' else 'converted' end from (values(new.user_id,'tourist'),((new.sale->>'owner')::uuid,'partner')) x(uid,role)
      join private.mvp_wa_consent w on w.user_id=x.uid and w.enabled
      join auth.users u on u.id=x.uid and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone;
  end if;
  return new;
end $$;
create trigger mvp_queue_coupon after insert on public.mvp_coupons for each row execute function private.mvp_queue_coupon();

create trigger mvp_queue_conversion after update of used_at on public.mvp_coupons for each row
when (old.used_at is null and new.used_at is not null) execute function private.mvp_queue_coupon();
create function public.mvp_wa_claim() returns jsonb language plpgsql security definer set search_path='' as $$
declare job private.mvp_wa_queue; number text; c public.mvp_coupons; jobs jsonb:='[]';
begin
  for job in select * from private.mvp_wa_queue where state in ('queued','retry','sending') and next_at<=now()
    and (lease_until is null or lease_until<now()) order by next_at limit 10 for update skip locked loop
    select w.phone into number from private.mvp_wa_consent w join auth.users u on u.id=w.user_id
      where w.user_id=job.user_id and w.enabled and w.changed_at=job.consent_at
      and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone;
    select * into c from public.mvp_coupons where id=job.coupon_id;
    if number is null or (job.audience='partner' and not exists(select 1 from public.mvp_partner_members where user_id=job.user_id))
       or (job.event='issued' and (now()>=(c.sale->>'expires')::timestamptz or c.used_at is not null or c.sale_stage in ('cancelled','declined'))) then
      update private.mvp_wa_queue set state='skipped',lease=null,lease_until=null where id=job.id;
    elsif job.attempts>=6 then
      update private.mvp_wa_queue set state='failed',lease=null,lease_until=null where id=job.id;
    else
      update private.mvp_wa_queue set state='sending',lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',attempts=attempts+1
        where id=job.id returning * into job;
      jobs:=jobs||jsonb_build_array(jsonb_build_object('id',job.id,'lease',job.lease,'to',number,'role',job.audience,'event',job.event,
        'title',c.sale->>'title','due',c.sale->'due','code',c.code));
    end if;
  end loop;
  return jobs;
end $$;

create function public.mvp_wa_finish(p_id uuid,p_lease uuid,p_status text,p_provider text,p_error text) returns void
language sql security definer set search_path='' as $$
  update private.mvp_wa_queue set state=case when p_status='accepted' then 'accepted'
    when p_status='retry' and attempts<6 then 'retry' else 'failed' end,
    provider_id=coalesce(p_provider,provider_id), last_error=left(p_error,100),
    next_at=now()+make_interval(secs=>least(3600,30*(2^attempts)::integer)),lease=null,lease_until=null
    where id=p_id and lease=p_lease and state='sending'
$$;
create function public.mvp_wa_callback(p_id uuid,p_message text,p_status text,p_retry boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare job private.mvp_wa_queue;
begin
  if p_status not in ('sent','delivered','read','failed') or p_message is null then return; end if;
  select * into job from private.mvp_wa_queue where id=p_id or (p_id is null and provider_id=p_message) for update;
  if not found then return; end if;
  insert into private.mvp_wa_callbacks(message_id,status) values(p_message,p_status) on conflict do nothing;
  if not found then return; end if;
  if job.state='read' or (job.state='delivered' and p_status<>'read') then return; end if;
  if p_status='failed' and (job.provider_id is not null and job.provider_id<>p_message or job.state in ('retry','skipped','failed')) then return; end if;
  update private.mvp_wa_queue set state=case when p_status='failed' and p_retry and attempts<6 then 'retry' else p_status end,
    last_error=case when p_status='failed' then 'meta_delivery' end,provider_id=p_message,
    next_at=now()+make_interval(secs=>least(3600,30*(2^attempts)::integer)),lease=null,lease_until=null where id=job.id;
end $$;
create function public.mvp_wa_stop(p_phone text,p_message text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid;
begin
  insert into private.mvp_wa_callbacks(message_id,status) values(p_message,'stop') on conflict do nothing;
  if not found then return; end if;
  for u in update private.mvp_wa_consent set enabled=false,changed_at=clock_timestamp() where enabled and phone=p_phone returning user_id loop
    insert into private.mvp_wa_permissions(user_id,enabled,source) values(u,false,'whatsapp');
  end loop;
end $$;
create function public.mvp_coupon_deliveries(p_code text,p_scope text) returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare receipt jsonb;
begin
  select * into receipt from public.mvp_coupon_statement(p_scope,p_code);
  return query select jsonb_build_object('audience',audience,'event',event,'state',state,'attempts',attempts) from private.mvp_wa_queue
    where coupon_id=(receipt->>'id')::uuid and (p_scope='admin' or audience=p_scope);
end $$;
do $$ declare f regprocedure; begin
  for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in
    ('mvp_wa_opt','mvp_wa_preference','mvp_coupon_deliveries','mvp_wa_claim','mvp_wa_finish','mvp_wa_callback','mvp_wa_stop') loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
    if f::text ~ '(mvp_wa_opt|mvp_wa_preference|mvp_coupon_deliveries)' then
      execute format('grant execute on function %s to authenticated',f);
    else execute format('grant execute on function %s to service_role',f); end if;
  end loop;
end $$;
revoke all on function private.mvp_queue_coupon() from public,anon,authenticated;
commit;

-- 20261117234134 mvp_coupon_operations

begin;
-- Um cancelamento sem conversão libera a unidade e a reserva de emissão.
drop index if exists public.mvp_coupons_one_active;
create unique index mvp_coupons_one_active on public.mvp_coupons(user_id,cupom_key)
  where used_at is null and sale_stage not in ('cancelled','declined');

create function public.mvp_coupon_action(p_code text,p_action text,p_reason text default null,p_channel text default 'app')
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; partner boolean; tourist boolean;
  previous text; target text; financial boolean:=p_action like 'fee_%';
begin
  if p_channel is null or p_channel not in ('app','panel','qr','whatsapp','admin') then raise exception 'Canal inválido.'; end if;
  if p_channel='admin' or financial then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale is not null
    and (user_id=u or (sale->>'owner'=u::text and public.mvp_is_partner()) or p_channel='admin') for update;
  if not found then raise exception 'Cupom indisponível.'; end if;
  partner:=(c.sale->>'owner'=u::text and public.mvp_is_partner()) or p_channel='admin';
  tourist:=coalesce(c.user_id=u,false);
  if p_action in ('cancel','decline','dispute','resolve','fee_disputed','fee_pending','fee_invoiced','fee_paid')
    and length(coalesce(trim(p_reason),'')) not between 1 and 300 then raise exception 'Registre o motivo ou a referência.'; end if;
  previous:=case when financial then c.fee_state else c.sale_stage end;
  target:=case p_action when 'interest' then 'interested' when 'cancel' then 'cancelled' when 'decline' then 'declined'
    when 'dispute' then 'disputed' when 'utilize' then 'utilized' when 'complete' then 'completed'
    when 'fee_invoiced' then 'invoiced' when 'fee_paid' then 'paid' when 'fee_disputed' then 'disputed' when 'fee_pending' then 'pending'
    when 'resolve' then coalesce((select detail->>'from' from private.mvp_coupon_events where coupon_id=c.id
      and kind in ('amount_mismatch','dispute') order by id desc limit 1),'issued') end;
  if target is null then raise exception 'Ação desconhecida.'; end if;
  if (p_action in ('decline','resolve','utilize','complete') and not partner) or
     (p_action='interest' and not tourist) then raise exception 'Ação não autorizada.' using errcode='42501'; end if;
  if previous=target then return; end if;
  if financial then
    if c.used_at is null or not ((target='invoiced' and previous='pending') or (target='paid' and previous='invoiced')
      or (target='disputed' and previous in ('pending','invoiced','paid')) or (target='pending' and previous='disputed')) then
      raise exception 'Transição financeira indisponível.'; end if;
    update public.mvp_coupons set fee_state=target where id=c.id;
  else
    if not ((p_action in ('interest','cancel','decline') and c.used_at is null and previous in ('issued','interested')
          and now()<(c.sale->>'expires')::timestamptz)
      or (p_action='dispute' and previous not in ('cancelled','declined','disputed') and (c.used_at is not null or now()<(c.sale->>'expires')::timestamptz))
      or (p_action='resolve' and previous='disputed')
      or (p_action='utilize' and previous='converted' and coalesce((select sum(paid_cents) from private.mvp_coupon_entries where coupon_id=c.id),0)>0)
      or (p_action='utilize' and previous='converted' and c.amount_cents=0)
      or (p_action='complete' and previous='utilized')) then raise exception 'Transição indisponível para este cupom.'; end if;
    update public.mvp_coupons set sale_stage=target where id=c.id;
  end if;
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,p_action,u,
    jsonb_build_object('from',previous,'to',target,'channel',p_channel,'reason',nullif(trim(p_reason),'')));
end $$;

create function public.mvp_admin_sale_status(p_id uuid,p_status text,p_reason text default null) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user();
begin
  perform private.assert_admin(u);
  if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  if p_status not in ('Ativa','Em análise','Recusada','Pausada','Encerrada') or p_status is null then raise exception 'Estado inválido.'; end if;
  if p_status in ('Recusada','Em análise') and length(coalesce(trim(p_reason),'')) not between 1 and 120 then raise exception 'Registre o motivo.'; end if;
  update public.mvp_partner_offers set status=p_status,pause_reason=nullif(trim(p_reason),''),updated_at=now()
    where id=p_id and status<>'Rascunho' and (p_status<>'Ativa' or
      (sale_terms is not null and valid_until>=(now() at time zone 'America/Fortaleza')::date and
       exists(select 1 from public.mvp_partner_members m where m.user_id=created_by)));
  if not found then raise exception 'Revise as condições, o parceiro e a vigência antes de publicar.'; end if;
end $$;
create function public.mvp_coupon_overview(p_scope text,p_filters jsonb default '{}') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); summary jsonb;
begin
  if p_scope='admin' then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  elsif p_scope is distinct from 'partner' or not public.mvp_is_partner() then raise exception 'Perfil indisponível.'; end if;
  select jsonb_build_object('issued',count(*),'converted',count(c.used_at),'paid',coalesce(sum(e.paid),0),
    'discount',coalesce(sum((c.sale->>'discount_cents')::bigint) filter(where c.used_at is not null),0),
    'fee',coalesce(sum(e.fee),0),'ticket',coalesce(round(sum(e.paid)::numeric/nullif(count(c.used_at),0)),0),
    'conversion_pct',coalesce(round(100.0*count(c.used_at)/nullif(count(*),0),1),0))
    into summary from public.mvp_coupons c left join lateral
      (select sum(x.paid_cents) paid,sum(x.fee_cents) fee from private.mvp_coupon_entries x where x.coupon_id=c.id)e on true
    where c.sale is not null and (p_scope='admin' or c.sale->>'owner'=u::text) and private.mvp_sale_match(c,p_filters);
  return summary;
end $$;
revoke all on function public.mvp_coupon_action(text,text,text,text),public.mvp_admin_sale_status(uuid,text,text),
  public.mvp_coupon_overview(text,jsonb) from public,anon,authenticated;
grant execute on function public.mvp_coupon_action(text,text,text,text),public.mvp_admin_sale_status(uuid,text,text),
  public.mvp_coupon_overview(text,jsonb) to authenticated;
commit;

-- 20261118022026 mvp_scale_guards

create table if not exists private.mvp_rate_limit(
  actor uuid not null, action text not null, minute timestamptz not null, n integer not null,
  primary key(actor, action));
alter table private.mvp_rate_limit enable row level security;
revoke all on private.mvp_rate_limit from public, anon, authenticated;

create or replace function private.mvp_rate_check(p_actor uuid, p_action text, p_max integer)
returns void language plpgsql security definer set search_path='' as $$
declare cnt integer;
begin
  insert into private.mvp_rate_limit as r(actor, action, minute, n)
  values(p_actor, p_action, date_trunc('minute', clock_timestamp()), 1)
  on conflict(actor, action) do update
    set minute = excluded.minute,
        n = case when excluded.minute = r.minute then r.n + 1 else 1 end
  returning n into cnt;
  if cnt > p_max then
    raise exception 'Muitas tentativas. Aguarde um minuto.' using errcode = 'P0001';
  end if;
end $$;
revoke all on function private.mvp_rate_check(uuid, text, integer) from public, anon, authenticated;

create or replace function public.mvp_request_reservation(p_item_key text, p_item_title text, p_day date, p_period text, p_people integer, p_request_key text, p_cupom_key text default null, p_customer_name text default null)
returns public.mvp_reservations language plpgsql security definer set search_path='public' as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  if p_day <= (now() at time zone 'America/Fortaleza')::date then raise exception 'day must be in the future' using errcode = '22023'; end if;
  select * into r from public.mvp_reservations where request_key = p_request_key;
  if found then
    if r.user_id <> uid then raise exception 'request key in use' using errcode = '42501'; end if;
    return r;
  end if;
  perform private.mvp_rate_check(uid, 'reservation', 10);
  insert into public.mvp_reservations (user_id, item_key, item_title, day, period, people, cupom_key, customer_name, request_key, history)
  values (uid, p_item_key, p_item_title, p_day, p_period, p_people, p_cupom_key, left(p_customer_name, 60), p_request_key,
          jsonb_build_array('Pedido enviado em ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM')))
  on conflict (request_key) do nothing returning * into r;
  if r.id is null then
    select * into r from public.mvp_reservations where request_key = p_request_key and user_id = uid;
  end if;
  return r;
end $$;

create index if not exists mvp_coupons_used_by_idx on public.mvp_coupons(used_by) where used_by is not null;;

-- 20261118024050 mvp_rls_and_fk_indexes

do $$
declare
  admin_cond constant text := $a$((((select auth.jwt()) ->> 'aal') = 'aal2') and exists(select 1 from public.staff_members s
    where s.user_id = (select auth.uid()) and s.staff_role = 'admin' and s.is_active))$a$;
  r record; q text; w text; stmt text;
  merges constant text[] := array[
    'coupon_instances|coupons_read_owner_or_partner|admin_read_coupon_instances_aal2|f',
    'establishments|establishments_authenticated|admin_read_establishments_aal2|f',
    'experiences|experiences_authenticated|admin_read_experiences_aal2|f',
    'offers|offers_authenticated|admin_read_offers_aal2|f',
    'partner_applications|partner_applications_read_own|admin_read_applications_aal2|f',
    'partners|partner_read_associated|admin_read_partners_aal2|f',
    'reservations|reservations_read_user_or_partner|admin_read_reservations_aal2|f',
    'municipalities|municipalities_public_read|municipalities_admin_manage|t',
    'pole_municipalities|pole_municipalities_public_read|pole_municipalities_admin_manage|t',
    'tourism_poles|tourism_poles_public_read|tourism_poles_admin_manage|t',
    'passport_products|mp_passports_public_catalog|mp_admin_read_all_passports|t',
    'passport_product_benefits|mp_passport_benefits_public_catalog|mp_admin_read_all_passport_benefits|t'];
  m text; p text[];
begin
  foreach m in array merges loop
    p := string_to_array(m, '|');
    select qual into q from pg_policies where schemaname='public' and tablename=p[1] and policyname=p[2];
    if q is null then raise exception 'Policy % não encontrada em %', p[2], p[1]; end if;
    if q like '%staff_members%' then continue; end if;

    if p[4] = 't' then
      execute format('create policy %I on public.%I for select to anon using (%s)', p[2] || '_anon', p[1], q);
      execute format('alter policy %I on public.%I to authenticated', p[2], p[1]);
    end if;
    execute format('alter policy %I on public.%I using ((%s) or %s)', p[2], p[1], q, admin_cond);

    if p[3] like '%\_manage' then
      execute format('drop policy %I on public.%I', p[3], p[1]);
      execute format('create policy %I on public.%I for insert to authenticated with check (%s)', p[1] || '_admin_insert', p[1], admin_cond);
      execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)', p[1] || '_admin_update', p[1], admin_cond, admin_cond);
      execute format('create policy %I on public.%I for delete to authenticated using (%s)', p[1] || '_admin_delete', p[1], admin_cond);
    else
      execute format('drop policy %I on public.%I', p[3], p[1]);
    end if;
  end loop;

  for r in select tablename, policyname, qual, with_check from pg_policies
           where schemaname='public' and (coalesce(qual,'')||coalesce(with_check,'')) ~ 'auth\.jwt\(\)'
             and (coalesce(qual,'')||coalesce(with_check,'')) !~ '\(select auth\.jwt\(\)\)' loop
    q := r.qual; w := r.with_check;
    foreach stmt in array array['aal','is_anonymous'] loop
      q := replace(replace(q, format('( SELECT (auth.jwt() ->> %L::text))', stmt), format('((select auth.jwt()) ->> %L)', stmt)),
                   format('(auth.jwt() ->> %L::text)', stmt), format('((select auth.jwt()) ->> %L)', stmt));
      w := replace(replace(w, format('( SELECT (auth.jwt() ->> %L::text))', stmt), format('((select auth.jwt()) ->> %L)', stmt)),
                   format('(auth.jwt() ->> %L::text)', stmt), format('((select auth.jwt()) ->> %L)', stmt));
    end loop;
    if q is not null then execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q); end if;
    if w is not null then execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, w); end if;
  end loop;
end $$;

create index if not exists custom_offer_requests_offer_idx on private.custom_offer_requests(offer_id);
create index if not exists offer_creation_requests_offer_idx on private.offer_creation_requests(offer_id);
create index if not exists assistant_conversations_user_idx on public.assistant_conversations(user_id);
create index if not exists partner_invitations_accepted_by_idx on public.partner_invitations(accepted_by);
create index if not exists partner_invitations_requested_by_idx on public.partner_invitations(requested_by);
create index if not exists passport_incidents_entitlement_idx on public.passport_benefit_incidents(entitlement_id);
create index if not exists passport_incidents_offer_idx on public.passport_benefit_incidents(offer_id);
create index if not exists passport_incidents_reported_by_idx on public.passport_benefit_incidents(reported_by);
create index if not exists passport_cancellations_buyer_idx on public.passport_cancellation_requests(buyer_user_id);
create index if not exists passport_entitlements_product_idx on public.passport_entitlements(product_id);
create index if not exists passport_entitlements_user_idx on public.passport_entitlements(user_id);
create index if not exists passport_orders_product_idx on public.passport_orders(product_id);;

-- 20261118040539 mvp_demo_seed

insert into public.partners (id, legal_name, trade_name, status)
values ('00000000-0000-4000-8000-0000000000de', 'Parceiro Exemplo Marapass', 'Parceiro Exemplo', 'approved')
on conflict (id) do nothing;

insert into public.establishments (id, partner_id, name, description, category, city, state_code, is_active, is_public)
values
 ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000de', 'Lençóis Tur (exemplo)', 'Agência de passeios nos Lençóis Maranhenses.', 'tours', 'Barreirinhas', 'MA', true, true),
 ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000de', 'Sabor da Ilha (exemplo)', 'Culinária maranhense no centro histórico.', 'gastronomy', 'São Luís', 'MA', true, true)
on conflict (id) do nothing;

insert into public.experiences (id, establishment_id, title, description, category, price_from_cents, duration_minutes, capacity, booking_required, status)
values
 ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000e1', 'Circuito Lagoa Azul (exemplo)', 'Passeio de 4x4 às lagoas com parada para banho.', 'tours', 15000, 240, 12, true, 'published'),
 ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000e1', 'Pôr do sol nas dunas (exemplo)', 'Caminhada guiada ao entardecer.', 'nature', 9000, 150, 15, true, 'published'),
 ('00000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000e2', 'Degustação de arroz de cuxá (exemplo)', 'Menu degustação com pratos típicos.', 'gastronomy', 6000, 90, 20, false, 'published')
on conflict (id) do nothing;

insert into public.experience_slots (experience_id, starts_at, ends_at, capacity)
select e.id, d + time '08:00', d + time '08:00' + make_interval(mins => e.duration_minutes), e.capacity
from public.experiences e
cross join generate_series(current_date + 1, current_date + 14, interval '1 day') d
where e.id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2')
  and not exists (select 1 from public.experience_slots s where s.experience_id = e.id);

insert into public.offers (id, establishment_id, experience_id, title, description, discount_type, discount_value,
  max_issuances, per_user_limit, is_published, access_scope, eligible_items, calculation_base,
  issue_until, convert_until, use_until)
values
 ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1',
  '10% no Circuito Lagoa Azul (exemplo)', 'Desconto para quem tem o app.', 'percent', 10, 200, 1, true, 'public',
  'Circuito Lagoa Azul', 'Valor do passeio por pessoa', now() + interval '60 days', now() + interval '75 days', now() + interval '90 days'),
 ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a3',
  'R$ 15 na degustação (exemplo)', 'Válido para portadores do passaporte.', 'fixed', 15, 100, 1, true, 'passport',
  'Degustação de arroz de cuxá', 'Valor total da conta', now() + interval '60 days', now() + interval '75 days', now() + interval '90 days')
on conflict (id) do nothing;

insert into public.passport_products (id, name, description, price_cents, currency, validity_start_rule,
  duration_days, activation_deadline_days, booking_explanation, included_benefits_explanation, is_published)
values ('00000000-0000-4000-8000-0000000000b1', 'Passaporte Lençóis 7 dias (exemplo)',
  'Passaporte de exemplo com benefícios em parceiros de Barreirinhas e São Luís.', 4990, 'BRL', 'activation',
  7, 30, 'Passeios com horário exigem reserva pelo app.', 'Inclui o desconto na degustação.', false)
on conflict (id) do nothing;

insert into public.passport_product_benefits (product_id, offer_id, issue_window_days, convert_window_days, use_window_days, max_per_holder, booking_required)
select '00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000f2', 7, 7, 7, 1, false
where not exists (select 1 from public.passport_product_benefits where product_id = '00000000-0000-4000-8000-0000000000b1');;

-- 20261119183558 delete_my_account_v2_turista

create or replace function public.delete_my_account()
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'auth'
as $function$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if exists (select 1 from public.staff_members s where s.user_id = uid and s.is_active)
     or exists (select 1 from public.partner_members m where m.user_id = uid and m.is_active)
     or exists (select 1 from public.partners p where p.owner_user_id = uid)
     or exists (select 1 from public.mvp_partner_members m where m.user_id = uid) then
    raise exception 'Contas de parceiro são excluídas pelo suporte, para não apagar ofertas ativas.' using errcode = 'P0001';
  end if;
  -- Pedido pago é registro fiscal: não some pela própria conta.
  if exists (select 1 from public.passport_orders o where o.buyer_user_id = uid and o.status in ('paid','cancel_requested','refunded')) then
    raise exception 'Sua conta tem uma compra registrada. Peça a exclusão pelo suporte.' using errcode = 'P0001';
  end if;

  -- Atividade do turista: reservas, cupons, check-ins e passaporte gratuito.
  delete from public.checkins
    where user_id = uid or reservation_id in (select id from public.reservations where user_id = uid);
  delete from public.coupon_redemptions
    where coupon_instance_id in (select id from public.coupon_instances where beneficiary_user_id = uid
                                 or reservation_id in (select id from public.reservations where user_id = uid));
  delete from public.coupon_instances
    where beneficiary_user_id = uid or reservation_id in (select id from public.reservations where user_id = uid)
       or passport_entitlement_id in (select id from public.passport_entitlements where user_id = uid);
  delete from public.reservations where user_id = uid;
  delete from public.passport_benefit_incidents
    where reported_by = uid or entitlement_id in (select id from public.passport_entitlements where user_id = uid);
  delete from public.passport_entitlement_benefits
    where entitlement_id in (select id from public.passport_entitlements where user_id = uid);
  delete from public.passport_entitlements where user_id = uid;
  delete from public.passport_cancellation_requests where buyer_user_id = uid;
  delete from public.passport_orders where buyer_user_id = uid;

  delete from public.assistant_messages
    where conversation_id in (select id from public.assistant_conversations where user_id = uid);
  delete from public.assistant_conversations where user_id = uid;
  delete from public.mvp_partner_requests where user_id = uid;
  update public.mvp_coupons set used_by = null where used_by = uid;
  delete from public.profiles where id = uid;
  begin
    delete from auth.users where id = uid;
  exception when foreign_key_violation then
    raise exception 'Sua conta tem registros do sistema anterior. Peça a exclusão pelo suporte.' using errcode = 'P0001';
  end;
end $function$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;;

-- 20261119184441 revoke_anon_write_assistant

revoke insert, update, delete on public.assistant_conversations, public.assistant_messages from anon;;

-- 20261119184630 my_reservation_and_coupon_wrappers

-- Versões para o app: o usuário vem do login (auth.uid()), nunca de parâmetro.
create or replace function public.my_request_reservation(p_slot_id uuid, p_participants integer, p_request_key text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return public.request_reservation(p_slot_id, uid, p_participants, p_request_key);
end $$;

create or replace function public.my_issue_coupon(p_offer_id uuid, p_idempotency_key text, p_reservation_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_reservation_id is not null and not exists (select 1 from public.reservations where id = p_reservation_id and user_id = uid) then
    raise exception 'reservation not found' using errcode = '42501';
  end if;
  return public.issue_coupon(p_offer_id, uid, p_idempotency_key, p_reservation_id);
end $$;

revoke execute on function public.my_request_reservation(uuid, integer, text) from public, anon;
revoke execute on function public.my_issue_coupon(uuid, text, uuid) from public, anon;
grant execute on function public.my_request_reservation(uuid, integer, text) to authenticated;
grant execute on function public.my_issue_coupon(uuid, text, uuid) to authenticated;;

-- 20261119191136 mvp_reservations_owner_scope

-- Cada item do catálogo pertence a um parceiro; só ele vê e decide as reservas desse item.
create table if not exists public.mvp_item_owners (
  item_key text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.mvp_item_owners enable row level security;
revoke all on public.mvp_item_owners from anon, authenticated;
grant select on public.mvp_item_owners to authenticated;
create policy mvp_item_owners_read_own on public.mvp_item_owners for select to authenticated
  using (user_id = (select auth.uid()));

-- Dono da reserva: o parceiro do item ou o parceiro da oferta do cupom usado.
create or replace function public.mvp_owns_reservation(p_item_key text, p_cupom_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select (select auth.uid()) is not null and public.mvp_is_partner() and (
    exists (select 1 from public.mvp_item_owners o where o.item_key = p_item_key and o.user_id = (select auth.uid()))
    or (p_cupom_key ~ '^po:[0-9a-fA-F-]{36}$' and exists (
          select 1 from public.mvp_partner_offers po
          where po.id = substr(p_cupom_key, 4)::uuid and po.created_by = (select auth.uid())))
  );
$$;
revoke execute on function public.mvp_owns_reservation(text, text) from public, anon;
grant execute on function public.mvp_owns_reservation(text, text) to authenticated;

drop policy if exists mvp_reservations_read on public.mvp_reservations;
create policy mvp_reservations_read on public.mvp_reservations for select
  using (user_id = (select auth.uid()) or public.mvp_owns_reservation(item_key, cupom_key));

create or replace function public.mvp_decide_reservation(p_id uuid, p_accept boolean)
returns public.mvp_reservations language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  select * into r from public.mvp_reservations where id = p_id;
  if not found or not public.mvp_owns_reservation(r.item_key, r.cupom_key) then
    raise exception 'Reserva de outro parceiro.' using errcode = '42501';
  end if;
  update public.mvp_reservations set status = case when p_accept then 'confirmada' else 'recusada' end, updated_at = now(),
    history = history || jsonb_build_array(case when p_accept then 'Confirmada pelo parceiro' else 'Recusada pelo parceiro' end)
  where id = p_id and status = 'solicitada' returning * into r;
  if not found then raise exception 'not pending' using errcode = '22023'; end if;
  return r;
end $$;

-- Demo: itens dos 3 polos para os parceiros de teste.
insert into public.mvp_item_owners(item_key, user_id)
select k, u.id from (values
  ('parceiro-lencois@demo.marapass.test', array['lagoas','rio','por','4x4','kite','marcelino','mangue','buriti','juja','vila','atins-hotel','ev-sabores','ev-regata','buriti-bolsa','foto-dunas','transfer-slz','transfer-atins']),
  ('parceiro-saoluis@demo.marapass.test', array['centro','boi','quilombo','cozinha','conchas','slz-hotel','ev-boi','foto-centro','barco','ceramica']),
  ('parceiro-chapada@demo.marapass.test', array['cach','mirante','biojoia'])
) t(email, keys) join auth.users u on u.email = t.email, unnest(t.keys) k
on conflict (item_key) do nothing;;

-- 20261120014114 admin_company_profile

-- Perfil do cadastro administrativo. Imagens pequenas, privadas e transacionais.
create table private.company_profile_photos (
  partner_id uuid primary key references public.partners(id) on delete cascade,
  jpeg bytea not null check (octet_length(jpeg) between 4 and 131072)
);
revoke all on private.company_profile_photos from public, anon, authenticated;

create function private.require_direct_company_phone() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.partners p where p.id = new.partner_id
    and regexp_replace(coalesce(p.contact_phone,''),'[ ()-]','','g') ~ '^\+?[1-9][0-9]{9,14}$') then
    raise exception 'Informe um WhatsApp válido com DDD.';
  end if;
  return new;
end $$;
create trigger require_direct_company_phone before insert on public.partner_direct_registrations
for each row execute function private.require_direct_company_phone();

create function public.admin_register_company_profile(
  p_request_key uuid, p_legal_name text, p_trade_name text, p_contact_email text,
  p_city text, p_category text, p_whatsapp text, p_tax_id text,
  p_latitude numeric, p_longitude numeric, p_photo text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  registration jsonb;
  photo bytea;
begin
  perform private.assert_admin(auth.uid());
  if (auth.jwt()->>'aal') is distinct from 'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  if p_whatsapp is null or p_whatsapp !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'WhatsApp inválido.'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90
    or p_longitude not between -180 and 180 then raise exception 'Coordenadas inválidas.'; end if;
  if p_photo is null or length(p_photo) not between 8 and 174764 then raise exception 'Foto inválida.'; end if;
  photo := decode(p_photo,'base64');
  if octet_length(photo) > 131072 or substring(photo from 1 for 3) <> decode('ffd8ff','hex')
    or right(encode(substring(photo from greatest(1,octet_length(photo)-1)),'hex'),4) <> 'ffd9'
    then raise exception 'A foto deve ser JPEG.'; end if;
  registration := public.admin_register_direct_company_once(auth.uid(),p_legal_name,p_trade_name,
    p_contact_email,p_city,p_category,p_whatsapp,p_tax_id,p_request_key);
  if not (registration->>'already_registered')::boolean then
    update public.establishments set latitude=p_latitude, longitude=p_longitude
      where id=(registration->>'establishment_id')::uuid;
    insert into private.company_profile_photos values ((registration->>'partner_id')::uuid,photo);
  end if;
  return registration;
end $$;

create function public.admin_company_photo(p_partner_id uuid) returns text
language plpgsql security definer stable set search_path = '' as $$
begin
  perform private.assert_admin(auth.uid());
  if (auth.jwt()->>'aal') is distinct from 'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  return (select encode(jpeg,'base64') from private.company_profile_photos where partner_id=p_partner_id);
end $$;
revoke all on function public.admin_register_company_profile(uuid,text,text,text,text,text,text,text,numeric,numeric,text),public.admin_company_photo(uuid) from public,anon,authenticated;
grant execute on function public.admin_register_company_profile(uuid,text,text,text,text,text,text,text,numeric,numeric,text),public.admin_company_photo(uuid) to authenticated;
;

-- 20261120175508 lojas_limpeza_legado

drop function if exists public.my_request_reservation(uuid, integer, text);
drop function if exists public.my_issue_coupon(uuid, text, uuid);
create index if not exists mvp_item_owners_user_id_idx on public.mvp_item_owners (user_id);
alter table private.coupon_media_uploads add column if not exists id bigint generated always as identity;
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'private.coupon_media_uploads'::regclass and contype = 'p') then
    alter table private.coupon_media_uploads add constraint coupon_media_uploads_pkey primary key (id);
  end if;
end $$;;

-- 20261120213234 mvp_item_slots

-- Horários e vagas por parceiro: cada item tem os turnos Manhã e Tarde com
-- faixa de horário, dias da semana e limite de pessoas por dia.
create table if not exists public.mvp_item_slots (
  item_key text not null,
  period text not null check (period in ('Manhã', 'Tarde')),
  hours text not null check (length(hours) between 3 and 40),
  capacity integer not null check (capacity between 1 and 500),
  weekdays smallint[] not null default '{1,2,3,4,5,6,7}' check (weekdays <@ '{1,2,3,4,5,6,7}'::smallint[]),
  active boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (item_key, period)
);
alter table public.mvp_item_slots enable row level security;
revoke all on public.mvp_item_slots from anon, authenticated;
grant select on public.mvp_item_slots to anon, authenticated;
create policy mvp_item_slots_read on public.mvp_item_slots for select to anon, authenticated using (true);
create index if not exists mvp_item_slots_updated_by_idx on public.mvp_item_slots (updated_by);

-- Parceiro dono do item grava um turno.
create or replace function public.mvp_set_item_slot(p_item_key text, p_period text, p_hours text, p_capacity integer, p_weekdays smallint[], p_active boolean)
returns public.mvp_item_slots language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); s public.mvp_item_slots;
begin
  if not public.mvp_is_partner() or not exists (select 1 from public.mvp_item_owners o where o.item_key = p_item_key and o.user_id = uid) then
    raise exception 'Este item não pertence à sua conta.' using errcode = '42501';
  end if;
  if coalesce(array_length(p_weekdays, 1), 0) = 0 then
    raise exception 'Escolha ao menos um dia da semana.' using errcode = 'P0001';
  end if;
  insert into public.mvp_item_slots (item_key, period, hours, capacity, weekdays, active, updated_by, updated_at)
  values (p_item_key, p_period, btrim(p_hours), p_capacity, p_weekdays, p_active, uid, now())
  on conflict (item_key, period) do update set hours = excluded.hours, capacity = excluded.capacity,
    weekdays = excluded.weekdays, active = excluded.active, updated_by = uid, updated_at = now()
  returning * into s;
  return s;
end $$;
revoke all on function public.mvp_set_item_slot(text, text, text, integer, smallint[], boolean) from public, anon;
grant execute on function public.mvp_set_item_slot(text, text, text, integer, smallint[], boolean) to authenticated;

-- Vagas restantes por dia e turno (só contagens; ninguém vê reservas alheias).
create or replace function public.mvp_slot_availability(p_item_key text, p_from date, p_to date)
returns table(day date, period text, hours text, capacity integer, booked integer, open boolean)
language sql stable security definer set search_path = public as $$
  select d::date, s.period, s.hours, s.capacity,
         coalesce((select sum(r.people)::int from public.mvp_reservations r
                   where r.item_key = s.item_key and r.day = d::date and r.period = s.period
                     and r.status in ('solicitada', 'confirmada')), 0),
         s.active and extract(isodow from d)::smallint = any (s.weekdays)
  from public.mvp_item_slots s
  cross join generate_series(p_from, least(p_to, p_from + 186), interval '1 day') d
  where s.item_key = p_item_key
  order by 1, 2;
$$;
revoke all on function public.mvp_slot_availability(text, date, date) from public;
grant execute on function public.mvp_slot_availability(text, date, date) to anon, authenticated;

-- A reserva respeita o turno configurado. Item sem turno cadastrado segue sem limite.
create or replace function public.mvp_request_reservation(p_item_key text, p_item_title text, p_day date, p_period text, p_people integer, p_request_key text, p_cupom_key text DEFAULT NULL::text, p_customer_name text DEFAULT NULL::text)
 returns mvp_reservations language plpgsql security definer set search_path to 'public' as $function$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations; s public.mvp_item_slots; used int;
begin
  if p_day <= (now() at time zone 'America/Fortaleza')::date then raise exception 'day must be in the future' using errcode = '22023'; end if;
  select * into r from public.mvp_reservations where request_key = p_request_key;
  if found then
    if r.user_id <> uid then raise exception 'request key in use' using errcode = '42501'; end if;
    return r;
  end if;
  perform private.mvp_rate_check(uid, 'reservation', 10);
  select * into s from public.mvp_item_slots where item_key = p_item_key and period = p_period;
  if found then
    if not s.active or not (extract(isodow from p_day)::smallint = any (s.weekdays)) then
      raise exception 'Este horário não funciona no dia escolhido.' using errcode = 'P0001';
    end if;
    perform pg_advisory_xact_lock(hashtext(p_item_key || '|' || p_day || '|' || p_period));
    select coalesce(sum(people), 0) into used from public.mvp_reservations
      where item_key = p_item_key and day = p_day and period = p_period and status in ('solicitada', 'confirmada');
    if used + p_people > s.capacity then
      raise exception 'Restam % vagas neste horário.', greatest(s.capacity - used, 0) using errcode = 'P0001';
    end if;
  end if;
  insert into public.mvp_reservations (user_id, item_key, item_title, day, period, people, cupom_key, customer_name, request_key, history)
  values (uid, p_item_key, p_item_title, p_day, p_period, p_people, p_cupom_key, left(p_customer_name, 60), p_request_key,
          jsonb_build_array('Pedido enviado em ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM')))
  on conflict (request_key) do nothing returning * into r;
  if r.id is null then
    select * into r from public.mvp_reservations where request_key = p_request_key and user_id = uid;
  end if;
  return r;
end $function$;;

-- 20261120213553 mvp_use_reservation

-- Comprovante da reserva: o parceiro lê o QR (ou digita R-XXXXXXXX), a
-- reserva confirmada vira "concluida" (utilizada) e o turista ganha o
-- check-in do lugar no passaporte.
create or replace function public.mvp_use_reservation(p_code text, p_polo text, p_cidade text)
returns public.mvp_reservations language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations; code text; n int;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  code := lower(regexp_replace(btrim(coalesce(p_code, '')), '^(MARAPASS-RES:|R-)', '', 'i'));
  if code !~ '^[0-9a-f]{8}([0-9a-f-]{28})?$' then
    raise exception 'Código de reserva inválido.' using errcode = 'P0001';
  end if;
  select count(*) into n from public.mvp_reservations x
    where x.id::text like code || '%' and public.mvp_owns_reservation(x.item_key, x.cupom_key);
  if n = 0 then raise exception 'Reserva não encontrada nesta conta.' using errcode = 'P0001'; end if;
  if n > 1 then raise exception 'Use o QR code: há mais de uma reserva com esse início.' using errcode = 'P0001'; end if;
  select * into r from public.mvp_reservations x
    where x.id::text like code || '%' and public.mvp_owns_reservation(x.item_key, x.cupom_key) for update;
  if r.status = 'concluida' then raise exception 'Esta reserva já foi utilizada.' using errcode = 'P0001'; end if;
  if r.status <> 'confirmada' then raise exception 'A reserva precisa estar confirmada.' using errcode = 'P0001'; end if;
  if r.day > (now() at time zone 'America/Fortaleza')::date then
    raise exception 'Esta reserva é para %.', to_char(r.day, 'DD/MM') using errcode = 'P0001';
  end if;
  update public.mvp_reservations set status = 'concluida', updated_at = now(),
    history = history || jsonb_build_array('Utilizada em ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM HH24:MI'))
  where id = r.id returning * into r;
  insert into public.mvp_checkins (user_id, item_key, polo, cidade, method)
  values (r.user_id, left(r.item_key, 60), left(coalesce(nullif(btrim(p_polo), ''), 'MaraPass'), 40), left(coalesce(nullif(btrim(p_cidade), ''), 'Maranhão'), 80), 'reserva')
  on conflict (user_id, item_key, day) do nothing;
  return r;
end $$;
revoke all on function public.mvp_use_reservation(text, text, text) from public, anon;
grant execute on function public.mvp_use_reservation(text, text, text) to authenticated;;
