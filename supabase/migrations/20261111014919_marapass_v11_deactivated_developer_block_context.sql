CREATE OR REPLACE FUNCTION public.my_access_context()
 RETURNS TABLE(user_id uuid, staff_role text, admin_role boolean, partner_owner boolean, partner_manager boolean, partner_validator boolean, mfa_verified boolean, admin_console_ready boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select
  (select auth.uid()) as user_id,
  CASE WHEN s.is_active THEN s.staff_role ELSE NULL END AS staff_role,
  (s.staff_role='admin' and s.is_active) as admin_role,
  exists(select 1 from public.partners p
    where p.owner_user_id=(select auth.uid()) and p.status='approved') as partner_owner,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='manager') as partner_manager,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='validator') as partner_validator,
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as mfa_verified,
  coalesce(s.staff_role='admin' and s.is_active,false)
    and coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as admin_console_ready
from (select 1) base
left join public.staff_members s
  on s.user_id=(select auth.uid())
where (select auth.uid()) is not null;
$function$;;
