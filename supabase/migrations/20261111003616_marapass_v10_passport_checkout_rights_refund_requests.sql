
-- Freezes the checkout contract and offers a traceable cancellation path.
CREATE FUNCTION public.mp_prepare_passport_order(
 p_user_id uuid,p_product_id uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_product public.passport_products%rowtype;v_existing public.passport_orders%rowtype;
 v_snapshot jsonb;v_benefits jsonb;v_order uuid;
BEGIN
 IF p_user_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'user and intent key required';END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(
 pg_catalog.hashtextextended('passport-order:'||p_user_id::text||':'||p_request_key::text,0));
 SELECT * INTO v_existing FROM public.passport_orders
 WHERE buyer_user_id=p_user_id AND purchase_intent_key=p_request_key;
 IF FOUND THEN
  IF v_existing.product_id<>p_product_id THEN RAISE EXCEPTION 'reused checkout key';END IF;
  RETURN jsonb_build_object('order_id',v_existing.id,'status',v_existing.status,
   'price_cents',v_existing.price_cents,'terms_snapshot',v_existing.terms_snapshot,
   'payment_enabled',false,'already_prepared',true);
 END IF;
 SELECT * INTO v_product FROM public.passport_products WHERE id=p_product_id AND is_published;
 IF NOT FOUND OR (v_product.validity_start_rule='fixed' AND v_product.fixed_ends_at<=now())
 THEN RAISE EXCEPTION 'passport not available';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
 'offer_id',o.id,'offer_title',o.title,'partner',p.trade_name,
 'establishment',e.name,'eligible_items',o.eligible_items,
 'base',o.calculation_base,'discount_type',o.discount_type,
 'discount_value',o.discount_value,'minimum_purchase_cents',o.minimum_purchase_cents,
 'maximum_discount_cents',o.maximum_discount_cents,
 'fixed_use_policy',o.fixed_use_policy,'advance_booking_required',o.advance_booking_required,
 'issue_window_days',b.issue_window_days,'convert_window_days',b.convert_window_days,
 'use_window_days',b.use_window_days,'limit',b.max_per_holder,'requires_booking',b.booking_required,
 'issue_until',o.issue_until,'convert_until',o.convert_until,'use_until',o.use_until
 ) ORDER BY o.title),'[]'::jsonb) INTO v_benefits
 FROM public.passport_product_benefits b JOIN public.offers o ON o.id=b.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id WHERE b.product_id=p_product_id;
 IF jsonb_array_length(v_benefits)=0 THEN RAISE EXCEPTION 'no passport benefits';END IF;
 v_snapshot:=jsonb_build_object(
  'product_id',v_product.id,'terms_version',v_product.terms_version,
  'name',v_product.name,'description',v_product.description,'price_cents',v_product.price_cents,
  'currency',v_product.currency,'validity_start_rule',v_product.validity_start_rule,
  'duration_days',v_product.duration_days,'fixed_starts_at',v_product.fixed_starts_at,
  'fixed_ends_at',v_product.fixed_ends_at,'activation_deadline_days',v_product.activation_deadline_days,
  'booking_explanation',v_product.booking_explanation,
  'included_benefits_explanation',v_product.included_benefits_explanation,
  'legal_terms',v_product.legal_terms,'benefits',v_benefits,
  'coupon_issuance_individually_free',true,
  'services_not_included_in_purchase',true,
  'right_of_withdrawal_no_automatic_waiver',true,
  'captured_at',now());
 INSERT INTO public.passport_orders(
  buyer_user_id,product_id,purchase_intent_key,price_cents,currency,status,terms_snapshot
 ) VALUES(p_user_id,p_product_id,p_request_key,v_product.price_cents,'BRL','pending_payment',v_snapshot)
 RETURNING id INTO v_order;
 RETURN jsonb_build_object('order_id',v_order,'status','pending_payment',
  'price_cents',v_product.price_cents,'terms_snapshot',v_snapshot,
  'payment_enabled',false,'already_prepared',false);
END $$;

CREATE FUNCTION public.mp_record_verified_passport_payment(
 p_order_id uuid,p_provider text,p_provider_reference text,p_verified_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE o public.passport_orders%rowtype;p public.passport_products%rowtype;
 v_entitlement uuid;v_from timestamptz;v_until timestamptz;v_status text;
BEGIN
 -- Service-role only; caller MUST verify and reconcile signed PSP webhook
 -- before invoking this function. There is no consumer endpoint for it.
 IF length(trim(coalesce(p_provider,'')))<2 OR length(trim(coalesce(p_provider_reference,'')))<8
 OR p_verified_at IS NULL OR p_verified_at>now()+interval '5 minutes' THEN
  RAISE EXCEPTION 'verified payment evidence required';END IF;
 SELECT * INTO o FROM public.passport_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'order not found';END IF;
 IF o.status='paid' THEN
  IF o.provider_payment_reference IS DISTINCT FROM p_provider_reference
  THEN RAISE EXCEPTION 'payment mismatch'; END IF;
  RETURN jsonb_build_object('order_id',o.id,'status','paid','already_recorded',true);
 END IF;
 IF o.status<>'pending_payment' THEN RAISE EXCEPTION 'order not pending payment';END IF;
 SELECT * INTO p FROM public.passport_products WHERE id=o.product_id;
 UPDATE public.passport_orders SET status='paid',payment_provider=p_provider,
 provider_payment_reference=p_provider_reference,payment_confirmed_at=p_verified_at,
 updated_at=now() WHERE id=o.id;
 v_from:=CASE p.validity_start_rule WHEN 'purchase' THEN p_verified_at
   WHEN 'fixed' THEN p.fixed_starts_at ELSE NULL END;
 v_until:=CASE p.validity_start_rule WHEN 'purchase' THEN p_verified_at+(p.duration_days||' days')::interval
   WHEN 'fixed' THEN p.fixed_ends_at ELSE NULL END;
 v_status:=CASE WHEN p.validity_start_rule='activation' THEN 'pending_activation' ELSE 'active' END;
 INSERT INTO public.passport_entitlements(
 order_id,user_id,product_id,status,purchased_at,valid_from,valid_until
 ) VALUES(o.id,o.buyer_user_id,o.product_id,v_status,p_verified_at,v_from,v_until)
 RETURNING id INTO v_entitlement;
 INSERT INTO public.passport_entitlement_benefits(
  entitlement_id,offer_id,terms_snapshot,issue_until,convert_until,use_until,
  max_issuances,booking_required
 )
 SELECT v_entitlement,b.offer_id,
   benefit.value,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.issue_window_days||' days')::interval,(benefit.value->>'issue_until')::timestamptz) END,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.convert_window_days||' days')::interval,(benefit.value->>'convert_until')::timestamptz) END,
   CASE WHEN v_from IS NULL THEN NULL ELSE least(
      v_from+(b.use_window_days||' days')::interval,(benefit.value->>'use_until')::timestamptz) END,
   b.max_per_holder,b.booking_required
 FROM public.passport_product_benefits b
 JOIN jsonb_array_elements(o.terms_snapshot->'benefits') AS benefit(value)
   ON benefit.value->>'offer_id'=b.offer_id::text
 WHERE b.product_id=o.product_id;
 RETURN jsonb_build_object('order_id',o.id,'status','paid',
 'entitlement_id',v_entitlement,'requires_activation',v_status='pending_activation');
END $$;

CREATE FUNCTION public.mp_activate_passport(
 p_user_id uuid,p_entitlement_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE e public.passport_entitlements%rowtype;p public.passport_products%rowtype;v_at timestamptz;
BEGIN
 SELECT * INTO e FROM public.passport_entitlements WHERE id=p_entitlement_id FOR UPDATE;
 IF NOT FOUND OR e.user_id<>p_user_id THEN RAISE EXCEPTION 'passport not owned by user';END IF;
 IF e.status='active' THEN RETURN jsonb_build_object('entitlement_id',e.id,'status','active','already_active',true);END IF;
 SELECT * INTO p FROM public.passport_products WHERE id=e.product_id;
 IF p.validity_start_rule<>'activation' OR e.status<>'pending_activation' THEN
  RAISE EXCEPTION 'passport cannot be activated';
 END IF;
 IF e.purchased_at+(p.activation_deadline_days||' days')::interval<now() THEN
  RAISE EXCEPTION 'activation deadline reached; request customer support';
 END IF;
 v_at:=now();
 UPDATE public.passport_entitlements SET status='active',valid_from=v_at,
 valid_until=v_at+(p.duration_days||' days')::interval,activated_at=v_at WHERE id=e.id;
 UPDATE public.passport_entitlement_benefits eb SET
 issue_until=least(v_at+(pb.issue_window_days||' days')::interval,
  (eb.terms_snapshot->>'issue_until')::timestamptz),
 convert_until=least(v_at+(pb.convert_window_days||' days')::interval,
  (eb.terms_snapshot->>'convert_until')::timestamptz),
 use_until=least(v_at+(pb.use_window_days||' days')::interval,
  (eb.terms_snapshot->>'use_until')::timestamptz)
 FROM public.passport_product_benefits pb WHERE pb.offer_id=eb.offer_id
 AND pb.product_id=e.product_id AND eb.entitlement_id=e.id;
 RETURN jsonb_build_object('entitlement_id',e.id,'status','active','already_active',false);
END $$;

CREATE FUNCTION public.mp_request_passport_cancellation(
 p_user_id uuid,p_order_id uuid,p_reason text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE o public.passport_orders%rowtype;r public.passport_cancellation_requests%rowtype;
 v_stat boolean;
BEGIN
 SELECT * INTO o FROM public.passport_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR o.buyer_user_id<>p_user_id THEN RAISE EXCEPTION 'order not owned by user';END IF;
 IF o.status IN ('refunded','cancelled') THEN
  RETURN jsonb_build_object('order_id',o.id,'status',o.status,'already_completed',true);
 END IF;
 SELECT * INTO r FROM public.passport_cancellation_requests WHERE order_id=o.id;
 IF FOUND THEN RETURN jsonb_build_object('request_id',r.id,'status',r.status,
   'statutory_withdrawal',r.statutory_withdrawal,'already_requested',true); END IF;
 v_stat:=o.payment_confirmed_at IS NOT NULL AND now()<=o.payment_confirmed_at+interval '7 days';
 INSERT INTO public.passport_cancellation_requests(order_id,buyer_user_id,reason,statutory_withdrawal)
 VALUES(o.id,p_user_id,nullif(left(coalesce(p_reason,''),2000),''),v_stat) RETURNING * INTO r;
 UPDATE public.passport_orders SET status=CASE WHEN status='pending_payment' THEN 'cancelled'
    ELSE 'cancel_requested' END,updated_at=now() WHERE id=o.id;
 RETURN jsonb_build_object('request_id',r.id,'status','requested',
 'statutory_withdrawal',v_stat,
 'refund_executed',false,'next_step','manual_or_provider_refund_review');
END $$;

CREATE FUNCTION public.mp_report_passport_benefit_issue(
 p_user_id uuid,p_entitlement_id uuid,p_offer_id uuid,p_reason text,p_remedy text
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 IF length(trim(coalesce(p_reason,''))) NOT BETWEEN 4 AND 2000
  OR p_remedy NOT IN ('fulfillment','equivalent','rescission_refund')
 THEN RAISE EXCEPTION 'describe issue and choose a remedy';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.passport_entitlements e
 JOIN public.passport_entitlement_benefits b ON b.entitlement_id=e.id
 WHERE e.id=p_entitlement_id AND b.offer_id=p_offer_id AND e.user_id=p_user_id)
 THEN RAISE EXCEPTION 'benefit not within the user contract';END IF;
 INSERT INTO public.passport_benefit_incidents(
 entitlement_id,offer_id,reported_by,reason,requested_remedy
 )VALUES(p_entitlement_id,p_offer_id,p_user_id,trim(p_reason),p_remedy) RETURNING id INTO v_id;
 RETURN jsonb_build_object('incident_id',v_id,'status','open');
END $$;

CREATE FUNCTION private.mp_guard_passport_order_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.buyer_user_id IS DISTINCT FROM OLD.buyer_user_id
 OR NEW.product_id IS DISTINCT FROM OLD.product_id
 OR NEW.price_cents IS DISTINCT FROM OLD.price_cents
 OR NEW.currency IS DISTINCT FROM OLD.currency
 OR NEW.terms_snapshot IS DISTINCT FROM OLD.terms_snapshot
 OR NEW.purchase_intent_key IS DISTINCT FROM OLD.purchase_intent_key THEN
 RAISE EXCEPTION 'checkout contract snapshot cannot be altered';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_freeze_order_contract BEFORE UPDATE ON public.passport_orders
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_order_snapshot();

DO $b$
DECLARE f text;
BEGIN
 FOR f IN SELECT unnest(ARRAY[
 'mp_prepare_passport_order(uuid,uuid,uuid)',
 'mp_record_verified_passport_payment(uuid,text,text,timestamptz)',
 'mp_activate_passport(uuid,uuid)',
 'mp_request_passport_cancellation(uuid,uuid,text)',
 'mp_report_passport_benefit_issue(uuid,uuid,uuid,text,text)'
 ]) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC,anon,authenticated',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role',f);
 END LOOP;
END $b$;
;
