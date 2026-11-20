begin;

create extension if not exists postgis with schema extensions;

create table public.tourism_poles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null
    check (length(trim(name)) between 2 and 120),
  description text,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'inactive')),
  valid_from date,
  valid_to date,
  official_source text,
  official_source_url text,
  source_checked_at date,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create table public.municipalities (
  ibge_code char(7) primary key
    check (ibge_code ~ '^[0-9]{7}$'),
  name text not null
    check (length(trim(name)) between 2 and 120),
  state_code char(2) not null default 'MA'
    check (state_code = 'MA'),
  boundary extensions.geometry(MultiPolygon, 4326),
  boundary_source text,
  boundary_source_url text,
  boundary_version text,
  boundary_as_of date,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (boundary is null or extensions.st_isvalid(boundary)),
  check (not is_published or boundary is not null)
);

create table public.pole_municipalities (
  pole_id uuid not null
    references public.tourism_poles(id) on delete restrict,
  municipality_ibge_code char(7) not null
    references public.municipalities(ibge_code) on delete restrict,
  valid_from date not null default current_date,
  valid_to date,
  is_active boolean not null default true,
  source text,
  created_at timestamptz not null default now(),
  primary key (pole_id, municipality_ibge_code, valid_from),
  check (valid_to is null or valid_to >= valid_from)
);

create index tourism_poles_active_order_idx
  on public.tourism_poles (display_order, slug)
  where status = 'active';

create index municipalities_boundary_gix
  on public.municipalities using gist (boundary);

create index pole_municipalities_by_municipality_idx
  on public.pole_municipalities
    (municipality_ibge_code, is_active, valid_from, valid_to);

create index pole_municipalities_by_pole_idx
  on public.pole_municipalities
    (pole_id, is_active, valid_from, valid_to);

alter table public.tourism_poles enable row level security;
alter table public.municipalities enable row level security;
alter table public.pole_municipalities enable row level security;

revoke all on public.tourism_poles from public, anon, authenticated;
revoke all on public.municipalities from public, anon, authenticated;
revoke all on public.pole_municipalities from public, anon, authenticated;

grant select on public.tourism_poles to anon, authenticated;
grant select, insert, update, delete
  on public.tourism_poles to authenticated;

grant select on public.municipalities to anon, authenticated;
grant select, insert, update, delete
  on public.municipalities to authenticated;

grant select on public.pole_municipalities to anon, authenticated;
grant select, insert, update, delete
  on public.pole_municipalities to authenticated;

create policy tourism_poles_public_read
  on public.tourism_poles
  for select to anon, authenticated
  using (
    status = 'active'
    and (valid_from is null or valid_from <= current_date)
    and (valid_to is null or valid_to >= current_date)
  );

create policy tourism_poles_admin_manage
  on public.tourism_poles
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

create policy municipalities_public_read
  on public.municipalities
  for select to anon, authenticated
  using (is_published);

create policy municipalities_admin_manage
  on public.municipalities
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

create policy pole_municipalities_public_read
  on public.pole_municipalities
  for select to anon, authenticated
  using (
    is_active
    and valid_from <= current_date
    and (valid_to is null or valid_to >= current_date)
    and exists (
      select 1
      from public.tourism_poles p
      where p.id = pole_id
        and p.status = 'active'
        and (p.valid_from is null or p.valid_from <= current_date)
        and (p.valid_to is null or p.valid_to >= current_date)
    )
    and exists (
      select 1
      from public.municipalities m
      where m.ibge_code = municipality_ibge_code
        and m.is_published
    )
  );

create policy pole_municipalities_admin_manage
  on public.pole_municipalities
  for all to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  )
  with check (
    (select auth.jwt() ->> 'aal') = 'aal2'
    and exists (
      select 1
      from public.staff_members s
      where s.user_id = (select auth.uid())
        and s.staff_role = 'admin'
        and s.is_active
    )
  );

commit;;
