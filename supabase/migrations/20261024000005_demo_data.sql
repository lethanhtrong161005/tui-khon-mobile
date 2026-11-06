-- =============================================================================
-- Dữ liệu demo cho buổi trình bày.
-- Cách dùng (SQL Editor trên Supabase Studio), sau khi đã đăng ký tài khoản qua app:
--   select private.seed_demo_data('demo@tuikhon.vn');          -- thêm dữ liệu
--   select private.seed_demo_data('demo@tuikhon.vn', true);    -- xoá dữ liệu cũ rồi tạo lại
-- =============================================================================

create function private.seed_demo_data(p_email text, p_reset boolean default false)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id  uuid;
    v_today    date := public.vn_today();
    v_month    date := date_trunc('month', public.vn_today())::date;
    v_day      date;
    v_cash     uuid;
    v_bank     uuid;
    v_momo     uuid;
    v_food     uuid;
    v_market   uuid;
    v_move     uuid;
    v_home     uuid;
    v_shop     uuid;
    v_bill     uuid;
    v_fun      uuid;
    v_salary   uuid;
    v_bonus    uuid;
    v_count    integer;
begin
    select id into v_user_id from auth.users where email = p_email;
    if v_user_id is null then
        raise exception 'Không tìm thấy user %', p_email;
    end if;

    if p_reset then
        delete from public.transactions where user_id = v_user_id;
        delete from public.budgets where user_id = v_user_id;
        delete from public.goals where user_id = v_user_id;
        delete from public.debts where user_id = v_user_id;
        delete from public.notifications where user_id = v_user_id;
        delete from public.wallets where user_id = v_user_id and name in ('Vietcombank', 'Ví MoMo');
    end if;

    -- Nguồn tiền (tự khai, không liên kết ngân hàng)
    select id into v_cash from public.wallets where user_id = v_user_id and name = 'Tiền mặt';
    if v_cash is null then
        insert into public.wallets (user_id, name, type, icon, color)
        values (v_user_id, 'Tiền mặt', 'cash', 'payments', '#006948') returning id into v_cash;
    end if;
    update public.wallets set initial_balance = 9000000 where id = v_cash and initial_balance = 0;
    select id into v_bank from public.wallets where user_id = v_user_id and name = 'Vietcombank';
    if v_bank is null then
        insert into public.wallets (user_id, name, type, icon, color, initial_balance)
        values (v_user_id, 'Vietcombank', 'bank', 'account_balance', '#1B5E20', 25000000) returning id into v_bank;
    end if;
    select id into v_momo from public.wallets where user_id = v_user_id and name = 'Ví MoMo';
    if v_momo is null then
        insert into public.wallets (user_id, name, type, icon, color, initial_balance)
        values (v_user_id, 'Ví MoMo', 'ewallet', 'account_balance_wallet', '#A50064', 6500000) returning id into v_momo;
    end if;

    -- Danh mục (theo tên mặc định; nếu user đã đổi tên thì để trống)
    select id into v_food   from public.categories where user_id = v_user_id and type = 'expense' and name = 'Ăn uống';
    select id into v_market from public.categories where user_id = v_user_id and type = 'expense' and name = 'Đi chợ & Siêu thị';
    select id into v_move   from public.categories where user_id = v_user_id and type = 'expense' and name = 'Di chuyển';
    select id into v_home   from public.categories where user_id = v_user_id and type = 'expense' and name = 'Nhà ở & Tiện ích';
    select id into v_shop   from public.categories where user_id = v_user_id and type = 'expense' and name = 'Mua sắm & Tiêu dùng';
    select id into v_bill   from public.categories where user_id = v_user_id and type = 'expense' and name = 'Hóa đơn & Dịch vụ';
    select id into v_fun    from public.categories where user_id = v_user_id and type = 'expense' and name = 'Giải trí';
    select id into v_salary from public.categories where user_id = v_user_id and type = 'income' and name = 'Lương';
    select id into v_bonus  from public.categories where user_id = v_user_id and type = 'income' and name = 'Thưởng';

    -- 60 ngày giao dịch, random cố định để lần nào chạy cũng ra số giống nhau
    perform setseed(0.42);
    for i in 0..59 loop
        v_day := v_today - i;

        insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
        values
            (v_user_id, v_cash, v_food, 'expense', 25000 + (floor(random() * 6) * 5000)::bigint,
             'Ăn sáng', least(public.vn_day_start(v_day) + interval '7 hours 30 minutes', now()), 'manual'),
            (v_user_id, v_cash, v_food, 'expense', 35000 + (floor(random() * 8) * 5000)::bigint,
             'Cơm trưa', least(public.vn_day_start(v_day) + interval '12 hours', now()), 'voice');

        if random() < 0.5 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_momo, v_food, 'expense', 45000 + (floor(random() * 5) * 5000)::bigint,
                    'Highlands Coffee', least(public.vn_day_start(v_day) + interval '15 hours', now()), 'ai');
        end if;
        if i % 4 = 0 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_cash, v_move, 'expense', 70000 + (floor(random() * 4) * 10000)::bigint,
                    'Đổ xăng Petrolimex', least(public.vn_day_start(v_day) + interval '18 hours', now()), 'ai');
        end if;
        if i % 7 = 3 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_bank, v_market, 'expense', 200000 + (floor(random() * 7) * 50000)::bigint,
                    'Đi chợ cuối tuần', least(public.vn_day_start(v_day) + interval '9 hours', now()), 'receipt');
        end if;
        if random() < 0.12 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_momo, v_shop, 'expense', 150000 + (floor(random() * 14) * 50000)::bigint,
                    'Mua sắm Shopee', least(public.vn_day_start(v_day) + interval '21 hours', now()), 'manual');
        end if;
        if random() < 0.08 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_momo, v_fun, 'expense', 90000 + (floor(random() * 6) * 20000)::bigint,
                    'Xem phim CGV', least(public.vn_day_start(v_day) + interval '20 hours', now()), 'manual');
        end if;
        if extract(day from v_day) = 1 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values
                (v_user_id, v_bank, v_home, 'expense', 4500000, 'Tiền thuê căn hộ',
                 least(public.vn_day_start(v_day) + interval '8 hours', now()), 'manual'),
                (v_user_id, v_bank, v_home, 'expense', 650000, 'Tiền điện nước',
                 least(public.vn_day_start(v_day) + interval '8 hours 5 minutes', now()), 'manual'),
                (v_user_id, v_bank, v_bill, 'expense', 300000, 'Internet & điện thoại',
                 least(public.vn_day_start(v_day) + interval '8 hours 10 minutes', now()), 'manual');
        end if;
        if extract(day from v_day) = 5 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_bank, v_salary, 'income', 15000000, 'Lương tháng',
                    least(public.vn_day_start(v_day) + interval '10 hours', now()), 'manual');
        end if;
        if i = 20 then
            insert into public.transactions (user_id, wallet_id, category_id, type, amount, note, occurred_at, source)
            values (v_user_id, v_bank, v_bonus, 'income', 2000000, 'Thưởng dự án',
                    least(public.vn_day_start(v_day) + interval '16 hours', now()), 'ai');
        end if;
    end loop;

    -- Ngân sách tháng này (tạo sau giao dịch để trigger sinh thông báo nếu đã vượt ngưỡng)
    insert into public.budgets (user_id, category_id, month, limit_amount)
    values
        (v_user_id, null, v_month, 12000000),
        (v_user_id, v_food, v_month, 3000000),
        (v_user_id, v_shop, v_month, 1000000)
    on conflict (user_id, category_id, month) do nothing;

    -- Mục tiêu
    insert into public.goals (user_id, name, icon, color, target_amount, saved_amount, deadline)
    values
        (v_user_id, 'Mua MacBook', 'laptop_mac', '#5C6BC0', 35000000, 12000000, v_today + 180),
        (v_user_id, 'Quỹ khẩn cấp', 'savings', '#26A69A', 30000000, 8500000, null);

    -- Sổ nợ: có khoản đến hạn hôm nay và quá hạn để demo phần nhắc
    insert into public.debts (user_id, person_name, phone, type, amount, paid_amount, due_date, note)
    values
        (v_user_id, 'Minh', '0901234567', 'borrow', 2000000, 500000, v_today + 10, 'Mượn tiền sửa xe'),
        (v_user_id, 'Lan', '0912345678', 'lend', 500000, 0, v_today, 'Cho Lan mượn đóng học'),
        (v_user_id, 'Anh Tuấn', null, 'borrow', 300000, 0, v_today + 1, 'Tiền ăn lẩu hôm trước'),
        (v_user_id, 'Hương', null, 'lend', 600000, 0, v_today - 3, 'Ứng tiền vé concert');

    select count(*) into v_count from public.transactions where user_id = v_user_id;
    return format('Đã tạo dữ liệu demo cho %s: %s giao dịch', p_email, v_count);
end;
$$;

revoke all on function private.seed_demo_data(text, boolean) from public, anon, authenticated;
