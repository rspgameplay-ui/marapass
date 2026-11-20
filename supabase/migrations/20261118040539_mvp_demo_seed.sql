-- Dados de exemplo para demonstração. Tudo marcado com "(exemplo)" e ligado ao
-- parceiro fixo 00000000-0000-4000-8000-0000000000de para remoção fácil:
--   delete from public.partners where id = '00000000-0000-4000-8000-0000000000de';
-- (as experiências, horários e ofertas caem em cascata pelo estabelecimento)

insert into public.partners (id, legal_name, trade_name, status)
values ('00000000-0000-4000-8000-0000000000de', 'Parceiro Exemplo Marapass', 'Parceiro Exemplo', 'approved')
on conflict (id) do nothing;

insert into public.establishments (id, partner_id, name, description, category, city, state_code, is_active, is_public)
values
 ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000de', 'Lençóis Tur (exemplo)', 'Agência de passeios nos Lençóis Maranhenses.', 'tours', 'Barreirinhas', 'MA', true, true),
 ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000de', 'Sabor da Ilha (exemplo)', 'Culinária maranhense no centro histórico.', 'gastronomy', 'São Luís', 'MA', true, true)
on conflict (id) do nothing;

insert into public.experiences (id, establishment_id, title, description, category, price_from_cents, duration_minutes, capacity, booking_required, status)
values
 ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000e1', 'Circuito Lagoa Azul (exemplo)', 'Passeio de 4x4 às lagoas com parada para banho.', 'tours', 15000, 240, 12, true, 'published'),
 ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000e1', 'Pôr do sol nas dunas (exemplo)', 'Caminhada guiada ao entardecer.', 'nature', 9000, 150, 15, true, 'published'),
 ('00000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000e2', 'Degustação de arroz de cuxá (exemplo)', 'Menu degustação com pratos típicos.', 'gastronomy', 6000, 90, 20, false, 'published')
on conflict (id) do nothing;

insert into public.experience_slots (experience_id, starts_at, ends_at, capacity)
select e.id, d + time '08:00', d + time '08:00' + make_interval(mins => e.duration_minutes), e.capacity
from public.experiences e
cross join generate_series(current_date + 1, current_date + 14, interval '1 day') d
where e.id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2')
  and not exists (select 1 from public.experience_slots s where s.experience_id = e.id);

insert into public.offers (id, establishment_id, experience_id, title, description, discount_type, discount_value,
  max_issuances, per_user_limit, is_published, access_scope, eligible_items, calculation_base,
  issue_until, convert_until, use_until)
values
 ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1',
  '10% no Circuito Lagoa Azul (exemplo)', 'Desconto para quem tem o app.', 'percent', 10, 200, 1, true, 'public',
  'Circuito Lagoa Azul', 'Valor do passeio por pessoa', now() + interval '60 days', now() + interval '75 days', now() + interval '90 days'),
 ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a3',
  'R$ 15 na degustação (exemplo)', 'Válido para portadores do passaporte.', 'fixed', 15, 100, 1, true, 'passport',
  'Degustação de arroz de cuxá', 'Valor total da conta', now() + interval '60 days', now() + interval '75 days', now() + interval '90 days')
on conflict (id) do nothing;

-- Passaporte criado como rascunho (não publicado): a publicação passa pelo fluxo
-- de aprovação comercial e não deve ser automática.
insert into public.passport_products (id, name, description, price_cents, currency, validity_start_rule,
  duration_days, activation_deadline_days, booking_explanation, included_benefits_explanation, is_published)
values ('00000000-0000-4000-8000-0000000000b1', 'Passaporte Lençóis 7 dias (exemplo)',
  'Passaporte de exemplo com benefícios em parceiros de Barreirinhas e São Luís.', 4990, 'BRL', 'activation',
  7, 30, 'Passeios com horário exigem reserva pelo app.', 'Inclui o desconto na degustação.', false)
on conflict (id) do nothing;

insert into public.passport_product_benefits (product_id, offer_id, issue_window_days, convert_window_days, use_window_days, max_per_holder, booking_required)
select '00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000f2', 7, 7, 7, 1, false
where not exists (select 1 from public.passport_product_benefits where product_id = '00000000-0000-4000-8000-0000000000b1');
