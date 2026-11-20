
-- MARAPASS MVP / ETAPA 2A
-- RBAC institucional, sessões de serviços e vínculo inequívoco da reserva com horário.
create table public.staff_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  staff_role text not null check (staff_role in ('admin','operator')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.experience_slots (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references public.experiences(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null check (capacity between 1 and 500),
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (experience_id, starts_at),
  unique (id, experience_id)
);
create index experience_slots_experience_start on public.experience_slots(experience_id, starts_at) where is_open;

alter table public.partner_applications
  add column partner_id uuid unique references public.partners(id),
  add column reviewed_by_user_id uuid references auth.users(id),
  add column reviewed_at timestamptz,
  add constraint partner_review_consistency check (
    (status = 'pending' and partner_id is null and reviewed_by_user_id is null and reviewed_at is null)
    or (status = 'approved' and partner_id is not null and reviewed_by_user_id is not null and reviewed_at is not null)
    or (status = 'rejected' and partner_id is null and reviewed_by_user_id is not null and reviewed_at is not null)
  );

alter table public.reservations
  add column slot_id uuid not null references public.experience_slots(id),
  add column request_key text not null unique,
  add constraint reservation_request_key_valid check (length(request_key) between 16 and 180);
create index reservations_slot_status on public.reservations(slot_id, status);

create function private.reservation_slot_guard() returns trigger
language plpgsql security invoker set search_path = ''
as $$
declare s record;
begin
  select experience_id, starts_at into s from public.experience_slots where id=new.slot_id;
  if not found
    or new.experience_id is distinct from s.experience_id
    or new.scheduled_at is distinct from s.starts_at then
    raise exception 'reservation experience, slot and scheduled time must match';
  end if;
  return new;
end $$;
create trigger guard_reservation_slot
  before insert or update of slot_id,experience_id,scheduled_at
  on public.reservations for each row execute function private.reservation_slot_guard();

create trigger touch_experience_slots
  before update on public.experience_slots
  for each row execute function private.touch_updated_at();

-- Secure exposure: public listable schedules; employee registry only self-readable.
alter table public.staff_members enable row level security;
alter table public.experience_slots enable row level security;
revoke all on public.staff_members, public.experience_slots from public, anon, authenticated;
grant select on public.staff_members to authenticated;
grant select on public.experience_slots to anon, authenticated;
grant select, insert, update, delete on public.staff_members, public.experience_slots to service_role;

create policy staff_read_self on public.staff_members
for select to authenticated using (user_id=(select auth.uid()));

create policy slots_public on public.experience_slots
for select to anon,authenticated
using (is_open and starts_at>now() and exists (
  select 1 from public.experiences x
  join public.establishments e on e.id=x.establishment_id
  join public.partners p on p.id=e.partner_id
  where x.id=experience_id and x.status='published'
    and e.is_public and e.is_active and p.status='approved'
));

create policy slots_partner on public.experience_slots
for select to authenticated using (
  exists(select 1 from public.experiences x
    join public.establishments e on e.id=x.establishment_id
    join public.partners p on p.id=e.partner_id
    where x.id=experience_id and
      (p.owner_user_id=(select auth.uid())
        or exists(select 1 from public.partner_members m
          where m.partner_id=p.id and m.user_id=(select auth.uid())
          and m.is_active)))
);

-- Don't expose administrative functions by default.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
;
