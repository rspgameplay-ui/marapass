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
