-- Reference DDL for the cache already deployed to nwwxobiqynawxxnbvubz.
-- Do not rerun on production merely to install the Flutter frontend.
create table if not exists public.map_environment_cache (
 city_code text primary key check (city_code ~ '^21[0-9]{5}$'),
 payload jsonb,
 expires_at timestamptz not null default '-infinity',
 locked_until timestamptz not null default '-infinity',
 fetched_at timestamptz
);
alter table public.map_environment_cache enable row level security;
revoke all on public.map_environment_cache from public, anon, authenticated;
grant select, insert, update on public.map_environment_cache to service_role;
create or replace function public.claim_map_environment(p_code text)
returns boolean language sql security invoker set search_path = '' as $$
 with claim as (
  insert into public.map_environment_cache(city_code,locked_until)
  values(p_code,now()+interval '1 minute')
  on conflict(city_code) do update set locked_until=now()+interval '1 minute'
  where public.map_environment_cache.expires_at<=now()
    and public.map_environment_cache.locked_until<=now()
  returning 1
 ) select exists(select 1 from claim);
$$;
revoke all on function public.claim_map_environment(text) from public,anon,authenticated;
grant execute on function public.claim_map_environment(text) to service_role;
