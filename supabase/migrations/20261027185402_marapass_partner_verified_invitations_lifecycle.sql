
-- MaraPass / convites de parceiros: sem acesso automático pela mera indicação de e-mail.
CREATE TABLE public.partner_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid NOT NULL UNIQUE REFERENCES public.partners(id) ON DELETE CASCADE,
  email text NOT NULL,
  status text NOT NULL DEFAULT 'prepared'
    CHECK(status IN ('prepared','sent','failed','accepted','revoked')),
  requested_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  send_requested_at timestamptz,
  sent_at timestamptz,
  expires_at timestamptz,
  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id),
  send_count integer NOT NULL DEFAULT 0 CHECK(send_count BETWEEN 0 AND 10000),
  dispatch_method text CHECK(dispatch_method IS NULL OR dispatch_method IN ('invite','magiclink')),
  CONSTRAINT partner_invitation_accepted_consistency CHECK (
    (status='accepted' AND accepted_at IS NOT NULL AND accepted_by IS NOT NULL)
    OR (status <> 'accepted' AND accepted_at IS NULL AND accepted_by IS NULL)
  )
);
CREATE INDEX partner_invitation_email_state_idx ON public.partner_invitations(lower(email),status);
ALTER TABLE public.partner_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.partner_invitations FROM public,anon,authenticated;
GRANT SELECT ON public.partner_invitations TO authenticated;
CREATE POLICY partner_invitations_admin_read ON public.partner_invitations FOR SELECT
TO authenticated USING (
  (select auth.jwt()->>'aal')='aal2'
  AND EXISTS(SELECT 1 FROM public.staff_members s
    WHERE s.user_id=(select auth.uid()) AND s.is_active AND s.staff_role='admin')
);
CREATE FUNCTION public.admin_prepare_partner_invitation(p_admin_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE p public.partners%rowtype;i public.partner_invitations%rowtype; v_mail text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO p FROM public.partners WHERE id=p_partner_id FOR UPDATE;
 IF NOT FOUND OR p.status <> 'pending' OR p.owner_user_id IS NOT NULL THEN
   RAISE EXCEPTION 'partner not eligible for invitation';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.partner_direct_registrations d WHERE d.partner_id=p.id) THEN
   RAISE EXCEPTION 'only directly registered companies can be invited through this flow';
 END IF;
 v_mail:=lower(trim(coalesce(p.contact_email,'')));
 IF v_mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
  RAISE EXCEPTION 'invalid invite contact email';
 END IF;
 SELECT * INTO i FROM public.partner_invitations WHERE partner_id=p.id FOR UPDATE;
 IF FOUND THEN
   IF i.status='accepted' OR i.status='revoked' THEN
     RAISE EXCEPTION 'invitation already accepted or revoked';
   END IF;
   IF i.send_requested_at IS NOT NULL AND i.send_requested_at > now()-interval '60 seconds' THEN
     RAISE EXCEPTION 'invitation rate limited';
   END IF;
   IF i.email<>v_mail THEN
     RAISE EXCEPTION 'contact email changed after invitation; require manual review';
   END IF;
   UPDATE public.partner_invitations SET status='prepared',updated_at=now(),
     send_requested_at=now(), expires_at=now()+interval '7 days',
     send_count=send_count+1
     WHERE id=i.id RETURNING * INTO i;
 ELSE
   INSERT INTO public.partner_invitations
     (partner_id,email,requested_by,send_requested_at,expires_at,send_count)
   VALUES(p.id,v_mail,p_admin_user_id,now(),now()+interval '7 days',1)
   RETURNING * INTO i;
 END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,'dispatch_prepared',p_admin_user_id,
  jsonb_build_object('partner_id',p.id,'send_count',i.send_count));
 RETURN jsonb_build_object('invitation_id',i.id,'partner_id',p.id,
   'email',i.email,'trade_name',p.trade_name);
END $$;

CREATE FUNCTION public.admin_record_partner_invitation_dispatch(
 p_admin_user_id uuid,p_invitation_id uuid,p_success boolean,p_method text
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE i public.partner_invitations%rowtype;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 SELECT * INTO i FROM public.partner_invitations WHERE id=p_invitation_id FOR UPDATE;
 IF NOT FOUND OR i.status<>'prepared' THEN RAISE EXCEPTION 'invitation not prepared'; END IF;
 IF p_success AND p_method NOT IN ('invite','magiclink') THEN
   RAISE EXCEPTION 'invalid dispatch method';
 END IF;
 UPDATE public.partner_invitations SET status=CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
   sent_at=CASE WHEN p_success THEN now() ELSE sent_at END,
   dispatch_method=CASE WHEN p_success THEN p_method ELSE NULL END,
   updated_at=now()
 WHERE id=i.id;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('partner_invitation',i.id,CASE WHEN p_success THEN 'sent' ELSE 'send_failed' END,
   p_admin_user_id,jsonb_build_object('partner_id',i.partner_id,'method',p_method));
 RETURN jsonb_build_object('status',CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
  'partner_id',i.partner_id);
END $$;

-- Service RPC called only after Auth has verified the caller's signed JWT.
-- Identity EMAIL is read from auth.users, never supplied as form text.
CREATE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text;
BEGIN
 SELECT lower(email) INTO v_mail FROM auth.users WHERE id=p_user_id
 AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL
 AND (banned_until IS NULL OR banned_until<now());
 IF v_mail IS NULL THEN RAISE EXCEPTION 'verified email required';END IF;
 RETURN coalesce((
 SELECT jsonb_agg(jsonb_build_object('partner_id',p.id,'trade_name',p.trade_name,
   'status',i.status,'expires_at',i.expires_at,'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;

CREATE FUNCTION public.partner_accept_invitation(p_user_id uuid,p_partner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_mail text; i public.partner_invitations%rowtype;p public.partners%rowtype;
BEGIN
 SELECT lower(email) INTO v_mail FROM auth.users WHERE id=p_user_id
 AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL
 AND (banned_until IS NULL OR banned_until<now());
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

CREATE FUNCTION public.admin_activate_invited_partner(p_admin_user_id uuid,p_partner_id uuid)
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
 SELECT EXISTS(SELECT 1 FROM auth.users u
   WHERE u.id=p.owner_user_id AND lower(u.email)=lower(i.email)
     AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
     AND (u.banned_until IS NULL OR u.banned_until<now())) INTO v_verified;
 IF NOT v_verified THEN RAISE EXCEPTION 'partner owner email unverified';END IF;
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

REVOKE ALL ON FUNCTION public.admin_prepare_partner_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_record_partner_invitation_dispatch(uuid,uuid,boolean,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.partner_accept_invitation(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_prepare_partner_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_record_partner_invitation_dispatch(uuid,uuid,boolean,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.partner_accept_invitation(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_invited_partner(uuid,uuid) TO service_role;
;
