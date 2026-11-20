
CREATE FUNCTION private.verified_auth_email(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT lower(u.email) FROM auth.users u WHERE u.id=p_user_id
 AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
 AND (u.banned_until IS NULL OR u.banned_until < now()) LIMIT 1
$$;
REVOKE ALL ON FUNCTION private.verified_auth_email(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.verified_auth_email(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text;
BEGIN
 v_mail:=private.verified_auth_email(p_user_id);
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 RETURN coalesce((
 SELECT jsonb_agg(jsonb_build_object('partner_id',p.id,'trade_name',p.trade_name,
   'status',i.status,'partner_status',p.status,'expires_at',i.expires_at,
   'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.partner_accept_invitation(p_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text; i public.partner_invitations%rowtype;p public.partners%rowtype;
BEGIN
 v_mail:=private.verified_auth_email(p_user_id);
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'partner not found';END IF;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR lower(i.email)<>v_mail THEN
   RAISE EXCEPTION 'no matching invitation for verified email';
 END IF;
 IF i.status='accepted' AND i.accepted_by=p_user_id AND p.owner_user_id=p_user_id THEN
   RETURN jsonb_build_object('partner_id',p.id,'status','accepted','already_accepted',true);
 END IF;
 IF i.status<>'sent' OR i.expires_at<=now() OR p.owner_user_id IS NOT NULL OR p.status<>'pending' THEN
   RAISE EXCEPTION 'invitation unavailable or expired';
 END IF;
 UPDATE public.partners SET owner_user_id=p_user_id,updated_at=now() WHERE id=p.id;
 UPDATE public.partner_invitations SET status='accepted',accepted_at=now(),
 accepted_by=p_user_id,updated_at=now() WHERE id=i.id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,'accepted_by_verified_user',p_user_id,
 jsonb_build_object('partner_id',p.id,'owner_linked',true));
 RETURN jsonb_build_object('partner_id',p.id,'status','accepted',
   'partner_status','pending','already_accepted',false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_activate_invited_partner(p_admin_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE p public.partners%rowtype;i public.partner_invitations%rowtype;v_verified boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR p.id IS NULL OR i.status<>'accepted' OR p.owner_user_id IS NULL
   OR i.accepted_by IS DISTINCT FROM p.owner_user_id THEN
  RAISE EXCEPTION 'partner owner has not accepted verified invitation';
 END IF;
 SELECT (private.verified_auth_email(p.owner_user_id) = lower(i.email)) INTO v_verified;
 IF NOT coalesce(v_verified,false) THEN RAISE EXCEPTION 'partner owner email unverified';END IF;
 IF p.status NOT IN ('pending','approved') THEN
   RAISE EXCEPTION 'partner cannot be activated';
 END IF;
 IF p.status='pending' THEN
   UPDATE public.partners SET status='approved',updated_at=now() WHERE id=p.id;
   INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
   VALUES('partner',p.id,'activated_after_invitation',p_admin_user_id,
      jsonb_build_object('owner_user_id',p.owner_user_id,'invitation_id',i.id));
 END IF;
 RETURN jsonb_build_object('partner_id',p.id,'status','approved','owner_verified',true);
END $$;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_accept_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_accept_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) TO service_role;
;
