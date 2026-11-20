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
