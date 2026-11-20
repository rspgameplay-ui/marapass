
alter table public.map_attractions
 add column if not exists external_ref text,
 add column if not exists access_mode text not null default 'guided',
 add column if not exists navigation_warning text,
 add column if not exists coordinate_quality text not null default 'reference',
 add column if not exists partner_segments text[] not null default '{}';
create unique index if not exists map_attractions_external_ref_unique on public.map_attractions (external_ref) where external_ref is not null;
create table if not exists public.map_demo_offers (
 id uuid primary key default gen_random_uuid(),
 attraction_id uuid not null references public.map_attractions(id) on delete cascade,
 title text not null,
 benefit_label text not null,
 segment text not null,
 terms text not null default 'Demonstração sem valor comercial; não pode ser emitido ou resgatado.',
 starts_at timestamptz not null default now(),
 ends_at timestamptz not null default '2027-02-01T00:00:00Z',
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 constraint map_demo_offers_window check(ends_at>starts_at)
);
create unique index if not exists map_demo_offers_attr_title_unique on public.map_demo_offers(attraction_id,title);
create index if not exists map_demo_offers_active_idx on public.map_demo_offers(is_active,ends_at);
alter table public.map_demo_offers enable row level security;
revoke all on public.map_demo_offers from anon,authenticated;
grant select on public.map_demo_offers to anon,authenticated;
drop policy if exists map_demo_offers_public_read on public.map_demo_offers;
create policy map_demo_offers_public_read on public.map_demo_offers for select to anon,authenticated
 using(is_active=true and now() >= starts_at and now()<ends_at and exists (
 select 1 from public.map_attractions a where a.id=attraction_id
 and a.publication_status='published' and a.verified_at is not null
 ));
;
