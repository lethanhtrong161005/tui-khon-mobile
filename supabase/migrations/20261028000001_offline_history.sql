-- Additive offline journal. Never truncate/reset existing rows.
-- RPCs require READ COMMITTED (PostgREST default); reject snapshot isolation.
begin;
create table public.payables (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, amount bigint not null check(amount>0), due_date date not null,
 recurrence text not null default 'none' check(recurrence in ('none','weekly','monthly','yearly')),
 category_id uuid, wallet_id uuid, note text, enabled boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(id,user_id),
 foreign key(category_id,user_id) references public.categories(id,user_id), foreign key(wallet_id,user_id) references public.wallets(id,user_id)
);
create table public.payable_occurrences (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 payable_id uuid not null, due_date date not null, amount bigint not null check(amount>0),
 status text not null default 'pending' check(status in ('pending','paid','skipped')), paid_at timestamptz,
 transaction_id uuid unique, wallet_id uuid, category_id uuid, note text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(payable_id,due_date), foreign key(payable_id,user_id) references public.payables(id,user_id),
 foreign key(transaction_id,user_id) references public.transactions(id,user_id),
 foreign key(wallet_id,user_id) references public.wallets(id,user_id),
 foreign key(category_id,user_id) references public.categories(id,user_id)
);
create table public.category_rules (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 keyword text not null check(length(trim(keyword))>0), merchant text, category_id uuid not null, enabled boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(category_id,user_id) references public.categories(id,user_id)
);
create table public.debt_payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 debt_id uuid not null, amount bigint not null check(amount>0), paid_at timestamptz not null default now(), note text,
 record_transaction boolean not null default false, wallet_id uuid, transaction_id uuid unique,
 is_legacy boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(debt_id,user_id) references public.debts(id,user_id), foreign key(wallet_id,user_id) references public.wallets(id,user_id),
 foreign key(transaction_id,user_id) references public.transactions(id,user_id) deferrable initially deferred,
 check(not record_transaction or (wallet_id is not null and transaction_id is not null))
);
-- Preserve historical aggregate payments without inventing cash movements.
insert into public.debt_payments(user_id,debt_id,amount,paid_at,is_legacy)
 select user_id,id,paid_amount,updated_at,true from public.debts where paid_amount>0;
set constraints all immediate;
alter table public.notifications add column updated_at timestamptz not null default now();
create table private.sync_changes (
 seq bigint generated always as identity primary key, user_id uuid not null references auth.users(id) on delete cascade,
 entity text not null, id uuid not null, row_data jsonb not null, version bigint not null, deleted boolean not null
);
create index on private.sync_changes(user_id,seq);
create table private.sync_ops (
 user_id uuid not null references auth.users(id) on delete cascade, op_id uuid not null,
 request jsonb not null, response jsonb not null, primary key(user_id,op_id)
);
create function private.sync_lock(p_user uuid) returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if current_setting('transaction_isolation') <> 'read committed' then
  raise exception 'Offline sync requires READ COMMITTED' using errcode='25001';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('offline-sync:'||p_user::text,0));
end $$;
create function private.sync_before() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform private.sync_lock(new.user_id);
 if tg_op='UPDATE' then
  if new.id<>old.id or new.user_id<>old.user_id then raise exception 'Immutable owner/id' using errcode='42501'; end if;
  new.version:=old.version+1;
 else new.version:=1;
 end if;
 new.updated_at:=clock_timestamp();
 return new;
end $$;
create function private.sync_after() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into private.sync_changes(user_id,entity,id,row_data,version,deleted)
 values(new.user_id,tg_table_name,new.id,to_jsonb(new),new.version,new.deleted);
 return null;
end $$;
-- Statement lock precedes row locks for normal authenticated writes.
create function private.sync_statement() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null then perform private.sync_lock(auth.uid()); end if;
 return null;
end $$;
do $$ declare t text; begin
 foreach t in array array['wallets','categories','transactions','budgets','debts','goals','debt_payments','payables','payable_occurrences','category_rules','notifications'] loop
 execute format('alter table public.%I add column version bigint not null default 1, add column deleted boolean not null default false',t);
 execute format('alter table public.%I enable row level security',t);
 if t in ('debt_payments','payables','payable_occurrences','category_rules') then
 execute format('create policy "own rows" on public.%I for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()))',t);
 end if;
 -- Hide tombstones from existing balance/statistics functions and clients.
 execute format('create policy "live rows" on public.%I as restrictive for select to authenticated using(not deleted)',t);
 execute format('grant select on public.%I to authenticated',t);
 -- Versioned mutation is RPC-only. This prevents forged versions and hard deletes.
 execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
 execute format('create trigger a_sync_statement before insert or update on public.%I for each statement execute function private.sync_statement()',t);
 execute format('create trigger a_sync_before before insert or update on public.%I for each row execute function private.sync_before()',t);
 execute format('create trigger z_sync_after after insert or update on public.%I for each row execute function private.sync_after()',t);
 execute format('insert into private.sync_changes(user_id,entity,id,row_data,version,deleted) select user_id,%L,id,to_jsonb(t),version,deleted from public.%I t',t,t);
 end loop;
end $$;
-- Retain every row, but let live natural keys be reused after deletion.
alter table public.categories drop constraint categories_user_id_type_name_key;
create unique index categories_live_name_key on public.categories(user_id,type,name) where not deleted;
alter table public.budgets drop constraint budgets_user_id_category_id_month_key;
create unique index budgets_live_month_key on public.budgets(user_id,category_id,month) nulls not distinct where not deleted;
alter table public.payable_occurrences drop constraint payable_occurrences_payable_id_due_date_key;
create unique index payable_occurrences_live_due_key on public.payable_occurrences(payable_id,due_date) where not deleted;
alter table public.category_rules alter column category_id drop not null;
-- Wallet names were never unique in the original schema: retaining that behavior
-- preserves existing duplicates and already permits recreation after tombstoning.
create function private.payment_effects() returns trigger language plpgsql security definer set search_path='' as $$
declare d public.debts; total numeric; cat uuid;
begin
 select * into strict d from public.debts where id=new.debt_id and user_id=new.user_id and not deleted for update;
 if tg_op='UPDATE' and (new.debt_id<>old.debt_id or new.transaction_id is distinct from old.transaction_id or new.is_legacy<>old.is_legacy) then
 raise exception 'Immutable payment linkage'; end if;
 if new.is_legacy and (new.record_transaction or new.transaction_id is not null) then raise exception 'Legacy history cannot create cash movements'; end if;
 if new.record_transaction and not new.deleted then
 if not exists(select 1 from public.wallets where id=new.wallet_id and user_id=new.user_id and not deleted) then raise exception 'Invalid wallet'; end if;
 if tg_op='INSERT' and exists(select 1 from public.transactions where id=new.transaction_id) then raise exception 'Transaction already exists'; end if;
 select id into cat from public.categories where user_id=new.user_id and not deleted
 and ((d.type='borrow' and type='expense' and name='Cho vay & Trả nợ') or (d.type='lend' and type='income' and name='Thu nợ')) order by created_at,id limit 1;
 insert into public.transactions(id,user_id,wallet_id,category_id,type,amount,note,occurred_at,source)
 values(new.transaction_id,new.user_id,new.wallet_id,cat,case d.type when 'borrow' then 'expense'::public.tx_type else 'income'::public.tx_type end,new.amount,coalesce(new.note,left(case d.type when 'borrow' then 'Trả nợ ' else 'Thu nợ từ ' end||d.person_name,255)),new.paid_at,'debt')
 on conflict(id) do update set wallet_id=excluded.wallet_id,category_id=excluded.category_id,type=excluded.type,amount=excluded.amount,note=excluded.note,occurred_at=excluded.occurred_at,deleted=false;
 elsif new.transaction_id is not null then
 update public.transactions set deleted=true where id=new.transaction_id and user_id=new.user_id and not deleted;
 end if;
 select coalesce(sum(amount),0) into total from public.debt_payments where debt_id=new.debt_id and not deleted;
 if total>d.amount then raise exception 'Payment exceeds remaining debt' using errcode='22023'; end if;
 update public.debts set paid_amount=total::bigint,status=case when total=amount then 'settled'::public.debt_status else 'active'::public.debt_status end where id=d.id;
 return null;
end $$;
create trigger payment_effects after insert or update on public.debt_payments for each row execute function private.payment_effects();
-- A supplied transaction_id opts into a recorded expense. The client derives
-- this UUID deterministically from the occurrence id and queues only the occurrence.
-- BEFORE timing creates the target before the immediate transaction FK check.
create function private.occurrence_effects() returns trigger language plpgsql security definer set search_path='' as $$
declare parent public.payables; attaching boolean;
begin
 if tg_op='UPDATE' then
 if new.payable_id<>old.payable_id then raise exception 'Immutable occurrence parent'; end if;
 if old.transaction_id is not null and new.transaction_id is distinct from old.transaction_id then raise exception 'Immutable occurrence transaction'; end if;
 attaching:=old.transaction_id is null and new.transaction_id is not null;
 else attaching:=new.transaction_id is not null;
 end if;
 select * into strict parent from public.payables where id=new.payable_id and user_id=new.user_id and not deleted;
 if attaching and (new.deleted or new.status<>'paid') then raise exception 'New transaction linkage requires a paid live occurrence'; end if;
 if attaching and exists(select 1 from public.transactions where id=new.transaction_id) then raise exception 'Transaction already exists'; end if;
 if new.transaction_id is not null and new.status='paid' and not new.deleted then
 if new.wallet_id is null or not exists(select 1 from public.wallets where id=new.wallet_id and user_id=new.user_id and not deleted) then raise exception 'Invalid occurrence wallet'; end if;
 if new.category_id is not null and not exists(select 1 from public.categories where id=new.category_id and user_id=new.user_id and not deleted and type='expense') then raise exception 'Invalid occurrence expense category'; end if;
 new.paid_at:=coalesce(new.paid_at,clock_timestamp());
 insert into public.transactions(id,user_id,wallet_id,category_id,type,amount,note,occurred_at,source)
 values(new.transaction_id,new.user_id,new.wallet_id,new.category_id,'expense',new.amount,coalesce(new.note,left(parent.name,255)),new.paid_at,'manual')
 on conflict(id) do update set wallet_id=excluded.wallet_id,category_id=excluded.category_id,type=excluded.type,amount=excluded.amount,note=excluded.note,occurred_at=excluded.occurred_at,deleted=false;
 elsif new.transaction_id is not null then
 update public.transactions set deleted=true where id=new.transaction_id and user_id=new.user_id and not deleted;
 end if;
 return new;
end $$;
create trigger b_occurrence_effects before insert or update on public.payable_occurrences for each row execute function private.occurrence_effects();
create function public.sync_push(op_id uuid,entity text,record_id uuid,base_version bigint,payload jsonb,deleted bool)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare u uuid:=auth.uid(); oldrow jsonb; result jsonb; req jsonb; logged private.sync_ops; cols text; vals text; sets text; k text; p jsonb; exists_row boolean; ref_table text; ref_ok boolean;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if op_id is null or record_id is null or base_version is null or base_version<0 or deleted is null or jsonb_typeof(payload) is distinct from 'object' then raise exception 'Invalid operation' using errcode='22023'; end if;
 if entity not in ('wallets','categories','transactions','budgets','debts','goals','debt_payments','payables','payable_occurrences','category_rules','notifications') then raise exception 'Invalid entity'; end if;
 perform private.sync_lock(u);
 req:=jsonb_build_array(entity,record_id,base_version,payload,deleted);
 select * into logged from private.sync_ops s where s.user_id=u and s.op_id=sync_push.op_id;
 if found then
 if logged.request<>req then raise exception 'op_id reused with different request' using errcode='22023'; end if;
 return logged.response;
 end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 and user_id=$2',entity) into oldrow using record_id,u;
 exists_row:=oldrow is not null;
 if (exists_row and (oldrow->>'version')::bigint<>base_version) or (not exists_row and base_version<>0) then
 result:=jsonb_build_object('status','conflict','row',oldrow,'version',coalesce((oldrow->>'version')::bigint,0));
 elsif not exists_row and deleted then result:=jsonb_build_object('status','not_found','row',null,'version',0);
 else
 if entity='notifications' then
 if not exists_row or deleted or not (payload ? 'is_read') then raise exception 'Notifications support is_read updates only' using errcode='42501'; end if;
 payload:=jsonb_build_object('is_read',payload->'is_read');
 end if;
 if payload ?| array['id','user_id','version','deleted','created_at','updated_at','is_legacy'] then raise exception 'Server managed field' using errcode='42501'; end if;
 if entity='debts' and payload ?| array['paid_amount','status'] then raise exception 'Use debt_payments'; end if;
 if entity='transactions' and (exists(select 1 from public.debt_payments where transaction_id=record_id) or exists(select 1 from public.payable_occurrences where transaction_id=record_id)) then raise exception 'Use the owning payment/occurrence for linked transactions'; end if;
 if entity='debt_payments' and not exists_row and payload->>'transaction_id' is not null and not coalesce((payload->>'record_transaction')::boolean,false) then
 raise exception 'A transaction_id requires record_transaction'; end if;
 if entity='debts' and exists_row and payload ? 'type' and payload->>'type'<>oldrow->>'type'
 and exists(select 1 from public.debt_payments where debt_id=record_id) then raise exception 'Cannot change debt direction with payment history'; end if;
 p:=payload;
 if entity='payable_occurrences' and p->>'transaction_id' is not null and not (p ? 'status') then
 p:=p||jsonb_build_object('status','paid'); end if;
 if entity='debt_payments' then

 if not exists_row and coalesce((p->>'record_transaction')::boolean,false) then
 p:=p||jsonb_build_object('transaction_id',coalesce((p->>'transaction_id')::uuid,gen_random_uuid()));
 end if;
 end if;
 -- Composite FKs enforce ownership; additionally reject references to tombstones.
 if not deleted then
 for k,ref_table in select * from (values ('wallet_id','wallets'),('category_id','categories'),('debt_id','debts'),('payable_id','payables')) refs(col,tbl) loop
 if (coalesce(oldrow,'{}'::jsonb)||p)->>k is not null then
 execute format('select exists(select 1 from public.%I where id=$1 and user_id=$2 and not deleted)',ref_table)
 into ref_ok using ((coalesce(oldrow,'{}'::jsonb)||p)->>k)::uuid,u;
 if not ref_ok then raise exception 'Invalid live reference %',k using errcode='23503'; end if;
 end if;
 end loop;
 end if;
 -- Cascade children while the parent is still live, so each payment undo can
 -- recalculate its debt and journal its linked transaction before the debt tombstone.
 if deleted and exists_row then
 if entity='debts' then
 update public.debt_payments child set deleted=true where child.debt_id=record_id and child.user_id=u and not child.deleted;
 elsif entity='categories' then
 update public.transactions child set category_id=null where child.category_id=record_id and child.user_id=u and not child.deleted;
 -- Category budgets and rules become tombstones; never convert a category
 -- budget into an overall budget or retain an unusable category rule.
 update public.budgets child set deleted=true where child.category_id=record_id and child.user_id=u and not child.deleted;
 update public.category_rules child set deleted=true where child.category_id=record_id and child.user_id=u and not child.deleted;
 update public.payables child set category_id=null where child.category_id=record_id and child.user_id=u and not child.deleted;
 update public.payable_occurrences child set category_id=null where child.category_id=record_id and child.user_id=u and not child.deleted;
 elsif entity='payables' then
 update public.payable_occurrences child set deleted=true where child.payable_id=record_id and child.user_id=u and not child.deleted;
 end if;
 end if;
 cols:='id,user_id,deleted'; vals:='$1,$2,$3'; sets:='deleted=$3';
 for k in select jsonb_object_keys(p) loop
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name=entity and column_name=k) then raise exception 'Unknown field %',k; end if;
 cols:=cols||format(',%I',k); vals:=vals||format(',(jsonb_populate_record(null::public.%I,$4)).%I',entity,k);
 sets:=sets||format(',%I=(jsonb_populate_record(null::public.%I,$4)).%I',k,entity,k);
 end loop;
 if exists_row then execute format('update public.%I set %s where id=$1 and user_id=$2',entity,sets) using record_id,u,deleted,p;
 else execute format('insert into public.%I(%s) values(%s)',entity,cols,vals) using record_id,u,deleted,p;
 end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 and user_id=$2',entity) into oldrow using record_id,u;
 result:=jsonb_build_object('status','applied','row',oldrow,'version',(oldrow->>'version')::bigint);
 end if;
 insert into private.sync_ops values(u,op_id,req,result);
 return result;
end $$;
create function public.sync_pull(cursor bigint,"limit" int default 500) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare u uuid:=auth.uid(); changes jsonb; next_cursor bigint;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if cursor is null or cursor<0 or "limit" is null or "limit"<1 or "limit">5000 then raise exception 'Invalid cursor/limit'; end if;
 perform private.sync_lock(u);
 -- This query takes a fresh READ COMMITTED snapshot AFTER acquiring the lock.
 select coalesce(jsonb_agg(jsonb_build_object('seq',c.seq,'entity',c.entity,'id',c.id,'row',c.row_data,'version',c.version,'deleted',c.deleted) order by c.seq),'[]'),coalesce(max(c.seq),cursor)
 into changes,next_cursor from (select * from private.sync_changes s where s.user_id=u and s.seq>cursor order by s.seq limit sync_pull."limit") c;
 return jsonb_build_object('changes',changes,'cursor',next_cursor,'has_more',exists(select 1 from private.sync_changes s where s.user_id=u and s.seq>next_cursor));
end $$;
create or replace function public.settle_debt(p_debt_id uuid,p_amount bigint default null,p_record_transaction boolean default false,p_wallet_id uuid default null)
returns public.debts language plpgsql volatile security definer set search_path='' as $$
declare d public.debts; w uuid; r jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform private.sync_lock(auth.uid());
 select * into d from public.debts where id=p_debt_id and user_id=auth.uid() and not deleted;
 if not found then raise exception 'Debt not found' using errcode='P0002'; end if;
 if d.status='settled' then return d; end if;
 if p_record_transaction then
 select id into w from public.wallets where user_id=auth.uid() and not deleted and not is_archived and (p_wallet_id is null or id=p_wallet_id) order by created_at,id limit 1;
 end if;
 r:=public.sync_push(gen_random_uuid(),'debt_payments',gen_random_uuid(),0,jsonb_build_object('debt_id',d.id,'amount',coalesce(p_amount,d.amount-d.paid_amount),'record_transaction',p_record_transaction,'wallet_id',w),false);
 select t.* into d from public.debts t where t.id=p_debt_id;
 return d;
end $$;
-- Definer budget triggers must exclude tombstones explicitly (RLS is bypassed).
create or replace function public.budget_spent(p_user_id uuid,p_category_id uuid,p_month date)
returns bigint language sql stable set search_path='' as $$
 select coalesce(sum(t.amount),0)::bigint from public.transactions t
 where t.user_id=p_user_id and not t.deleted and t.type='expense'
 and (p_category_id is null or t.category_id=p_category_id)
 and t.occurred_at>=public.vn_day_start(p_month)
 and t.occurred_at<public.vn_day_start((p_month+interval '1 month')::date)
$$;
-- Undo must also refresh budget notifications/flags for the affected month.
create trigger budget_alerts_tombstone after update of deleted on public.transactions
 for each row when(old.deleted is distinct from new.deleted) execute function private.on_transaction_change();
create or replace function private.on_goal_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.deleted then return new; end if;
    if new.status = 'active' and new.saved_amount >= new.target_amount then
        new.status := 'completed';
        insert into public.notifications (user_id, type, title, message, data)
        values (
            new.user_id, 'goal', 'Hoàn thành mục tiêu 🎉',
            format('Bạn đã để dành đủ %s cho "%s".', public.format_vnd(new.target_amount), new.name),
            jsonb_build_object('goal_id', new.id)
        );
    elsif new.status = 'completed' and new.saved_amount < new.target_amount then
        new.status := 'active';
    end if;
    return new;
end;
$$;
create or replace function private.refresh_budget_alerts(p_user_id uuid, p_month date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    b         record;
    v_spent   bigint;
    v_hit_80  boolean;
    v_hit_100 boolean;
    v_label   text;
begin
    for b in
        select bu.id, bu.category_id, bu.limit_amount, bu.alerted_80, bu.alerted_100, c.name as category_name
        from public.budgets bu
        left join public.categories c on c.id = bu.category_id
        where bu.user_id = p_user_id and bu.month = p_month and not bu.deleted
        for update of bu
    loop
        v_spent   := public.budget_spent(p_user_id, b.category_id, p_month);
        v_hit_100 := v_spent >= b.limit_amount;
        v_hit_80  := v_spent * 5 >= b.limit_amount * 4;
        v_label   := coalesce('"' || b.category_name || '"', 'tổng');

        if v_hit_100 and not b.alerted_100 then
            insert into public.notifications (user_id, type, title, message, data)
            values (
                p_user_id, 'budget', 'Vượt ngân sách',
                format('Bạn đã chi %s, vượt ngân sách %s tháng %s (%s).',
                       public.format_vnd(v_spent), v_label, to_char(p_month, 'MM/YYYY'),
                       public.format_vnd(b.limit_amount)),
                jsonb_build_object('budget_id', b.id, 'threshold', 100, 'spent', v_spent, 'limit', b.limit_amount)
            );
        elsif v_hit_80 and not b.alerted_80 then
            insert into public.notifications (user_id, type, title, message, data)
            values (
                p_user_id, 'budget', 'Sắp chạm ngân sách',
                format('Bạn đã dùng %s%% ngân sách %s tháng %s (%s / %s).',
                       v_spent * 100 / b.limit_amount, v_label, to_char(p_month, 'MM/YYYY'),
                       public.format_vnd(v_spent), public.format_vnd(b.limit_amount)),
                jsonb_build_object('budget_id', b.id, 'threshold', 80, 'spent', v_spent, 'limit', b.limit_amount)
            );
        end if;

        if v_hit_80 is distinct from b.alerted_80 or v_hit_100 is distinct from b.alerted_100 then
            update public.budgets
            set alerted_80 = v_hit_80, alerted_100 = v_hit_100
            where id = b.id;
        end if;
    end loop;
end;
$$;
create or replace function private.process_debt_reminders(p_today date default public.vn_today())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    owner_id uuid;
    d         record;
    v_stage   text;
    v_left    text;
    v_title   text;
    v_message text;
    v_count   integer := 0;
begin
    -- Lock the user before debt row locks, in the same order as sync_push.
    for owner_id in select distinct user_id from public.debts where not deleted order by user_id loop
    perform private.sync_lock(owner_id);
    for d in
        select * from public.debts
        where user_id=owner_id and not deleted and status = 'active' and due_date is not null and due_date <= p_today + 1
        for update
    loop
        v_stage := case
            when d.due_date < p_today then 'overdue'
            when d.due_date = p_today then 'due'
            else 'before'
        end;
        continue when private.debt_stage_rank(d.last_reminded_stage) >= private.debt_stage_rank(v_stage);

        v_left := public.format_vnd(d.amount - d.paid_amount);
        v_title := case v_stage
            when 'before' then 'Sắp đến hạn trả nợ'
            when 'due' then 'Hôm nay đến hạn trả nợ'
            else 'Khoản nợ đã quá hạn'
        end;
        v_message := case
            when d.type = 'borrow' and v_stage = 'before' then
                format('Bạn nợ %s %s, hạn trả là ngày mai.', d.person_name, v_left)
            when d.type = 'borrow' and v_stage = 'due' then
                format('Hôm nay là hạn trả %s cho %s. Trả rồi thì nhớ xác nhận trong app nhé.', v_left, d.person_name)
            when d.type = 'borrow' then
                format('Khoản nợ %s với %s đã quá hạn %s ngày. Bạn đã trả chưa?', v_left, d.person_name, p_today - d.due_date)
            when v_stage = 'before' then
                format('%s nợ bạn %s, hẹn trả vào ngày mai.', d.person_name, v_left)
            when v_stage = 'due' then
                format('Hôm nay %s hẹn trả bạn %s. Nhận rồi thì nhớ xác nhận nhé.', d.person_name, v_left)
            else
                format('%s nợ bạn %s đã quá hạn %s ngày. Bạn đã nhận tiền chưa?', d.person_name, v_left, p_today - d.due_date)
        end;

        insert into public.notifications (user_id, type, title, message, data)
        values (d.user_id, 'debt', v_title, v_message,
                jsonb_build_object('debt_id', d.id, 'stage', v_stage, 'due_date', d.due_date));
        update public.debts set last_reminded_stage = v_stage where id = d.id;
        v_count := v_count + 1;
    end loop;
    end loop;
    return v_count;
end;
$$;
-- Some installations omit the optional demo seeder. Wrap it only when present.
do $install_demo$
declare definition text;
begin
 if to_regprocedure('private.seed_demo_data(text,boolean)') is not null then
 alter function private.seed_demo_data(text,boolean) rename to seed_demo_data_v1;
 revoke all on function private.seed_demo_data_v1(text,boolean) from public,anon,authenticated;
 -- The old ON CONFLICT inference must name the new partial live-budget index.
 definition:=pg_get_functiondef('private.seed_demo_data_v1(text,boolean)'::regprocedure);
 definition:=replace(definition,'on conflict (user_id, category_id, month) do nothing',
 'on conflict (user_id, category_id, month) where not deleted do nothing');
 execute definition;
 execute $wrapper$
 create function private.seed_demo_data(p_email text,p_reset boolean default false)
 returns text language plpgsql security definer set search_path='' as $seed$
 declare u uuid; result text; cash_before jsonb; cash_after jsonb;
 begin
 if p_reset is distinct from false then raise exception 'Demo reset is disabled; use a fresh demo account' using errcode='22023'; end if;
 select id into strict u from auth.users where email=p_email;
 perform private.sync_lock(u);
 if exists(select 1 from public.transactions where user_id=u)
 or exists(select 1 from public.debts where user_id=u)
 or exists(select 1 from public.debt_payments where user_id=u)
 or exists(select 1 from public.budgets where user_id=u)
 or exists(select 1 from public.goals where user_id=u)
 or exists(select 1 from public.payables where user_id=u)
 or exists(select 1 from public.payable_occurrences where user_id=u)
 or exists(select 1 from public.category_rules where user_id=u)
 or exists(select 1 from public.notifications where user_id=u)
 or exists(select 1 from private.sync_ops where user_id=u)
 or exists(select 1 from public.ai_usage where user_id=u)
 or (select count(*) from public.wallets where user_id=u)<>1
 or exists(select 1 from public.wallets where user_id=u and
 (name<>'Tiền mặt' or initial_balance<>0 or deleted or version<>1 or type<>'cash' or is_archived))
 or (select count(*) from public.categories where user_id=u)<>22
 or exists(select 1 from public.categories where user_id=u and (not is_default or deleted or version<>1)) then
 raise exception 'Demo seeding is allowed only for a fresh account; existing data is preserved' using errcode='22023';
 end if;
 result:=private.seed_demo_data_v1(p_email,false);
 select jsonb_build_object('count',count(*),'income',sum(amount) filter(where type='income'),'expense',sum(amount) filter(where type='expense'))
 into cash_before from public.transactions where user_id=u;
 insert into public.debt_payments(user_id,debt_id,amount,paid_at,is_legacy)
 select d.user_id,d.id,d.paid_amount,d.updated_at,true from public.debts d
 where d.user_id=u and d.paid_amount>0 and not exists(select 1 from public.debt_payments p where p.debt_id=d.id);
 if exists(select 1 from public.debts d where d.user_id=u and d.paid_amount<>
 (select coalesce(sum(p.amount),0) from public.debt_payments p where p.debt_id=d.id and not p.deleted)) then
 raise exception 'Demo history totals do not match debt totals'; end if;
 select jsonb_build_object('count',count(*),'income',sum(amount) filter(where type='income'),'expense',sum(amount) filter(where type='expense'))
 into cash_after from public.transactions where user_id=u;
 if cash_after is distinct from cash_before then raise exception 'Legacy history changed demo cash movements'; end if;
 return result;
 end $seed$;
 $wrapper$;
 end if;
end $install_demo$;
revoke all on all functions in schema private from public,anon,authenticated;
revoke all on function public.sync_push(uuid,text,uuid,bigint,jsonb,bool),public.sync_pull(bigint,int),public.settle_debt(uuid,bigint,boolean,uuid) from public,anon;
grant execute on function public.sync_push(uuid,text,uuid,bigint,jsonb,bool),public.sync_pull(bigint,int),public.settle_debt(uuid,bigint,boolean,uuid) to authenticated;
commit;










