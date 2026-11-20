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
