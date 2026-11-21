-- Reagendar ou aumentar participantes também respeita os turnos e vagas.
create or replace function private.mvp_slot_guard(p_item_key text, p_day date, p_period text, p_people integer, p_exclude uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s public.mvp_item_slots; used int;
begin
  select * into s from public.mvp_item_slots where item_key = p_item_key and period = p_period;
  if not found then return; end if;
  if not s.active or not (extract(isodow from p_day)::smallint = any (s.weekdays)) then
    raise exception 'Este horário não funciona no dia escolhido.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtext(p_item_key || '|' || p_day || '|' || p_period));
  select coalesce(sum(people), 0) into used from public.mvp_reservations
    where item_key = p_item_key and day = p_day and period = p_period
      and status in ('solicitada', 'confirmada') and id is distinct from p_exclude;
  if used + p_people > s.capacity then
    raise exception 'Restam % vagas neste horário.', greatest(s.capacity - used, 0) using errcode = 'P0001';
  end if;
end $$;
revoke all on function private.mvp_slot_guard(text, date, text, integer, uuid) from public, anon, authenticated;

create or replace function public.mvp_update_reservation(p_id uuid, p_action text, p_day date DEFAULT NULL::date, p_period text DEFAULT NULL::text, p_people integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text)
 returns mvp_reservations language plpgsql security definer set search_path to 'public' as $function$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  select * into r from public.mvp_reservations where id = p_id and user_id = uid for update;
  if not found then raise exception 'not found' using errcode = '42501'; end if;
  if r.status not in ('solicitada','confirmada') then raise exception 'reservation closed' using errcode = '22023'; end if;
  if p_action = 'reschedule' then
    if p_day is null or p_day <= (now() at time zone 'America/Fortaleza')::date then raise exception 'day must be in the future' using errcode = '22023'; end if;
    perform private.mvp_slot_guard(r.item_key, p_day, p_period, r.people, r.id);
    update public.mvp_reservations set day = p_day, period = p_period, status = 'solicitada', updated_at = now(),
      history = history || jsonb_build_array('Novo dia pedido: ' || to_char(p_day, 'DD/MM') || ' (' || p_period || ')') where id = p_id returning * into r;
  elsif p_action = 'people' then
    if p_people > r.people then perform private.mvp_slot_guard(r.item_key, r.day, r.period, p_people, r.id); end if;
    update public.mvp_reservations set people = p_people, updated_at = now(),
      history = history || jsonb_build_array('Participantes alterados para ' || p_people) where id = p_id returning * into r;
  elsif p_action = 'cancel' then
    update public.mvp_reservations set status = 'cancelada', updated_at = now(),
      history = history || jsonb_build_array('Cancelada: ' || left(coalesce(p_reason, 'sem motivo'), 120)) where id = p_id returning * into r;
  else
    raise exception 'invalid action' using errcode = '22023';
  end if;
  return r;
end $function$;;
