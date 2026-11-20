CREATE OR REPLACE FUNCTION public.mp_admin_publish_passport(p_admin_user_id uuid, p_product_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_count integer;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT count(*) INTO v_count FROM public.passport_product_benefits pb
 JOIN public.offers o ON o.id=pb.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE pb.product_id=p_product_id AND o.is_published AND o.access_scope='passport'
 AND e.is_active AND e.is_public AND p.status='approved';
 IF v_count=0 THEN RAISE EXCEPTION 'a published exclusive offer is required';END IF;
 IF v_count<>(SELECT count(*) FROM public.passport_product_benefits WHERE product_id=p_product_id)
 THEN RAISE EXCEPTION 'all included benefits and partners must be available before publication';END IF;
 UPDATE public.passport_products SET is_published=true,updated_at=now()
 WHERE id=p_product_id AND NOT is_published;
 IF NOT FOUND THEN RAISE EXCEPTION 'passport not in draft state';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'published',p_admin_user_id,
 jsonb_build_object('benefit_count',v_count));
 RETURN jsonb_build_object('product_id',p_product_id,'published',true);
END $function$;
CREATE OR REPLACE FUNCTION public.mp_prepare_passport_order(p_user_id uuid, p_product_id uuid, p_request_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
 IF EXISTS (SELECT 1 FROM public.passport_product_benefits b
 JOIN public.offers o ON o.id=b.offer_id
 JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE b.product_id=p_product_id
 AND (NOT o.is_published OR NOT e.is_active OR NOT e.is_public OR p.status<>'approved'
 OR o.convert_until<=now() OR o.issue_until<=now()))
 THEN RAISE EXCEPTION 'benefits unavailable; new checkout suspended without affecting existing paid contracts';END IF;
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
END $function$;;
