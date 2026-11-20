
create table if not exists public.map_attractions (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 description text,
 municipality_ibge_code char(7) references public.municipalities(ibge_code),
 category text not null default 'atrativo',
 latitude numeric(10,7),
 longitude numeric(10,7),
 source_name text,
 source_url text,
 verified_at timestamptz,
 publication_status text not null default 'draft' check (publication_status in ('draft','published','archived')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint map_attractions_coordinates check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);
create index if not exists map_attractions_municipality_idx on public.map_attractions(municipality_ibge_code,publication_status);
alter table public.map_attractions enable row level security;
revoke all on public.map_attractions from anon, authenticated;
grant select on public.map_attractions to anon, authenticated;
drop policy if exists map_attractions_public_read on public.map_attractions;
create policy map_attractions_public_read on public.map_attractions for select to anon,authenticated using (publication_status='published' and verified_at is not null and latitude is not null and longitude is not null);
create or replace view public.map_partner_points with (security_invoker=true) as
select e.id,e.name,e.category,e.city,e.latitude,e.longitude,e.description
from public.establishments e
where e.is_active=true and e.is_public=true and e.latitude is not null and e.longitude is not null;
revoke all on public.map_partner_points from public,anon,authenticated;
grant select on public.map_partner_points to anon,authenticated;
;
