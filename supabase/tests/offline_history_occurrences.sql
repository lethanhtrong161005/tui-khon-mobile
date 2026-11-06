-- Atomic payable occurrence / transaction regression tests. Disposable test copy.
begin;
create function pg_temp.assert(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
insert into auth.users(id,email) values('12345678-1234-1234-1234-123456789abc','occurrence@test.invalid');
grant select on public.wallet_balances to authenticated;
set local request.jwt.claim.sub='12345678-1234-1234-1234-123456789abc';
set local role authenticated;
do $$
declare parent uuid:=gen_random_uuid(); occ uuid:=gen_random_uuid(); tx uuid:=gen_random_uuid(); cat uuid; w uuid; op uuid:=gen_random_uuid(); req jsonb; r jsonb; again jsonb; bal bigint; v bigint; failed_tx uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid();
begin
 select id into w from public.wallets limit 1;
 select id into cat from public.categories where type='expense' limit 1;
 select balance into bal from public.wallet_balances where wallet_id=w;
 r:=public.sync_push(gen_random_uuid(),'payables',parent,0,'{"name":"Rent","amount":100,"due_date":"2026-10-28"}',false);
 req:=jsonb_build_object('payable_id',parent,'due_date','2026-10-28','amount',100,'transaction_id',tx,'wallet_id',w,'category_id',cat,'paid_at','2026-10-28T12:00:00Z','note','Rent paid');
 r:=public.sync_push(op,'payable_occurrences',occ,0,req,false);
 perform pg_temp.assert(r->'row'->>'status'='paid','link implies paid');
 perform pg_temp.assert((select amount=100 and note='Rent paid' and type='expense' and category_id=cat and occurred_at='2026-10-28T12:00:00Z' from public.transactions where id=tx),'atomic derived transaction');
 again:=public.sync_push(op,'payable_occurrences',occ,0,req,false);
 perform pg_temp.assert(r=again,'idempotent occurrence replay');
 again:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,0,req,false);
 perform pg_temp.assert(again->>'status'='conflict','second device stale create conflicts');
 perform pg_temp.assert((select balance=bal-100 from public.wallet_balances where wallet_id=w),'no double expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,1,'{"amount":150,"note":"Revised"}',false);
 perform pg_temp.assert((select amount=150 and note='Revised' from public.transactions where id=tx),'occurrence edit updates expense');
 begin
 perform public.sync_push(gen_random_uuid(),'transactions',tx,2,'{"amount":999}',false);
 raise exception 'expected direct write denial'; exception when raise_exception then
 if sqlerrm='expected direct write denial' then raise; end if; end;
 begin
 perform public.sync_push(gen_random_uuid(),'payable_occurrences',occ,2,jsonb_build_object('transaction_id',gen_random_uuid()),false);
 raise exception 'expected immutable linkage'; exception when raise_exception then
 if sqlerrm='expected immutable linkage' then raise; end if; end;
 -- A natural-key collision happens after the BEFORE trigger attempts its insert;
 -- the entire statement must roll back, including the newly derived expense.
 begin
 perform public.sync_push(gen_random_uuid(),'payable_occurrences',gen_random_uuid(),0,req||jsonb_build_object('transaction_id',failed_tx),false);
 raise exception 'expected unique collision'; exception when unique_violation then null; end;
 perform pg_temp.assert(not exists(select 1 from public.transactions where id=failed_tx),'collision rolls back derived expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,2,'{"status":"pending"}',false);
 perform pg_temp.assert(not exists(select 1 from public.transactions where id=tx),'pending undoes expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,3,'{"status":"paid"}',false);
 perform pg_temp.assert((select amount=150 from public.transactions where id=tx),'paid restores same expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,4,'{}',true);
 perform pg_temp.assert((select balance=bal from public.wallet_balances where wallet_id=w),'soft delete undoes expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',occ,5,'{}',false);
 perform pg_temp.assert((select balance=bal-150 from public.wallet_balances where wallet_id=w),'restore occurrence restores expense');
 -- Detaching a category propagates through the occurrence back into its expense.
 select version into v from public.categories where id=cat;
 r:=public.sync_push(gen_random_uuid(),'categories',cat,v,'{}',true);
 perform pg_temp.assert((select category_id is null from public.payable_occurrences where id=occ),'category detaches occurrence');
 perform pg_temp.assert((select category_id is null from public.transactions where id=tx),'category remains detached on derived expense');
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',pending,0,jsonb_build_object('payable_id',parent,'due_date','2026-11-28','amount',200),false);
 r:=public.sync_push(gen_random_uuid(),'payable_occurrences',pending,1,jsonb_build_object('transaction_id',failed_tx,'wallet_id',w),false);
 perform pg_temp.assert((select amount=200 and note='Rent' from public.transactions where id=failed_tx),'attach transaction to pending occurrence');
 r:=public.sync_push(gen_random_uuid(),'payables',parent,1,'{}',true);
 perform pg_temp.assert(not exists(select 1 from public.payable_occurrences where payable_id=parent),'parent cascades occurrences');
 perform pg_temp.assert((select balance=bal from public.wallet_balances where wallet_id=w),'parent cascades linked expenses');
 r:=public.sync_pull(0,5000);
 perform pg_temp.assert(exists(select 1 from jsonb_array_elements(r->'changes') c where c->>'id'=tx::text and (c->>'deleted')::boolean),'derived transaction tombstone journaled');
end $$;
reset role;
rollback;
