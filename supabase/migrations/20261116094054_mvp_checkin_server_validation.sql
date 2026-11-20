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
