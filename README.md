# Túi Khôn — Sổ ghi chép tài chính cá nhân

Ứng dụng Flutter cho **Android/iOS** để ghi thu/chi, theo dõi ngân sách, nợ và mục tiêu tiết kiệm. Có thể nhập tay, nói tiếng Việt, gõ câu tự nhiên hoặc quét hóa đơn để AI đề xuất trước khi xác nhận.

Túi Khôn không giữ tiền, liên kết ngân hàng hoặc thực hiện thanh toán. Mọi chức năng dùng được mà không mua gói.

- **Cài source, dựng backend, tạo key và chạy app:** [SETUP.md](SETUP.md).
- **Context để tiếp tục trên máy khác:** [docs/HANDOFF.md](docs/HANDOFF.md).
- **Nghiệp vụ:** [docs/NGHIEP_VU.md](docs/NGHIEP_VU.md).
- **Nâng cấp giữ dữ liệu:** [docs/OFFLINE_UPGRADE.md](docs/OFFLINE_UPGRADE.md).
- **Backend và SQL tests:** [supabase/README.md](supabase/README.md), [supabase/tests/README.md](supabase/tests/README.md).

## Chức năng

| Nhóm | Chức năng |
| --- | --- |
| Tài khoản | Email/mật khẩu, OTP 6 số, quên mật khẩu, Google tùy chọn, avatar, khóa Face ID/vân tay |
| Ghi nhanh | Nhập tay, giọng nói, ảnh; AI tối đa 10 bản nháp, hỏi bổ sung từng khoản; sửa/chọn trước khi lưu; cảnh báo trùng |
| Offline | SQLite/Drift riêng từng tài khoản, hàng đợi bền vững, đồng bộ khi có mạng; chọn bản giữ khi hai thiết bị sửa cùng dữ liệu |
| Lịch sử | Lọc tháng/thu chi/danh mục/nguồn tiền, tìm ghi chú, sửa/xóa và xem ảnh hóa đơn |
| Nguồn tiền & danh mục | Nguồn tiền tự khai và số dư đầu; quản lý danh mục, quy tắc phân loại đã học |
| Kế hoạch | Ngân sách tháng tổng/từng danh mục, tiến độ 80%/100%; mục tiêu có nạp/rút số ghi chú |
| Sổ nợ | Vay/cho vay, hạn trả, lịch sử trả từng phần; sửa/hoàn tác cập nhật giao dịch liên kết nếu có |
| Nhắc nhở | Nhắc ghi chép, hạn nợ, khoản phải trả một lần/tuần/tháng; không tự tạo khoản chi khi đến hạn |
| Báo cáo & AI | Báo cáo tháng offline, so sánh tháng trước, nhận xét AI có cache; cố vấn 30/90 ngày |
| CSV | Xuất toàn bộ/theo bộ lọc; nhập tối đa 10.000 giao dịch có xem trước lỗi/trùng và ánh xạ danh mục/nguồn tiền |

## Kiến trúc

```text
Flutter + Riverpod
       |
       v
SQLite / Drift theo tài khoản <--> Hàng đợi đồng bộ
                                         |
                                         v
                             Supabase sync_push / sync_pull
                                         |
                                         v
                                 PostgreSQL + RLS

Flutter --> Supabase Auth / Storage
Flutter --> Edge Functions --> Gemini (key chỉ ở server)
```

Giao diện đọc SQLite, gồm số dư, ngân sách và báo cáo. Mỗi thay đổi được lưu cùng hàng đợi trong một transaction. Supabase xác thực tài khoản, giữ dữ liệu đồng bộ và ảnh; Gemini chạy qua Edge Functions.

**Lần đăng nhập và tải dữ liệu đầu tiên cần mạng.** Sau đó ghi chép dùng được offline. AI cloud, xác thực và đồng bộ vẫn cần kết nối; khi AI không khả dụng, bộ phân tích tiếng Việt trên máy hỗ trợ ghi nhanh cơ bản. Đồng bộ có thể dừng khi hệ điều hành đóng app và tiếp tục khi mở lại.

## Bắt đầu khi lấy project về

### 1. Lấy source và chọn nhánh bàn giao

```sh
git clone --branch feature/offline-ai-history https://github.com/lethanhtrong161005/tui-khon-mobile.git
cd tui-khon-mobile
git branch --show-current
git log -1 --oneline
```

Nhánh bàn giao là **`feature/offline-ai-history`**. `dev` đang là bản khởi tạo;
`feature/supabase-backend` là bản trước offline. Nếu đã clone repo vào nhánh khác:

```sh
git fetch origin
git switch --track origin/feature/offline-ai-history
```

Nếu nhánh local đã tồn tại, dùng `git switch feature/offline-ai-history`.
Đọc [context bàn giao](docs/HANDOFF.md) trước khi tiếp tục dark theme/i18n.
Laptop mới cần dựng backend và env riêng; Git không mang theo tài khoản hoặc DB local.

### 2. Cài dependencies

Theo lockfile: **Flutter ≥3.47 / Dart ≥3.13**; môi trường đã kiểm thử dùng **Flutter 3.47.7**. Node.js ≥20 dùng cho Supabase CLI. Android cần SDK/JDK; iOS cần macOS/Xcode; Docker chỉ bắt buộc khi dựng backend local.

```sh
flutter doctor -v
flutter pub get
flutter test
```

### 3. Dựng backend và tạo env

| Cách | Phù hợp | Env Flutter |
| --- | --- | --- |
| [Supabase cloud](SETUP.md#4-supabase-cloud) | Demo, thiết bị thật, backend dùng chung nhóm | `.env` |
| [Supabase local](SETUP.md#5-supabase-local) | Dev backend trên máy với Docker | `.env.local` |

**Bắt buộc:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` của backend đã áp migrations. Tên biến `SUPABASE_ANON_KEY` giữ theo code; giá trị nên là **publishable key**. **Tùy chọn:** Gemini key ở server để bật AI, OAuth client IDs để đăng nhập Google. Email/nhập tay dùng được khi chưa bật hai phần tùy chọn này.

Làm phần backend và [env/key trong SETUP](SETUP.md#3-env-va-cach-lay-key) trước khi chạy app; chỉ `flutter pub get` chưa đủ.

### 4. Chạy app

```sh
flutter devices
# Thay DEVICE_ID bằng id thực tế; dùng cloud:
flutter run -d DEVICE_ID --dart-define-from-file=.env
```

Với Android emulator + backend local, dùng `.env.local`, URL `http://10.0.2.2:54321`. iOS Simulator dùng `http://127.0.0.1:54321`. [SETUP](SETUP.md#8-chay-app-ide-va-build) có lệnh máy thật, IDE và build APK.

## Cấu trúc

```text
tui-khon-mobile/
├── lib/
│   ├── main.dart                 # Supabase → AuthGate
│   ├── core/
│   │   ├── offline/              # SQLite, outbox, đồng bộ, xung đột, chống trùng
│   │   └── ...                   # Config, providers, services, utils, widgets
│   └── features/
│       ├── auth/                 # Đăng nhập, OTP, khóa app
│       ├── home/                 # Dashboard, dữ liệu ghi chép
│       ├── quick_record/         # AI nhiều bản nháp, quy tắc đã học
│       ├── receipt/              # Chụp, lưu local, upload/xem ảnh
│       ├── transactions/         # Lịch sử giao dịch
│       ├── planning/             # Ngân sách, nợ/lịch sử trả, mục tiêu
│       ├── reminders/            # Khoản phải trả, lịch thông báo
│       ├── statistics/           # Biểu đồ thống kê
│       ├── reports/              # Báo cáo tháng, cache nhận xét AI
│       ├── data_exchange/        # CSV: xuất, xem trước, ánh xạ, nhập
│       ├── advisor/              # Cố vấn 30/90 ngày
│       ├── settings/             # Nguồn tiền, danh mục
│       └── profile/              # Hồ sơ, cài đặt
├── android/                      # Nền tảng Android
├── ios/                          # Nền tảng iOS
├── supabase/
│   ├── migrations/               # Schema, RLS, RPC, journal
│   ├── functions/                # ai-quick-record, ai-advisor
│   ├── templates/                # Email OTP
│   ├── tests/                    # SQL tests cô lập
│   └── config.toml               # Cấu hình local
├── test/                         # Flutter unit/widget tests
├── docs/                         # HANDOFF, nghiệp vụ, hướng dẫn nâng cấp
├── .env.example                  # Mẫu Flutter, không chứa key thật
├── AGENTS.md                     # Điểm bắt đầu cho coding agent
├── README.md
└── SETUP.md
```

## Kiểm tra và nâng cấp

```sh
flutter analyze --no-fatal-infos
flutter test
```

[SETUP](SETUP.md#9-kiem-tra-sau-setup) có kiểm thử SQL/Edge Functions và checklist nghiệm thu. DB đã có dữ liệu cần áp migration bổ sung theo [OFFLINE_UPGRADE](docs/OFFLINE_UPGRADE.md); không reset dữ liệu cần giữ. Không commit env đã điền key.

Để test đăng ký/OTP/email mà chưa có project cloud, xem phần **Chạy thử ngay với backend local** cuối [SETUP.md](SETUP.md). Chạy app bằng `.env.local`; OTP xem trong Mailpit. Google và Gemini cần cấu hình riêng trước khi thử thật.
