
-- Role specialized for contracted developer review. No administrative writes.
ALTER TABLE public.staff_members DROP CONSTRAINT staff_members_staff_role_check;
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_staff_role_check
  CHECK (staff_role IN ('admin','operator','developer'));

CREATE OR REPLACE FUNCTION public.mp_admin_authorize_developer(
 p_admin_user_id uuid,p_developer_user_id uuid,p_email text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_email text;v_state boolean;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_developer_user_id IS NULL OR p_admin_user_id=p_developer_user_id THEN
  RAISE EXCEPTION 'invalid developer account';END IF;
 SELECT lower(email), email_confirmed_at IS NOT NULL
 INTO v_email,v_state FROM auth.users WHERE id=p_developer_user_id;
 IF v_email IS NULL OR v_email<>lower(trim(p_email)) THEN
  RAISE EXCEPTION 'developer invite identity mismatch';END IF;
 IF EXISTS(SELECT 1 FROM public.staff_members WHERE user_id=p_developer_user_id)
 THEN RAISE EXCEPTION 'account already has an application role'; END IF;
 INSERT INTO public.staff_members(user_id,staff_role,is_active)
 VALUES(p_developer_user_id,'developer',true);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_invited',p_admin_user_id,
 jsonb_build_object('role','developer','read_only',true,'email_verified_at_invite',v_state));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'staff_role','developer',
 'read_only',true,'active',true);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
TO service_role;

CREATE OR REPLACE FUNCTION public.mp_admin_revoke_developer(
 p_admin_user_id uuid,p_developer_user_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 UPDATE public.staff_members SET is_active=false
 WHERE user_id=p_developer_user_id AND staff_role='developer' AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'developer access not active';END IF;
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_revoked',p_admin_user_id,
 jsonb_build_object('staff_role','developer'));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'active',false);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_revoke_developer(uuid,uuid)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_revoke_developer(uuid,uuid)
TO service_role;
;
