
CREATE OR REPLACE FUNCTION private.capture_coupon_conditions()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_presentation jsonb;
BEGIN
 SELECT jsonb_build_object(
   'terms',o.description,'presentation',o.presentation,
   'establishment',e.name,'city',e.city,'address',e.street_address
 ) INTO v_presentation FROM public.offers o
 JOIN public.establishments e ON e.id=o.establishment_id WHERE o.id=NEW.offer_id;
 -- Previous trigger overwrote the new immutable commercial snapshot.
 -- Keep commercial conditions authoritative while retaining display context.
 NEW.conditions_snapshot:=COALESCE(v_presentation,'{}'::jsonb)
   || COALESCE(NEW.conditions_snapshot,'{}'::jsonb);
 RETURN NEW;
END $$;

CREATE FUNCTION private.mp_guard_coupon_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 IF NEW.offer_id IS DISTINCT FROM OLD.offer_id
 OR NEW.beneficiary_user_id IS DISTINCT FROM OLD.beneficiary_user_id
 OR NEW.reservation_id IS DISTINCT FROM OLD.reservation_id
 OR NEW.passport_entitlement_id IS DISTINCT FROM OLD.passport_entitlement_id
 OR NEW.issuance_key IS DISTINCT FROM OLD.issuance_key
 OR NEW.display_code IS DISTINCT FROM OLD.display_code
 OR NEW.offer_title_snapshot IS DISTINCT FROM OLD.offer_title_snapshot
 OR NEW.discount_type_snapshot IS DISTINCT FROM OLD.discount_type_snapshot
 OR NEW.discount_value_snapshot IS DISTINCT FROM OLD.discount_value_snapshot
 OR NEW.conditions_snapshot IS DISTINCT FROM OLD.conditions_snapshot
 OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
 OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
 THEN RAISE EXCEPTION 'issued coupon identity and commercial conditions are immutable';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER mp_guard_coupon_snapshot_before_update
BEFORE UPDATE ON public.coupon_instances FOR EACH ROW
EXECUTE FUNCTION private.mp_guard_coupon_snapshot();
;
