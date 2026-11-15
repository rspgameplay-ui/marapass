-- PROPOSTA — NÃO APLICADA. Revisar antes de rodar em qualquer projeto Supabase.
--
-- Exclusão de conta pelo próprio usuário (exigência da Apple/Google e da LGPD).
-- O app chama `rpc('delete_my_account')` e, se a função não existir, mostra uma
-- mensagem orientando o contato com o suporte.
--
-- Decisões que o time precisa confirmar antes de aplicar:
--   1. Cupons e pedidos: apagar ou anonimizar? (relatórios financeiros e
--      prestação de contas ao parceiro podem exigir retenção por prazo legal).
--   2. Reservas: manter anonimizadas para o parceiro? Aqui o usuário é desvinculado.
--   3. Contas de parceiro/staff não podem se auto-excluir por este caminho.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if exists (select 1 from public.staff_members s where s.user_id = uid and s.is_active)
     or exists (select 1 from public.partner_members m where m.user_id = uid and m.is_active)
     or exists (select 1 from public.partners p where p.owner_user_id = uid) then
    raise exception 'partner and staff accounts must be removed by an administrator'
      using errcode = '42501';
  end if;

  delete from public.assistant_messages
    where conversation_id in (select id from public.assistant_conversations where user_id = uid);
  delete from public.assistant_conversations where user_id = uid;
  delete from public.profiles where id = uid;

  -- Remove o login. As tabelas que referenciam auth.users sem ON DELETE
  -- CASCADE (reservas, cupons, pedidos) precisam ser tratadas conforme a
  -- decisão 1 e 2 acima antes desta linha.
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
