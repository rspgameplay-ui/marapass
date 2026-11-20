
-- Immutable commercial terms once exposed; no unilateral withdrawal of
-- benefits attached to a paid passport or to an already issued coupon.
CREATE FUNCTION private.mp_guard_offer_contract()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.is_published OR EXISTS(SELECT 1 FROM public.passport_product_benefits WHERE offer_id=OLD.id)
     OR EXISTS(SELECT 1 FROM public.coupon_instances WHERE offer_id=OLD.id)
  THEN RAISE EXCEPTION 'offer may not be deleted; withdraw through a lawful resolution process';END IF;
  RETURN OLD;
 END IF;

 IF OLD.is_published AND
  (
    NEW.title IS DISTINCT FROM OLD.title
    OR NEW.description IS DISTINCT FROM OLD.description
    OR NEW.discount_type IS DISTINCT FROM OLD.discount_type
    OR NEW.discount_value IS DISTINCT FROM OLD.discount_value
    OR NEW.currency IS DISTINCT FROM OLD.currency
    OR NEW.access_scope IS DISTINCT FROM OLD.access_scope
    OR NEW.eligible_items IS DISTINCT FROM OLD.eligible_items
    OR NEW.calculation_base IS DISTINCT FROM OLD.calculation_base
    OR NEW.minimum_purchase_cents IS DISTINCT FROM OLD.minimum_purchase_cents
    OR NEW.maximum_discount_cents IS DISTINCT FROM OLD.maximum_discount_cents
    OR NEW.fixed_use_policy IS DISTINCT FROM OLD.fixed_use_policy
    OR NEW.issue_until IS DISTINCT FROM OLD.issue_until
    OR NEW.convert_until IS DISTINCT FROM OLD.convert_until
    OR NEW.use_until IS DISTINCT FROM OLD.use_until
    OR NEW.advance_booking_required IS DISTINCT FROM OLD.advance_booking_required
    OR NEW.per_user_limit IS DISTINCT FROM OLD.per_user_limit
    OR NEW.max_issuances IS DISTINCT FROM OLD.max_issuances
  ) THEN
   RAISE EXCEPTION 'published commercial terms are immutable; create a new offer/version';
 END IF;
 IF OLD.is_published AND NOT NEW.is_published AND EXISTS (
   SELECT 1 FROM public.passport_entitlement_benefits eb
   JOIN public.passport_entitlements e ON e.id=eb.entitlement_id
   WHERE eb.offer_id=OLD.id AND e.status IN ('active','pending_activation')
 ) THEN
   RAISE EXCEPTION 'paid passport benefit cannot be silently removed';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_offer_contract_before_update_delete
BEFORE UPDATE OR DELETE ON public.offers
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_offer_contract();

CREATE FUNCTION private.mp_guard_passport_terms()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.is_published OR EXISTS(SELECT 1 FROM public.passport_orders WHERE product_id=OLD.id)
  THEN RAISE EXCEPTION 'published/contracted passport cannot be deleted'; END IF;
  RETURN OLD;
 END IF;
 IF OLD.is_published AND (
  NEW.name IS DISTINCT FROM OLD.name OR NEW.description IS DISTINCT FROM OLD.description
  OR NEW.price_cents IS DISTINCT FROM OLD.price_cents
  OR NEW.validity_start_rule IS DISTINCT FROM OLD.validity_start_rule
  OR NEW.duration_days IS DISTINCT FROM OLD.duration_days
  OR NEW.fixed_starts_at IS DISTINCT FROM OLD.fixed_starts_at
  OR NEW.fixed_ends_at IS DISTINCT FROM OLD.fixed_ends_at
  OR NEW.activation_deadline_days IS DISTINCT FROM OLD.activation_deadline_days
  OR NEW.booking_explanation IS DISTINCT FROM OLD.booking_explanation
  OR NEW.included_benefits_explanation IS DISTINCT FROM OLD.included_benefits_explanation
  OR NEW.legal_terms IS DISTINCT FROM OLD.legal_terms
 ) THEN RAISE EXCEPTION 'published passport terms are immutable; create a new version'; END IF;
 IF OLD.is_published AND NOT NEW.is_published AND EXISTS (
   SELECT 1 FROM public.passport_orders o WHERE o.product_id=OLD.id AND o.status='paid'
 ) THEN RAISE EXCEPTION 'passport with paid orders cannot be withdrawn without remedy';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_passport_terms_before_update_delete
BEFORE UPDATE OR DELETE ON public.passport_products
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_terms();

CREATE FUNCTION private.mp_guard_passport_benefit_config()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.product_id ELSE NEW.product_id END;
 IF EXISTS(SELECT 1 FROM public.passport_products p WHERE p.id=v_id AND p.is_published)
    OR EXISTS(SELECT 1 FROM public.passport_orders o WHERE o.product_id=v_id)
 THEN RAISE EXCEPTION 'cannot change benefits of published or contracted passport; create a new version'; END IF;
 IF TG_OP='INSERT' OR TG_OP='UPDATE' THEN
   IF NOT EXISTS(SELECT 1 FROM public.offers o WHERE o.id=NEW.offer_id AND o.access_scope='passport')
   THEN RAISE EXCEPTION 'passport benefit requires passport-exclusive offer'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE TRIGGER mp_guard_passport_benefit_config_before_write
BEFORE INSERT OR UPDATE OR DELETE ON public.passport_product_benefits
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_passport_benefit_config();

CREATE FUNCTION private.mp_guard_publish_passport()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.is_published AND NOT OLD.is_published THEN
  IF NOT EXISTS (
   SELECT 1 FROM public.passport_product_benefits pb JOIN public.offers o ON o.id=pb.offer_id
   WHERE pb.product_id=NEW.id AND o.is_published AND o.access_scope='passport'
  ) THEN RAISE EXCEPTION 'passport requires published benefits before publication'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_publish_passport_before_update
BEFORE UPDATE OF is_published ON public.passport_products
FOR EACH ROW EXECUTE FUNCTION private.mp_guard_publish_passport();

CREATE FUNCTION public.mp_calculate_coupon_discount(
 p_discount_type text,p_discount_value numeric,p_eligible_base_cents integer,
 p_minimum_purchase_cents integer,p_maximum_discount_cents integer
)
RETURNS integer LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_discount integer;
BEGIN
 IF p_eligible_base_cents IS NULL OR p_eligible_base_cents<0 OR p_discount_value<=0
   OR p_discount_type NOT IN ('percent','fixed') OR p_minimum_purchase_cents<0
   OR (p_maximum_discount_cents IS NOT NULL AND p_maximum_discount_cents<=0)
 THEN RAISE EXCEPTION 'invalid discount calculation'; END IF;
 IF p_eligible_base_cents<p_minimum_purchase_cents THEN RETURN 0; END IF;
 v_discount:=CASE WHEN p_discount_type='percent'
  THEN round(p_eligible_base_cents::numeric*p_discount_value/100)::int
  ELSE round(p_discount_value*100)::int END;
 RETURN least(p_eligible_base_cents,v_discount,coalesce(p_maximum_discount_cents,2147483647));
END $$;
REVOKE ALL ON FUNCTION public.mp_calculate_coupon_discount(text,numeric,integer,integer,integer)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_calculate_coupon_discount(text,numeric,integer,integer,integer)
 TO service_role;
;
