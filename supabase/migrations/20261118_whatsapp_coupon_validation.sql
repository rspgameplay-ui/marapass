-- Validação de cupom pelo WhatsApp do parceiro (Edge Function `whatsapp-coupon`).
-- O restaurante manda "VALIDAR <código> <valor>" do número cadastrado aqui; a
-- função resolve o número para um usuário validador e chama redeem_coupon, que
-- continua sendo a única regra de negócio (permissão, validade, desconto).

create table if not exists public.partner_whatsapp_validators (
  phone_e164 text primary key check (phone_e164 ~ '^[0-9]{10,15}$'), -- só dígitos, com DDI (ex.: 5598999999999)
  user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.partner_whatsapp_validators enable row level security;
-- Sem policies: só o service_role (Edge Function) lê e escreve.
revoke all on public.partner_whatsapp_validators from public, anon, authenticated;

-- Busca o cupom emitido pelo código exibido ao turista.
create or replace function public.whatsapp_find_coupon(p_code text)
returns table (
  coupon_id uuid,
  offer_title text,
  status text,
  expires_at timestamptz,
  beneficiary_user_id uuid
)
language sql
security invoker
set search_path = ''
as $$
  select c.id, c.offer_title_snapshot, c.status, c.expires_at, c.beneficiary_user_id
  from public.coupon_instances c
  where c.display_code = upper(trim(p_code))
  limit 1
$$;
revoke all on function public.whatsapp_find_coupon(text) from public, anon, authenticated;
grant execute on function public.whatsapp_find_coupon(text) to service_role;

-- Telefone do turista (para o aviso de confirmação), se ele informou no perfil.
create or replace function public.whatsapp_customer_phone(p_user_id uuid)
returns text
language sql
security invoker
set search_path = ''
as $$
  select regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
  from public.profiles p
  where p.id = p_user_id
$$;
revoke all on function public.whatsapp_customer_phone(uuid) from public, anon, authenticated;
grant execute on function public.whatsapp_customer_phone(uuid) to service_role;

notify pgrst, 'reload schema';
