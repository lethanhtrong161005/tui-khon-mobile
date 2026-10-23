-- =============================================================================
-- Hàm, trigger, view, RPC
--   public.*  : app gọi được qua supabase.rpc(...) — chạy SECURITY INVOKER nên vẫn chịu RLS
--   private.* : nội bộ (trigger, cron) — không lộ ra API
-- Múi giờ nghiệp vụ: Asia/Ho_Chi_Minh.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tiện ích
-- -----------------------------------------------------------------------------
create function public.vn_today()
returns date
language sql
stable
set search_path = ''
as $$
    select (now() at time zone 'Asia/Ho_Chi_Minh')::date;
$$;

-- 00:00 giờ VN của một ngày, dạng timestamptz
create function public.vn_day_start(p_day date)
returns timestamptz
language sql
stable
set search_path = ''
as $$
    select p_day::timestamp at time zone 'Asia/Ho_Chi_Minh';
$$;

-- 1200000 -> '1.200.000đ'
create function public.format_vnd(p_amount bigint)
returns text
language sql
immutable
set search_path = ''
as $$
    select replace(to_char(p_amount, 'FM999,999,999,999,999,990'), ',', '.') || 'đ';
$$;

create function private.vn_month_of(p_ts timestamptz)
returns date
language sql
stable
set search_path = ''
as $$
    select date_trunc('month', p_ts at time zone 'Asia/Ho_Chi_Minh')::date;
$$;

-- Tổng chi của một ngân sách trong tháng (category null = tất cả danh mục)
create function public.budget_spent(p_user_id uuid, p_category_id uuid, p_month date)
returns bigint
language sql
stable
set search_path = ''
as $$
    select coalesce(sum(t.amount), 0)::bigint
    from public.transactions t
    where t.user_id = p_user_id
      and t.type = 'expense'
      and (p_category_id is null or t.category_id = p_category_id)
      and t.occurred_at >= public.vn_day_start(p_month)
      and t.occurred_at < public.vn_day_start((p_month + interval '1 month')::date);
$$;

-- -----------------------------------------------------------------------------
-- Đăng ký: tạo profile, ví "Tiền mặt" và danh mục mặc định
-- Icon là tên Material icon để app map sang IconData.
-- -----------------------------------------------------------------------------
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, email, display_name, avatar_url)
    values (
        new.id,
        new.email,
        left(coalesce(
            nullif(new.raw_user_meta_data ->> 'display_name', ''),
            nullif(new.raw_user_meta_data ->> 'full_name', ''),
            nullif(new.raw_user_meta_data ->> 'name', ''),
            split_part(new.email, '@', 1)
        ), 100),
        coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
    );

    insert into public.wallets (user_id, name, type, icon, color)
    values (new.id, 'Tiền mặt', 'cash', 'payments', '#006948');

    insert into public.categories (user_id, name, type, icon, color, is_default)
    select new.id, c.name, c.type::public.tx_type, c.icon, c.color, true
    from (values
        ('Ăn uống',             'expense', 'restaurant',          '#FF7043'),
        ('Đi chợ & Siêu thị',   'expense', 'local_grocery_store', '#9CCC65'),
        ('Di chuyển',           'expense', 'local_gas_station',   '#42A5F5'),
        ('Nhà ở & Tiện ích',    'expense', 'home_work',           '#8D6E63'),
        ('Mua sắm & Tiêu dùng', 'expense', 'shopping_bag',        '#AB47BC'),
        ('Hóa đơn & Dịch vụ',   'expense', 'receipt_long',        '#EF5350'),
        ('Giải trí',            'expense', 'sports_esports',      '#FFA726'),
        ('Sức khỏe',            'expense', 'local_hospital',      '#66BB6A'),
        ('Giáo dục',            'expense', 'school',              '#5C6BC0'),
        ('Du lịch',             'expense', 'flight',              '#26A69A'),
        ('Quà tặng & Hiếu hỷ',  'expense', 'card_giftcard',       '#EC407A'),
        ('Bảo hiểm',            'expense', 'shield',              '#26C6DA'),
        ('Đầu tư',              'expense', 'trending_up',         '#7E57C2'),
        ('Cho vay & Trả nợ',    'expense', 'handshake',           '#78909C'),
        ('Chi tiêu khác',       'expense', 'payments',            '#BDBDBD'),
        ('Lương',               'income',  'payments',            '#4CAF50'),
        ('Thưởng',              'income',  'stars',               '#E91E63'),
        ('Kinh doanh',          'income',  'storefront',          '#FF9800'),
        ('Làm thêm',            'income',  'work',                '#03A9F4'),
        ('Đầu tư & Lãi',        'income',  'savings',             '#9C27B0'),
        ('Thu nợ',              'income',  'request_quote',       '#009688'),
        ('Thu nhập khác',       'income',  'celebration',         '#607D8B')
    ) as c (name, type, icon, color);

    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function private.handle_new_user();

-- -----------------------------------------------------------------------------
-- Số dư ví
-- -----------------------------------------------------------------------------
create view public.wallet_balances
with (security_invoker = true)
as
select
    w.id as wallet_id,
    w.user_id,
    w.name,
    w.type,
    w.icon,
    w.color,
    w.is_archived,
    w.initial_balance,
    w.created_at,
    (w.initial_balance
        + coalesce(sum(case t.type when 'income' then t.amount else -t.amount end), 0))::bigint as balance
from public.wallets w
left join public.transactions t on t.wallet_id = w.id
group by w.id;

-- -----------------------------------------------------------------------------
-- Thống kê: get_period_summary(từ ngày, đến ngày) — ngày VN, bao gồm cả 2 đầu
-- -----------------------------------------------------------------------------
create function public.get_period_summary(p_from date, p_to date)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
    with tx as (
        select t.type, t.amount, t.category_id,
               (t.occurred_at at time zone 'Asia/Ho_Chi_Minh')::date as day
        from public.transactions t
        where t.user_id = (select auth.uid())
          and t.occurred_at >= public.vn_day_start(p_from)
          and t.occurred_at < public.vn_day_start(p_to + 1)
    ),
    by_category as (
        select tx.type, tx.category_id, c.name, c.icon, c.color,
               sum(tx.amount)::bigint as total, count(*) as count
        from tx
        left join public.categories c on c.id = tx.category_id
        group by tx.type, tx.category_id, c.name, c.icon, c.color
    ),
    by_day as (
        select tx.day,
               coalesce(sum(tx.amount) filter (where tx.type = 'income'), 0)::bigint as income,
               coalesce(sum(tx.amount) filter (where tx.type = 'expense'), 0)::bigint as expense
        from tx
        group by tx.day
    )
    select jsonb_build_object(
        'from', p_from,
        'to', p_to,
        'income', (select coalesce(sum(amount), 0)::bigint from tx where type = 'income'),
        'expense', (select coalesce(sum(amount), 0)::bigint from tx where type = 'expense'),
        'transaction_count', (select count(*) from tx),
        'by_category', coalesce((select jsonb_agg(to_jsonb(b) order by b.total desc) from by_category b), '[]'::jsonb),
        'by_day', coalesce((select jsonb_agg(to_jsonb(d) order by d.day) from by_day d), '[]'::jsonb)
    );
$$;

-- Dashboard / Stats: tháng hiện tại (hoặc p_month) + so sánh tháng trước + ngân sách + tổng số dư
create function public.get_monthly_summary(p_month date default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
    v_start date := date_trunc('month', coalesce(p_month, public.vn_today()))::date;
    v_end   date := (v_start + interval '1 month')::date - 1;
    v_prev  jsonb;
begin
    v_prev := public.get_period_summary((v_start - interval '1 month')::date, v_start - 1);

    return public.get_period_summary(v_start, v_end) || jsonb_build_object(
        'month', v_start,
        'previous', jsonb_build_object('income', v_prev -> 'income', 'expense', v_prev -> 'expense'),
        'total_balance', (
            select coalesce(sum(wb.balance), 0)::bigint
            from public.wallet_balances wb
            where not wb.is_archived
        ),
        'budgets', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', b.id,
                'category_id', b.category_id,
                'category_name', c.name,
                'limit_amount', b.limit_amount,
                'spent', public.budget_spent(b.user_id, b.category_id, b.month)
            ) order by b.category_id nulls first)
            from public.budgets b
            left join public.categories c on c.id = b.category_id
            where b.user_id = (select auth.uid()) and b.month = v_start
        ), '[]'::jsonb)
    );
end;
$$;

-- -----------------------------------------------------------------------------
-- Cảnh báo ngân sách 80% / 100%: chỉ báo ở lần vượt ngưỡng, tự reset khi chi giảm lại
-- -----------------------------------------------------------------------------
create function private.refresh_budget_alerts(p_user_id uuid, p_month date)
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
        where bu.user_id = p_user_id and bu.month = p_month
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

create function private.on_transaction_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_old_month date;
    v_new_month date;
begin
    if tg_op <> 'INSERT' and old.type = 'expense' then
        v_old_month := private.vn_month_of(old.occurred_at);
    end if;
    if tg_op <> 'DELETE' and new.type = 'expense' then
        v_new_month := private.vn_month_of(new.occurred_at);
    end if;

    if v_old_month is not null and v_old_month is distinct from v_new_month then
        perform private.refresh_budget_alerts(old.user_id, v_old_month);
    end if;
    if v_new_month is not null then
        perform private.refresh_budget_alerts(new.user_id, v_new_month);
    end if;
    return null;
end;
$$;

create trigger budget_alerts
    after insert or delete or update of type, amount, category_id, occurred_at on public.transactions
    for each row execute function private.on_transaction_change();

create function private.on_budget_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform private.refresh_budget_alerts(new.user_id, new.month);
    return null;
end;
$$;

create trigger budget_alerts
    after insert or update of limit_amount, category_id, month on public.budgets
    for each row execute function private.on_budget_change();

-- -----------------------------------------------------------------------------
-- Sổ nợ: ghi trả một phần / trả hết.
-- p_amount null = trả hết phần còn lại. Nếu p_record_transaction: ghi kèm giao dịch
-- (tôi trả nợ → chi "Cho vay & Trả nợ"; người khác trả tôi → thu "Thu nợ").
-- -----------------------------------------------------------------------------
create function public.settle_debt(
    p_debt_id            uuid,
    p_amount             bigint default null,
    p_record_transaction boolean default false,
    p_wallet_id          uuid default null
)
returns public.debts
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_debt        public.debts;
    v_remaining   bigint;
    v_pay         bigint;
    v_wallet_id   uuid;
    v_category_id uuid;
begin
    select * into v_debt from public.debts where id = p_debt_id for update;
    if not found then
        raise exception 'Không tìm thấy khoản nợ' using errcode = 'P0002';
    end if;
    if v_debt.status = 'settled' then
        return v_debt;
    end if;

    v_remaining := v_debt.amount - v_debt.paid_amount;
    v_pay := coalesce(p_amount, v_remaining);
    if v_pay <= 0 or v_pay > v_remaining then
        raise exception 'Số tiền trả không hợp lệ (còn lại %)', v_remaining using errcode = '22023';
    end if;

    update public.debts
    set paid_amount = paid_amount + v_pay,
        status = case when paid_amount + v_pay >= amount then 'settled'::public.debt_status else 'active' end
    where id = p_debt_id
    returning * into v_debt;

    if p_record_transaction then
        v_wallet_id := coalesce(
            p_wallet_id,
            (select id from public.wallets where not is_archived order by created_at limit 1)
        );
        select id into v_category_id
        from public.categories
        where (v_debt.type = 'borrow' and type = 'expense' and name = 'Cho vay & Trả nợ')
           or (v_debt.type = 'lend' and type = 'income' and name = 'Thu nợ')
        limit 1;

        insert into public.transactions (wallet_id, category_id, type, amount, note, source)
        values (
            v_wallet_id,
            v_category_id,
            case v_debt.type when 'borrow' then 'expense'::public.tx_type else 'income'::public.tx_type end,
            v_pay,
            left(case v_debt.type when 'borrow' then 'Trả nợ ' else 'Thu nợ từ ' end || v_debt.person_name, 255),
            'debt'
        );
    end if;

    return v_debt;
end;
$$;

-- Đổi hạn trả thì nhắc lại từ đầu
create function private.on_debt_due_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.due_date is distinct from old.due_date then
        new.last_reminded_stage := null;
    end if;
    return new;
end;
$$;

create trigger debt_due_change
    before update of due_date on public.debts
    for each row execute function private.on_debt_due_change();

-- -----------------------------------------------------------------------------
-- Mục tiêu: tự chuyển "completed" khi để dành đủ (và ngược lại khi rút bớt)
-- -----------------------------------------------------------------------------
create function private.on_goal_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

create trigger goal_progress
    before insert or update of saved_amount, target_amount on public.goals
    for each row execute function private.on_goal_change();

-- -----------------------------------------------------------------------------
-- Rate limit AI: tăng bộ đếm trong ngày (giờ VN) nếu còn lượt
-- Trả về {"allowed": bool, "used": n, "limit": n}
-- -----------------------------------------------------------------------------
create function public.consume_ai_quota(p_kind public.ai_kind)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_limit   integer := case p_kind when 'chat' then 50 when 'scan' then 20 when 'advisor' then 10 end;
    v_count   integer;
begin
    if v_user_id is null then
        raise exception 'Chưa đăng nhập' using errcode = '42501';
    end if;

    insert into public.ai_usage as u (user_id, day, kind, count)
    values (v_user_id, public.vn_today(), p_kind, 1)
    on conflict (user_id, day, kind) do update
        set count = u.count + 1
        where u.count < v_limit
    returning u.count into v_count;

    return jsonb_build_object(
        'allowed', v_count is not null,
        'used', coalesce(v_count, v_limit),
        'limit', v_limit
    );
end;
$$;

-- -----------------------------------------------------------------------------
-- Quyền gọi hàm: chỉ user đã đăng nhập
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant execute on function
    public.vn_today(),
    public.vn_day_start(date),
    public.format_vnd(bigint),
    public.budget_spent(uuid, uuid, date),
    public.get_period_summary(date, date),
    public.get_monthly_summary(date),
    public.settle_debt(uuid, bigint, boolean, uuid),
    public.consume_ai_quota(public.ai_kind)
to authenticated;
