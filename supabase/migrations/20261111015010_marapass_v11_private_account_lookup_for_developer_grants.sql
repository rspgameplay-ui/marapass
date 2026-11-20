
CREATE FUNCTION private.mp_account_email(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$ SELECT lower(email) FROM auth.users WHERE id=p_user_id AND deleted_at IS NULL LIMIT 1 $$;
REVOKE ALL ON FUNCTION private.mp_account_email(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.mp_account_email(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.mp_admin_authorize_developer(
 p_admin_user_id uuid,p_developer_user_id uuid,p_email text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_email text;
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 IF p_developer_user_id IS NULL OR p_admin_user_id=p_developer_user_id THEN
  RAISE EXCEPTION 'invalid developer account';END IF;
 v_email:=private.mp_account_email(p_developer_user_id);
 IF v_email IS NULL OR v_email<>lower(trim(p_email)) THEN
  RAISE EXCEPTION 'developer invite identity mismatch';END IF;
 IF EXISTS(SELECT 1 FROM public.staff_members WHERE user_id=p_developer_user_id)
 THEN RAISE EXCEPTION 'account already has an application role'; END IF;
 INSERT INTO public.staff_members(user_id,staff_role,is_active)
 VALUES(p_developer_user_id,'developer',true);
 INSERT INTO private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
 VALUES('developer_access',p_developer_user_id,'developer_invited',p_admin_user_id,
 jsonb_build_object('role','developer','read_only',true));
 RETURN jsonb_build_object('user_id',p_developer_user_id,'staff_role','developer',
 'read_only',true,'active',true);
END $$;

CREATE OR REPLACE FUNCTION public.mp_admin_list_developers(p_admin_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 RETURN COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
   'user_id',s.user_id,'email',private.mp_account_email(s.user_id),
   'is_active',s.is_active,'created_at',s.created_at
  ) ORDER BY s.created_at DESC)
  FROM public.staff_members s
  WHERE s.staff_role='developer'
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mp_admin_list_developers(uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_authorize_developer(uuid,uuid,text)
 TO service_role;
GRANT EXECUTE ON FUNCTION public.mp_admin_list_developers(uuid) TO service_role;
;
