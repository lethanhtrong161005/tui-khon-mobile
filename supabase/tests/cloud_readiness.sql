-- Run in the intended project's SQL Editor (administrator).
-- All fixture users, trigger data and sync operations roll back together.
-- Does not send email, call AI, or modify any existing account.
begin;
do $cloud$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  tx uuid := gen_random_uuid();
  op uuid := gen_random_uuid();
  wallet uuid;
  category uuid;
  payload jsonb;
  first_reply jsonb;
  replay jsonb;
  pulled jsonb;
begin
  insert into auth.users(id,email,raw_user_meta_data)
    values (a,'cloud-qa-'||a||'@example.invalid','{"display_name":"Cloud QA A"}'),
           (b,'cloud-qa-'||b||'@example.invalid','{"display_name":"Cloud QA B"}');
  if not exists(select 1 from public.profiles where id=a) then
    raise exception 'Profile bootstrap failed';
  end if;
  select id into wallet from public.wallets where user_id=a and not deleted limit 1;
  select id into category from public.categories where user_id=a and type='expense' and not deleted limit 1;
  if wallet is null or category is null then raise exception 'Notebook bootstrap failed'; end if;
  payload := jsonb_build_object('type','expense','amount',65000,
    'wallet_id',wallet,'category_id',category,'note','Cloud QA rollback',
    'source','manual','occurred_at',now());

  set local role authenticated;
  perform set_config('request.jwt.claim.sub',a::text,true);
  first_reply := public.sync_push(op,'transactions',tx,0,payload,false);
  if first_reply->>'status' <> 'applied' then raise exception 'Push failed: %',first_reply; end if;
  replay := public.sync_push(op,'transactions',tx,0,payload,false);
  if replay <> first_reply then raise exception 'Replay changed the response'; end if;
  if (select count(*) from public.transactions where id=tx) <> 1 then
    raise exception 'Retry duplicated the transaction';
  end if;
  begin
    insert into public.transactions(id,user_id,type,amount,wallet_id,occurred_at)
      values(gen_random_uuid(),a,'expense',1,wallet,now());
    raise exception 'Direct writes unexpectedly permitted';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',b::text,true);
  if exists(select 1 from public.transactions where id=tx) then
    raise exception 'RLS exposed another account transaction';
  end if;
  pulled := public.sync_pull(0,500);
  if exists(select 1 from jsonb_array_elements(pulled->'changes') c
    where c->>'id'=tx::text) then raise exception 'Pull leaked another account'; end if;

  perform set_config('request.jwt.claim.sub',a::text,true);
  pulled := public.sync_pull(0,500);
  if not exists(select 1 from jsonb_array_elements(pulled->'changes') c
    where c->>'id'=tx::text) then raise exception 'Pull omitted own transaction'; end if;
  replay := public.sync_push(gen_random_uuid(),'transactions',tx,
    (first_reply->>'version')::bigint,payload||'{"amount":70000}'::jsonb,false);
  if replay->>'status' <> 'applied' then raise exception 'Edit failed'; end if;
  first_reply := public.sync_push(gen_random_uuid(),'transactions',tx,
    (replay->>'version')::bigint,payload||'{"amount":80000}'::jsonb,false);
  replay := public.sync_push(gen_random_uuid(),'transactions',tx,
    (replay->>'version')::bigint,payload||'{"amount":90000}'::jsonb,false);
  if replay->>'status' <> 'conflict' then raise exception 'Stale-device conflict missing'; end if;
  replay := public.sync_push(gen_random_uuid(),'transactions',tx,
    (first_reply->>'version')::bigint,'{}'::jsonb,true);
  if replay->>'status' <> 'applied' then raise exception 'Tombstone failed'; end if;
  reset role;
end;
$cloud$;
rollback;
select 'PASS cloud bootstrap, RLS, RPC push/pull, replay, edit, conflict and tombstone (rolled back)' as result;
