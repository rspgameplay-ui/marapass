-- Mídia dinâmica
alter table public.mvp_partner_offers add column if not exists image_url text check (image_url is null or image_url ~ '^https://');
alter table public.mvp_partner_offers add column if not exists banner_url text check (banner_url is null or banner_url ~ '^https://');
alter table public.mvp_places add column if not exists image_url text check (image_url is null or image_url ~ '^https://');
alter table public.mvp_places add column if not exists banner_url text check (banner_url is null or banner_url ~ '^https://');

-- Bucket público de imagens (leitura por URL pública; 5 MB; só imagens)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marapass-assets', 'marapass-assets', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Parceiro aprovado envia e gerencia só a própria pasta: <user_id>/arquivo
drop policy if exists "marapass_assets_partner_insert" on storage.objects;
create policy "marapass_assets_partner_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.mvp_is_partner()));
drop policy if exists "marapass_assets_partner_update" on storage.objects;
create policy "marapass_assets_partner_update" on storage.objects for update to authenticated
  using (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "marapass_assets_partner_delete" on storage.objects;
create policy "marapass_assets_partner_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'marapass-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Índices das consultas do app e do painel
create index if not exists mvp_checkins_user_created_idx on public.mvp_checkins (user_id, created_at desc);
create index if not exists mvp_checkins_day_idx on public.mvp_checkins (day);
create index if not exists mvp_checkins_item_idx on public.mvp_checkins (item_key);
create index if not exists mvp_coupons_user_idx on public.mvp_coupons (user_id, issued_at desc);
create index if not exists mvp_coupons_key_idx on public.mvp_coupons (cupom_key);
create index if not exists mvp_reservations_user_idx on public.mvp_reservations (user_id, day);
create index if not exists mvp_reservations_status_day_idx on public.mvp_reservations (status, day);
create index if not exists mvp_offers_status_until_idx on public.mvp_partner_offers (status, valid_until);
create index if not exists mvp_offers_creator_idx on public.mvp_partner_offers (created_by);
create index if not exists mvp_tickets_user_idx on public.mvp_tickets (user_id, created_at desc);
create index if not exists mvp_partner_requests_status_idx on public.mvp_partner_requests (status);;
