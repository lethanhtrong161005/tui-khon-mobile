-- Harness fixture: executed ONLY inside the runner's new in-memory engine,
-- BEFORE the additive migration. Deliberately nonzero, independently known sums.
insert into auth.users(id,email) values
 ('11111111-1111-1111-1111-111111111111','fixture-a@test.invalid'),
 ('22222222-2222-2222-2222-222222222222','fixture-b@test.invalid');
update public.wallets set initial_balance=1000 where user_id='11111111-1111-1111-1111-111111111111';
update public.wallets set initial_balance=2000 where user_id='22222222-2222-2222-2222-222222222222';
insert into public.transactions(user_id,wallet_id,type,amount,note)
 select user_id,id,'income',700,'Existing income' from public.wallets where user_id='11111111-1111-1111-1111-111111111111';
insert into public.transactions(user_id,wallet_id,type,amount,note)
 select user_id,id,'expense',120,'Existing expense' from public.wallets where user_id='22222222-2222-2222-2222-222222222222';
insert into public.debts(user_id,person_name,type,amount,paid_amount,status) values
 ('11111111-1111-1111-1111-111111111111','Partial','borrow',1000,200,'active'),
 ('22222222-2222-2222-2222-222222222222','Settled','lend',500,500,'settled');
insert into public.budgets(user_id,month,limit_amount) values
 ('11111111-1111-1111-1111-111111111111','2026-10-01',10000);
insert into public.goals(user_id,name,target_amount,saved_amount) values
 ('22222222-2222-2222-2222-222222222222','Existing savings',5000,300);
