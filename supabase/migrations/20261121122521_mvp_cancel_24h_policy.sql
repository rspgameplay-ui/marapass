-- Política do cliente (21/11): 100% de reembolso até 24 h antes do início.
-- Início = dia + primeira hora do turno do parceiro (ou 8h manhã, 14h tarde e
-- check-in das hospedagens). O cancelamento continua permitido; fora do
-- prazo, o histórico registra que não há reembolso.
create or replace function public.mvp_reservation_start(r public.mvp_reservations)
returns timestamptz language sql stable security definer set search_path = public as $$
  select (r.day + make_interval(hours => coalesce(
           (select substring(s.hours from '(\d{1,2})\s*h')::int from public.mvp_item_slots s
             where s.item_key = r.item_key and s.period = r.period),
           case when r.period = 'Tarde' then 14 when r.period = 'Manhã' then 8 else 14 end)))
         at time zone 'America/Fortaleza';
$$;
revoke all on function public.mvp_reservation_start(public.mvp_reservations) from public, anon;
grant execute on function public.mvp_reservation_start(public.mvp_reservations) to authenticated;

create or replace function public.mvp_update_reservation(p_id uuid, p_action text, p_day date DEFAULT NULL::date, p_period text DEFAULT NULL::text, p_people integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text)
 returns mvp_reservations language plpgsql security definer set search_path to 'public' as $function$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations; free boolean;
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
    free := now() <= public.mvp_reservation_start(r) - interval '24 hours';
    update public.mvp_reservations set status = 'cancelada', updated_at = now(),
      history = history || jsonb_build_array(
        'Cancelada: ' || left(coalesce(p_reason, 'sem motivo'), 120)
        || case when free then ' (dentro do prazo: reembolso integral)' else ' (menos de 24 h antes: sem reembolso)' end)
    where id = p_id returning * into r;
  else
    raise exception 'invalid action' using errcode = '22023';
  end if;
  return r;
end $function$;;
