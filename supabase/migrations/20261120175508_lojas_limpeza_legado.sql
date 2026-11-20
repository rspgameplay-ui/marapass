-- Preparação para as lojas: remove a camada canônica que nenhuma tela usa
-- e corrige avisos do advisor do Supabase.

-- 1. RPCs legadas (as telas usam mvp_request_reservation e os cupons mvp_*).
drop function if exists public.my_request_reservation(uuid, integer, text);
drop function if exists public.my_issue_coupon(uuid, text, uuid);

-- 2. Índice da chave estrangeira sem cobertura.
create index if not exists mvp_item_owners_user_id_idx
  on public.mvp_item_owners (user_id);

-- 3. Chave primária no registro de limite de envio de mídia.
alter table private.coupon_media_uploads
  add column if not exists id bigint generated always as identity;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'private.coupon_media_uploads'::regclass and contype = 'p'
  ) then
    alter table private.coupon_media_uploads
      add constraint coupon_media_uploads_pkey primary key (id);
  end if;
end $$;
