-- 1) Exclusão da própria conta (Apple/Google/LGPD)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if exists (select 1 from public.staff_members s where s.user_id = uid and s.is_active)
     or exists (select 1 from public.partner_members m where m.user_id = uid and m.is_active)
     or exists (select 1 from public.partners p where p.owner_user_id = uid)
     or exists (select 1 from public.mvp_partner_members m where m.user_id = uid) then
    raise exception 'Contas de parceiro são excluídas pelo suporte, para não apagar ofertas ativas.' using errcode = 'P0001';
  end if;
  delete from public.assistant_messages
    where conversation_id in (select id from public.assistant_conversations where user_id = uid);
  delete from public.assistant_conversations where user_id = uid;
  delete from public.mvp_partner_requests where user_id = uid;
  -- Cupons já usados ficam no histórico do parceiro, sem identificar a pessoa.
  update public.mvp_coupons set used_by = null where used_by = uid;
  delete from public.profiles where id = uid;
  begin
    delete from auth.users where id = uid;
  exception when foreign_key_violation then
    raise exception 'Sua conta tem registros do sistema anterior. Peça a exclusão pelo suporte.' using errcode = 'P0001';
  end;
end $$;

-- 2) Parceiro real: pedido + aprovação pela equipe MaraPass
create table if not exists public.mvp_partner_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  business text not null check (length(trim(business)) between 2 and 120),
  cadastur text,
  city text not null,
  phone text not null,
  status text not null default 'pendente' check (status in ('pendente','aprovado','recusado')),
  note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
alter table public.mvp_partner_requests enable row level security;
revoke all on public.mvp_partner_requests from anon, authenticated;
grant select on public.mvp_partner_requests to authenticated;
drop policy if exists "dono le o proprio pedido" on public.mvp_partner_requests;
create policy "dono le o proprio pedido" on public.mvp_partner_requests
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.mvp_request_partner(p_business text, p_cadastur text, p_city text, p_phone text)
returns public.mvp_partner_requests language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_requests;
begin
  insert into public.mvp_partner_requests (user_id, business, cadastur, city, phone)
  values (uid, trim(p_business), nullif(trim(p_cadastur), ''), trim(p_city), trim(p_phone))
  on conflict (user_id) do update set business = excluded.business, cadastur = excluded.cadastur,
    city = excluded.city, phone = excluded.phone,
    status = case when public.mvp_partner_requests.status = 'aprovado' then 'aprovado' else 'pendente' end,
    created_at = now()
  returning * into r;
  return r;
end $$;

-- Só a equipe (service role / SQL) aprova.
create or replace function public.mvp_decide_partner(p_user uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.mvp_partner_requests set status = case when p_approve then 'aprovado' else 'recusado' end,
    note = p_note, decided_at = now() where user_id = p_user;
  if p_approve then
    insert into public.mvp_partner_members (user_id) values (p_user) on conflict do nothing;
  else
    delete from public.mvp_partner_members where user_id = p_user;
  end if;
end $$;

-- Fim do atalho de demonstração (qualquer logado virava parceiro).
create or replace function public.mvp_join_demo_partner()
returns void language plpgsql security definer set search_path = public as $$
begin
  raise exception 'A área do parceiro agora exige cadastro aprovado pela equipe MaraPass.' using errcode = 'P0001';
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke all on function public.mvp_request_partner(text, text, text, text) from public, anon;
grant execute on function public.mvp_request_partner(text, text, text, text) to authenticated;
revoke all on function public.mvp_decide_partner(uuid, boolean, text) from public, anon, authenticated;;
