-- =============================================================================
-- Row Level Security: mỗi user chỉ đọc/ghi dữ liệu của chính mình.
-- Dùng (select auth.uid()) để Postgres chỉ tính 1 lần mỗi câu lệnh.
-- =============================================================================

-- Bảng có toàn quyền CRUD trên dữ liệu của mình
do $$
declare
    t text;
begin
    foreach t in array array[
        'wallets', 'categories', 'transactions', 'budgets', 'goals', 'debts'
    ]
    loop
        execute format('alter table public.%I enable row level security', t);
        execute format(
            'create policy "own rows" on public.%I for all to authenticated '
            'using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',
            t
        );
    end loop;
end;
$$;

-- profiles: tạo bởi trigger, user chỉ xem và sửa hồ sơ của mình
alter table public.profiles enable row level security;
create policy "read own profile" on public.profiles for select to authenticated
    using (id = (select auth.uid()));
create policy "update own profile" on public.profiles for update to authenticated
    using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- Chỉ cho sửa các cột hồ sơ; id/email do server quản lý
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, avatar_url, phone)
    on public.profiles to authenticated;

-- notifications: hệ thống tạo (trigger security definer), user xem / đánh dấu đã đọc / xoá
alter table public.notifications enable row level security;
create policy "read own notifications" on public.notifications for select to authenticated
    using (user_id = (select auth.uid()));
create policy "update own notifications" on public.notifications for update to authenticated
    using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "delete own notifications" on public.notifications for delete to authenticated
    using (user_id = (select auth.uid()));

-- ai_usage: chỉ xem; ghi qua hàm consume_ai_quota (security definer)
alter table public.ai_usage enable row level security;
create policy "read own ai usage" on public.ai_usage for select to authenticated
    using (user_id = (select auth.uid()));

-- Bảng nội bộ không cho anon chạm vào
revoke all on all tables in schema public from anon;

-- Schema private không lộ ra API
revoke all on schema private from public, anon, authenticated;

-- =============================================================================
-- Storage: bucket private "receipts", file nằm ở {user_id}/{tên file}
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

create policy "receipts: read own" on storage.objects for select to authenticated
    using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "receipts: upload own" on storage.objects for insert to authenticated
    with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "receipts: update own" on storage.objects for update to authenticated
    using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "receipts: delete own" on storage.objects for delete to authenticated
    using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =============================================================================
-- Storage: bucket public "avatars", mỗi user chỉ ghi vào {user_id}/
-- (ảnh đại diện không nhạy cảm nên cho đọc công khai qua URL)
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "avatars: upload own" on storage.objects for insert to authenticated
    with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars: update own" on storage.objects for update to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars: delete own" on storage.objects for delete to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
-- upsert cần đọc được object hiện có
create policy "avatars: read own" on storage.objects for select to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
