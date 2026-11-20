-- Extend only the editorial category allowlist. Preserve function body, ACL and search_path.
do $migration$
declare definition text;
begin
 definition := pg_get_functiondef('private.map_command(text,jsonb)'::regprocedure);
 if position('''residential''' in definition)>0 then return; end if;
 if position('''crafts'',''photography'',''tourist_transport''' in definition)=0 then raise exception 'Unexpected category validation; no change applied.'; end if;
 execute replace(definition,'''crafts'',''photography'',''tourist_transport''','''crafts'',''photography'',''residential'',''tourist_transport''');
end $migration$;;
