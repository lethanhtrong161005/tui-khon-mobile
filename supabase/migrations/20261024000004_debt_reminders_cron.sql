-- =============================================================================
-- Nhắc hạn sổ nợ: chạy bằng pg_cron 08:00 giờ VN.
-- Mỗi khoản nợ còn hạn được nhắc tối đa 3 lần: trước 1 ngày, đúng ngày, quá hạn.
-- App cũng tự lên lịch thông báo trên máy và hỏi lại khi mở app; bản server này
-- tạo thông báo trong app (bảng notifications) để không phụ thuộc thiết bị.
-- =============================================================================

create function private.debt_stage_rank(p_stage text)
returns integer
language sql
immutable
set search_path = ''
as $$
    select case p_stage when 'before' then 1 when 'due' then 2 when 'overdue' then 3 else 0 end;
$$;

-- Trả về số thông báo đã tạo. Test tay: select private.process_debt_reminders('2026-11-01');
create function private.process_debt_reminders(p_today date default public.vn_today())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    d         record;
    v_stage   text;
    v_left    text;
    v_title   text;
    v_message text;
    v_count   integer := 0;
begin
    for d in
        select * from public.debts
        where status = 'active' and due_date is not null and due_date <= p_today + 1
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
    return v_count;
end;
$$;

-- 08:00 giờ VN = 01:00 UTC. Môi trường không có pg_cron (vd Postgres thuần để test) thì bỏ qua.
do $$
begin
    if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
        create extension if not exists pg_cron;
        perform cron.schedule('tuikhon-debt-reminders', '0 1 * * *', 'select private.process_debt_reminders()');
    else
        raise notice 'pg_cron không có sẵn: cần tự lên lịch private.process_debt_reminders()';
    end if;
end;
$$;
