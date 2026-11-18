begin;
create table private.mvp_wa_consent (
  user_id uuid primary key references auth.users(id) on delete cascade, phone text not null,
  enabled boolean not null, changed_at timestamptz not null default now()
);
create table private.mvp_wa_permissions (
  id bigint generated always as identity primary key, user_id uuid,
  enabled boolean not null, source text not null, version text not null default 'cupom-v1', at timestamptz not null default now()
);
create table private.mvp_wa_queue (
  id uuid primary key default gen_random_uuid(), coupon_id uuid not null references public.mvp_coupons(id) on delete restrict,
  user_id uuid, audience text not null check(audience in ('tourist','partner')),
  event text not null check(event in ('issued','converted')), consent_at timestamptz not null, state text not null default 'queued',
  attempts int not null default 0, next_at timestamptz not null default now(), lease uuid, lease_until timestamptz,
  provider_id text, last_error text, unique(coupon_id,event,audience)
);
create index mvp_wa_ready on private.mvp_wa_queue(next_at) where state in ('queued','sending','retry');
create table private.mvp_wa_callbacks (
  message_id text not null, status text not null, at timestamptz not null default now(), primary key(message_id,status)
);
alter table private.mvp_wa_consent enable row level security;
alter table private.mvp_wa_permissions enable row level security;
alter table private.mvp_wa_queue enable row level security;
alter table private.mvp_wa_callbacks enable row level security;
revoke all on private.mvp_wa_consent,private.mvp_wa_permissions,private.mvp_wa_queue,private.mvp_wa_callbacks from public,anon,authenticated;

create function private.mvp_forget_wa_contact() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update private.mvp_wa_queue set user_id=null,state=case when state in ('queued','retry','sending') then 'skipped' else state end,
    lease=null,lease_until=null where user_id=old.id;
  update private.mvp_wa_permissions set user_id=null where user_id=old.id;
  return old;
end $$;
create trigger mvp_forget_wa_contact before delete on auth.users for each row execute function private.mvp_forget_wa_contact();
revoke all on function private.mvp_forget_wa_contact() from public,anon,authenticated;
create function public.mvp_wa_opt(p_enabled boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=public.mvp_require_user(); number text;
begin
  if p_enabled is null then raise exception 'Informe a preferência.'; end if;
  if p_enabled then
    select ltrim(phone,'+') into number from auth.users where id=u and phone_confirmed_at is not null;
    if number is null or number !~ '^[1-9][0-9]{7,14}$' then raise exception 'Confirme o telefone antes de autorizar.'; end if;
    insert into private.mvp_wa_consent(user_id,phone,enabled) values(u,number,true)
      on conflict(user_id) do update set phone=excluded.phone,enabled=true,changed_at=clock_timestamp()
      where not mvp_wa_consent.enabled or mvp_wa_consent.phone<>excluded.phone;
  else
    update private.mvp_wa_consent set enabled=false,changed_at=clock_timestamp() where user_id=u and enabled;
  end if;
  if found then insert into private.mvp_wa_permissions(user_id,enabled,source) values(u,p_enabled,'app'); end if;
  return p_enabled;
end $$;
create function public.mvp_wa_preference() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.mvp_wa_consent w join auth.users u on u.id=w.user_id
    where u.id=public.mvp_require_user() and w.enabled and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone)
$$;
create function private.mvp_queue_coupon() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.sale is not null then
    insert into private.mvp_wa_queue(coupon_id,user_id,audience,consent_at,event)
      select new.id,x.uid,x.role,w.changed_at,case when tg_op='INSERT' then 'issued' else 'converted' end from (values(new.user_id,'tourist'),((new.sale->>'owner')::uuid,'partner')) x(uid,role)
      join private.mvp_wa_consent w on w.user_id=x.uid and w.enabled
      join auth.users u on u.id=x.uid and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone;
  end if;
  return new;
end $$;
create trigger mvp_queue_coupon after insert on public.mvp_coupons for each row execute function private.mvp_queue_coupon();

create trigger mvp_queue_conversion after update of used_at on public.mvp_coupons for each row
when (old.used_at is null and new.used_at is not null) execute function private.mvp_queue_coupon();
create function public.mvp_wa_claim() returns jsonb language plpgsql security definer set search_path='' as $$
declare job private.mvp_wa_queue; number text; c public.mvp_coupons; jobs jsonb:='[]';
begin
  for job in select * from private.mvp_wa_queue where state in ('queued','retry','sending') and next_at<=now()
    and (lease_until is null or lease_until<now()) order by next_at limit 10 for update skip locked loop
    select w.phone into number from private.mvp_wa_consent w join auth.users u on u.id=w.user_id
      where w.user_id=job.user_id and w.enabled and w.changed_at=job.consent_at
      and u.phone_confirmed_at is not null and ltrim(u.phone,'+')=w.phone;
    select * into c from public.mvp_coupons where id=job.coupon_id;
    if number is null or (job.audience='partner' and not exists(select 1 from public.mvp_partner_members where user_id=job.user_id))
       or (job.event='issued' and (now()>=(c.sale->>'expires')::timestamptz or c.used_at is not null or c.sale_stage in ('cancelled','declined'))) then
      update private.mvp_wa_queue set state='skipped',lease=null,lease_until=null where id=job.id;
    elsif job.attempts>=6 then
      update private.mvp_wa_queue set state='failed',lease=null,lease_until=null where id=job.id;
    else
      update private.mvp_wa_queue set state='sending',lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',attempts=attempts+1
        where id=job.id returning * into job;
      jobs:=jobs||jsonb_build_array(jsonb_build_object('id',job.id,'lease',job.lease,'to',number,'role',job.audience,'event',job.event,
        'title',c.sale->>'title','due',c.sale->'due','code',c.code));
    end if;
  end loop;
  return jobs;
end $$;

create function public.mvp_wa_finish(p_id uuid,p_lease uuid,p_status text,p_provider text,p_error text) returns void
language sql security definer set search_path='' as $$
  update private.mvp_wa_queue set state=case when p_status='accepted' then 'accepted'
    when p_status='retry' and attempts<6 then 'retry' else 'failed' end,
    provider_id=coalesce(p_provider,provider_id), last_error=left(p_error,100),
    next_at=now()+make_interval(secs=>least(3600,30*(2^attempts)::integer)),lease=null,lease_until=null
    where id=p_id and lease=p_lease and state='sending'
$$;
create function public.mvp_wa_callback(p_id uuid,p_message text,p_status text,p_retry boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare job private.mvp_wa_queue;
begin
  if p_status not in ('sent','delivered','read','failed') or p_message is null then return; end if;
  select * into job from private.mvp_wa_queue where id=p_id or (p_id is null and provider_id=p_message) for update;
  if not found then return; end if;
  insert into private.mvp_wa_callbacks(message_id,status) values(p_message,p_status) on conflict do nothing;
  if not found then return; end if;
  if job.state='read' or (job.state='delivered' and p_status<>'read') then return; end if;
  if p_status='failed' and (job.provider_id is not null and job.provider_id<>p_message or job.state in ('retry','skipped','failed')) then return; end if;
  update private.mvp_wa_queue set state=case when p_status='failed' and p_retry and attempts<6 then 'retry' else p_status end,
    last_error=case when p_status='failed' then 'meta_delivery' end,provider_id=p_message,
    next_at=now()+make_interval(secs=>least(3600,30*(2^attempts)::integer)),lease=null,lease_until=null where id=job.id;
end $$;
create function public.mvp_wa_stop(p_phone text,p_message text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid;
begin
  insert into private.mvp_wa_callbacks(message_id,status) values(p_message,'stop') on conflict do nothing;
  if not found then return; end if;
  for u in update private.mvp_wa_consent set enabled=false,changed_at=clock_timestamp() where enabled and phone=p_phone returning user_id loop
    insert into private.mvp_wa_permissions(user_id,enabled,source) values(u,false,'whatsapp');
  end loop;
end $$;
create function public.mvp_coupon_deliveries(p_code text,p_scope text) returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare receipt jsonb;
begin
  select * into receipt from public.mvp_coupon_statement(p_scope,p_code);
  return query select jsonb_build_object('audience',audience,'event',event,'state',state,'attempts',attempts) from private.mvp_wa_queue
    where coupon_id=(receipt->>'id')::uuid and (p_scope='admin' or audience=p_scope);
end $$;
do $$ declare f regprocedure; begin
  for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in
    ('mvp_wa_opt','mvp_wa_preference','mvp_coupon_deliveries','mvp_wa_claim','mvp_wa_finish','mvp_wa_callback','mvp_wa_stop') loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
    if f::text ~ '(mvp_wa_opt|mvp_wa_preference|mvp_coupon_deliveries)' then
      execute format('grant execute on function %s to authenticated',f);
    else execute format('grant execute on function %s to service_role',f); end if;
  end loop;
end $$;
revoke all on function private.mvp_queue_coupon() from public,anon,authenticated;
commit;
