-- Contratos mínimos das migrações mvp_* anteriores, registradas no histórico remoto.
-- Utiliser exclusivement dans la base locale vide marapass_coupon_test.
create schema auth;
create schema private;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;
create table auth.users(id uuid primary key,phone text,phone_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('aal',current_setting('test.aal',true),'is_anonymous',false)$$;
create table private.test_admins(id uuid primary key);
create function private.assert_admin(u uuid) returns void language plpgsql as $$begin
  if not exists(select 1 from private.test_admins where id=u) then raise exception 'Admin only' using errcode='42501'; end if;
end $$;
create table public.mvp_partner_requests(user_id uuid primary key references auth.users(id),city text,business text);
create table public.mvp_partner_members(user_id uuid primary key references auth.users(id));
create table public.mvp_partner_offers(id uuid primary key default gen_random_uuid(),created_by uuid not null references auth.users(id),
  title text not null,benefit text not null,rules text,category text,issue_limit integer check(issue_limit between 1 and 10000),
  valid_until date not null,status text not null default 'Em análise',pause_reason text,image_url text,created_at timestamptz default now(),updated_at timestamptz default now());
create table public.mvp_coupons(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
  cupom_key text not null,code text unique not null,issued_at timestamptz not null default now(),
  used_at timestamptz,used_by uuid references auth.users(id),amount_cents int check(amount_cents>=0));
create unique index mvp_coupons_one_active on public.mvp_coupons(user_id,cupom_key) where used_at is null;
alter table public.mvp_coupons enable row level security;
alter table public.mvp_partner_offers enable row level security;
create function public.mvp_is_partner() returns boolean language sql stable security definer as $$
select exists(select 1 from public.mvp_partner_members where user_id=auth.uid())$$;
create function public.mvp_require_user() returns uuid language plpgsql stable security definer as $$begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='42501'; end if;return auth.uid();end$$;
create function public.mvp_create_offer(p_title text,p_benefit text,p_rules text,p_limit integer,p_until date,p_category text default 'passeio')
returns public.mvp_partner_offers language plpgsql security definer as $$declare o public.mvp_partner_offers;begin
  if not public.mvp_is_partner() then raise exception 'not a partner';end if;
  insert into public.mvp_partner_offers(created_by,title,benefit,rules,issue_limit,valid_until,category)
    values(public.mvp_require_user(),p_title,p_benefit,p_rules,p_limit,p_until,p_category) returning * into o;return o;
end$$;
grant usage on schema auth to authenticated,anon;
grant select on public.mvp_partner_offers,public.mvp_coupons to authenticated;
