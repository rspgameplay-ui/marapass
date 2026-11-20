drop function if exists public.my_request_reservation(uuid, integer, text);
drop function if exists public.my_issue_coupon(uuid, text, uuid);
create index if not exists mvp_item_owners_user_id_idx on public.mvp_item_owners (user_id);
alter table private.coupon_media_uploads add column if not exists id bigint generated always as identity;
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'private.coupon_media_uploads'::regclass and contype = 'p') then
    alter table private.coupon_media_uploads add constraint coupon_media_uploads_pkey primary key (id);
  end if;
end $$;;
