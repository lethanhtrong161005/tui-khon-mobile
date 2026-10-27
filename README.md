# 🪙 Túi Khôn — Sổ ghi chép tài chính cá nhân

App Flutter (iOS + Android) giúp **tự ghi chép** thu chi, nợ, ngân sách và mục tiêu tiết kiệm, có trợ lý Gemini AI để ghi nhanh bằng giọng nói, chữ tự nhiên hoặc ảnh hóa đơn.

> Túi Khôn **không phải ví điện tử**: không giữ tiền, không liên kết ngân hàng, không thanh toán. Mọi chức năng miễn phí.
> Nghiệp vụ chi tiết: [docs/NGHIEP_VU.md](docs/NGHIEP_VU.md) · Cài đặt & chạy: [SETUP.md](SETUP.md)

## Chức năng

| Nhóm | Chức năng |
| --- | --- |
| Tài khoản | Đăng ký email + OTP 6 số, đăng nhập email / Google, quên mật khẩu, khoá app bằng Face ID / vân tay, đổi ảnh đại diện |
| Trang chủ | Số dư tổng, thu/chi tháng, ngân sách tháng, giao dịch gần đây, thông báo, hỏi về khoản nợ đến hạn khi mở app |
| Ghi nhanh AI | Gõ hoặc nói ("ăn phở 65k"), quét hóa đơn, nhập tay, sửa trước khi lưu, tự dùng bộ phân tích offline khi AI không khả dụng |
| Lịch sử | Lọc theo tháng / thu chi / danh mục / nguồn tiền, tìm kiếm, sửa, vuốt để xoá, xem ảnh hóa đơn |
| Kế hoạch | **Ngân sách** (tổng / theo danh mục, cảnh báo 80% và 100%), **Sổ nợ** (tôi nợ / nợ tôi, hạn trả, nhắc nhở, trả một phần), **Mục tiêu tiết kiệm** |
| Cố vấn AI | Nhận xét và lời khuyên chi tiêu 30/90 ngày, cơ cấu chi tiêu, dự báo 30 ngày tới |
| Cài đặt | Nguồn tiền tự khai (Tiền mặt, TK ngân hàng, MoMo…), danh mục thu chi |
| Offline & đồng bộ | SQLite/Drift theo từng tài khoản, hàng đợi bền vững, chống gửi trùng, đối chiếu xung đột hai thiết bị |
| Lịch sử trả nợ | Từng lần trả có ngày, số tiền, ghi chú; sửa/hoàn tác cập nhật cả giao dịch liên kết |
| Trao đổi dữ liệu | Xuất CSV UTF-8, nhập có xem trước/ánh xạ/cảnh báo lỗi và trùng, tối đa 10.000 dòng |
| Nhắc & tổng kết | Nhắc ghi chép, khoản phải trả một lần/tuần/tháng, báo cáo tháng offline và nhận xét AI có cache |

## Công nghệ

| Tầng | Công nghệ |
| --- | --- |
| App | Flutter 3.x, Riverpod 2, `supabase_flutter`, `speech_to_text`, `image_picker`, `local_auth`, `flutter_local_notifications` |
| Backend | Supabase: Postgres 17 + Row Level Security, Auth (email OTP, Google), Storage (`receipts` riêng tư, `avatars`), RPC / trigger, pg_cron |
| AI | Google Gemini, chỉ gọi qua Supabase Edge Functions (`ai-quick-record`, `ai-advisor`), key không nằm trong app |
| Dữ liệu local | SQLite qua Drift; ghi local + outbox trong một transaction, RPC `sync_push` / `sync_pull` đồng bộ với Supabase |

## Cấu trúc

```
lib/
├── main.dart                 # khởi tạo Supabase → AuthGate
├── core/                     # config, Supabase providers, services (giọng nói, nhắc nợ, khoá app), widget dùng chung
└── features/
    ├── auth/                 # đăng nhập, đăng ký, OTP, quên mật khẩu, màn khoá app
    ├── home/                 # dashboard, model + repository giao dịch / danh mục / nguồn tiền
    ├── quick_record/         # ghi nhanh AI (chữ, giọng nói, hóa đơn)
    ├── transactions/         # lịch sử giao dịch
    ├── planning/             # ngân sách, sổ nợ, mục tiêu
    ├── advisor/              # cố vấn AI
    ├── settings/             # nguồn tiền, danh mục
    ├── profile/              # hồ sơ, cài đặt
    └── receipt/              # chụp / lưu / xem ảnh hóa đơn
supabase/                     # migrations, Edge Functions, cấu hình (xem supabase/README.md)
test/                         # unit + widget test với repository giả
docs/NGHIEP_VU.md             # nghiệp vụ
SETUP.md                      # hướng dẫn cài đặt, tạo Supabase, chạy app
```

## Chạy nhanh

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter run --dart-define-from-file=.env
```

Chưa có backend? Làm theo [SETUP.md](SETUP.md) (Supabase local bằng Docker hoặc project cloud).

Nâng cấp từ bản trước: xem [docs/OFFLINE_UPGRADE.md](docs/OFFLINE_UPGRADE.md). Áp migration bổ sung trước khi chạy app mới; không reset dữ liệu cũ. Lần đăng nhập đầu tiên cần mạng để tải dữ liệu. Sau đó ghi chép và báo cáo hoạt động từ SQLite; AI cloud vẫn cần kết nối.
