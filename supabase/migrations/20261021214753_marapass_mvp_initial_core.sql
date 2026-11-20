
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
