-- Corrige os avisos de desempenho do Supabase:
--  * auth_rls_initplan: auth.jwt() passa a ser chamado como (select auth.jwt()), avaliado uma vez por consulta.
--  * multiple_permissive_policies: a policy de leitura de admin (aal2) é fundida por OR na policy de leitura
--    existente; policies ALL de admin viram INSERT/UPDATE/DELETE; catálogos públicos ganham cópia só para anon
--    (o anon não tem acesso a staff_members, então a condição de admin só vale para authenticated).
--  * unindexed_foreign_keys: índices nas 12 FKs restantes.
-- O comportamento de acesso não muda.

do $$
declare
  admin_cond constant text := $a$((((select auth.jwt()) ->> 'aal') = 'aal2') and exists(select 1 from public.staff_members s
    where s.user_id = (select auth.uid()) and s.staff_role = 'admin' and s.is_active))$a$;
  r record; q text; w text; stmt text;
  -- (tabela, policy de leitura existente, policy de admin a remover, true = manter cópia anon)
  merges constant text[] := array[
    'coupon_instances|coupons_read_owner_or_partner|admin_read_coupon_instances_aal2|f',
    'establishments|establishments_authenticated|admin_read_establishments_aal2|f',
    'experiences|experiences_authenticated|admin_read_experiences_aal2|f',
    'offers|offers_authenticated|admin_read_offers_aal2|f',
    'partner_applications|partner_applications_read_own|admin_read_applications_aal2|f',
    'partners|partner_read_associated|admin_read_partners_aal2|f',
    'reservations|reservations_read_user_or_partner|admin_read_reservations_aal2|f',
    'municipalities|municipalities_public_read|municipalities_admin_manage|t',
    'pole_municipalities|pole_municipalities_public_read|pole_municipalities_admin_manage|t',
    'tourism_poles|tourism_poles_public_read|tourism_poles_admin_manage|t',
    'passport_products|mp_passports_public_catalog|mp_admin_read_all_passports|t',
    'passport_product_benefits|mp_passport_benefits_public_catalog|mp_admin_read_all_passport_benefits|t'];
  m text; p text[];
begin
  foreach m in array merges loop
    p := string_to_array(m, '|');
    select qual into q from pg_policies where schemaname='public' and tablename=p[1] and policyname=p[2];
    if q is null then raise exception 'Policy % não encontrada em %', p[2], p[1]; end if;
    if q like '%staff_members%' then continue; end if; -- já aplicada

    if p[4] = 't' then
      execute format('create policy %I on public.%I for select to anon using (%s)', p[2] || '_anon', p[1], q);
      execute format('alter policy %I on public.%I to authenticated', p[2], p[1]);
    end if;
    execute format('alter policy %I on public.%I using ((%s) or %s)', p[2], p[1], q, admin_cond);

    if p[3] like '%\_manage' then
      execute format('drop policy %I on public.%I', p[3], p[1]);
      execute format('create policy %I on public.%I for insert to authenticated with check (%s)', p[1] || '_admin_insert', p[1], admin_cond);
      execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)', p[1] || '_admin_update', p[1], admin_cond, admin_cond);
      execute format('create policy %I on public.%I for delete to authenticated using (%s)', p[1] || '_admin_delete', p[1], admin_cond);
    else
      execute format('drop policy %I on public.%I', p[3], p[1]);
    end if;
  end loop;

  -- Reescreve chamadas auth.jwt() soltas ou embrulhadas de forma que o linter não reconhece.
  for r in select tablename, policyname, qual, with_check from pg_policies
           where schemaname='public' and (coalesce(qual,'')||coalesce(with_check,'')) ~ 'auth\.jwt\(\)'
             and (coalesce(qual,'')||coalesce(with_check,'')) !~ '\(select auth\.jwt\(\)\)' loop
    q := r.qual; w := r.with_check;
    foreach stmt in array array['aal','is_anonymous'] loop
      q := replace(replace(q, format('( SELECT (auth.jwt() ->> %L::text))', stmt), format('((select auth.jwt()) ->> %L)', stmt)),
                   format('(auth.jwt() ->> %L::text)', stmt), format('((select auth.jwt()) ->> %L)', stmt));
      w := replace(replace(w, format('( SELECT (auth.jwt() ->> %L::text))', stmt), format('((select auth.jwt()) ->> %L)', stmt)),
                   format('(auth.jwt() ->> %L::text)', stmt), format('((select auth.jwt()) ->> %L)', stmt));
    end loop;
    if q is not null then execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q); end if;
    if w is not null then execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, w); end if;
  end loop;
end $$;

create index if not exists custom_offer_requests_offer_idx on private.custom_offer_requests(offer_id);
create index if not exists offer_creation_requests_offer_idx on private.offer_creation_requests(offer_id);
create index if not exists assistant_conversations_user_idx on public.assistant_conversations(user_id);
create index if not exists partner_invitations_accepted_by_idx on public.partner_invitations(accepted_by);
create index if not exists partner_invitations_requested_by_idx on public.partner_invitations(requested_by);
create index if not exists passport_incidents_entitlement_idx on public.passport_benefit_incidents(entitlement_id);
create index if not exists passport_incidents_offer_idx on public.passport_benefit_incidents(offer_id);
create index if not exists passport_incidents_reported_by_idx on public.passport_benefit_incidents(reported_by);
create index if not exists passport_cancellations_buyer_idx on public.passport_cancellation_requests(buyer_user_id);
create index if not exists passport_entitlements_product_idx on public.passport_entitlements(product_id);
create index if not exists passport_entitlements_user_idx on public.passport_entitlements(user_id);
create index if not exists passport_orders_product_idx on public.passport_orders(product_id);
