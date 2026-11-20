create or replace function public.mvp_activate_coupon(p_cupom_key text) returns public.mvp_coupons
language plpgsql security definer set search_path = public as $$
declare uid uuid := public.mvp_require_user(); r public.mvp_coupons; c text; tries int := 0;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if p_cupom_key is null or length(p_cupom_key) not between 1 and 40 then
    raise exception 'invalid coupon' using errcode = '22023';
  end if;
  select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
  if found then return r; end if;
  loop
    tries := tries + 1;
    c := 'MP-' || (select string_agg(substr(alphabet, 1 + (get_byte(b, i) % 32), 1), '')
                   from (select extensions.gen_random_bytes(4) b) x, generate_series(0, 3) i);
    begin
      insert into public.mvp_coupons (user_id, cupom_key, code) values (uid, p_cupom_key, c) returning * into r;
      return r;
    exception when unique_violation then
      select * into r from public.mvp_coupons where user_id = uid and cupom_key = p_cupom_key and used_at is null;
      if found then return r; end if;
      if tries > 8 then raise; end if;
    end;
  end loop;
end $$;;
