-- Run with psql -v ON_ERROR_STOP=1 against a disposable migrated test copy.
-- All test writes roll back. No pgTAP extension required.
begin;
create function pg_temp.assert(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
select pg_temp.assert(not exists(
 select 1 from public.debts d where d.paid_amount<>(select coalesce(sum(p.amount),0) from public.debt_payments p where p.debt_id=d.id and not p.deleted)
),'backfilled history equals existing paid_amount');
select pg_temp.assert(not exists(select 1 from public.debt_payments where is_legacy and (record_transaction or transaction_id is not null)),'legacy backfill creates no cash movement');
insert into auth.users(id,email) values('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','offline-a@test.invalid'),('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','offline-b@test.invalid');
set local request.jwt.claim.sub='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
set local role authenticated;
do $$
declare r jsonb; replay jsonb; c bigint; w uuid; tx uuid; p uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); op uuid:=gen_random_uuid(); n uuid;
begin
 select id into w from public.wallets limit 1;
 perform pg_temp.assert((public.consume_ai_quota('chat')->>'allowed')::boolean,'quota RPC remains available outside sync');
 r:=public.sync_push(op,'debts',d,0,'{"person_name":"Test","type":"borrow","amount":1000}',false);
 perform pg_temp.assert(r->>'status'='applied','create debt');
 replay:=public.sync_push(op,'debts',d,0,'{"person_name":"Test","type":"borrow","amount":1000}',false);
 perform pg_temp.assert(replay=r,'exact idempotent replay');
 begin
 perform public.sync_push(op,'debts',d,0,'{}',false); raise exception 'expected idempotency error';
 exception when invalid_parameter_value then null; end;
 r:=public.sync_push(gen_random_uuid(),'debts',d,0,'{}',false);
 perform pg_temp.assert(r->>'status'='conflict','stale version conflict');
 -- Supplied linkage cannot hijack or tombstone an unrelated transaction.
 begin
 perform public.sync_push(gen_random_uuid(),'debt_payments',gen_random_uuid(),0,jsonb_build_object('debt_id',d,'amount',1,'transaction_id',gen_random_uuid()),false);
 raise exception 'expected unrecorded linkage denial'; exception when raise_exception then
 if sqlerrm='expected unrecorded linkage denial' then raise; end if; end;
 tx:=gen_random_uuid();
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,0,jsonb_build_object('debt_id',d,'amount',300,'paid_at','2026-10-28T00:00:00Z','record_transaction',true,'wallet_id',w,'transaction_id',tx),false);
 perform pg_temp.assert((select paid_amount=300 from public.debts where id=d),'payment recalc');
 perform pg_temp.assert((select amount=300 and type='expense' from public.transactions where id=tx),'linked transaction');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,1,'{"amount":400}',false);
 perform pg_temp.assert((select paid_amount=400 from public.debts where id=d),'payment edit');
 begin
 perform public.sync_push(gen_random_uuid(),'debt_payments',gen_random_uuid(),0,jsonb_build_object('debt_id',d,'amount',900),false);
 raise exception 'expected overpayment failure'; exception when invalid_parameter_value then null; end;
 perform pg_temp.assert((select paid_amount=400 from public.debts where id=d),'overpayment rollback');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,2,'{}',true);
 perform pg_temp.assert((select paid_amount=0 and status='active' from public.debts where id=d),'undo recalc');
 perform pg_temp.assert(not exists(select 1 from public.transactions where id=tx),'undo hides linked transaction');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,3,'{}',false);
 perform pg_temp.assert((select paid_amount=400 from public.debts where id=d),'restore payment');
 perform pg_temp.assert((select amount=400 from public.transactions where id=tx),'restore linked transaction');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,4,'{}',true);
 r:=public.sync_pull(0,1); c:=(r->>'cursor')::bigint;
 perform pg_temp.assert(jsonb_array_length(r->'changes')=1 and (r->>'has_more')::boolean,'pagination');
 r:=public.sync_pull(c,5000);
 perform pg_temp.assert(exists(select 1 from jsonb_array_elements(r->'changes') x where x->>'id'=tx::text and (x->>'deleted')::boolean),'transaction tombstone in journal');
 perform pg_temp.assert(not exists(select 1 from jsonb_array_elements(r->'changes') x where x->'row'->>'user_id'<>'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),'owner scoped pull');
 begin
 perform public.sync_push(gen_random_uuid(),'wallets',gen_random_uuid(),0,'{"name":"Bad","user_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}',false);
 raise exception 'expected owner protection'; exception when insufficient_privilege then null; end;
 begin
 insert into public.wallets(name) values('Bypass'); raise exception 'expected direct write protection'; exception when insufficient_privilege then null; end;
 perform public.settle_debt(d,100,false,null);
 perform pg_temp.assert((select paid_amount=100 from public.debts where id=d),'legacy RPC creates history');
 begin
 perform public.sync_push(gen_random_uuid(),'notifications',gen_random_uuid(),0,'{"is_read":true}',false);
 raise exception 'expected notification create denial'; exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into public.notifications(id,user_id,type,title,message) values('cccccccc-cccc-cccc-cccc-cccccccccccc','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','system','Server title','Server message');
set local role authenticated;
do $$ declare r jsonb; begin
 r:=public.sync_push(gen_random_uuid(),'notifications','cccccccc-cccc-cccc-cccc-cccccccccccc',1,'{"id":"cccccccc-cccc-cccc-cccc-cccccccccccc","title":"forged","is_read":true}',false);
 perform pg_temp.assert((select is_read and title='Server title' from public.notifications where id='cccccccc-cccc-cccc-cccc-cccccccccccc'),'notifications full cached payload only updates is_read');
end $$;
reset role;
set local request.jwt.claim.sub='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
set local role authenticated;
select pg_temp.assert(not exists(select 1 from public.debts where person_name='Test'),'RLS cross owner');
select pg_temp.assert(not exists(select 1 from jsonb_array_elements(public.sync_pull(0,5000)->'changes') x where x->'row'->>'user_id'<>'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'journal cross owner');
reset role;
set local request.jwt.claim.sub='';
do $$ begin
 begin perform public.sync_pull(0); raise exception 'expected auth failure'; exception when insufficient_privilege then null; end;
end $$;
rollback;



