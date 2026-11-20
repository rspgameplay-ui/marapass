
CREATE FUNCTION public.mp_admin_create_offer(
 p_admin_user_id uuid,p_data jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
 v_offer uuid; v_est uuid;
 v_type text; v_access text; v_title text;
 v_value numeric; v_publish boolean;
 v_issue timestamptz;v_convert timestamptz;v_use timestamptz;
 v_min integer;v_max integer;
 v_partner_status text;v_est_active boolean;v_est_public boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>12000
 THEN RAISE EXCEPTION 'invalid offer payload';END IF;
 v_est:=(p_data->>'establishment_id')::uuid;
 SELECT p.status,e.is_active,e.is_public INTO v_partner_status,v_est_active,v_est_public
 FROM public.establishments e JOIN public.partners p ON p.id=e.partner_id WHERE e.id=v_est;
 IF NOT FOUND OR NOT v_est_active THEN RAISE EXCEPTION 'establishment not available';END IF;
 v_type:=p_data->>'discount_type';v_access:=p_data->>'access_scope';
 v_title:=trim(coalesce(p_data->>'title',''));v_value:=(p_data->>'discount_value')::numeric;
 v_publish:=coalesce((p_data->>'publish')::boolean,false);
 v_issue:=(p_data->>'issue_until')::timestamptz;
 v_convert:=(p_data->>'convert_until')::timestamptz;
 v_use:=(p_data->>'use_until')::timestamptz;
 v_min:=coalesce((p_data->>'minimum_purchase_cents')::int,0);
 v_max:=(p_data->>'maximum_discount_cents')::int;
 IF length(v_title) NOT BETWEEN 3 AND 160
   OR v_type NOT IN ('percent','fixed')
   OR v_access NOT IN ('public','passport')
   OR v_value IS NULL OR v_value<=0
   OR (v_type='percent' AND v_value>100)
   OR v_min<0 OR (v_max IS NOT NULL AND v_max<=0)
   OR length(trim(coalesce(p_data->>'eligible_items','')))<3
   OR length(trim(coalesce(p_data->>'calculation_base','')))<3
   OR v_issue IS NULL OR v_convert IS NULL OR v_use IS NULL
   OR v_issue<=now() OR v_convert<v_issue OR v_use<v_convert
 THEN RAISE EXCEPTION 'incomplete or inconsistent commercial conditions';END IF;
 IF v_publish AND (v_partner_status<>'approved' OR NOT v_est_public) THEN
   RAISE EXCEPTION 'partner and establishment must be approved/published';
 END IF;
 INSERT INTO public.offers (
  establishment_id,title,description,discount_type,discount_value,currency,
  is_published,access_scope,eligible_items,calculation_base,minimum_purchase_cents,
  maximum_discount_cents,fixed_use_policy,issue_until,convert_until,use_until,
  advance_booking_required,disclosure_extra,per_user_limit,max_issuances
 ) VALUES (
  v_est,v_title,NULLIF(trim(coalesce(p_data->>'description','')),''),
  v_type,v_value,'BRL',v_publish,v_access,
  trim(p_data->>'eligible_items'),trim(p_data->>'calculation_base'),
  v_min,v_max,'single_use_no_change',v_issue,v_convert,v_use,
  coalesce((p_data->>'advance_booking_required')::boolean,false),
  NULLIF(trim(coalesce(p_data->>'disclosure_extra','')),''),
  coalesce((p_data->>'per_user_limit')::int,1),
  (p_data->>'max_issuances')::int
 ) RETURNING id INTO v_offer;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('offer',v_offer,CASE WHEN v_publish THEN 'created_published' ELSE 'created_draft' END,
 p_admin_user_id,jsonb_build_object('access_scope',v_access,'rules_version',1));
 RETURN jsonb_build_object('offer_id',v_offer,'published',v_publish);
END $$;

CREATE FUNCTION public.mp_admin_create_passport_draft(
 p_admin_user_id uuid,p_data jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;v_rule text;v_duration integer;v_from timestamptz;v_until timestamptz;
 v_activation integer;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>12000
 THEN RAISE EXCEPTION 'invalid passport payload';END IF;
 v_rule:=p_data->>'validity_start_rule';
 v_duration:=(p_data->>'duration_days')::int;
 v_from:=(p_data->>'fixed_starts_at')::timestamptz;
 v_until:=(p_data->>'fixed_ends_at')::timestamptz;
 v_activation:=(p_data->>'activation_deadline_days')::int;
 INSERT INTO public.passport_products(
  name,description,price_cents,validity_start_rule,duration_days,
  fixed_starts_at,fixed_ends_at,activation_deadline_days,
  booking_explanation,included_benefits_explanation,legal_terms,is_published
 )VALUES(
  trim(p_data->>'name'),trim(p_data->>'description'),
  (p_data->>'price_cents')::int,v_rule,
  CASE WHEN v_rule='fixed' THEN NULL ELSE v_duration END,
  CASE WHEN v_rule='fixed' THEN v_from ELSE NULL END,
  CASE WHEN v_rule='fixed' THEN v_until ELSE NULL END,
  CASE WHEN v_rule='activation' THEN v_activation ELSE NULL END,
  coalesce(nullif(trim(p_data->>'booking_explanation'),''),
    'Consulte a disponibilidade e a exigência de agendamento de cada parceiro.'),
  coalesce(p_data->>'included_benefits_explanation',''),
  'O direito de arrependimento nas contratações à distância seguirá o art. 49 do CDC, sem renúncia pelo mero acesso ou emissão de cupom.',
  false
 ) RETURNING id INTO v_id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',v_id,'created_draft',p_admin_user_id,'{}');
 RETURN jsonb_build_object('product_id',v_id,'published',false);
END $$;

CREATE FUNCTION public.mp_admin_attach_passport_benefit(
 p_admin_user_id uuid,p_product_id uuid,p_offer_id uuid,p_issue_days integer,
 p_convert_days integer,p_use_days integer,p_max_per_holder integer,
 p_booking_required boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_id uuid;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF NOT EXISTS(SELECT 1 FROM public.passport_products WHERE id=p_product_id AND NOT is_published)
 OR NOT EXISTS(SELECT 1 FROM public.offers o JOIN public.establishments e ON e.id=o.establishment_id
 JOIN public.partners p ON p.id=e.partner_id
 WHERE o.id=p_offer_id AND o.is_published AND o.access_scope='passport'
 AND e.is_public AND e.is_active AND p.status='approved') THEN
 RAISE EXCEPTION 'draft passport and active exclusive offer required';END IF;
 INSERT INTO public.passport_product_benefits(
  product_id,offer_id,issue_window_days,convert_window_days,use_window_days,
  max_per_holder,booking_required
 ) VALUES(p_product_id,p_offer_id,p_issue_days,p_convert_days,p_use_days,
 p_max_per_holder,p_booking_required)
 RETURNING id INTO v_id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'benefit_attached',p_admin_user_id,
 jsonb_build_object('offer_id',p_offer_id,'benefit_id',v_id));
 RETURN jsonb_build_object('benefit_id',v_id,'product_id',p_product_id);
END $$;
CREATE FUNCTION public.mp_admin_publish_passport(
 p_admin_user_id uuid,p_product_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
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
 UPDATE public.passport_products SET is_published=true,updated_at=now()
 WHERE id=p_product_id AND NOT is_published;
 IF NOT FOUND THEN RAISE EXCEPTION 'passport not in draft state';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('passport_product',p_product_id,'published',p_admin_user_id,
 jsonb_build_object('benefit_count',v_count));
 RETURN jsonb_build_object('product_id',p_product_id,'published',true);
END $$;

CREATE POLICY mp_admin_read_all_passports ON public.passport_products FOR SELECT TO authenticated
USING((SELECT auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid())
 AND s.is_active AND s.staff_role='admin'));
CREATE POLICY mp_admin_read_all_passport_benefits ON public.passport_product_benefits FOR SELECT TO authenticated
USING((SELECT auth.jwt()->>'aal')='aal2' AND EXISTS(
 SELECT 1 FROM public.staff_members s WHERE s.user_id=(SELECT auth.uid())
 AND s.is_active AND s.staff_role='admin'));

REVOKE ALL ON FUNCTION public.mp_admin_create_offer(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_create_passport_draft(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_attach_passport_benefit(uuid,uuid,uuid,integer,integer,integer,integer,boolean) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_publish_passport(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_create_offer(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_create_passport_draft(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_attach_passport_benefit(uuid,uuid,uuid,integer,integer,integer,integer,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_publish_passport(uuid,uuid) TO service_role;
;
