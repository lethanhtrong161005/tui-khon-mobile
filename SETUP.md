# Hướng dẫn cài đặt & chạy Túi Khôn

Repo này chứa cả **app Flutter** (`lib/`) và **backend Supabase** (`supabase/`).
Nghiệp vụ xem ở [docs/NGHIEP_VU.md](docs/NGHIEP_VU.md).

**Nâng cấp bản offline từ project có sẵn dữ liệu:** đọc [docs/OFFLINE_UPGRADE.md](docs/OFFLINE_UPGRADE.md). App dùng SQLite/Drift và RPC đồng bộ, cần áp migration bổ sung trước khi chạy bản mới. Không reset DB cần giữ.

```
tui-khon-mobile/
├── lib/                    # App Flutter (iOS + Android)
│   ├── core/               # cấu hình, service (giọng nói, nhắc nợ, khoá app), widget dùng chung
│   └── features/           # auth, home, quick_record, planning, transactions, settings, advisor, profile, receipt
├── supabase/
│   ├── migrations/         # schema, RLS, trigger, RPC, cron nhắc nợ, dữ liệu demo
│   ├── functions/          # Edge Functions gọi Gemini: ai-quick-record, ai-advisor
│   ├── templates/          # mẫu email OTP
│   └── config.toml         # cấu hình Supabase local
├── test/                   # unit + widget test (không cần backend)
└── .env.example            # biến môi trường của app
```

---

## 1. Cài công cụ

| Công cụ | Phiên bản | Dùng để |
| --- | --- | --- |
| Flutter SDK | ≥ 3.35 (đang dùng 3.47) | build app |
| Android Studio + Android SDK 34+ | | chạy Android emulator / máy thật |
| Xcode 15+ (chỉ macOS) | | chạy iOS |
| Node.js | ≥ 18 | chạy Supabase CLI qua `npx supabase …` |
| Docker Desktop | | **chỉ khi** chạy Supabase local |
| Git | | |

Kiểm tra môi trường:

```bash
flutter doctor
```

```bash
npx supabase --version
```

## 2. Lấy mã nguồn & cài thư viện

```bash
git clone <url-repo> tui-khon-mobile
```

```bash
cd tui-khon-mobile
```

```bash
flutter pub get
```

Chạy test để chắc mọi thứ ổn. Test dùng dữ liệu giả, không cần backend:

```bash
flutter test
```

---

## 3. Dựng backend Supabase

Có 2 cách. **Cách A** để dev hằng ngày trên máy, không tốn gì. **Cách B** để demo hoặc dùng chung cả nhóm.

### Cách A — Supabase chạy local bằng Docker

1. Mở Docker Desktop.
2. Ở thư mục gốc repo, khởi động Supabase:
   ```bash
   npx supabase start
   ```
   - Lần đầu sẽ tải khoảng 2–3 GB image.
   - Lệnh này tự áp toàn bộ `supabase/migrations/` và in ra:
     - `API_URL` (http://127.0.0.1:54321)
     - `PUBLISHABLE_KEY` (hoặc `ANON_KEY`)
     - `STUDIO_URL` (http://127.0.0.1:54323): giao diện quản trị database
     - `MAILPIT_URL` (http://127.0.0.1:54324): hộp thư giả để đọc mã OTP
   - Nếu CLI báo thiếu `GOOGLE_CLIENT_IDS`, đặt tạm hai biến này trước khi chạy:
     ```bash
     export GOOGLE_CLIENT_IDS=local-dummy GOOGLE_CLIENT_SECRET=local-dummy
     ```
     (PowerShell: `$env:GOOGLE_CLIENT_IDS='local-dummy'; $env:GOOGLE_CLIENT_SECRET='local-dummy'`)
3. (Tuỳ chọn) Bật AI: tạo `supabase/functions/.env` chứa:
   ```
   GEMINI_API_KEY=<key lấy ở https://aistudio.google.com/app/apikey>
   ```
   Chạy `npx supabase functions serve --env-file supabase/functions/.env`. Không có key thì Ghi nhanh vẫn chạy bằng bộ phân tích offline.
4. Có migration mới thì áp bổ sung, giữ dữ liệu local:
   ```bash
   npx supabase migration up --local
   ```
   Chỉ dùng `npx supabase db reset` cho môi trường test trống mà bạn chủ động muốn xoá hết dữ liệu.
5. Tạo file `.env.local` cho app (đã nằm trong `.gitignore`):
   ```
   # Android emulator truy cập máy host qua 10.0.2.2; iOS Simulator dùng 127.0.0.1
   SUPABASE_URL=http://10.0.2.2:54321
   SUPABASE_ANON_KEY=<PUBLISHABLE_KEY in ra ở bước 2>
   GOOGLE_WEB_CLIENT_ID=
   GOOGLE_IOS_CLIENT_ID=
   ```
   Bản debug Android đã cho phép HTTP thường (xem `android/app/src/debug/AndroidManifest.xml`), nên kết nối được tới Supabase local.

### Cách B — Tạo project Supabase trên cloud

1. **Tạo project**:
   - Vào https://supabase.com → **New project**.
   - Đặt tên `tui-khon`, chọn region **Southeast Asia (Singapore)**, đặt mật khẩu database (lưu lại).
   - Đợi khoảng 2 phút cho project khởi tạo.
2. **Liên kết repo với project**:
   - Lấy `project-ref` ở Project Settings → General (chuỗi dạng `abcdxyz…`).
   - Chạy lần lượt:
     ```bash
     npx supabase login
     ```
     ```bash
     npx supabase link --project-ref <project-ref>
     ```
3. **Tạo database**:
   ```bash
   npx supabase db push
   ```
   Lệnh này tạo các bảng, RLS, trigger, RPC, bucket `receipts` / `avatars` và lịch pg_cron nhắc nợ.
   - Kiểm tra *Database → Extensions* đã bật `pg_cron`.
   - Kiểm tra *Integrations → Cron* có job `tuikhon-debt-reminders`.
   - Nếu chưa có: bật `pg_cron` rồi chạy lại đoạn `do $$ … $$` cuối file `supabase/migrations/…_debt_reminders_cron.sql` trong SQL Editor.
4. **Gemini (AI)**:
   - Tạo `supabase/.env` từ `supabase/.env.example`, điền `GEMINI_API_KEY` (để trống `GEMINI_MODEL` thì dùng `gemini-flash-latest`).
   - Đẩy secrets và deploy hai Edge Function:
     ```bash
     npx supabase secrets set --env-file supabase/.env
     ```
     ```bash
     npx supabase functions deploy ai-quick-record ai-advisor
     ```
5. **Cấu hình đăng nhập** trong Dashboard → *Authentication*:
   - **Sign In / Providers → Email**:
     - Bật *Confirm email*.
     - *Email OTP Length* = 6, *Email OTP Expiration* = 600 giây.
   - **Emails → Templates**:
     - Sửa *Confirm signup* và *Reset password*, dán nội dung từ `supabase/templates/confirmation.html` và `recovery.html`.
     - Bắt buộc có `{{ .Token }}` để gửi **mã 6 số** thay cho link.
   - **Emails → SMTP Settings**: **bắt buộc** cấu hình SMTP riêng (Resend, hoặc Gmail App Password). SMTP mặc định của Supabase chỉ gửi vài email mỗi giờ.
   - **Providers → Google** (nếu dùng):
     - Bật provider.
     - *Client IDs*: Web client ID đứng đầu, sau đó iOS / Android client ID, ngăn cách bằng dấu phẩy.
     - Bật *Skip nonce checks*.
6. **Lấy key cho app**: Project Settings → **API** → copy *Project URL* và khoá **anon / publishable**.
   - Tuyệt đối **không** dùng `service_role` / secret key trong app.
   - Tạo `.env` từ `.env.example`:
     ```
     SUPABASE_URL=https://<project-ref>.supabase.co
     SUPABASE_ANON_KEY=<anon hoặc publishable key>
     GOOGLE_WEB_CLIENT_ID=<Web client ID>
     GOOGLE_IOS_CLIENT_ID=<iOS client ID>
     ```
7. Gói free của Supabase sẽ **tạm dừng project sau 7 ngày không có request**. Mở dashboard trước buổi demo để đánh thức.

### Google Sign-In (tuỳ chọn)
1. Vào Google Cloud Console → *APIs & Services → Credentials* → tạo **OAuth client ID** cho từng nền tảng:
   - **Web**: dùng làm `GOOGLE_WEB_CLIENT_ID` và nhập ở Supabase.
   - **iOS**: bundle id `com.example.tuiKhonMobile` (xem trong Xcode), dùng làm `GOOGLE_IOS_CLIENT_ID`.
   - **Android**: package `com.example.tui_khon_mobile` + SHA-1. Lấy SHA-1 bằng lệnh `cd android && ./gradlew signingReport`.
2. iOS: thêm *reversed iOS client ID* (`com.googleusercontent.apps.xxxx`) vào `ios/Runner/Info.plist` → `CFBundleURLTypes`.

---

## 4. Chạy app

```bash
flutter devices
```

Android emulator + Supabase local:

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env.local
```

Supabase cloud (máy thật hoặc emulator):

```bash
flutter run --dart-define-from-file=.env
```

Bấm `r` trong terminal để hot reload.

Chạy từ Android Studio / VS Code: thêm `--dart-define-from-file=.env.local` vào *Additional run args* của Run Configuration. Thiếu tham số này, app sẽ hiện màn "Thiếu cấu hình Supabase".

### Thử nhanh với dữ liệu demo
1. Đăng ký tài khoản trong app.
   - Supabase local: mở Mailpit (http://127.0.0.1:54324) để lấy mã OTP.
   - Supabase cloud: mã gửi vào email thật.
2. Mở SQL Editor (Studio local hoặc Dashboard cloud), chạy:
   ```sql
   select private.seed_demo_data('<email vừa đăng ký>');
   ```
   Chỉ chạy cho tài khoản demo mới, chưa sửa dữ liệu. Bản nâng cấp từ chối reset hoặc nạp lại để giữ dữ liệu đã ghi. Lệnh tạo 60 ngày giao dịch, 3 nguồn tiền, ngân sách, mục tiêu và các khoản nợ (có khoản đến hạn hôm nay và đã quá hạn).
3. Kéo màn hình Trang chủ xuống để tải lại. Hộp "Khoản nợ đã đến hạn" sẽ hiện.
4. Chạy tay job nhắc nợ của server (thay cho cron lúc 08:00):
   ```sql
   select private.process_debt_reminders();
   ```

### Thử tính năng phần cứng trên emulator
- **Vân tay**:
  - Cài vân tay cho máy ảo: Settings → Security → Fingerprint.
  - Trong app: Cá nhân → bật "Khoá bằng Face ID / vân tay".
  - Khi app hỏi, giả lập chạm vân tay: Extended controls (⋯) → Fingerprint → *Touch sensor*.
- **Mic**: Extended controls → Microphone → bật *Virtual microphone uses host audio input*.
- **Camera / ảnh hóa đơn**: dùng camera ảo của emulator, hoặc kéo ảnh vào emulator rồi chọn từ thư viện.

---

## 5. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Màn "Thiếu cấu hình Supabase" | Chạy thiếu `--dart-define-from-file=…`. |
| Đăng nhập báo "Không có kết nối mạng" trên emulator | Dùng `10.0.2.2` chứ không phải `127.0.0.1`. Kiểm tra `npx supabase status` xem Supabase local còn chạy không. |
| Không nhận được email OTP (cloud) | Chưa cấu hình SMTP riêng, hoặc mail rơi vào Spam. |
| AI luôn báo "đang bận" / dùng bộ phân tích offline | Chưa đặt `GEMINI_API_KEY` hoặc chưa deploy Edge Functions. |
| Không có thông báo nhắc nợ trên máy | Android 13+: cấp quyền Thông báo cho app. Lịch chỉ được đặt cho hạn trả trong tương lai. |
| `flutter build` lỗi desugaring | Không xoá khối `coreLibraryDesugaring` trong `android/app/build.gradle.kts` (thư viện thông báo cần nó). |
