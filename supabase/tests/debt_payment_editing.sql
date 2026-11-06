-- Disposable engine / transaction only; no writes survive this test.
begin;
create function pg_temp.assert(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
insert into auth.users(id,email) values ('cccccccc-1111-2222-3333-444444444444','payment-editing@test.invalid');
set local request.jwt.claim.sub='cccccccc-1111-2222-3333-444444444444';
set local role authenticated;
do $$
declare d uuid:=gen_random_uuid(); p uuid:='11112222-3333-4444-5555-666677778888';
  t uuid:=md5('tuikhon:debt-payment:'||p::text)::uuid; w uuid; w2 uuid:=gen_random_uuid();
  op uuid:=gen_random_uuid(); r jsonb; replay jsonb; v bigint;
begin
 perform pg_temp.assert(t='7da29022-ac54-628b-d143-61cfd54937e3'::uuid,'cross-platform deterministic UUID');
 select id into w from public.wallets limit 1;
 perform public.sync_push(gen_random_uuid(),'wallets',w2,0,'{"name":"Second"}',false);
 perform public.sync_push(gen_random_uuid(),'debts',d,0,'{"type":"lend","person_name":"QA","amount":1000}',false);
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,0,jsonb_build_object('debt_id',d,'amount',300),false);
 -- Only deterministic, previously unused linkage may be attached on edit.
 begin
   perform public.sync_push(gen_random_uuid(),'debt_payments',p,1,jsonb_build_object('record_transaction',true,'transaction_id',gen_random_uuid(),'wallet_id',w),false);
   raise exception 'expected invalid linkage';
 exception when raise_exception then if sqlerrm='expected invalid linkage' then raise; end if; end;
 r:=public.sync_push(op,'debt_payments',p,1,jsonb_build_object('record_transaction',true,'transaction_id',t,'wallet_id',w,'note','  Edited note  '),false);
 replay:=public.sync_push(op,'debt_payments',p,1,jsonb_build_object('record_transaction',true,'transaction_id',t,'wallet_id',w,'note','  Edited note  '),false);
 perform pg_temp.assert(r=replay,'exact retry returns same result');
 perform pg_temp.assert((select amount=300 and type='income' and note='Edited note' from public.transactions where id=t),'first attachment derives income and trimmed note');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,1,'{"amount":301}',false);
 perform pg_temp.assert(r->>'status'='conflict','second device stale edit conflicts');
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,2,jsonb_build_object('amount',350,'wallet_id',w2,'paid_at','2026-10-24T02:30:00Z','note','Changed'),false);
 perform pg_temp.assert((select amount=350 and wallet_id=w2 and note='Changed' and occurred_at='2026-10-24T02:30:00Z' from public.transactions where id=t),'edit propagates all fields');
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,3,'{"record_transaction":false}',false);
 perform pg_temp.assert(not exists(select 1 from public.transactions where id=t),'off hides cash entry');
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,4,'{"record_transaction":true}',false);
 perform pg_temp.assert((select count(*)=1 from public.transactions where id=t),'on restores same ID exactly once');
 -- Retain an archived wallet for the original recording, but do not select it anew.
 select version into v from public.wallets where id=w2;
 perform public.sync_push(gen_random_uuid(),'wallets',w2,v,'{"is_archived":true}',false);
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,5,'{"note":"Retained archive"}',false);
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,6,'{"record_transaction":false}',false);
 begin
   perform public.sync_push(gen_random_uuid(),'debt_payments',p,7,'{"record_transaction":true}',false);
   raise exception 'expected archived denial';
 exception when raise_exception then if sqlerrm='expected archived denial' then raise; end if; end;
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,7,jsonb_build_object('record_transaction',true,'wallet_id',w,'note',''),false);
 perform pg_temp.assert((select note='Thu nợ từ QA' from public.transactions where id=t),'empty note falls back identically to local');
 begin
   perform public.sync_push(gen_random_uuid(),'debt_payments',gen_random_uuid(),0,jsonb_build_object('debt_id',d,'amount',700),false);
   raise exception 'expected overpay';
 exception when invalid_parameter_value then null; end;
 perform pg_temp.assert((select paid_amount=350 from public.debts where id=d),'overpay rolls back fully');
 perform public.sync_push(gen_random_uuid(),'debt_payments',p,8,'{}',true);
 perform pg_temp.assert((select paid_amount=0 from public.debts where id=d),'undo recalculates debt');
 perform pg_temp.assert(not exists(select 1 from public.transactions where id=t),'undo tombstones linked entry');
end $$;
rollback;
