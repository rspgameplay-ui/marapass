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
