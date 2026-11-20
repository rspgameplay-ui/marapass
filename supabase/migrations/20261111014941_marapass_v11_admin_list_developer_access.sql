
CREATE OR REPLACE FUNCTION public.mp_admin_list_developers(p_admin_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $$
BEGIN
 PERFORM private.assert_admin(p_admin_user_id);
 RETURN COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
   'user_id',s.user_id,'email',u.email,
   'is_active',s.is_active,'created_at',s.created_at,
   'confirmed',u.email_confirmed_at IS NOT NULL
  ) ORDER BY s.created_at DESC)
  FROM public.staff_members s JOIN auth.users u ON u.id=s.user_id
  WHERE s.staff_role='developer'
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.mp_admin_list_developers(uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mp_admin_list_developers(uuid) TO service_role;
;
