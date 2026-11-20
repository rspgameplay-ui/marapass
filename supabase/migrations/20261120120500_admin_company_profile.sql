-- Perfil do cadastro administrativo. Imagens pequenas, privadas e transacionais.
create table private.company_profile_photos (
  partner_id uuid primary key references public.partners(id) on delete cascade,
  jpeg bytea not null check (octet_length(jpeg) between 4 and 131072)
);
revoke all on private.company_profile_photos from public, anon, authenticated;

create function private.require_direct_company_phone() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.partners p where p.id = new.partner_id
    and regexp_replace(coalesce(p.contact_phone,''),'[ ()-]','','g') ~ '^\+?[1-9][0-9]{9,14}$') then
    raise exception 'Informe um WhatsApp válido com DDD.';
  end if;
  return new;
end $$;
create trigger require_direct_company_phone before insert on public.partner_direct_registrations
for each row execute function private.require_direct_company_phone();

create function public.admin_register_company_profile(
  p_request_key uuid, p_legal_name text, p_trade_name text, p_contact_email text,
  p_city text, p_category text, p_whatsapp text, p_tax_id text,
  p_latitude numeric, p_longitude numeric, p_photo text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  registration jsonb;
  photo bytea;
begin
  perform private.assert_admin(auth.uid());
  if (auth.jwt()->>'aal') is distinct from 'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  if p_whatsapp is null or p_whatsapp !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'WhatsApp inválido.'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90
    or p_longitude not between -180 and 180 then raise exception 'Coordenadas inválidas.'; end if;
  if p_photo is null or length(p_photo) not between 8 and 174764 then raise exception 'Foto inválida.'; end if;
  photo := decode(p_photo,'base64');
  if octet_length(photo) > 131072 or substring(photo from 1 for 3) <> decode('ffd8ff','hex')
    or right(encode(substring(photo from greatest(1,octet_length(photo)-1)),'hex'),4) <> 'ffd9'
    then raise exception 'A foto deve ser JPEG.'; end if;
  registration := public.admin_register_direct_company_once(auth.uid(),p_legal_name,p_trade_name,
    p_contact_email,p_city,p_category,p_whatsapp,p_tax_id,p_request_key);
  if not (registration->>'already_registered')::boolean then
    update public.establishments set latitude=p_latitude, longitude=p_longitude
      where id=(registration->>'establishment_id')::uuid;
    insert into private.company_profile_photos values ((registration->>'partner_id')::uuid,photo);
  end if;
  return registration;
end $$;

create function public.admin_company_photo(p_partner_id uuid) returns text
language plpgsql security definer stable set search_path = '' as $$
begin
  perform private.assert_admin(auth.uid());
  if (auth.jwt()->>'aal') is distinct from 'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  return (select encode(jpeg,'base64') from private.company_profile_photos where partner_id=p_partner_id);
end $$;
revoke all on function public.admin_register_company_profile(uuid,text,text,text,text,text,text,text,numeric,numeric,text),public.admin_company_photo(uuid) from public,anon,authenticated;
grant execute on function public.admin_register_company_profile(uuid,text,text,text,text,text,text,text,numeric,numeric,text),public.admin_company_photo(uuid) to authenticated;
