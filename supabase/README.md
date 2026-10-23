# Túi Khôn — Backend (Supabase)

Backend không có API server riêng.
- App Flutter đọc/ghi thẳng các bảng qua `supabase_flutter`. **Row Level Security** đảm bảo mỗi user chỉ chạm được dữ liệu của mình.
- Logic nhiều bước nằm ở **RPC / trigger** Postgres.
- Gemini chỉ được gọi từ **Edge Functions**, key nằm trong Supabase secrets.

Cách tạo project và deploy: xem [../SETUP.md](../SETUP.md) mục 3.

## Migrations

| File | Nội dung |
| --- | --- |
| `…01_init_schema.sql` | Bảng `profiles`, `wallets` (nguồn tiền), `categories`, `transactions`, `budgets`, `goals`, `debts`, `notifications`, `ai_usage`. Khoá ngoại theo cặp `(id, user_id)` nên không tham chiếu chéo được sang dữ liệu user khác. |
| `…02_rls_policies.sql` | RLS cho mọi bảng. Hồ sơ chỉ sửa được `display_name`, `avatar_url`, `phone`. Bucket `receipts` (riêng tư) và `avatars` (công khai), user chỉ ghi được vào thư mục `{user_id}/`. |
| `…03_functions_triggers.sql` | Tạo hồ sơ + nguồn tiền "Tiền mặt" + 22 danh mục khi đăng ký; view `wallet_balances`; thống kê; cảnh báo ngân sách 80% / 100%; `settle_debt`; mục tiêu tự hoàn thành; giới hạn lượt AI. |
| `…04_debt_reminders_cron.sql` | `private.process_debt_reminders()` + pg_cron 08:00 giờ VN: nhắc trước hạn 1 ngày, đúng ngày, quá hạn (mỗi mức một lần). |
| `…05_demo_data.sql` | `private.seed_demo_data(email, reset)` nạp dữ liệu demo cho một tài khoản. |

## App gọi gì

| Việc | Gọi |
| --- | --- |
| CRUD | `from('transactions' / 'categories' / 'wallets' / 'budgets' / 'debts' / 'goals')`, không cần gửi `user_id` |
| Số dư từng nguồn tiền | `from('wallet_balances')` |
| Dashboard, ngân sách tháng | `rpc('get_monthly_summary', {p_month})` |
| Thống kê khoảng ngày | `rpc('get_period_summary', {p_from, p_to})` |
| Trả nợ | `rpc('settle_debt', {p_debt_id, p_amount (null = trả hết), p_record_transaction})` |
| Thông báo | `from('notifications')` |
| AI ghi nhanh / quét hóa đơn | `functions.invoke('ai-quick-record', body: {text, source} hoặc {imageBase64, mimeType})`, trả về bản nháp và **không** ghi DB |
| Cố vấn AI | `functions.invoke('ai-advisor', body: {range: 30 \| 90})` |
| Ảnh | `storage.from('receipts')` (xem qua signed URL 15 phút), `storage.from('avatars')` |

Edge Functions trả lỗi dạng `{ success: false, error: { code, message, details } }`. `message` là câu tiếng Việt, hiện thẳng cho user được. Hết lượt AI trong ngày thì trả về `429 RATE_LIMIT_EXCEEDED`.

## Lệnh hay dùng

| Việc | Lệnh |
| --- | --- |
| Khởi động / dừng Supabase local | `npx supabase start` / `npx supabase stop` |
| Áp lại migration local (xoá dữ liệu) | `npx supabase db reset` |
| Đẩy migration lên cloud | `npx supabase db push` |
| Deploy Edge Functions | `npx supabase functions deploy ai-quick-record ai-advisor` |
| Đặt secrets (Gemini) | `npx supabase secrets set --env-file supabase/.env` |

Chạy tay trong SQL Editor:

```sql
select private.seed_demo_data('demo@tuikhon.vn');  -- dữ liệu demo
select private.process_debt_reminders();           -- job nhắc nợ
```
