begin;
-- Um cancelamento sem conversão libera a unidade e a reserva de emissão.
drop index if exists public.mvp_coupons_one_active;
create unique index mvp_coupons_one_active on public.mvp_coupons(user_id,cupom_key)
  where used_at is null and sale_stage not in ('cancelled','declined');

create function public.mvp_coupon_action(p_code text,p_action text,p_reason text default null,p_channel text default 'app')
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; partner boolean; tourist boolean;
  previous text; target text; financial boolean:=p_action like 'fee_%';
begin
  if p_channel is null or p_channel not in ('app','panel','qr','whatsapp','admin') then raise exception 'Canal inválido.'; end if;
  if p_channel='admin' or financial then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale is not null
    and (user_id=u or (sale->>'owner'=u::text and public.mvp_is_partner()) or p_channel='admin') for update;
  if not found then raise exception 'Cupom indisponível.'; end if;
  partner:=(c.sale->>'owner'=u::text and public.mvp_is_partner()) or p_channel='admin';
  tourist:=coalesce(c.user_id=u,false);
  if p_action in ('cancel','decline','dispute','resolve','fee_disputed','fee_pending','fee_invoiced','fee_paid')
    and length(coalesce(trim(p_reason),'')) not between 1 and 300 then raise exception 'Registre o motivo ou a referência.'; end if;
  previous:=case when financial then c.fee_state else c.sale_stage end;
  target:=case p_action when 'interest' then 'interested' when 'cancel' then 'cancelled' when 'decline' then 'declined'
    when 'dispute' then 'disputed' when 'utilize' then 'utilized' when 'complete' then 'completed'
    when 'fee_invoiced' then 'invoiced' when 'fee_paid' then 'paid' when 'fee_disputed' then 'disputed' when 'fee_pending' then 'pending'
    when 'resolve' then coalesce((select detail->>'from' from private.mvp_coupon_events where coupon_id=c.id
      and kind in ('amount_mismatch','dispute') order by id desc limit 1),'issued') end;
  if target is null then raise exception 'Ação desconhecida.'; end if;
  if (p_action in ('decline','resolve','utilize','complete') and not partner) or
     (p_action='interest' and not tourist) then raise exception 'Ação não autorizada.' using errcode='42501'; end if;
  if previous=target then return; end if;
  if financial then
    if c.used_at is null or not ((target='invoiced' and previous='pending') or (target='paid' and previous='invoiced')
      or (target='disputed' and previous in ('pending','invoiced','paid')) or (target='pending' and previous='disputed')) then
      raise exception 'Transição financeira indisponível.'; end if;
    update public.mvp_coupons set fee_state=target where id=c.id;
  else
    if not ((p_action in ('interest','cancel','decline') and c.used_at is null and previous in ('issued','interested')
          and now()<(c.sale->>'expires')::timestamptz)
      or (p_action='dispute' and previous not in ('cancelled','declined','disputed') and (c.used_at is not null or now()<(c.sale->>'expires')::timestamptz))
      or (p_action='resolve' and previous='disputed')
      or (p_action='utilize' and previous='converted' and coalesce((select sum(paid_cents) from private.mvp_coupon_entries where coupon_id=c.id),0)>0)
      or (p_action='utilize' and previous='converted' and c.amount_cents=0)
      or (p_action='complete' and previous='utilized')) then raise exception 'Transição indisponível para este cupom.'; end if;
    update public.mvp_coupons set sale_stage=target where id=c.id;
  end if;
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,p_action,u,
    jsonb_build_object('from',previous,'to',target,'channel',p_channel,'reason',nullif(trim(p_reason),'')));
end $$;

create function public.mvp_admin_sale_status(p_id uuid,p_status text,p_reason text default null) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user();
begin
  perform private.assert_admin(u);
  if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  if p_status not in ('Ativa','Em análise','Recusada','Pausada','Encerrada') or p_status is null then raise exception 'Estado inválido.'; end if;
  if p_status in ('Recusada','Em análise') and length(coalesce(trim(p_reason),'')) not between 1 and 120 then raise exception 'Registre o motivo.'; end if;
  update public.mvp_partner_offers set status=p_status,pause_reason=nullif(trim(p_reason),''),updated_at=now()
    where id=p_id and status<>'Rascunho' and (p_status<>'Ativa' or
      (sale_terms is not null and valid_until>=(now() at time zone 'America/Fortaleza')::date and
       exists(select 1 from public.mvp_partner_members m where m.user_id=created_by)));
  if not found then raise exception 'Revise as condições, o parceiro e a vigência antes de publicar.'; end if;
end $$;
create function public.mvp_coupon_overview(p_scope text,p_filters jsonb default '{}') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); summary jsonb;
begin
  if p_scope='admin' then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  elsif p_scope is distinct from 'partner' or not public.mvp_is_partner() then raise exception 'Perfil indisponível.'; end if;
  select jsonb_build_object('issued',count(*),'converted',count(c.used_at),'paid',coalesce(sum(e.paid),0),
    'discount',coalesce(sum((c.sale->>'discount_cents')::bigint) filter(where c.used_at is not null),0),
    'fee',coalesce(sum(e.fee),0),'ticket',coalesce(round(sum(e.paid)::numeric/nullif(count(c.used_at),0)),0),
    'conversion_pct',coalesce(round(100.0*count(c.used_at)/nullif(count(*),0),1),0))
    into summary from public.mvp_coupons c left join lateral
      (select sum(x.paid_cents) paid,sum(x.fee_cents) fee from private.mvp_coupon_entries x where x.coupon_id=c.id)e on true
    where c.sale is not null and (p_scope='admin' or c.sale->>'owner'=u::text) and private.mvp_sale_match(c,p_filters);
  return summary;
end $$;
revoke all on function public.mvp_coupon_action(text,text,text,text),public.mvp_admin_sale_status(uuid,text,text),
  public.mvp_coupon_overview(text,jsonb) from public,anon,authenticated;
grant execute on function public.mvp_coupon_action(text,text,text,text),public.mvp_admin_sale_status(uuid,text,text),
  public.mvp_coupon_overview(text,jsonb) to authenticated;
commit;
