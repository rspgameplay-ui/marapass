
create or replace function public.issue_coupon(
  p_offer_id uuid, p_user_id uuid, p_idempotency_key text,
  p_reservation_id uuid default null
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_offer record;
  v_old public.coupon_instances%rowtype;
  v_id uuid;
  v_code text;
  v_expiry timestamptz;
begin
  if p_user_id is null or length(p_idempotency_key) not between 16 and 180 then
    raise exception 'invalid issuance request';
  end if;
  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;
  if found then
    if v_old.offer_id<>p_offer_id or v_old.beneficiary_user_id<>p_user_id
       or v_old.reservation_id is distinct from p_reservation_id then
      raise exception 'idempotency key reused with another request';
    end if;
    return v_old.id;
  end if;
  select o.*,e.partner_id,e.is_active,p.status as partner_status into v_offer
    from public.offers o
    join public.establishments e on e.id=o.establishment_id
    join public.partners p on p.id=e.partner_id
    where o.id=p_offer_id
    for update of o;
  if not found or not v_offer.is_published or not v_offer.is_active
      or v_offer.partner_status<>'approved'
      or (v_offer.starts_at is not null and v_offer.starts_at>now())
      or (v_offer.ends_at is not null and v_offer.ends_at<=now()) then
    raise exception 'offer unavailable';
  end if;
  if v_offer.max_issuances is not null
    and (select count(*) from public.coupon_instances where offer_id=p_offer_id)
          >= v_offer.max_issuances then
    raise exception 'offer issuance limit reached';
  end if;
  -- Cancelled issuances remain in audit history, but do not block the
  -- customer's new issuance when a linked reservation was cancelled.
  if (select count(*) from public.coupon_instances
        where offer_id=p_offer_id and beneficiary_user_id=p_user_id
          and status<>'cancelled') >= v_offer.per_user_limit then
    raise exception 'user offer limit reached';
  end if;
  if p_reservation_id is not null and not exists (
    select 1 from public.reservations r
    where r.id=p_reservation_id and r.user_id=p_user_id
      and r.status='confirmed' and r.experience_id=v_offer.experience_id
  ) then
    raise exception 'invalid linked reservation';
  end if;
  v_code := 'MP-' || upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,12));
  v_expiry := least(coalesce(v_offer.ends_at,now()+interval '30 days'),
                    now()+interval '30 days');
  insert into public.coupon_instances(
    offer_id,beneficiary_user_id,reservation_id,issuance_key,display_code,
    offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,expires_at)
  values(p_offer_id,p_user_id,p_reservation_id,p_idempotency_key,v_code,
    v_offer.title,v_offer.discount_type,v_offer.discount_value,v_expiry)
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.issue_coupon(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.issue_coupon(uuid,uuid,text,uuid) to service_role;
;
