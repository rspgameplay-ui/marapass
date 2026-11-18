-- Requer as tabelas e RPCs mvp_* da migração mvp_app_web_demo.
-- O parceiro do MVP é identificado pelo titular aprovado da oferta (created_by).
begin;
alter table public.mvp_partner_offers
  add column sale_terms jsonb,
  add column sale_approved boolean not null default false;
alter table public.mvp_coupons
  alter column user_id drop not null,
  add column sale jsonb,
  add column payment_reported_at timestamptz,
  add column sale_stage text not null default 'issued',
  add column fee_state text;
-- A checagem antiga não incluía o estado Recusada já utilizado pelo painel.
do $$ declare c name; begin
  select conname into c from pg_constraint where conrelid='public.mvp_partner_offers'::regclass and contype='c'
    and conkey=array[(select attnum from pg_attribute where attrelid='public.mvp_partner_offers'::regclass and attname='status')];
  if c is not null then execute format('alter table public.mvp_partner_offers drop constraint %I',c); end if;
end $$;
alter table public.mvp_partner_offers add constraint mvp_sale_offer_status check(status in
  ('Rascunho','Em análise','Ativa','Pausada','Encerrada','Recusada'));
create index if not exists mvp_coupon_offer_usage on public.mvp_coupons(cupom_key,user_id);

create table private.mvp_coupon_entries (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  kind text not null check (kind in ('conversion','refund')),
  reference text not null,
  paid_cents integer not null,
  fee_cents integer not null,
  points integer not null,
  reason text,
  actor uuid not null,
  at timestamptz not null default clock_timestamp(),
  unique(coupon_id,kind,reference),
  check ((kind='conversion' and paid_cents>=0 and fee_cents>=0 and points>=0)
      or (kind='refund' and paid_cents<0 and fee_cents<=0 and points<=0))
);
create unique index mvp_one_conversion on private.mvp_coupon_entries(coupon_id) where kind='conversion';
create table private.mvp_coupon_events (
  id bigint generated always as identity primary key,
  coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  kind text not null, actor uuid, detail jsonb not null default '{}',
  at timestamptz not null default clock_timestamp()
);
create index mvp_coupon_events_timeline on private.mvp_coupon_events(coupon_id,id);
alter table private.mvp_coupon_entries enable row level security;
alter table private.mvp_coupon_events enable row level security;
revoke all on private.mvp_coupon_entries,private.mvp_coupon_events from public,anon,authenticated;
revoke insert,update,delete,truncate on public.mvp_coupons,public.mvp_partner_offers from public,anon,authenticated;

create function private.mvp_sale_fee(amount integer) returns integer language sql immutable strict
set search_path='' as $$ select ((amount::bigint * 5 + 50) / 100)::integer $$;

-- Percentuais usam pontos-base (10% = 1000). Nominais e preços usam centavos.
create function public.mvp_set_sale_terms(p_offer_id uuid,p_price integer,p_kind text,p_discount integer,
  p_payment text,p_url text,p_points boolean default true,p_per_user integer default 1,p_window jsonb default '{}')
returns public.mvp_partner_offers language plpgsql security definer set search_path='' as $$
declare u uuid := public.mvp_require_user(); o public.mvp_partner_offers; cut integer; starts date; label text;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  if p_price is null or p_price not between 1 and 1000000000 or p_discount is null or p_discount<0 or
     p_kind is null or p_kind not in ('percent','fixed','promo') or (p_kind='percent' and p_discount>10000) or
     (p_kind in ('fixed','promo') and p_discount>p_price) or p_per_user is null or p_per_user not between 1 and 10000 or
     p_points is null or length(coalesce(trim(p_payment),''))>400 or length(coalesce(trim(p_url),''))>1000 or
     (nullif(trim(p_url),'') is not null and p_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?([/?#][^[:space:]]*)?$') or
     (nullif(trim(p_payment),'') is null and nullif(trim(p_url),'') is null)
    then raise exception 'Confira preço, desconto, limite e instruções de pagamento.'; end if;
  starts:=coalesce(nullif(p_window->>'from','')::date,(now() at time zone 'America/Fortaleza')::date);
  if length(coalesce(p_window->>'hours',''))>160 or (nullif(p_window->>'contact','') is not null and
      p_window->>'contact' !~ '^[1-9][0-9]{7,14}$') then raise exception 'Confira os horários e o contato.'; end if;
  cut := case when p_kind='promo' then p_price-p_discount when p_kind='fixed' then p_discount else ((p_price::bigint*p_discount+5000)/10000)::integer end;
  label:=case when p_kind='percent' then replace(trim_scale(p_discount::numeric/100)::text,'.',',')||'% de desconto'
    when p_kind='promo' then 'Preço promocional de R$ '||replace(to_char(p_discount::numeric/100,'FM999999990.00'),'.',',')
    else 'R$ '||replace(to_char(p_discount::numeric/100,'FM999999990.00'),'.',',')||' de desconto' end;
  update public.mvp_partner_offers set benefit=label,sale_terms=jsonb_build_object('price',p_price,'kind',p_kind,
    'discount',p_discount,'discount_cents',cut,'due',p_price-cut,'payment',trim(p_payment),'url',nullif(trim(p_url),''),
    'points',p_points,'per_user',p_per_user,'from',starts,'hours',p_window->>'hours','contact',p_window->>'contact'),sale_approved=false,status='Em análise',updated_at=now()
    where id=p_offer_id and created_by=u and valid_until>=starts returning * into o;
  if not found then raise exception 'Oferta indisponível.' using errcode='42501'; end if;
  return o;
end $$;

-- Cadastro e envio para aprovação devem ser uma única transação.
create function public.mvp_create_sale_offer(p_offer jsonb,p_terms jsonb) returns public.mvp_partner_offers
language plpgsql security definer set search_path='' as $$
declare o public.mvp_partner_offers; benefit text;
begin
  benefit:=case when p_terms->>'kind'='percent' then trim_scale((p_terms->>'discount')::numeric/100)::text||'% de desconto'
    else 'R$ '||replace(to_char((p_terms->>'discount')::numeric/100,'FM999999990.00'),'.',',')||' de desconto' end;
  o:=public.mvp_create_offer(p_offer->>'title',replace(benefit,'.',','),p_offer->>'rules',(p_offer->>'limit')::int,
    (p_offer->>'until')::date,p_offer->>'category');
  o:=public.mvp_set_sale_terms(o.id,(p_terms->>'price')::int,p_terms->>'kind',(p_terms->>'discount')::int,
    p_terms->>'payment',p_terms->>'url',(p_terms->>'points')::boolean,(p_terms->>'per_user')::int,coalesce(p_terms->'window','{}'));
  if coalesce((p_offer->>'draft')::boolean,false) then
    update public.mvp_partner_offers set status='Rascunho' where id=o.id returning * into o; end if;
  return o;
end $$;

-- Reutiliza o comando de aprovação da administração e o MFA já exigido por ele.
create function private.mvp_certify_sale() returns trigger language plpgsql set search_path='' as $$
begin
  if new.status='Ativa' and new.sale_terms is not null and not old.sale_approved then
    perform private.assert_admin(auth.uid());
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
    new.sale_approved:=true;
  end if;
  if new.status in ('Em análise','Recusada') then new.sale_approved:=false; end if;
  return new;
end $$;
create trigger mvp_certify_sale before update of status,sale_terms on public.mvp_partner_offers
  for each row execute function private.mvp_certify_sale();

create or replace function public.mvp_set_offer_status(p_id uuid,p_status text,p_reason text default null)
returns public.mvp_partner_offers language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); o public.mvp_partner_offers;
begin
  if not public.mvp_is_partner() or p_status is null or p_status not in ('Ativa','Pausada','Encerrada') then
    raise exception 'Ação indisponível.' using errcode='42501'; end if;
  update public.mvp_partner_offers set status=p_status,pause_reason=case when p_status='Pausada' then left(p_reason,120) end,updated_at=now()
    where id=p_id and created_by=u and (p_status<>'Ativa' or (sale_approved and status='Pausada')) returning * into o;
  if not found then raise exception 'A oferta precisa de aprovação administrativa.'; end if;
  return o;
end $$;
drop policy if exists mvp_offers_read on public.mvp_partner_offers;
create policy mvp_offers_read on public.mvp_partner_offers for select using (
  (status='Ativa' and valid_until >= (now() at time zone 'America/Fortaleza')::date)
  or (created_by=(select auth.uid()) and (select public.mvp_is_partner())));
drop policy if exists mvp_coupons_read on public.mvp_coupons;
create policy mvp_coupons_read on public.mvp_coupons for select using (user_id=(select auth.uid()));
create or replace function public.mvp_offer_stats() returns table(offer_id uuid,issued bigint,used bigint)
language sql stable security definer set search_path='' as $$
  select o.id,count(c.id),count(c.used_at) from public.mvp_partner_offers o left join public.mvp_coupons c on c.cupom_key='po:'||o.id
  where o.created_by=(select auth.uid()) and (select public.mvp_is_partner()) group by o.id
$$;

create or replace function public.mvp_activate_offer_coupon(p_offer_id uuid) returns public.mvp_coupons
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); o public.mvp_partner_offers; c public.mvp_coupons;
  key text:='po:'||p_offer_id; total bigint; mine bigint; expiry timestamptz;
begin
  select * into o from public.mvp_partner_offers where id=p_offer_id for update;
  if not found then raise exception 'Oferta indisponível.'; end if;
  if u=o.created_by then raise exception 'O parceiro não pode emitir cupom da própria oferta.'; end if;
  select * into c from public.mvp_coupons where user_id=u and cupom_key=key and used_at is null and sale_stage not in ('cancelled','declined');
  if found then return c; end if;
  expiry:=(o.valid_until+1)::timestamp at time zone 'America/Fortaleza';
  if (now() at time zone 'America/Fortaleza')::date<(o.sale_terms->>'from')::date or o.status<>'Ativa' or not o.sale_approved or o.sale_terms is null or clock_timestamp()>=expiry or
     not exists(select 1 from public.mvp_partner_members where user_id=o.created_by)
    then raise exception 'Oferta indisponível.'; end if;
  select count(*),count(*) filter(where user_id=u) into total,mine from public.mvp_coupons where cupom_key=key and sale_stage not in ('cancelled','declined');
  if total>=o.issue_limit or mine>=(o.sale_terms->>'per_user')::int then raise exception 'Limite de emissão atingido.'; end if;
  insert into public.mvp_coupons(user_id,cupom_key,code,sale) values(u,key,'MP-'||upper(replace(gen_random_uuid()::text,'-','')),
    o.sale_terms||jsonb_build_object('offer',o.id,'owner',o.created_by,'title',o.title,'benefit',o.benefit,
      'rules',o.rules,'city',(select city from public.mvp_partner_requests where user_id=o.created_by),'category',o.category,'expires',expiry,'rate_bps',500)) returning * into c;
  insert into private.mvp_coupon_events(coupon_id,kind,actor) values(c.id,'issued',u);
  return c;
end $$;
create or replace function public.mvp_activate_coupon(p_cupom_key text) returns public.mvp_coupons
language plpgsql security definer set search_path='' as $$
begin
  if p_cupom_key ~ '^po:[0-9a-fA-F-]{36}$' then
    return public.mvp_activate_offer_coupon(substr(p_cupom_key,4)::uuid); end if;
  raise exception 'Cupom editorial de demonstração. Escolha uma oferta comercial aprovada.';
end $$;

create function public.mvp_report_payment(p_code text) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons;
begin
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and user_id=u and sale is not null for update;
  if not found then raise exception 'Cupom indisponível.'; end if;
  if c.sale_stage in ('cancelled','declined','disputed') then raise exception 'Cupom indisponível para informar pagamento.'; end if;
  if c.used_at is not null or c.payment_reported_at is not null then return; end if;
  if clock_timestamp()>=(c.sale->>'expires')::timestamptz then raise exception 'Cupom vencido.'; end if;
  update public.mvp_coupons set payment_reported_at=clock_timestamp() where id=c.id;
  insert into private.mvp_coupon_events(coupon_id,kind,actor) values(c.id,'payment_reported',u);
end $$;
-- O mesmo RPC recebe o código emitido pelo servidor nas telas de QR, link e painel.
create table private.mvp_coupon_lookup_limit(actor uuid primary key,minute timestamptz not null,n integer not null);
alter table private.mvp_coupon_lookup_limit enable row level security;
revoke all on private.mvp_coupon_lookup_limit from public,anon,authenticated;
create function public.mvp_confirm_receipt(p_code text,p_amount_cents integer,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; fee integer; pts integer; attempts integer;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  if p_channel is null or p_channel not in ('panel','whatsapp','qr') then raise exception 'Canal inválido.'; end if;
  insert into private.mvp_coupon_lookup_limit values(u,date_trunc('minute',clock_timestamp()),1) on conflict(actor) do update
    set minute=excluded.minute,n=case when excluded.minute=mvp_coupon_lookup_limit.minute then mvp_coupon_lookup_limit.n+1 else 1 end
    returning n into attempts;
  if attempts>30 then return jsonb_build_object('ok',false,'reason','rate_limited'); end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale->>'owner'=u::text for update;
  if not found then return jsonb_build_object('ok',false,'reason','unavailable'); end if;
  if c.user_id is null and c.used_at is null then return jsonb_build_object('ok',false,'reason','unavailable'); end if;
  if c.user_id=u then raise exception 'O titular do cupom não pode confirmar o próprio pagamento.'; end if;
  if p_amount_cents is null or p_amount_cents<0 then raise exception 'Informe o valor recebido.'; end if;
  if c.used_at is null and clock_timestamp()>=(c.sale->>'expires')::timestamptz then return jsonb_build_object('ok',false,'reason','expired'); end if;
  if c.sale_stage in ('cancelled','declined','disputed') then return jsonb_build_object('ok',false,'reason',c.sale_stage); end if;
  if p_amount_cents<>(c.sale->>'due')::integer then
    if c.used_at is null then
      update public.mvp_coupons set sale_stage='disputed' where id=c.id;
      insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,'amount_mismatch',u,
        jsonb_build_object('received',p_amount_cents,'from',c.sale_stage,'to','disputed','channel',p_channel)); end if;
    return jsonb_build_object('ok',false,'reason','amount_mismatch'); end if;
  if c.used_at is not null then return jsonb_build_object('ok',true,'already',true,'cupom_key',c.cupom_key); end if;
  if clock_timestamp()>=(c.sale->>'expires')::timestamptz then return jsonb_build_object('ok',false,'reason','expired'); end if;
  fee:=private.mvp_sale_fee(p_amount_cents);
  pts:=case when (c.sale->>'points')::boolean then p_amount_cents/100 else 0 end;
  insert into private.mvp_coupon_entries(coupon_id,kind,reference,paid_cents,fee_cents,points,actor)
    values(c.id,'conversion','original',p_amount_cents,fee,pts,u);
  update public.mvp_coupons set used_at=clock_timestamp(),used_by=u,amount_cents=p_amount_cents,fee_state='pending',sale_stage='converted' where id=c.id;
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail) values(c.id,'converted',u,
    jsonb_build_object('from',c.sale_stage,'to','converted','channel',p_channel));
  return jsonb_build_object('ok',true,'cupom_key',c.cupom_key,'fee_cents',fee,'points',pts);
end $$;

create or replace function public.mvp_validate_coupon(p_code text,p_amount_cents integer default null) returns jsonb
language sql security definer set search_path='' as $$select public.mvp_confirm_receipt(p_code,p_amount_cents,'panel')$$;

create function public.mvp_refund_coupon(p_code text,p_amount integer,p_reference text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); c public.mvp_coupons; old private.mvp_coupon_entries;
  balance integer; fee integer; pts integer; remaining integer;
begin
  if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  select * into c from public.mvp_coupons where code=upper(trim(p_code)) and sale->>'owner'=u::text and used_at is not null for update;
  if not found then raise exception 'Conversão indisponível.'; end if;
  if p_amount is null or p_amount<=0 or length(coalesce(trim(p_reference),'')) not between 1 and 100
    or length(coalesce(trim(p_reason),'')) not between 1 and 300 then raise exception 'Confira valor, referência e motivo do estorno.'; end if;
  select * into old from private.mvp_coupon_entries where coupon_id=c.id and kind='refund' and reference=trim(p_reference);
  if found then
    if old.paid_cents<>-p_amount or old.reason<>trim(p_reason) then raise exception 'Referência já usada com outros dados.'; end if;
    return; end if;
  select sum(paid_cents),sum(fee_cents),sum(points) into balance,fee,pts from private.mvp_coupon_entries where coupon_id=c.id;
  remaining:=balance-p_amount;
  if remaining<0 then raise exception 'Estorno superior ao saldo.'; end if;
  insert into private.mvp_coupon_entries(coupon_id,kind,reference,paid_cents,fee_cents,points,reason,actor)
    values(c.id,'refund',trim(p_reference),-p_amount,private.mvp_sale_fee(remaining)-fee,
      (case when (c.sale->>'points')::boolean then remaining/100 else 0 end)-pts,trim(p_reason),u);
  insert into private.mvp_coupon_events(coupon_id,kind,actor,detail)
    values(c.id,'refunded',u,jsonb_build_object('reference',trim(p_reference),'amount',p_amount));
end $$;

create function private.mvp_sale_match(c public.mvp_coupons,f jsonb) returns boolean language sql stable set search_path='' as $$
  select (nullif(f->>'from','') is null or c.issued_at>=((f->>'from')::date::timestamp at time zone 'America/Fortaleza')) and
    (nullif(f->>'until','') is null or c.issued_at<(((f->>'until')::date+1)::timestamp at time zone 'America/Fortaleza')) and
    (nullif(f->>'owner','') is null or c.sale->>'owner'=f->>'owner') and
    (nullif(f->>'city','') is null or lower(c.sale->>'city')=lower(f->>'city')) and
    (nullif(f->>'category','') is null or c.sale->>'category'=f->>'category')
$$;
revoke all on function private.mvp_sale_match(public.mvp_coupons,jsonb) from public,anon,authenticated;
-- Cada página leva o estado e os lançamentos. Consultas da carteira nunca escutam outra conta.
create function public.mvp_coupon_statement(p_scope text default 'tourist',p_code text default null,
  p_before timestamptz default null,p_before_id uuid default null,p_limit integer default 50,p_filters jsonb default '{}')
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user();
begin
  if p_scope='admin' then
    perform private.assert_admin(u);
    if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  elsif p_scope='partner' then
    if not public.mvp_is_partner() then raise exception 'Parceiro sem autorização.' using errcode='42501'; end if;
  elsif p_scope is distinct from 'tourist' then raise exception 'Perfil inválido.'; end if;
  return query select jsonb_build_object('id',c.id,'code',c.code,'issued_at',c.issued_at,'sale',c.sale,
    'fee_state',c.fee_state,'stage',c.sale_stage,'state',case when c.sale_stage in ('cancelled','declined','disputed') then c.sale_stage
      when c.used_at is not null then case when coalesce(e.refunds,0)=0 then c.sale_stage
        when e.paid=0 then 'refunded' else 'partial_refund' end
      when c.user_id is null then 'cancelled'
      when (c.sale->>'expires')::timestamptz<=now() then 'expired'
      when c.payment_reported_at is not null then 'payment_reported' else c.sale_stage end,
    'paid',coalesce(e.paid,0),'fee',coalesce(e.fee,0),'points',coalesce(e.points,0),
    'entries',coalesce(e.items,'[]'::jsonb),'events',coalesce(h.items,'[]'::jsonb))
    from public.mvp_coupons c
    left join lateral (select sum(x.paid_cents) paid,sum(x.fee_cents) fee,sum(x.points) points,
      count(*) filter(where x.kind='refund') refunds,jsonb_agg(case when p_scope='tourist' then to_jsonb(x)-'actor'-'fee_cents' else to_jsonb(x) end order by x.at,x.id) items
      from private.mvp_coupon_entries x where x.coupon_id=c.id) e on true
    left join lateral (select jsonb_agg(case when p_scope='tourist' then jsonb_build_object('kind',x.kind,'at',x.at) else to_jsonb(x)-'coupon_id' end order by x.id) items
      from private.mvp_coupon_events x where x.coupon_id=c.id and (p_scope<>'tourist' or x.kind not like 'fee_%')) h on true
    where c.sale is not null and (p_scope='admin' or (p_scope='tourist' and c.user_id=u)
      or (p_scope='partner' and c.sale->>'owner'=u::text))
    and private.mvp_sale_match(c,p_filters) and (p_code is null or c.code=upper(trim(p_code)))
    and (p_before is null or (c.issued_at,c.id)<(p_before,p_before_id))
    order by c.issued_at desc,c.id desc limit greatest(1,least(coalesce(p_limit,50),100));
end $$;
create index mvp_coupon_sales_owner on public.mvp_coupons((sale->>'owner'),issued_at desc,id desc) where sale is not null;
create index mvp_coupon_sales_wallet on public.mvp_coupons(user_id,issued_at desc,id desc) where sale is not null;
create function public.mvp_coupon_points() returns table(coupon_id uuid,at timestamptz,points integer,kind text,reference text,title text,paid_cents integer)
language sql stable security definer set search_path='' as $$
  select c.id,e.at,e.points,e.kind,e.reference,c.sale->>'title',e.paid_cents from private.mvp_coupon_entries e
  join public.mvp_coupons c on c.id=e.coupon_id where c.user_id=public.mvp_require_user() order by e.at,e.id
$$;
-- O catálogo público mostra só as condições necessárias para escolher a oferta.
create function public.mvp_public_sales() returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',o.id,'title',o.title,'benefit',o.benefit,'rules',o.rules,'category',o.category,
    'valid_until',o.valid_until,'image_url',o.image_url,'status',o.status,'sale_approved',true,
    'sale_terms',o.sale_terms-'payment'-'url')
  from public.mvp_partner_offers o join public.mvp_partner_members m on m.user_id=o.created_by
  where o.status='Ativa' and o.sale_approved and (o.sale_terms->>'from')::date<=(now() at time zone 'America/Fortaleza')::date and o.valid_until>=(now() at time zone 'America/Fortaleza')::date
  order by o.created_at desc,o.id
$$;
revoke all on function public.mvp_public_sales() from public;
grant execute on function public.mvp_public_sales() to anon,authenticated;

-- A exclusão de conta já existente preserva a conversão e desvincula o turista.
create function private.mvp_anonymize_coupon() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update public.mvp_coupons set user_id=null where user_id=old.id and sale is not null;
  update private.mvp_coupon_events set actor=null where actor=old.id and kind in ('issued','payment_reported');
  return old;
end $$;
create trigger mvp_anonymize_coupon before delete on auth.users for each row execute function private.mvp_anonymize_coupon();
revoke all on function private.mvp_anonymize_coupon() from public,anon,authenticated;
create function public.mvp_admin_sale_terms() returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.assert_admin(public.mvp_require_user());
  if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Confirme o segundo fator.'; end if;
  return query select jsonb_build_object('id',o.id,'owner',o.created_by,'partner',(select business from public.mvp_partner_requests where user_id=o.created_by),'terms',o.sale_terms) from public.mvp_partner_offers o where o.sale_terms is not null;
end $$;
do $$ declare f regprocedure; begin
  for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in
    ('mvp_admin_sale_terms','mvp_create_sale_offer','mvp_set_sale_terms','mvp_set_offer_status','mvp_offer_stats','mvp_activate_offer_coupon','mvp_activate_coupon',
     'mvp_report_payment','mvp_confirm_receipt','mvp_validate_coupon','mvp_refund_coupon','mvp_coupon_statement','mvp_coupon_points') loop
    execute format('revoke all on function %s from public,anon,authenticated',f);
    execute format('grant execute on function %s to authenticated',f);
  end loop;
end $$;
revoke all on function private.mvp_sale_fee(integer),private.mvp_certify_sale() from public,anon,authenticated;
commit;
