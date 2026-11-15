-- Transactional integration test against the installed migration.
-- Uses an existing admin session only inside privileged SQL; never mints tokens.
-- ALL test content and membership events roll back, including on failed assertions.
begin;
do $$
<<test_map_content>>
declare actor uuid; sid uuid; result jsonb; doc jsonb; preview jsonb; old jsonb; request uuid;
 id text:='map-integration-'||gen_random_uuid()::text; denied boolean; original_claims text;
begin
 select s.user_id,s.id into actor,sid from auth.sessions s join public.staff_members m on m.user_id=s.user_id
 where m.staff_role='admin' and m.is_active and (s.not_after is null or s.not_after>now()) limit 1;
 if actor is null then raise exception 'A live admin session is required for this transactional test';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'session_id',sid,'aal','aal2','role','authenticated')::text,true);
 result:=public.map_content_command('access');
 if result->>'role'<>'admin' or (result->>'ready')::boolean is not true then raise exception 'Admin access failed';end if;
 doc:=jsonb_build_object('id',id,'name','Ponto de teste transacional','description','Não publicado fora desta transação','municipalityId','2111300','city','São Luís','lat',-2.53,'lng',-44.30,'cat','culture','referenceLocation',true,'googlePlaceId','google_test_place_id_12345');
 request:=gen_random_uuid();
 result:=public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',0,'request_id',request,'reason','Teste de integração'));
 old:=public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',0,'request_id',request,'reason','Teste de integração'));
 if old is distinct from result or (result->>'revision')::integer<>1 then raise exception 'Idempotency failed';end if;
 if exists(select 1 from public.map_publications where map_publications.id=test_map_content.id) then raise exception 'Draft leaked';end if;
 denied:=false;
 begin perform public.map_content_command('save',jsonb_build_object('id',id,'content',doc||jsonb_build_object('googlePlaceId','https://invalid.example/place'),'kind','attraction','expected_revision',1,'request_id',gen_random_uuid(),'reason','Rejeitar identificador inválido'));exception when others then denied:=true;end;
 if not denied then raise exception 'Invalid Google place ID accepted';end if;

 denied:=false;
 begin perform public.map_content_command('publish',jsonb_build_object('id',id,'expected_revision',1,'request_id',gen_random_uuid(),'reason','Teste sem prévia'));exception when others then denied:=true;end;
 if not denied then raise exception 'Publish without preview allowed';end if;
 preview:=public.map_content_command('preview',jsonb_build_object('id',id));
 result:=public.map_content_command('publish',jsonb_build_object('id',id,'expected_revision',1,'preview_id',preview->>'preview_id','request_id',gen_random_uuid(),'reason','Primeira publicação de teste'));
 if (result->>'revision')::integer<>2 or not exists(select 1 from public.map_publications p where p.id=test_map_content.id and p.is_visible) then raise exception 'Publish failed';end if;
 if (select content->>'googlePlaceId' from public.map_publications p where p.id=test_map_content.id)<>'google_test_place_id_12345' then raise exception 'Google ID missing from publication';end if;
 doc:=doc||jsonb_build_object('name','Ponto atualizado no computador');
 result:=public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',2,'request_id',gen_random_uuid(),'reason','Editar nome no computador'));
 if (select content->>'name' from public.map_publications p where p.id=test_map_content.id)<>'Ponto de teste transacional' then raise exception 'Unpublished edit leaked';end if;
 denied:=false;
 begin perform public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',2,'request_id',gen_random_uuid(),'reason','Conflito de edição'));exception when sqlstate '40001' then denied:=true;end;
 if not denied then raise exception 'Stale save allowed';end if;
 denied:=false;
 begin perform public.map_content_command('publish',jsonb_build_object('id',id,'expected_revision',3,'preview_id',preview->>'preview_id','request_id',gen_random_uuid(),'reason','Prévia vencida por edição'));exception when others then denied:=true;end;
 if not denied then raise exception 'Old preview allowed';end if;
 preview:=public.map_content_command('preview',jsonb_build_object('id',id));
 result:=public.map_content_command('publish',jsonb_build_object('id',id,'expected_revision',3,'preview_id',preview->>'preview_id','request_id',gen_random_uuid(),'reason','Segunda publicação de teste'));
 if (select content->>'name' from public.map_publications p where p.id=test_map_content.id)<>'Ponto atualizado no computador' then raise exception 'Public reader did not update';end if;
 result:=public.map_content_command('restore',jsonb_build_object('id',id,'expected_revision',4,'restore_revision',2,'request_id',gen_random_uuid(),'reason','Restaurar primeira publicação'));
 if result->'content'->>'name'<>'Ponto de teste transacional' or result->>'status'<>'draft' then raise exception 'Restore failed';end if;
 if (select content->>'name' from public.map_publications p where p.id=test_map_content.id)<>'Ponto atualizado no computador' then raise exception 'Restore changed live version';end if;
 result:=public.map_content_command('history',jsonb_build_object('id',id));
 if jsonb_array_length(result)<>5 then raise exception 'History incomplete';end if;
 result:=public.map_content_command('archive',jsonb_build_object('id',id,'expected_revision',5,'request_id',gen_random_uuid(),'reason','Arquivar registro de teste'));
 if not exists(select 1 from public.map_publications p where p.id=test_map_content.id and not p.is_visible and p.content is null) then raise exception 'Archive tombstone missing';end if;
 -- An active ordinary member is still constrained by scope and MFA.
 result:=public.map_content_command('grant',jsonb_build_object('user_id',actor,'role','editor','municipalities',jsonb_build_array('2111300'),'active',true,'expected_updated_at',null,'request_id',gen_random_uuid(),'reason','Atribuir editor para teste'));
 old:=result;
 update public.staff_members set is_active=false where user_id=actor;
 denied:=false;doc:=doc||jsonb_build_object('municipalityId','2101700');
 begin perform public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',6,'request_id',gen_random_uuid(),'reason','Tentativa fora do território'));exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'Scope bypass';end if;
 denied:=false;
 begin perform public.map_content_command('archive',jsonb_build_object('id',id,'expected_revision',6,'request_id',gen_random_uuid(),'reason','Editor tenta arquivar'));exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'Editor published or archived';end if;
 doc:=doc||jsonb_build_object('municipalityId','2111300');
 result:=public.map_content_command('save',jsonb_build_object('id',id,'content',doc,'kind','attraction','expected_revision',6,'request_id',gen_random_uuid(),'reason','Editor cria revisão permitida'));
 result:=public.map_content_command('submit',jsonb_build_object('id',id,'expected_revision',7,'request_id',gen_random_uuid(),'reason','Editor envia para revisão'));
 update public.staff_members set is_active=true where user_id=actor;
 result:=public.map_content_command('grant',jsonb_build_object('user_id',actor,'role','reviewer','municipalities',jsonb_build_array('2111300'),'active',true,'expected_updated_at',old->>'updated_at','request_id',gen_random_uuid(),'reason','Atribuir revisor para teste'));
 old:=result;
 update public.staff_members set is_active=false where user_id=actor;
 preview:=public.map_content_command('preview',jsonb_build_object('id',id));
 result:=public.map_content_command('publish',jsonb_build_object('id',id,'expected_revision',8,'preview_id',preview->>'preview_id','request_id',gen_random_uuid(),'reason','Revisor publica versão revisada'));
 if result->>'status'<>'published' then raise exception 'Reviewer publication failed';end if;
 update public.staff_members set is_active=true where user_id=actor;
 result:=public.map_content_command('grant',jsonb_build_object('user_id',actor,'role','reviewer','municipalities',jsonb_build_array('2111300'),'active',false,'expected_updated_at',old->>'updated_at','request_id',gen_random_uuid(),'reason','Revogar revisor para teste'));
 update public.staff_members set is_active=false where user_id=actor;
 denied:=false;
 begin perform public.map_content_command('get',jsonb_build_object('id',id));exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'Revoked role still authorized';end if;
 update public.staff_members set is_active=true where user_id=actor;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'session_id',sid,'aal','aal1','role','authenticated')::text,true);
 denied:=false;
 begin perform public.map_content_command('get',jsonb_build_object('id',id));exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'MFA bypass';end if;
 perform set_config('request.jwt.claims','{}',true);
 denied:=false;
 begin perform public.map_content_command('get',jsonb_build_object('id',id));exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'Unauthenticated access';end if;
end $$;
select 'All editorial workflow integration assertions passed; test records rolled back.' as result;
rollback;
