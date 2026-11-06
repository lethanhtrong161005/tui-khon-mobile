-- Full-install demo wrapper regression; all data is disposable and rolled back.
begin;
create function pg_temp.assert(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
insert into auth.users(id,email) values('abcdefab-abcd-abcd-abcd-abcdefabcdef','fresh-demo@test.invalid');
do $$ declare result text; before_data jsonb; after_data jsonb; begin
 perform pg_temp.assert(to_regprocedure('private.seed_demo_data_v1(text,boolean)') is not null,'original seed preserved privately');
 perform pg_temp.assert(not has_function_privilege('authenticated','private.seed_demo_data_v1(text,boolean)','EXECUTE'),'original seed not client callable');
 perform pg_temp.assert(not has_function_privilege('authenticated','private.seed_demo_data(text,boolean)','EXECUTE'),'wrapper remains administrative');
 begin
 perform private.seed_demo_data('fresh-demo@test.invalid',true);
 raise exception 'expected reset rejection'; exception when invalid_parameter_value then null; end;
 result:=private.seed_demo_data('fresh-demo@test.invalid');
 perform pg_temp.assert(result is not null,'fresh account seeds successfully');
 perform pg_temp.assert((select count(*)>100 from public.transactions where user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef'),'demo transactions created');
 perform pg_temp.assert((select sum(amount)=500000 and bool_and(is_legacy and not record_transaction and transaction_id is null) from public.debt_payments where user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef'),'demo aggregate converted to noncash legacy history');
 perform pg_temp.assert(not exists(select 1 from public.debts d where d.user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef' and d.paid_amount<>(select coalesce(sum(amount),0) from public.debt_payments p where p.debt_id=d.id and not deleted)),'all demo debt totals match history');
 perform pg_temp.assert(exists(select 1 from private.sync_changes where user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef' and entity='debt_payments'),'demo history journaled');
 select jsonb_agg(to_jsonb(t) order by id) into before_data from public.transactions t where user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef';
 begin
 perform private.seed_demo_data('fresh-demo@test.invalid',false);
 raise exception 'expected nonempty rejection'; exception when invalid_parameter_value then null; end;
 select jsonb_agg(to_jsonb(t) order by id) into after_data from public.transactions t where user_id='abcdefab-abcd-abcd-abcd-abcdefabcdef';
 perform pg_temp.assert(after_data=before_data,'repeat seed preserves transactions');
 begin
 perform private.seed_demo_data('fixture-a@test.invalid',false);
 raise exception 'expected real account rejection'; exception when invalid_parameter_value then null; end;
end $$;
rollback;
