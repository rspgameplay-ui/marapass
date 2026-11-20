
CREATE OR REPLACE FUNCTION public.partner_list_my_invitations(p_user_id uuid)
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
   'status',i.status,'partner_status',p.status,'expires_at',i.expires_at,
   'accepted_at',i.accepted_at) ORDER BY i.created_at DESC)
 FROM public.partner_invitations i JOIN public.partners p ON p.id=i.partner_id
 WHERE lower(i.email)=v_mail AND i.status IN ('sent','accepted')
 ),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.partner_list_my_invitations(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.partner_list_my_invitations(uuid) TO service_role;
;
