-- Regression tests for integration fixes; disposable migrated test copy only.
begin;
create function pg_temp.assert(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
insert into auth.users(id,email) values('dddddddd-dddd-dddd-dddd-dddddddddddd','cascade@test.invalid');
-- Simulate a migrated legacy entry without inventing a linked transaction.
insert into public.debts(id,user_id,person_name,type,amount) values('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','dddddddd-dddd-dddd-dddd-dddddddddddd','Legacy','lend',1000);
insert into public.debt_payments(id,user_id,debt_id,amount,is_legacy) values('ffffffff-ffff-ffff-ffff-ffffffffffff','dddddddd-dddd-dddd-dddd-dddddddddddd','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',200,true);
grant select on public.wallet_balances to authenticated;
set local request.jwt.claim.sub='dddddddd-dddd-dddd-dddd-dddddddddddd';
set local role authenticated;
do $$
declare r jsonb; w uuid; cat uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); rule uuid:=gen_random_uuid(); tx uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); g uuid:=gen_random_uuid(); n bigint; bal bigint; v bigint;
begin
 select id into w from public.wallets limit 1;
 select balance into bal from public.wallet_balances where wallet_id=w;
 r:=public.sync_push(gen_random_uuid(),'debt_payments','ffffffff-ffff-ffff-ffff-ffffffffffff',1,'{"amount":250,"paid_at":"2026-10-27T00:00:00Z"}',false);
 perform pg_temp.assert((r->'row'->>'is_legacy')::boolean,'legacy flag preserved on edit');
 perform pg_temp.assert((select paid_amount=250 from public.debts where id='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),'legacy amount edit recalc');
 r:=public.sync_push(gen_random_uuid(),'debt_payments','ffffffff-ffff-ffff-ffff-ffffffffffff',2,'{}',true);
 perform pg_temp.assert((select paid_amount=0 from public.debts where id='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),'legacy undo recalc');
 perform pg_temp.assert((select balance=bal from public.wallet_balances where wallet_id=w),'legacy edit/undo leaves balance unchanged');
 r:=public.sync_push(gen_random_uuid(),'categories',cat,0,'{"name":"Detach","type":"expense"}',false);
 r:=public.sync_push(gen_random_uuid(),'budgets',b,0,jsonb_build_object('category_id',cat,'month','2026-10-01','limit_amount',999999),false);
 r:=public.sync_push(gen_random_uuid(),'category_rules',rule,0,jsonb_build_object('category_id',cat,'keyword','test'),false);
 r:=public.sync_push(gen_random_uuid(),'transactions',tx,0,jsonb_build_object('category_id',cat,'wallet_id',w,'type','expense','amount',10),false);
 r:=public.sync_push(gen_random_uuid(),'categories',cat,1,'{}',true);
 perform pg_temp.assert((select category_id is null from public.transactions where id=tx),'category detach transaction');
 perform pg_temp.assert(not exists(select 1 from public.budgets where id=b),'category deletion removes budget');
 perform pg_temp.assert(not exists(select 1 from public.category_rules where id=rule),'category deletion removes rule');
 r:=public.sync_push(gen_random_uuid(),'categories',gen_random_uuid(),0,'{"name":"Detach","type":"expense"}',false);

 r:=public.sync_push(gen_random_uuid(),'budgets',gen_random_uuid(),0,'{"category_id":null,"month":"2026-10-01","limit_amount":999999}',false);
 r:=public.sync_push(gen_random_uuid(),'debts',d,0,'{"person_name":"Person","type":"borrow","amount":1000}',false);
 r:=public.sync_push(gen_random_uuid(),'debt_payments',p,0,jsonb_build_object('debt_id',d,'amount',100,'record_transaction',true,'wallet_id',w),false);
 perform pg_temp.assert((select t.note='Trả nợ Person' and c.name='Cho vay & Trả nợ' from public.transactions t join public.categories c on c.id=t.category_id where t.id=(r->'row'->>'transaction_id')::uuid),'borrow default note/category');
 r:=public.sync_push(gen_random_uuid(),'debts',gen_random_uuid(),0,'{"person_name":"Lender","type":"lend","amount":1000}',false);
 r:=public.sync_push(gen_random_uuid(),'debt_payments',gen_random_uuid(),0,jsonb_build_object('debt_id',r->'row'->>'id','amount',100,'record_transaction',true,'wallet_id',w),false);
 perform pg_temp.assert((select t.note='Thu nợ từ Lender' and c.name='Thu nợ' from public.transactions t join public.categories c on c.id=t.category_id where t.id=(r->'row'->>'transaction_id')::uuid),'lend default note/category');
 r:=public.sync_push(gen_random_uuid(),'debt_payments',(r->'row'->>'id')::uuid,1,'{}',true);
 select version into v from public.debts where id=d;
 r:=public.sync_push(gen_random_uuid(),'debts',d,v,'{}',true);
 perform pg_temp.assert(not exists(select 1 from public.debt_payments where debt_id=d),'debt deletion cascades payments');
 perform pg_temp.assert((select balance=bal-10 from public.wallet_balances where wallet_id=w),'wallet view excludes cascaded transaction tombstone');
 r:=public.sync_push(gen_random_uuid(),'transactions',tx,2,'{}',true);
 perform pg_temp.assert((select balance=bal from public.wallet_balances where wallet_id=w),'wallet view excludes ordinary transaction tombstone');
 r:=public.sync_push(gen_random_uuid(),'goals',g,0,'{"name":"No notification on delete","target_amount":100}',false);
 select count(*) into n from public.notifications where type='goal';
 r:=public.sync_push(gen_random_uuid(),'goals',g,1,'{"saved_amount":100}',true);
 perform pg_temp.assert((select count(*)=n from public.notifications where type='goal'),'soft deletion does not complete/notify goal');
end $$;
reset role;
select pg_temp.assert(exists(select 1 from public.debt_payments where id='ffffffff-ffff-ffff-ffff-ffffffffffff' and is_legacy and deleted and transaction_id is null and not record_transaction),'legacy tombstone has no linked transaction');
-- Verify actual tombstones retain category linkage instead of becoming overall rows.
select pg_temp.assert(exists(select 1 from public.budgets b join public.categories c on c.id=b.category_id where c.user_id='dddddddd-dddd-dddd-dddd-dddddddddddd' and c.name='Detach' and c.deleted and b.deleted),'deleted category budget retains category id');
select pg_temp.assert(exists(select 1 from public.category_rules r join public.categories c on c.id=r.category_id where c.user_id='dddddddd-dddd-dddd-dddd-dddddddddddd' and c.name='Detach' and c.deleted and r.deleted),'deleted category rule retains category id');
-- Definer functions bypass RLS and must filter tombstones themselves.
do $$ declare b uuid; old_version bigint; n integer; begin
 insert into public.budgets(user_id,month,limit_amount,deleted,alerted_80,alerted_100)
 values('dddddddd-dddd-dddd-dddd-dddddddddddd','2026-12-01',1,true,true,true) returning id,version into b,old_version;
 perform private.refresh_budget_alerts('dddddddd-dddd-dddd-dddd-dddddddddddd','2026-12-01');
 perform pg_temp.assert((select version=old_version and alerted_80 and alerted_100 from public.budgets where id=b),'budget refresh ignores tombstones');
 insert into public.debts(user_id,person_name,type,amount,due_date,deleted) values
 ('dddddddd-dddd-dddd-dddd-dddddddddddd','Deleted reminder','borrow',100,'2026-10-28',true),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd','Live reminder','borrow',100,'2026-10-28',false);
 n:=private.process_debt_reminders('2026-10-28');
 perform pg_temp.assert(n=1,'reminders process only live due debt');
 perform pg_temp.assert(not exists(select 1 from public.notifications x join public.debts d on d.id=(x.data->>'debt_id')::uuid where x.type='debt' and d.deleted),'no notification for tombstoned debt');
 perform pg_temp.assert(exists(select 1 from private.sync_changes where entity='notifications' and row_data->>'type'='debt'),'cron notification journaled');
end $$;
rollback;



