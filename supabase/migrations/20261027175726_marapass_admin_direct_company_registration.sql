
ALTER TABLE public.partners ALTER COLUMN owner_user_id DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS partners_tax_id_unique ON public.partners(tax_id) WHERE tax_id IS NOT NULL;
ALTER TABLE public.partners ADD CONSTRAINT partners_tax_id_digits CHECK(tax_id IS NULL OR tax_id ~ '^[0-9]{14}$');
CREATE TABLE public.partner_direct_registrations(
 partner_id uuid PRIMARY KEY REFERENCES public.partners(id) ON DELETE CASCADE,
 establishment_id uuid NOT NULL UNIQUE REFERENCES public.establishments(id),
 registered_by_user_id uuid NOT NULL REFERENCES auth.users(id),
 registration_source text NOT NULL DEFAULT 'admin' CHECK(registration_source='admin'),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.partner_direct_registrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.partner_direct_registrations FROM public, anon, authenticated;
GRANT SELECT ON public.partner_direct_registrations TO authenticated;
CREATE POLICY partner_direct_registrations_admin_aal2 ON public.partner_direct_registrations FOR SELECT TO authenticated
USING ((auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid()) AND s.is_active AND s.staff_role='admin'));
CREATE FUNCTION public.admin_register_direct_company(
 p_admin_user_id uuid,p_legal_name text,p_trade_name text,p_contact_email text,
 p_city text,p_category text,p_contact_phone text DEFAULT NULL,p_tax_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_partner uuid;v_establishment uuid;v_tax_id text;v_email text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_legal_name IS NULL OR length(trim(p_legal_name)) NOT BETWEEN 2 AND 160
    OR p_trade_name IS NULL OR length(trim(p_trade_name)) NOT BETWEEN 2 AND 160
    OR p_city IS NULL OR length(trim(p_city)) NOT BETWEEN 2 AND 120 THEN
  RAISE EXCEPTION 'invalid company or city name';
 END IF;
 v_email:=lower(trim(coalesce(p_contact_email,'')));
 IF length(v_email) NOT BETWEEN 5 AND 254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  THEN RAISE EXCEPTION 'invalid contact email';
 END IF;
 IF p_category IS NULL OR p_category NOT IN (
 'tours','nature','culture','gastronomy','lodging','events','crafts','photography','tourist_transport','services')
  THEN RAISE EXCEPTION 'invalid category';END IF;
 IF p_contact_phone IS NOT NULL AND length(trim(p_contact_phone))>32 THEN
  RAISE EXCEPTION 'invalid phone';END IF;
 v_tax_id:=NULLIF(regexp_replace(coalesce(p_tax_id,''),'[^0-9]','','g'),'');
 IF v_tax_id IS NOT NULL AND length(v_tax_id)<>14 THEN RAISE EXCEPTION 'invalid CNPJ';END IF;
 INSERT INTO public.partners(owner_user_id,legal_name,trade_name,contact_email,contact_phone,tax_id,status)
 VALUES(NULL,trim(p_legal_name),trim(p_trade_name),v_email,NULLIF(trim(coalesce(p_contact_phone,'')),''),v_tax_id,'pending')
 RETURNING id INTO v_partner;
 INSERT INTO public.establishments(partner_id,name,category,city,state_code,is_active,is_public)
 VALUES(v_partner,trim(p_trade_name),p_category,trim(p_city),'MA',true,false)
 RETURNING id INTO v_establishment;
 INSERT INTO public.partner_direct_registrations(partner_id,establishment_id,registered_by_user_id)
 VALUES(v_partner,v_establishment,p_admin_user_id);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner',v_partner,'admin_direct_registration',p_admin_user_id,
 jsonb_build_object('establishment_id',v_establishment,'status','pending','owner_linked',false,'source','admin'));
 RETURN jsonb_build_object('partner_id',v_partner,'establishment_id',v_establishment,
 'partner_status','pending','establishment_public',false,'owner_linked',false);
END $$;
REVOKE ALL ON FUNCTION public.admin_register_direct_company(uuid,text,text,text,text,text,text,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_register_direct_company(uuid,text,text,text,text,text,text,text) TO service_role;
CREATE INDEX partner_direct_registrations_actor ON public.partner_direct_registrations(registered_by_user_id);
;
