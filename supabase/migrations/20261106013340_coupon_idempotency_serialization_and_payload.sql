do $patch$
declare d text;
begin
 d := pg_get_functiondef('public.issue_coupon(uuid,uuid,text,uuid)'::regprocedure);
 d := replace(d,'if p_user_id is null or length(p_idempotency_key) not between 16 and 180 then','if p_user_id is null or length(coalesce(p_idempotency_key, '''')) not between 16 and 180 then');
 d := replace(d,'  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;', E'  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''coupon-issue:'' || p_idempotency_key, 0));\n  select * into v_old from public.coupon_instances where issuance_key=p_idempotency_key;');
 execute d;
 d := pg_get_functiondef('public.redeem_coupon(uuid,uuid,text,integer)'::regprocedure);
 d := replace(d,'if p_validator_user_id is null or length(p_idempotency_key) not between 16 and 180','if p_validator_user_id is null or length(coalesce(p_idempotency_key, '''')) not between 16 and 180');
 d := replace(d,'  select * into v_old from public.coupon_redemptions where idempotency_key=p_idempotency_key;', E'  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''coupon-redeem:'' || p_idempotency_key, 0));\n  select * into v_old from public.coupon_redemptions where idempotency_key=p_idempotency_key;');
 d := replace(d,'or v_old.validated_by_user_id<>p_validator_user_id then',E'or v_old.validated_by_user_id<>p_validator_user_id\n      or v_old.transaction_amount_cents is distinct from p_transaction_amount_cents then');
 execute d;
end $patch$;;
