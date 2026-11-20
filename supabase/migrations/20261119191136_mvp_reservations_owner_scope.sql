-- Cada item do catálogo pertence a um parceiro; só ele vê e decide as reservas desse item.
create table if not exists public.mvp_item_owners (
  item_key text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.mvp_item_owners enable row level security;
revoke all on public.mvp_item_owners from anon, authenticated;
grant select on public.mvp_item_owners to authenticated;
create policy mvp_item_owners_read_own on public.mvp_item_owners for select to authenticated
  using (user_id = (select auth.uid()));

-- Dono da reserva: o parceiro do item ou o parceiro da oferta do cupom usado.
create or replace function public.mvp_owns_reservation(p_item_key text, p_cupom_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select (select auth.uid()) is not null and public.mvp_is_partner() and (
    exists (select 1 from public.mvp_item_owners o where o.item_key = p_item_key and o.user_id = (select auth.uid()))
    or (p_cupom_key ~ '^po:[0-9a-fA-F-]{36}$' and exists (
          select 1 from public.mvp_partner_offers po
          where po.id = substr(p_cupom_key, 4)::uuid and po.created_by = (select auth.uid())))
  );
$$;
revoke execute on function public.mvp_owns_reservation(text, text) from public, anon;
grant execute on function public.mvp_owns_reservation(text, text) to authenticated;

drop policy if exists mvp_reservations_read on public.mvp_reservations;
create policy mvp_reservations_read on public.mvp_reservations for select
  using (user_id = (select auth.uid()) or public.mvp_owns_reservation(item_key, cupom_key));

create or replace function public.mvp_decide_reservation(p_id uuid, p_accept boolean)
returns public.mvp_reservations language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_reservations;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  select * into r from public.mvp_reservations where id = p_id;
  if not found or not public.mvp_owns_reservation(r.item_key, r.cupom_key) then
    raise exception 'Reserva de outro parceiro.' using errcode = '42501';
  end if;
  update public.mvp_reservations set status = case when p_accept then 'confirmada' else 'recusada' end, updated_at = now(),
    history = history || jsonb_build_array(case when p_accept then 'Confirmada pelo parceiro' else 'Recusada pelo parceiro' end)
  where id = p_id and status = 'solicitada' returning * into r;
  if not found then raise exception 'not pending' using errcode = '22023'; end if;
  return r;
end $$;

-- Demo: itens dos 3 polos para os parceiros de teste.
insert into public.mvp_item_owners(item_key, user_id)
select k, u.id from (values
  ('parceiro-lencois@demo.marapass.test', array['lagoas','rio','por','4x4','kite','marcelino','mangue','buriti','juja','vila','atins-hotel','ev-sabores','ev-regata','buriti-bolsa','foto-dunas','transfer-slz','transfer-atins']),
  ('parceiro-saoluis@demo.marapass.test', array['centro','boi','quilombo','cozinha','conchas','slz-hotel','ev-boi','foto-centro','barco','ceramica']),
  ('parceiro-chapada@demo.marapass.test', array['cach','mirante','biojoia'])
) t(email, keys) join auth.users u on u.email = t.email, unnest(t.keys) k
on conflict (item_key) do nothing;;
