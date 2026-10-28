-- Additive: no row rewrite, no ID or monetary changes to existing history.
-- Both clients and PostgreSQL derive the same ID for first-time attachments.
create or replace function private.debt_payment_transaction_id(payment_id uuid)
returns uuid language sql immutable strict set search_path='' as $$
  select md5('tuikhon:debt-payment:' || payment_id::text)::uuid
$$;

create or replace function private.payment_effects() returns trigger language plpgsql security definer set search_path='' as $$
declare d public.debts; total numeric; cat uuid; first_link boolean := false; retained_wallet boolean := false;
begin
 select * into strict d from public.debts where id=new.debt_id and user_id=new.user_id and not deleted for update;
 if tg_op='UPDATE' then
   first_link := old.transaction_id is null and new.record_transaction
     and new.transaction_id = private.debt_payment_transaction_id(new.id);
   retained_wallet := old.record_transaction and new.wallet_id is not distinct from old.wallet_id;
   if new.debt_id<>old.debt_id or new.is_legacy<>old.is_legacy
      or (new.transaction_id is distinct from old.transaction_id and not first_link) then
     raise exception 'Immutable payment linkage';
   end if;
 end if;
 if new.is_legacy and (new.record_transaction or new.transaction_id is not null) then raise exception 'Legacy history cannot create cash movements'; end if;
 if new.record_transaction and not new.deleted then
 if not exists(select 1 from public.wallets where id=new.wallet_id and user_id=new.user_id and not deleted and (not is_archived or retained_wallet)) then raise exception 'Invalid wallet'; end if;
 if (tg_op='INSERT' or first_link) and exists(select 1 from public.transactions where id=new.transaction_id) then raise exception 'Transaction already exists'; end if;
 select id into cat from public.categories where user_id=new.user_id and not deleted
 and ((d.type='borrow' and type='expense' and name='Cho vay & Trả nợ') or (d.type='lend' and type='income' and name='Thu nợ')) order by created_at,id limit 1;
 insert into public.transactions(id,user_id,wallet_id,category_id,type,amount,note,occurred_at,source)
 values(new.transaction_id,new.user_id,new.wallet_id,cat,case d.type when 'borrow' then 'expense'::public.tx_type else 'income'::public.tx_type end,new.amount,coalesce(nullif(btrim(new.note),''),left(case d.type when 'borrow' then 'Trả nợ ' else 'Thu nợ từ ' end||d.person_name,255)),new.paid_at,'debt')
 on conflict(id) do update set wallet_id=excluded.wallet_id,category_id=excluded.category_id,type=excluded.type,amount=excluded.amount,note=excluded.note,occurred_at=excluded.occurred_at,deleted=false;
 elsif new.transaction_id is not null then
 update public.transactions set deleted=true where id=new.transaction_id and user_id=new.user_id and not deleted;
 end if;
 select coalesce(sum(amount),0) into total from public.debt_payments where debt_id=new.debt_id and not deleted;
 if total>d.amount then raise exception 'Payment exceeds remaining debt' using errcode='22023'; end if;
 update public.debts set paid_amount=total::bigint,status=case when total=amount then 'settled'::public.debt_status else 'active'::public.debt_status end where id=d.id;
 return null;
end $$;
