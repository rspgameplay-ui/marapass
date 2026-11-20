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
