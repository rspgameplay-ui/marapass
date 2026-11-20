
-- MaraPass: painel administrativo de consulta com RLS exigindo MFA aal2.
-- Na fase inicial, nenhuma operação de escrita é exposta ao navegador.
create policy admin_read_applications_aal2 on public.partner_applications for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_partners_aal2 on public.partners for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_establishments_aal2 on public.establishments for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_experiences_aal2 on public.experiences for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_offers_aal2 on public.offers for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_reservations_aal2 on public.reservations for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);
create policy admin_read_coupon_instances_aal2 on public.coupon_instances for select to authenticated
using (
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
  and exists(select 1 from public.staff_members s
    where s.user_id=(select auth.uid()) and s.staff_role='admin' and s.is_active)
);

create function public.marapass_admin_overview()
returns jsonb
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or coalesce((select auth.jwt()->>'aal'),'aal1')<>'aal2'
    or not exists (select 1 from public.staff_members s
      where s.user_id=(select auth.uid()) and s.is_active and s.staff_role='admin') then
     raise exception 'admin mfa verification required' using errcode='42501';
  end if;
  return jsonb_build_object(
     'applications_pending',(select count(*) from public.partner_applications where status='pending'),
     'partners_approved',(select count(*) from public.partners where status='approved'),
     'establishments_public',(select count(*) from public.establishments where is_public and is_active),
     'experiences_published',(select count(*) from public.experiences where status='published'),
     'offers_published',(select count(*) from public.offers where is_published),
     'reservations_requested',(select count(*) from public.reservations where status='requested'),
     'reservations_confirmed',(select count(*) from public.reservations where status='confirmed'),
     'coupons_issued',(select count(*) from public.coupon_instances where status='issued')
  );
end $$;

revoke all on function public.marapass_admin_overview() from public,anon,authenticated;
grant execute on function public.marapass_admin_overview() to authenticated;
comment on function public.marapass_admin_overview() is
  'Leitura restrita a staff.admin ativo com JWT aal2; sem direitos de escrita.';
;
