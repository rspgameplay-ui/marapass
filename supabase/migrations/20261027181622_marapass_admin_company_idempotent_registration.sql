
-- MaraPass: retry-safe administrative registration; the legacy function is retained
-- as private service-only operational primitive.
ALTER TABLE public.partner_direct_registrations ADD COLUMN IF NOT EXISTS request_key uuid;
CREATE UNIQUE INDEX IF NOT EXISTS partner_direct_registration_request_key_unique
 ON public.partner_direct_registrations(registered_by_user_id,request_key)
 WHERE request_key IS NOT NULL;

CREATE FUNCTION public.admin_register_direct_company_once(
 p_admin_user_id uuid,
 p_legal_name text,
 p_trade_name text,
 p_contact_email text,
 p_city text,
 p_category text,
 p_contact_phone text,
 p_tax_id text,
 p_request_key uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_existing record;
 v_registration jsonb;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_request_key IS NULL THEN RAISE EXCEPTION 'idempotency key required'; END IF;
 -- Serialize parallel retries of the same user intent.
 PERFORM pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(p_admin_user_id::text || ':' || p_request_key::text, 0)
 );
 SELECT d.partner_id,d.establishment_id,p.status,p.owner_user_id,e.is_public
   INTO v_existing
   FROM public.partner_direct_registrations d
   JOIN public.partners p ON p.id=d.partner_id
   JOIN public.establishments e ON e.id=d.establishment_id
   WHERE d.registered_by_user_id=p_admin_user_id AND d.request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object(
     'partner_id',v_existing.partner_id,
     'establishment_id',v_existing.establishment_id,
     'partner_status',v_existing.status,
     'establishment_public',v_existing.is_public,
     'owner_linked',v_existing.owner_user_id IS NOT NULL,
     'already_registered',true);
 END IF;

 v_registration:=public.admin_register_direct_company(
   p_admin_user_id,p_legal_name,p_trade_name,p_contact_email,p_city,
   p_category,p_contact_phone,p_tax_id);
 UPDATE public.partner_direct_registrations
 SET request_key=p_request_key
 WHERE partner_id=(v_registration->>'partner_id')::uuid
   AND registered_by_user_id=p_admin_user_id;
 RETURN v_registration || jsonb_build_object('already_registered',false);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_register_direct_company_once(uuid,text,text,text,text,text,text,text,uuid)
 FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_register_direct_company_once(uuid,text,text,text,text,text,text,text,uuid)
 TO service_role;
;
