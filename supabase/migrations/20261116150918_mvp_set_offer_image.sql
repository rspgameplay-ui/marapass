create or replace function public.mvp_set_offer_image(p_id uuid, p_url text)
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); o public.mvp_partner_offers;
begin
  if p_url is not null and p_url not like 'https://nwwxobiqynawxxnbvubz.supabase.co/storage/v1/object/public/marapass-assets/' || uid::text || '/%' then
    raise exception 'A foto precisa ser enviada pelo app.' using errcode = 'P0001';
  end if;
  update public.mvp_partner_offers set image_url = p_url, updated_at = now()
    where id = p_id and created_by = uid returning * into o;
  if o.id is null then
    raise exception 'Oferta não encontrada nesta conta.' using errcode = 'P0001';
  end if;
  return o;
end $$;
revoke all on function public.mvp_set_offer_image(uuid, text) from public, anon;
grant execute on function public.mvp_set_offer_image(uuid, text) to authenticated;;
