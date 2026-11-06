-- =============================================================================
-- Túi Khôn — schema lõi
-- Quy ước:
--   * Tiền lưu BIGINT, đơn vị VND (không có số lẻ).
--   * Mọi bảng dữ liệu người dùng có user_id (mặc định auth.uid()) + RLS (xem migration sau).
--   * Khoá ngoại tới wallets/categories/... dùng cặp (id, user_id) để không thể
--     tham chiếu chéo sang dữ liệu của user khác.
-- =============================================================================

create schema if not exists private;

-- -----------------------------------------------------------------------------
-- Enum
-- -----------------------------------------------------------------------------
create type public.tx_type as enum ('income', 'expense');
create type public.wallet_type as enum ('cash', 'bank', 'ewallet', 'other');
create type public.tx_source as enum ('manual', 'ai', 'voice', 'receipt', 'debt');
create type public.debt_type as enum ('borrow', 'lend');
create type public.debt_status as enum ('active', 'settled');
create type public.goal_status as enum ('active', 'completed', 'cancelled');
create type public.notification_type as enum ('budget', 'reminder', 'debt', 'goal', 'system');
create type public.ai_kind as enum ('chat', 'scan', 'advisor');

-- -----------------------------------------------------------------------------
-- updated_at tự động
-- -----------------------------------------------------------------------------
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- profiles: 1-1 với auth.users, tạo bởi trigger handle_new_user
-- -----------------------------------------------------------------------------
create table public.profiles (
    id                uuid primary key references auth.users (id) on delete cascade,
    email             text,
    display_name      text check (char_length(display_name) <= 100),
    avatar_url        text,
    phone             text check (char_length(phone) <= 20),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- wallets = "Nguồn tiền" tự khai (Tiền mặt, TK Vietcombank, MoMo...).
-- Chỉ là nhãn ghi chép + số dư đầu kỳ; app KHÔNG liên kết ngân hàng.
-- -----------------------------------------------------------------------------
create table public.wallets (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name            text not null check (char_length(name) between 1 and 50),
    type            public.wallet_type not null default 'cash',
    icon            text not null default 'account_balance_wallet',   -- tên Material icon
    color           text check (color ~ '^#[0-9A-Fa-f]{6}$'),
    initial_balance bigint not null default 0,
    is_archived     boolean not null default false,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (id, user_id)
);
create index wallets_user_id_idx on public.wallets (user_id);

-- -----------------------------------------------------------------------------
-- categories
-- -----------------------------------------------------------------------------
create table public.categories (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name       text not null check (char_length(name) between 1 and 50),
    type       public.tx_type not null,
    icon       text not null default 'category',
    color      text not null default '#9E9E9E' check (color ~ '^#[0-9A-Fa-f]{6}$'),
    is_default boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (id, user_id),
    unique (user_id, type, name)
);

-- -----------------------------------------------------------------------------
-- transactions
-- -----------------------------------------------------------------------------
create table public.transactions (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
    wallet_id    uuid not null,
    category_id  uuid,
    type         public.tx_type not null,
    amount       bigint not null check (amount > 0),
    note         text check (char_length(note) <= 255),
    occurred_at  timestamptz not null default now(),
    source       public.tx_source not null default 'manual',
    receipt_path text,                         -- đường dẫn trong bucket receipts
    client_id    uuid unique,                  -- id sinh ở app, chống ghi trùng khi đồng bộ offline
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    unique (id, user_id),
    foreign key (wallet_id, user_id) references public.wallets (id, user_id),
    foreign key (category_id, user_id) references public.categories (id, user_id) on delete set null (category_id)
);
create index transactions_user_occurred_idx on public.transactions (user_id, occurred_at desc);
create index transactions_wallet_idx on public.transactions (wallet_id);
create index transactions_category_idx on public.transactions (category_id);

-- -----------------------------------------------------------------------------
-- budgets: ngân sách theo tháng; category_id null = ngân sách tổng
-- -----------------------------------------------------------------------------
create table public.budgets (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
    category_id  uuid,
    month        date not null check (month = date_trunc('month', month)::date),
    limit_amount bigint not null check (limit_amount > 0),
    alerted_80   boolean not null default false,
    alerted_100  boolean not null default false,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    foreign key (category_id, user_id) references public.categories (id, user_id) on delete cascade,
    unique nulls not distinct (user_id, category_id, month)
);

-- -----------------------------------------------------------------------------
-- goals: mục tiêu tiết kiệm
-- -----------------------------------------------------------------------------
create table public.goals (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name          text not null check (char_length(name) between 1 and 100),
    icon          text not null default 'savings',
    color         text check (color ~ '^#[0-9A-Fa-f]{6}$'),
    target_amount bigint not null check (target_amount > 0),
    saved_amount  bigint not null default 0 check (saved_amount >= 0),
    deadline      date,
    status        public.goal_status not null default 'active',
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);
create index goals_user_id_idx on public.goals (user_id);

-- -----------------------------------------------------------------------------
-- debts: sổ nợ ghi chú (borrow = tôi nợ người khác, lend = người khác nợ tôi).
-- Không tự ảnh hưởng số dư; settle_debt() có thể ghi kèm giao dịch nếu user chọn.
-- -----------------------------------------------------------------------------
create table public.debts (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    person_name text not null check (char_length(person_name) between 1 and 100),
    phone       text check (char_length(phone) <= 20),
    type        public.debt_type not null,
    amount      bigint not null check (amount > 0),
    paid_amount bigint not null default 0 check (paid_amount >= 0),
    due_date    date,
    note        text check (char_length(note) <= 255),
    status      public.debt_status not null default 'active',
    last_reminded_stage text check (last_reminded_stage in ('before', 'due', 'overdue')),  -- mức nhắc đã gửi
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    unique (id, user_id),
    check (paid_amount <= amount)
);
create index debts_user_id_idx on public.debts (user_id);

-- -----------------------------------------------------------------------------
-- notifications (in-app)
-- -----------------------------------------------------------------------------
create table public.notifications (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
    type       public.notification_type not null,
    title      text not null,
    message    text not null,
    data       jsonb not null default '{}'::jsonb,
    is_read    boolean not null default false,
    created_at timestamptz not null default now()
);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- ai_usage: đếm lượt gọi AI theo ngày (giờ VN) để rate limit
-- -----------------------------------------------------------------------------
create table public.ai_usage (
    user_id uuid not null references auth.users (id) on delete cascade,
    day     date not null,
    kind    public.ai_kind not null,
    count   integer not null default 0,
    primary key (user_id, day, kind)
);

-- -----------------------------------------------------------------------------
-- Trigger updated_at
-- -----------------------------------------------------------------------------
create trigger set_updated_at before update on public.profiles
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.wallets
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.categories
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.transactions
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.budgets
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.goals
    for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.debts
    for each row execute function private.set_updated_at();
