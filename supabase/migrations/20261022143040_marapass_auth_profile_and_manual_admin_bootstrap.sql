
-- MaraPass 2026 / Auth onboarding and controlled first administrator bootstrap.
-- Authentication itself is managed by Supabase Auth.
-- No JWT role is inferred from user-editable metadata.

create function private.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id,display_name)
  values (new.id, '')
  on conflict(id) do nothing;
  return new;
end;
$$;

revoke all on function private.create_profile_for_auth_user() from public,anon,authenticated,service_role;

create trigger marapass_auth_profile_created
after insert on auth.users
for each row
execute function private.create_profile_for_auth_user();

create function private.audit_staff_role()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid;
  v_new jsonb;
  v_old jsonb;
begin
  v_user := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  v_old := case when tg_op = 'INSERT' then null else
    jsonb_build_object('role',old.staff_role,'active',old.is_active) end;
  v_new := case when tg_op = 'DELETE' then null else
    jsonb_build_object('role',new.staff_role,'active',new.is_active) end;
  if tg_op <> 'UPDATE' or v_new is distinct from v_old then
    insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
    values (
      'staff_member',v_user,lower(tg_op),null,
      jsonb_build_object('before',v_old,'after',v_new)
    );
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

revoke all on function private.audit_staff_role() from public,anon,authenticated;
grant execute on function private.audit_staff_role() to service_role;

create trigger marapass_staff_role_audit
after insert or update or delete on public.staff_members
for each row execute function private.audit_staff_role();

-- Deliberately NOT exposed through the Data API. Only run manually from
-- privileged SQL Editor after the designated person's email is verified.
create function private.grant_first_administrator(p_verified_email text)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if p_verified_email is null
    or length(trim(p_verified_email))<6 then
    raise exception 'provide verified account email';
  end if;

  -- Serializes one-time bootstrap even if two operators submit concurrently.
  perform pg_catalog.pg_advisory_xact_lock(82354112, 10222026);

  if exists(select 1 from public.staff_members where staff_role='admin') then
    raise exception 'initial administrator is already assigned';
  end if;

  select u.id into v_user
    from auth.users u
    where lower(u.email)=lower(trim(p_verified_email))
      and u.email_confirmed_at is not null
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until<now());
  if v_user is null then
    raise exception 'confirmed, active Auth account not found';
  end if;

  insert into public.profiles(id,display_name) values(v_user,'')
  on conflict(id) do nothing;

  insert into public.staff_members(user_id,staff_role,is_active)
  values(v_user,'admin',true)
  on conflict(user_id) do update set staff_role='admin',is_active=true;

  insert into private.audit_events(entity_type,entity_id,operation,actor_user_id,context)
  values(
    'staff_member',v_user,'first_admin_bootstrap',null,
    jsonb_build_object('method','confirmed_email_with_privileged_sql_editor')
  );

  return v_user;
end $$;

revoke all on function private.grant_first_administrator(text)
from public,anon,authenticated,service_role;

-- Client-safe role discovery, NEVER privileged role assignment.
create function public.my_access_context()
returns table(
  user_id uuid,
  staff_role text,
  admin_role boolean,
  partner_owner boolean,
  partner_manager boolean,
  partner_validator boolean,
  mfa_verified boolean,
  admin_console_ready boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
select
  (select auth.uid()) as user_id,
  s.staff_role,
  (s.staff_role='admin' and s.is_active) as admin_role,
  exists(select 1 from public.partners p
    where p.owner_user_id=(select auth.uid()) and p.status='approved') as partner_owner,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='manager') as partner_manager,
  exists(select 1 from public.partner_members m
    join public.partners p on p.id=m.partner_id
    where m.user_id=(select auth.uid()) and m.is_active and p.status='approved'
      and m.member_role='validator') as partner_validator,
  coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as mfa_verified,
  coalesce(s.staff_role='admin' and s.is_active,false)
    and coalesce((select auth.jwt()->>'aal'),'aal1')='aal2' as admin_console_ready
from (select 1) base
left join public.staff_members s
  on s.user_id=(select auth.uid())
where (select auth.uid()) is not null;
$$;

revoke all on function public.my_access_context()
from public,anon,authenticated;
grant execute on function public.my_access_context() to authenticated;

comment on function private.grant_first_administrator(text)
is 'One-time manual bootstrap; verified email required. Not executable via API, service_role, anon, or authenticated.';

comment on function public.my_access_context()
is 'Reads the current session access status without assigning roles. admin_console_ready requires MFA aal2, and privileged backend operations must verify MFA independently.';
;
