alter table public.mvp_reservations drop constraint mvp_reservations_period_check;
alter table public.mvp_reservations add constraint mvp_reservations_period_check
  check (period in ('Manhã', 'Tarde') or period ~ '^[0-9]{1,2} noites? · .{1,80}$');
do $$
declare d text;
begin
  select pg_get_functiondef('public.mvp_admin_command(text,jsonb)'::regprocedure) into d;
  d := replace(d, $q$status in ('pendente','Pendente','Aguardando')$q$, $q$status = 'solicitada'$q$);
  execute d;
end $$;;
