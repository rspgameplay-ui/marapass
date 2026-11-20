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
