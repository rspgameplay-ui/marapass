-- Rotas de "Defina sua Rota" na conta do turista (passam entre aparelhos).
create table if not exists public.mvp_trips (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (length(id) between 1 and 60),
  data jsonb not null check (pg_column_size(data) < 64000),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.mvp_trips enable row level security;
revoke all on public.mvp_trips from anon, authenticated;
grant select, insert, update, delete on public.mvp_trips to authenticated;
create policy mvp_trips_own on public.mvp_trips for all to authenticated
  using (user_id = (select auth.uid()) and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false))
  with check (user_id = (select auth.uid()) and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false));;
