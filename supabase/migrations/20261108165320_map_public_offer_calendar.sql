create or replace function private.map_offer_calendar(p_day date,p_city text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare day_start timestamptz; day_end timestamptz; result jsonb;
begin
 if p_day is null or p_day<(now() at time zone 'America/Fortaleza')::date or p_day>(now() at time zone 'America/Fortaleza')::date+366 then raise exception 'Escolha uma data entre hoje e os próximos 366 dias.';end if;
 if p_city is null or length(trim(p_city)) not between 2 and 100 then raise exception 'Informe o município.';end if;
 day_start:=p_day::timestamp at time zone 'America/Fortaleza'; day_end:=(p_day+1)::timestamp at time zone 'America/Fortaleza';
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into result from (
 select o.id as offer_id,o.title,o.starts_at,o.ends_at,e.id as establishment_id,e.name,e.city,e.category,e.latitude as lat,e.longitude as lng,e.street_address as address
 from public.offers o join public.establishments e on e.id=o.establishment_id
 where o.is_published and e.is_active and e.is_public and e.state_code='MA' and lower(e.city)=lower(trim(p_city))
 and (o.starts_at is null or o.starts_at<day_end) and (o.ends_at is null or o.ends_at>day_start)
 and (o.max_issuances is null or o.max_issuances>(select count(*) from public.coupon_instances c where c.offer_id=o.id))
 and e.latitude is not null and e.longitude is not null
 order by e.name,o.id limit 101
 ) q;
 return jsonb_build_object('day',p_day,'timezone','America/Fortaleza','offers',result,'checked_at',now(),'notice','Vigência publicada. Dias, horários, regras e estoque precisam ser confirmados na emissão.');
end $fn$;
revoke all on function private.map_offer_calendar(date,text) from public,anon,authenticated;
grant execute on function private.map_offer_calendar(date,text) to anon,authenticated;
grant usage on schema private to anon;
create or replace function public.map_offer_calendar(p_day date,p_city text)
returns jsonb language sql security invoker set search_path='' as $fn$select private.map_offer_calendar(p_day,p_city)$fn$;
revoke all on function public.map_offer_calendar(date,text) from public;
grant execute on function public.map_offer_calendar(date,text) to anon,authenticated;
notify pgrst,'reload schema';;
