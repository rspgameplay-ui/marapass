-- Ofertas criadas na área do parceiro (demonstração) e atendimento com protocolo.
create table public.mvp_partner_offers (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(title) between 4 and 80),
  benefit text not null check (length(benefit) between 2 and 60),
  rules text not null default '' check (length(rules) <= 400),
  category text not null default 'passeio' check (category in ('passeio','gastronomia','hospedagem','cultura','natureza','evento','artesanato','fotografia','transporte')),
  issue_limit integer not null check (issue_limit between 1 and 10000),
  valid_until date not null,
  status text not null default 'Em análise' check (status in ('Em análise','Ativa','Pausada','Encerrada')),
  pause_reason text check (length(pause_reason) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mvp_tickets (
  id uuid primary key default gen_random_uuid(),
  protocol text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('Suporte','Sugestão','Avaliação','Reserva','Artesanato','Fotografia','Transfer')),
  subject text not null check (length(subject) between 1 and 120),
  body text not null check (length(body) between 1 and 1000),
  status text not null default 'Aberta' check (status in ('Aberta','Respondida','Encerrada')),
  replies jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.mvp_partner_offers enable row level security;
alter table public.mvp_tickets enable row level security;

-- Turistas logados veem ofertas ativas e válidas; parceiros veem todas.
create policy mvp_offers_read on public.mvp_partner_offers for select to authenticated
  using ((status = 'Ativa' and valid_until >= current_date) or public.mvp_is_partner());
create policy mvp_tickets_read on public.mvp_tickets for select to authenticated
  using (user_id = (select auth.uid()));

-- Cupons de ofertas do banco usam a chave 'po:<uuid>'.
alter table public.mvp_coupons drop constraint if exists mvp_coupons_cupom_key_check;
alter table public.mvp_coupons add constraint mvp_coupons_cupom_key_check check (length(cupom_key) between 1 and 45);

create or replace function public.mvp_create_offer(p_title text, p_benefit text, p_rules text, p_limit integer, p_until date, p_category text default 'passeio')
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  if p_until < current_date then raise exception 'date in the past' using errcode = '22023'; end if;
  insert into public.mvp_partner_offers (created_by, title, benefit, rules, issue_limit, valid_until, category)
  values (uid, trim(p_title), trim(p_benefit), coalesce(trim(p_rules), ''), p_limit, p_until, coalesce(p_category, 'passeio'))
  returning * into r;
  return r;
end $$;

-- Na homologação, o próprio parceiro de demonstração aprova (em produção: gestão MaraPass).
create or replace function public.mvp_set_offer_status(p_id uuid, p_status text, p_reason text default null)
returns public.mvp_partner_offers language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() then raise exception 'not a partner' using errcode = '42501'; end if;
  if p_status not in ('Ativa','Pausada','Encerrada') then raise exception 'invalid status' using errcode = '22023'; end if;
  update public.mvp_partner_offers
     set status = p_status, pause_reason = case when p_status = 'Pausada' then left(p_reason, 120) else null end, updated_at = now()
   where id = p_id returning * into r;
  if not found then raise exception 'not found' using errcode = '22023'; end if;
  return r;
end $$;

-- Estatística de cada oferta (emitidos e usados), visível ao parceiro.
create or replace function public.mvp_offer_stats()
returns table (offer_id uuid, issued bigint, used bigint) language sql stable security definer set search_path = public as $$
  select o.id, count(c.id), count(c.used_at)
    from public.mvp_partner_offers o
    left join public.mvp_coupons c on c.cupom_key = 'po:' || o.id::text
   where public.mvp_is_partner()
   group by o.id;
$$;

-- Ativar cupom de oferta do banco: respeita status, validade e limite.
create or replace function public.mvp_activate_offer_coupon(p_offer_id uuid) returns public.mvp_coupons
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); o public.mvp_partner_offers; n bigint;
begin
  select * into o from public.mvp_partner_offers where id = p_offer_id for update;
  if not found or o.status <> 'Ativa' or o.valid_until < current_date then
    raise exception 'offer unavailable' using errcode = '22023';
  end if;
  if not exists (select 1 from public.mvp_coupons where user_id = uid and cupom_key = 'po:' || o.id::text and used_at is null) then
    select count(*) into n from public.mvp_coupons where cupom_key = 'po:' || o.id::text;
    if n >= o.issue_limit then raise exception 'issue limit reached' using errcode = '22023'; end if;
  end if;
  return public.mvp_activate_coupon('po:' || o.id::text);
end $$;

create or replace function public.mvp_open_ticket(p_kind text, p_subject text, p_body text) returns public.mvp_tickets
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_tickets; tries int := 0;
begin
  loop
    tries := tries + 1;
    begin
      insert into public.mvp_tickets (protocol, user_id, kind, subject, body)
      values ('P' || lpad(((get_byte(extensions.gen_random_bytes(3), 0) * 65536 + get_byte(extensions.gen_random_bytes(3), 1) * 256 + get_byte(extensions.gen_random_bytes(3), 2)) % 900000 + 100000)::text, 6, '0'),
              uid, p_kind, left(p_subject, 120), left(p_body, 1000))
      returning * into r;
      return r;
    exception when unique_violation then
      if tries > 8 then raise; end if;
    end;
  end loop;
end $$;

create or replace function public.mvp_reply_ticket(p_id uuid, p_text text) returns public.mvp_tickets
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_tickets;
begin
  update public.mvp_tickets set replies = replies || jsonb_build_array(left(p_text, 1000))
   where id = p_id and user_id = uid returning * into r;
  if not found then raise exception 'not found' using errcode = '42501'; end if;
  return r;
end $$;

revoke all on function public.mvp_create_offer(text,text,text,integer,date,text), public.mvp_set_offer_status(uuid,text,text),
  public.mvp_offer_stats(), public.mvp_activate_offer_coupon(uuid), public.mvp_open_ticket(text,text,text),
  public.mvp_reply_ticket(uuid,text) from public, anon;
grant execute on function public.mvp_create_offer(text,text,text,integer,date,text), public.mvp_set_offer_status(uuid,text,text),
  public.mvp_offer_stats(), public.mvp_activate_offer_coupon(uuid), public.mvp_open_ticket(text,text,text),
  public.mvp_reply_ticket(uuid,text) to authenticated;
grant select on public.mvp_partner_offers, public.mvp_tickets to authenticated;
revoke all on public.mvp_partner_offers, public.mvp_tickets from anon;;
