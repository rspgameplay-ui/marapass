-- Executar no projeto de homologação após configurar a Edge Function e o Vault.
-- Os segredos abaixo são nomes de entradas no Vault. O comando agendado contém apenas seus nomes.
do $$
begin
  if not exists(select 1 from pg_extension where extname='pg_cron')
     or not exists(select 1 from pg_extension where extname='pg_net') then
    raise exception 'Habilite pg_cron e pg_net no projeto de destino.'; end if;
  if (select count(*) from vault.decrypted_secrets where name in ('coupon_dispatch_url','coupon_worker_secret')
      and nullif(decrypted_secret,'') is not null)<>2 then
    raise exception 'Configure coupon_dispatch_url e coupon_worker_secret no Vault.'; end if;
end $$;
select cron.schedule('marapass-coupon-whatsapp','* * * * *',$job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='coupon_dispatch_url'),
    headers := jsonb_build_object('Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='coupon_worker_secret'),
                                  'Content-Type','application/json'),
    body := '{}'::jsonb, timeout_milliseconds := 120000)
$job$);
