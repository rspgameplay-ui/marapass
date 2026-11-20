-- Gestão do app MaraPass (MVP) pela Central Administrativa:
-- só administrador ativo com segundo fator (aal2).
create or replace function public.mvp_admin_command(p_action text, p_args jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid(); res jsonb;
begin
  perform private.assert_admin(uid);
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'Confirme o segundo fator (MFA) para gerenciar o app.' using errcode = 'P0001';
  end if;

  if p_action = 'overview' then
    return jsonb_build_object(
      'pedidos_parceiro', (select count(*) from mvp_partner_requests where status = 'pendente'),
      'parceiros', (select count(*) from mvp_partner_members),
      'ofertas_analise', (select count(*) from mvp_partner_offers where status = 'Em análise'),
      'ofertas_ativas', (select count(*) from mvp_partner_offers where status = 'Ativa'),
      'checkins_hoje', (select count(*) from mvp_checkins where day = (now() at time zone 'America/Fortaleza')::date),
      'checkins_total', (select count(*) from mvp_checkins),
      'cupons_ativados', (select count(*) from mvp_coupons),
      'cupons_usados', (select count(*) from mvp_coupons where used_at is not null),
      'reservas_pendentes', (select count(*) from mvp_reservations where status in ('pendente','Pendente','Aguardando')),
      'atendimentos_abertos', (select count(*) from mvp_tickets where status not in ('Resolvido','Fechado')),
      'usuarios', (select count(*) from auth.users where coalesce(is_anonymous,false) = false));
  elsif p_action = 'partner_requests' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('user_id', r.user_id, 'email', u.email, 'business', r.business, 'cadastur', r.cadastur,
        'city', r.city, 'phone', r.phone, 'status', r.status, 'note', r.note, 'created_at', r.created_at) x
      from mvp_partner_requests r join auth.users u on u.id = r.user_id) s;
    return res;
  elsif p_action = 'decide_partner' then
    perform public.mvp_decide_partner((p_args->>'user_id')::uuid, (p_args->>'approve')::boolean, nullif(p_args->>'note', ''));
    return jsonb_build_object('ok', true);
  elsif p_action = 'offers' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('id', o.id, 'title', o.title, 'benefit', o.benefit, 'rules', o.rules, 'category', o.category,
        'limit', o.issue_limit, 'valid_until', o.valid_until, 'status', o.status, 'email', u.email, 'created_at', o.created_at,
        'issued', (select count(*) from mvp_coupons c where c.cupom_key = 'po:' || o.id),
        'used', (select count(*) from mvp_coupons c where c.cupom_key = 'po:' || o.id and c.used_at is not null)) x
      from mvp_partner_offers o left join auth.users u on u.id = o.created_by) s;
    return res;
  elsif p_action = 'set_offer' then
    if p_args->>'status' not in ('Ativa', 'Recusada', 'Pausada', 'Em análise') then
      raise exception 'Status de oferta inválido.' using errcode = 'P0001';
    end if;
    update mvp_partner_offers set status = p_args->>'status', pause_reason = nullif(p_args->>'reason', ''), updated_at = now()
      where id = (p_args->>'id')::uuid;
    return jsonb_build_object('ok', true);
  elsif p_action = 'places' then
    select coalesce(jsonb_agg(jsonb_build_object('item_key', p.item_key, 'code', p.code, 'token', p.token,
      'lat', p.lat, 'lng', p.lng, 'radius_m', p.radius_m,
      'checkins', (select count(*) from mvp_checkins c where c.item_key = p.item_key)) order by p.code), '[]') into res
      from mvp_places p;
    return res;
  elsif p_action = 'set_radius' then
    update mvp_places set radius_m = (p_args->>'radius_m')::int where item_key = p_args->>'item_key';
    return jsonb_build_object('ok', true);
  elsif p_action = 'checkins' then
    select coalesce(jsonb_agg(x order by x->>'created_at' desc), '[]') into res from (
      select jsonb_build_object('item_key', c.item_key, 'cidade', c.cidade, 'method', c.method, 'distance_m', c.distance_m,
        'rating', c.rating, 'created_at', c.created_at) x
      from mvp_checkins c order by c.created_at desc limit 100) s;
    return res;
  end if;
  raise exception 'Ação desconhecida.' using errcode = 'P0001';
end $$;
revoke all on function public.mvp_admin_command(text, jsonb) from public, anon;
grant execute on function public.mvp_admin_command(text, jsonb) to authenticated;;
