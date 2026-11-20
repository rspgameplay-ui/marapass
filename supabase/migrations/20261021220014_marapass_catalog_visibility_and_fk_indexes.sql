
-- MARAPASS / ETAPA 2D -- índices para FKs e publicação condicionada.
create index if not exists checkins_establishment_fk_idx on public.checkins(establishment_id);
create index if not exists checkins_reservation_fk_idx on public.checkins(reservation_id);
create index if not exists coupon_instances_reservation_fk_idx on public.coupon_instances(reservation_id);
create index if not exists redemptions_partner_establishment_fk_idx
  on public.coupon_redemptions(partner_id,establishment_id);
create index if not exists redemptions_validator_fk_idx
  on public.coupon_redemptions(validated_by_user_id);
create index if not exists offers_establishment_experience_fk_idx
  on public.offers(establishment_id,experience_id);
create index if not exists partner_applications_reviewer_fk_idx
  on public.partner_applications(reviewed_by_user_id);
create index if not exists partners_owner_fk_idx on public.partners(owner_user_id);

drop policy if exists establishments_public on public.establishments;
create policy establishments_public on public.establishments for select
to anon,authenticated using (
  is_public and is_active
  and exists(select 1 from public.partners p
    where p.id=partner_id and p.status='approved')
);

drop policy if exists experiences_public on public.experiences;
create policy experiences_public on public.experiences for select
to anon,authenticated using (
  status='published'
  and exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and e.is_active and e.is_public
      and p.status='approved')
);

drop policy if exists offers_public on public.offers;
create policy offers_public on public.offers for select
to anon,authenticated using (
  is_published
  and (starts_at is null or starts_at<=now())
  and (ends_at is null or ends_at>now())
  and exists(select 1 from public.establishments e
    join public.partners p on p.id=e.partner_id
    where e.id=establishment_id and e.is_active and e.is_public
      and p.status='approved')
);
;
