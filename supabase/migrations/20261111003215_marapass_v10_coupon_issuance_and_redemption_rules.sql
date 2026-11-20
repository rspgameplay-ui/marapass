
-- New issuance pipeline: immutable snapshot, passport entitlement, issuance
-- and conversion deadlines and same instance through validation.
CREATE FUNCTION public.mp_issue_coupon_v2(
 p_offer_id uuid,p_user_id uuid,p_idempotency_key text,
 p_reservation_id uuid DEFAULT NULL,p_passport_entitlement_id uuid DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_offer record;
 v_old public.coupon_instances%rowtype;
 v_benefit public.passport_entitlement_benefits%rowtype;
 v_id uuid;
 v_code text;
 v_issuance_until timestamptz;
 v_conversion_until timestamptz;
 v_use_until timestamptz;
 v_snapshot jsonb;
BEGIN
 IF p_user_id IS NULL OR length(coalesce(p_idempotency_key,'')) NOT BETWEEN 16 AND 180
 THEN RAISE EXCEPTION 'invalid issuance request';END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coupon-issue:'||p_idempotency_key,0));
 SELECT * INTO v_old FROM public.coupon_instances WHERE issuance_key=p_idempotency_key;
 IF FOUND THEN
  IF v_old.offer_id<>p_offer_id OR v_old.beneficiary_user_id<>p_user_id
    OR v_old.reservation_id IS DISTINCT FROM p_reservation_id
    OR v_old.passport_entitlement_id IS DISTINCT FROM p_passport_entitlement_id
  THEN RAISE EXCEPTION 'idempotency key reused with another issuance';END IF;
  RETURN v_old.id;
 END IF;
 SELECT o.*, e.partner_id,e.is_active,p.status partner_status
 INTO v_offer FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE o.id=p_offer_id FOR UPDATE OF o;

 IF NOT FOUND OR NOT v_offer.is_published OR NOT v_offer.is_active
   OR v_offer.partner_status<>'approved'
   OR (v_offer.starts_at IS NOT NULL AND v_offer.starts_at>now())
   OR (v_offer.ends_at IS NOT NULL AND v_offer.ends_at<=now()) THEN
  RAISE EXCEPTION 'offer unavailable';
 END IF;
 v_issuance_until:=v_offer.issue_until;
 v_conversion_until:=v_offer.convert_until;
 v_use_until:=v_offer.use_until;
 IF v_offer.access_scope='passport' THEN
  IF p_passport_entitlement_id IS NULL THEN RAISE EXCEPTION 'paid passport required'; END IF;
  SELECT b.* INTO v_benefit FROM public.passport_entitlement_benefits b
   JOIN public.passport_entitlements e ON e.id=b.entitlement_id
   JOIN public.passport_orders ord ON ord.id=e.order_id
   WHERE b.entitlement_id=p_passport_entitlement_id
     AND b.offer_id=p_offer_id
     AND e.user_id=p_user_id
     AND e.status='active'
     AND e.valid_from<=now() AND e.valid_until>now()
     AND ord.status='paid' AND ord.payment_confirmed_at IS NOT NULL
     AND b.issue_until>now();
  IF NOT FOUND THEN RAISE EXCEPTION 'eligible active paid passport not found'; END IF;
  v_issuance_until:=least(v_issuance_until,v_benefit.issue_until);
  v_conversion_until:=least(v_conversion_until,v_benefit.convert_until);
  v_use_until:=least(v_use_until,v_benefit.use_until);
  IF (SELECT count(*) FROM public.coupon_instances ci
   WHERE ci.offer_id=p_offer_id AND ci.passport_entitlement_id=p_passport_entitlement_id
      AND ci.status<>'cancelled')>=v_benefit.max_issuances THEN
     RAISE EXCEPTION 'passport benefit issuance limit reached'; END IF;
 ELSIF p_passport_entitlement_id IS NOT NULL THEN
  RAISE EXCEPTION 'public coupon does not require paid passport';
 END IF;
 IF v_issuance_until IS NULL OR v_issuance_until<=now()
   OR v_conversion_until IS NULL OR v_conversion_until<=now()
   OR v_use_until IS NULL OR v_use_until<=now() THEN
  RAISE EXCEPTION 'offer benefit window expired';
 END IF;
 IF v_offer.max_issuances IS NOT NULL AND
   (SELECT count(*) FROM public.coupon_instances WHERE offer_id=p_offer_id)>=v_offer.max_issuances
 THEN RAISE EXCEPTION 'offer issuance limit reached'; END IF;
 IF (SELECT count(*) FROM public.coupon_instances
     WHERE offer_id=p_offer_id AND beneficiary_user_id=p_user_id AND status<>'cancelled'
    )>=v_offer.per_user_limit THEN
   RAISE EXCEPTION 'user offer limit reached';END IF;
 IF p_reservation_id IS NOT NULL AND NOT EXISTS (
   SELECT 1 FROM public.reservations r
   WHERE r.id=p_reservation_id AND r.user_id=p_user_id
     AND r.status='confirmed' AND r.experience_id=v_offer.experience_id
 ) THEN RAISE EXCEPTION 'invalid linked reservation';END IF;

 v_snapshot:=jsonb_build_object(
  'offer_id',v_offer.id,'commercial_terms_version',v_offer.commercial_terms_version,
  'access_scope',v_offer.access_scope,'eligible_items',v_offer.eligible_items,
  'calculation_base',v_offer.calculation_base,
  'minimum_purchase_cents',v_offer.minimum_purchase_cents,
  'maximum_discount_cents',v_offer.maximum_discount_cents,
  'fixed_use_policy',v_offer.fixed_use_policy,
  'issuing_deadline',v_issuance_until,
  'conversion_deadline',v_conversion_until,
  'use_deadline',v_use_until,
  'advance_booking_required',v_offer.advance_booking_required,
  'disclosure_extra',v_offer.disclosure_extra,
  'nominal_not_cash',true,
  'passport_no_individual_issuance_charge',v_offer.access_scope='passport'
 );
 v_code:='MP-'||upper(substr(encode(extensions.gen_random_bytes(10),'hex'),1,16));
 INSERT INTO public.coupon_instances(
  offer_id,beneficiary_user_id,reservation_id,issuance_key,display_code,
  offer_title_snapshot,discount_type_snapshot,discount_value_snapshot,expires_at,
  conditions_snapshot,passport_entitlement_id
 )
 VALUES(
  p_offer_id,p_user_id,p_reservation_id,p_idempotency_key,v_code,
  v_offer.title,v_offer.discount_type,v_offer.discount_value,v_conversion_until,
  v_snapshot,p_passport_entitlement_id
 ) RETURNING id INTO v_id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.mp_issue_coupon_v2(uuid,uuid,text,uuid,uuid)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_issue_coupon_v2(uuid,uuid,text,uuid,uuid)
TO service_role;

-- Keep existing service signature but route all calls through new checks.
CREATE OR REPLACE FUNCTION public.issue_coupon(
 p_offer_id uuid,p_user_id uuid,p_idempotency_key text,p_reservation_id uuid DEFAULT NULL
) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=''
AS $$
 SELECT public.mp_issue_coupon_v2(p_offer_id,p_user_id,p_idempotency_key,p_reservation_id,NULL::uuid)
$$;
REVOKE ALL ON FUNCTION public.issue_coupon(uuid,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.issue_coupon(uuid,uuid,text,uuid) TO service_role;

-- Validation calculates the *actual* applied discount against eligible
-- transaction base; a nominal coupon cannot turn into cash or be reused.
CREATE OR REPLACE FUNCTION public.redeem_coupon(
 p_coupon_instance_id uuid,p_validator_user_id uuid,p_idempotency_key text,
 p_transaction_amount_cents integer DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_old public.coupon_redemptions%rowtype;
 v_coupon public.coupon_instances%rowtype;
 v_partner_id uuid;
 v_establishment_id uuid;
 v_partner_status text;
 v_establishment_active boolean;
 v_redemption_id uuid;
 v_min integer;
 v_max integer;
 v_discount integer;
BEGIN
 IF p_validator_user_id IS NULL
   OR length(coalesce(p_idempotency_key,'')) NOT BETWEEN 16 AND 180
   OR p_transaction_amount_cents IS NULL OR p_transaction_amount_cents<0
 THEN RAISE EXCEPTION 'eligible purchase base and valid request are required'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coupon-redeem:'||p_idempotency_key,0));
 SELECT * INTO v_old FROM public.coupon_redemptions WHERE idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_old.coupon_instance_id<>p_coupon_instance_id
     OR v_old.validated_by_user_id<>p_validator_user_id
     OR v_old.transaction_amount_cents IS DISTINCT FROM p_transaction_amount_cents THEN
    RAISE EXCEPTION 'validation idempotency key reused with another transaction';END IF;
  RETURN v_old.id;
 END IF;
 SELECT * INTO v_coupon FROM public.coupon_instances WHERE id=p_coupon_instance_id FOR UPDATE;
 IF NOT FOUND OR v_coupon.status<>'issued' OR v_coupon.expires_at<=now() THEN
  RAISE EXCEPTION 'coupon not valid for conversion';END IF;
 SELECT e.partner_id,e.id,p.status,e.is_active INTO
 v_partner_id,v_establishment_id,v_partner_status,v_establishment_active
 FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id WHERE o.id=v_coupon.offer_id;
 IF v_partner_status<>'approved' OR NOT v_establishment_active OR NOT EXISTS(
  SELECT 1 FROM public.partners p WHERE p.id=v_partner_id AND(
   p.owner_user_id=p_validator_user_id OR EXISTS(
   SELECT 1 FROM public.partner_members m WHERE m.partner_id=p.id
     AND m.user_id=p_validator_user_id AND m.is_active
     AND m.member_role IN ('manager','validator'))
  )
 ) THEN RAISE EXCEPTION 'partner or validator unauthorized'; END IF;
 v_min:=COALESCE((v_coupon.conditions_snapshot->>'minimum_purchase_cents')::int,0);
 v_max:=(v_coupon.conditions_snapshot->>'maximum_discount_cents')::int;
 v_discount:=public.mp_calculate_coupon_discount(
  v_coupon.discount_type_snapshot,v_coupon.discount_value_snapshot,
  p_transaction_amount_cents,v_min,v_max);
 IF v_discount<=0 THEN RAISE EXCEPTION 'purchase not eligible for discount';END IF;
 INSERT INTO public.coupon_redemptions(
  coupon_instance_id,partner_id,establishment_id,validated_by_user_id,idempotency_key,
  transaction_amount_cents,eligible_base_cents,applied_discount_cents
 ) VALUES(
  p_coupon_instance_id,v_partner_id,v_establishment_id,p_validator_user_id,
  p_idempotency_key,p_transaction_amount_cents,p_transaction_amount_cents,v_discount
 ) RETURNING id INTO v_redemption_id;
 UPDATE public.coupon_instances SET status='redeemed',redeemed_at=now(),
   eligible_base_cents=p_transaction_amount_cents,applied_discount_cents=v_discount
 WHERE id=p_coupon_instance_id;
 INSERT INTO public.checkins(
 user_id,establishment_id,reservation_id,coupon_redemption_id,method)
 VALUES(v_coupon.beneficiary_user_id,v_establishment_id,v_coupon.reservation_id,v_redemption_id,'coupon');
 RETURN v_redemption_id;
END $$;
REVOKE ALL ON FUNCTION public.redeem_coupon(uuid,uuid,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_coupon(uuid,uuid,text,integer) TO service_role;
;
