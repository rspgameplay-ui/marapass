
-- MARAPASS / ETAPA 2E
-- Read-only guest experience, with internal partner records inaccessible to anon.
drop policy if exists establishments_public on public.establishments;
drop policy if exists establishments_partner on public.establishments;
create policy establishments_anon on public.establishments
for select to anon using (is_active and is_public);
create policy establishments_authenticated on public.establishments
for select to authenticated using (
  (is_active and is_public)
  or exists(
    select 1 from public.partners p where p.id=partner_id
    and (p.owner_user_id=(select auth.uid())
      or exists(select 1 from public.partner_members m
        where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists experiences_public on public.experiences;
drop policy if exists experiences_partner on public.experiences;
create policy experiences_anon on public.experiences
for select to anon using (
  status='published' and exists (
    select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy experiences_authenticated on public.experiences
for select to authenticated using (
  (status='published' and exists (
    select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public))
  or exists (
    select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists offers_public on public.offers;
drop policy if exists offers_partner on public.offers;
create policy offers_anon on public.offers
for select to anon using (
  is_published and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public)
);
create policy offers_authenticated on public.offers
for select to authenticated using (
  (is_published and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    where e.id=establishment_id and e.is_active and e.is_public))
  or exists(
    select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

drop policy if exists slots_public on public.experience_slots;
drop policy if exists slots_partner on public.experience_slots;
create policy slots_anon on public.experience_slots
for select to anon using (
  is_open and starts_at>now() and exists(
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    where x.id=experience_id and x.status='published'
      and e.is_active and e.is_public)
);
create policy slots_authenticated on public.experience_slots
for select to authenticated using (
  (is_open and starts_at>now() and exists(
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    where x.id=experience_id and x.status='published'
      and e.is_active and e.is_public))
  or exists (
    select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    join public.partners p on p.id=e.partner_id
    where x.id=experience_id
      and (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid()) and m.is_active))
  )
);

create function private.hide_catalog_for_suspended_partner() returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if old.status is distinct from new.status and new.status <> 'approved' then
    update public.establishments set is_public=false
      where partner_id=new.id and is_public;
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values('partner',new.id,'catalog_unpublished_by_status',null,
      jsonb_build_object('status',new.status));
  end if;
  return new;
end $$;
create trigger hide_partner_catalog_on_suspension
after update of status on public.partners
for each row execute function private.hide_catalog_for_suspended_partner();
grant execute on function private.hide_catalog_for_suspended_partner() to service_role;
revoke execute on function private.hide_catalog_for_suspended_partner() from public,anon,authenticated;
;
