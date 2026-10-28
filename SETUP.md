# Cài đặt, tạo key và chạy source Túi Khôn

Hướng dẫn cho người nhận source lần đầu. Repo có app Flutter và backend Supabase; không cần Java backend riêng, Firebase hoặc dịch vụ thanh toán. Giao diện dùng SQLite/Drift trên thiết bị rồi đồng bộ với Supabase.

Nếu đã có DB của bản cũ, đọc [hướng dẫn nâng cấp giữ dữ liệu](docs/OFFLINE_UPGRADE.md) trước. Chạy lệnh từ thư mục chứa `pubspec.yaml`, trừ khi khối lệnh ghi rõ chuyển thư mục.

## Mục lục

1. [Công cụ](#1-cong-cu)
2. [Lấy source và chọn nhánh](#2-lay-source-va-chon-nhanh)
3. [Env và cách lấy key](#3-env-va-cach-lay-key)
4. [Supabase cloud](#4-supabase-cloud)
5. [Supabase local](#5-supabase-local)
6. [Gemini](#6-tao-gemini-key-tuy-chon)
7. [Google Sign-In](#7-google-sign-in-tuy-chon)
8. [Chạy app, IDE và build](#8-chay-app-ide-va-build)
9. [Kiểm tra](#9-kiem-tra-sau-setup)
10. [Lỗi thường gặp](#10-loi-thuong-gap)

<a id="1-cong-cu"></a>

## 1. Công cụ

| Công cụ | Yêu cầu / kiểm tra | Khi nào cần |
| --- | --- | --- |
| Git | `git --version` | Clone/chọn nhánh |
| Flutter | **≥3.47**, đã kiểm thử với **3.47.7**; `flutter --version` | App/test/build |
| Dart | **≥3.13, <4.0**, đi kèm Flutter; `dart --version` | Theo lockfile; không cài riêng |
| Android Studio + Android SDK | SDK Platform, Platform-Tools, Command-line Tools, Emulator; `flutter doctor -v` | Android |
| JDK | Java 17 đã dùng để build; xem Java mà Flutter chọn trong `flutter doctor -v` | Gradle Android, không phải server |
| macOS + Xcode | Xcode/Command Line Tools và công cụ iOS theo `flutter doctor -v` | Chỉ khi build/chạy iOS |
| Node.js + npm | **Node ≥20**, `node --version` | Supabase CLI qua `npx`, SQL tests |
| Docker Desktop | Docker engine đang chạy, `docker info` | Chỉ backend local; không cần để dùng backend cloud |

`pubspec.lock` yêu cầu Flutter/Dart cao hơn mức tối thiểu cũ trong `pubspec.yaml`; dùng phiên bản trong bảng. Giữ lockfile và chạy `flutter pub get`, không `pub upgrade` nếu chỉ muốn tái lập bản bàn giao.

Kiểm tra:

```sh
flutter doctor -v
flutter --version
dart --version
node --version
npx supabase --version
```

Android: đọc/chấp nhận SDK licenses nếu Flutter yêu cầu:

```sh
flutter doctor --android-licenses
```

Khắc phục các mục thiếu của nền tảng muốn chạy. Windows không build iOS và không cần sửa cảnh báo thiếu Xcode khi chỉ chạy Android. `npx` có thể hỏi cài Supabase CLI lần đầu; cho phép cài package chính thức. Repo đã có `supabase/config.toml`, **không cần chạy `supabase init` lại**.

Nguồn: [cài Flutter](https://docs.flutter.dev/get-started/install), [Supabase CLI — yêu cầu Node ≥20](https://supabase.com/docs/guides/local-development/cli/getting-started).

<a id="2-lay-source-va-chon-nhanh"></a>

## 2. Lấy source và chọn nhánh

```sh
git clone --branch feature/offline-ai-history https://github.com/lethanhtrong161005/tui-khon-mobile.git
cd tui-khon-mobile
git branch --show-current
git log -1 --oneline
```

Bản bàn giao đầy đủ nằm trên **`feature/offline-ai-history`**. Nếu đã clone trước đó:

```sh
git fetch origin
git switch --track origin/feature/offline-ai-history
```

Nếu đã có nhánh local, dùng `git switch feature/offline-ai-history`. Không dùng
`dev` (bản khởi tạo) hoặc `feature/supabase-backend` (trước offline) thay thế.
Đọc [docs/HANDOFF.md](docs/HANDOFF.md) để lấy context chức năng, kiểm thử và điểm
bắt đầu cho dark theme/i18n.

**Laptop mới dùng backend local riêng và dữ liệu mẫu mới.** Env/key, Docker DB,
tài khoản, phiên đăng nhập và SQLite/ảnh trên máy cũ không nằm trong Git. Làm
mục 5, đăng ký + OTP qua Mailpit rồi tạo demo theo mục 9; lấy key từ backend mới,
không dùng lại key local của máy khác.

Cài dependencies và test không cần backend:

```sh
flutter pub get
flutter test
```

Chọn **cloud** để demo/dùng chung/máy thật, hoặc **local** để dev backend. Không cần dựng cả hai. Dùng app offline không có nghĩa là bỏ bước tạo backend và tải dữ liệu lần đầu.

<a id="3-env-va-cach-lay-key"></a>

## 3. Env và cách lấy key

### 3.1. Các biến đang được source sử dụng

| Biến | Nơi lấy / tạo | Điền ở đâu | Bắt buộc? |
| --- | --- | --- | --- |
| `SUPABASE_URL` | Project URL cloud hoặc API URL từ `npx supabase status` | `.env` / `.env.local` ở gốc repo | Có |
| `SUPABASE_ANON_KEY` | **Publishable key** của cùng project; local lấy từ CLI | Cùng env Flutter | Có |
| `GOOGLE_WEB_CLIENT_ID` | OAuth client loại Web trong Google Cloud | Env Flutter | Khi dùng Google Sign-In |
| `GOOGLE_IOS_CLIENT_ID` | OAuth client iOS đúng bundle ID | Env Flutter; URL scheme iOS cấu hình riêng | Khi dùng Google trên iOS |
| `GEMINI_API_KEY` | Google AI Studio, mục 6 | `supabase/.env` để deploy secrets hoặc `supabase/functions/.env` cho local | Khi muốn gọi AI thật |
| `GEMINI_MODEL` | Model project Gemini được phép gọi | Cùng env server chứa Gemini key | Không; để trống dùng mặc định source |
| `GOOGLE_CLIENT_IDS` | Web client ID đứng đầu, tiếp theo native client IDs dùng thật | Biến shell chạy CLI local, do `supabase/config.toml` đọc; có mẫu ở `supabase/.env` | Config local hiện bật Google; chưa test Google có thể dùng dummy |
| `GOOGLE_CLIENT_SECRET` | Secret của OAuth **Web**, không phải Gemini key | Biến shell local; cloud điền trong Auth provider của Dashboard | Secret thật chỉ cần khi bật Google thật |

Giữ tên `SUPABASE_ANON_KEY` vì `lib/core/config/env.dart` đọc tên này; giá trị nên là **publishable key** (`sb_publishable_...`). Source truyền giá trị đó vào `Supabase.initialize(publishableKey: ...)`. Legacy anon key có thể dùng với project cũ. Không đưa `sb_secret_...` / `service_role` vào app. Xem [các loại key Supabase](https://supabase.com/docs/guides/getting-started/api-keys).

Mật khẩu database, token đăng nhập Supabase CLI, SMTP password, OAuth Web secret, Gemini key và publishable key là những thông tin khác nhau. Không thay chúng cho nhau. Chuỗi `REPLACE_...` / `your-project-ref` dưới đây là placeholder phải thay.

### 3.2. Mẫu `.env` — Flutter dùng cloud

PowerShell:

```powershell
Copy-Item .env.example .env
```

macOS/Linux:

```sh
cp .env.example .env
```

Mở file, thay URL/key bằng của mục 4. Chưa dùng Google thì xóa client IDs mẫu và để trống:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=REPLACE_WITH_PROJECT_PUBLISHABLE_KEY
GOOGLE_WEB_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

### 3.3. Mẫu `.env.local` — Flutter dùng local

Copy mẫu như trên nhưng đổi đích thành `.env.local`. Với Android Emulator:

```dotenv
SUPABASE_URL=http://10.0.2.2:54321
SUPABASE_ANON_KEY=REPLACE_WITH_LOCAL_PUBLISHABLE_KEY
GOOGLE_WEB_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

Lấy key từ CLI trên máy đang chạy backend, không chép key local của người khác. iOS Simulator đổi URL thành `http://127.0.0.1:54321`. Máy thật xem bảng host ở mục 5.3.

### 3.4. Mẫu `supabase/.env` — secrets server cloud

Copy `supabase/.env.example` thành `supabase/.env`. Chỉ bật AI cloud thì nội dung cần là:

```dotenv
GEMINI_API_KEY=REPLACE_WITH_GEMINI_API_KEY
GEMINI_MODEL=
```

Mẫu trong repo còn có hai biến Google. Nếu dùng để giữ cấu hình local thật, chúng có dạng:

```dotenv
GOOGLE_CLIENT_IDS=REPLACE_WEB_CLIENT_ID,REPLACE_IOS_CLIENT_ID
GOOGLE_CLIENT_SECRET=REPLACE_WEB_CLIENT_SECRET
```

Chỉ liệt kê native IDs thực sự dùng; test Android không cần iOS ID giả. Bỏ các dòng placeholder chưa dùng khỏi file deploy. `secrets set` **không tự bật Google provider cloud**; provider được cấu hình ở mục 7. Với CLI local, hướng dẫn dùng biến shell rõ ràng, không mặc định file này tự được nạp.

### 3.5. Mẫu `supabase/functions/.env` — Functions local

Tạo file:

```dotenv
GEMINI_API_KEY=REPLACE_WITH_GEMINI_API_KEY
GEMINI_MODEL=
```

Đây không phải env Flutter. Edge Runtime tự cấp kết nối Supabase cho Functions; không cần thêm service-role key để chạy hai Function hiện có.

Env thật đã bị `.gitignore` loại. Kiểm tra:

```sh
git check-ignore .env .env.local supabase/.env supabase/functions/.env
```

Chỉ chia sẻ file `*.env.example`; không commit/gửi key thật vào chat, ảnh chụp hoặc file hướng dẫn.

<a id="4-supabase-cloud"></a>

## 4. Supabase cloud

### 4.1. Tạo project và lấy URL/key

1. Vào [Supabase Dashboard](https://supabase.com/dashboard), đăng nhập, tạo/chọn organization rồi **New project**.
2. Đặt tên project, chọn region phù hợp (ví dụ Singapore), tạo mật khẩu database và lưu riêng. Chờ project sẵn sàng.
3. Lấy **Project URL** và **Publishable key** từ hộp **Connect** hoặc **Settings → API Keys**. Project cũ có thể đặt Project URL trong API settings tương ứng. Điền hai giá trị vào `.env` Flutter.
4. Lấy **Project reference/ID** trong Settings/General hoặc phần `your-project-ref` của `https://your-project-ref.supabase.co`; không nhầm organization ID/API key.

Nếu chỉ chạy app với backend nhóm đã dựng, xin **URL + publishable key** của backend đó, tạo `.env` rồi tới mục 8. Không cần quyền DB admin để dùng app; vẫn phải có tài khoản ứng dụng bằng email/Google.

### 4.2. Link và tạo/cập nhật database

Người dựng backend chạy từ gốc repo, thay project ref trước khi chạy:

```sh
npx supabase login
npx supabase link --project-ref REPLACE_WITH_PROJECT_REF
npx supabase db push --dry-run
npx supabase db push
```

Nhập mật khẩu database nếu CLI yêu cầu. `login` xác thực tài khoản CLI, không sinh key cho Flutter. Nếu CLI báo thiếu Google env do config local, đặt dummy ở mục 5.1 trong shell; không dùng dummy để bật Google provider cloud.

Trên project mới, migrations tạo schema/RLS/RPC, bucket và cron. Kiểm tra:

- Table Editor có `profiles`, `wallets`, `transactions`, `debt_payments`, `payables` và các bảng nghiệp vụ khác.
- Database Functions có **`sync_push` và `sync_pull`**, cần cho app offline tải dữ liệu đầu.
- Storage có **`receipts` riêng tư**, **`avatars` public** cùng policies do migration tạo; không tự mở public bucket receipts.
- Extensions có `pg_cron`, Cron có job `tuikhon-debt-reminders`. Nếu môi trường không hỗ trợ cron, xem migration nhắc nợ/hướng dẫn backend trước khi đặt lịch thủ công.

**DB đã có dữ liệu:** `db push` chỉ áp migration chưa chạy; không reset hoặc sửa migration đã áp dụng. History local/remote không khớp thì đối chiếu với người quản lý DB, không tự sửa history để bỏ qua lỗi. Xem [OFFLINE_UPGRADE](docs/OFFLINE_UPGRADE.md). Cập nhật các thiết bị sang app mới cùng đợt: sau migration offline, app cũ ghi trực tiếp vào bảng sẽ bị từ chối.

### 4.3. Đăng nhập email, OTP và SMTP

Trong Dashboard → **Authentication** (tên menu con có thể đổi):

1. **Sign In / Providers → Email:** bật đăng ký email và **Confirm email**.
2. Đặt email OTP **6 chữ số**, hết hạn **600 giây**, thời gian chờ gửi lại tối thiểu 60 giây.
3. **Emails → Templates:** dùng `supabase/templates/confirmation.html` cho Confirm signup và `supabase/templates/recovery.html` cho Reset password. Giữ `{{ .Token }}` để gửi mã; app không dùng flow bấm magic link.
4. **Emails → SMTP Settings / Custom SMTP:** nhập sender email/name, SMTP host/port/username/password từ nhà cung cấp; xác minh domain/sender theo yêu cầu của họ. Có thể dùng SMTP của dịch vụ như Resend.
5. Thử gửi tới email người test truy cập được; kiểm tra Spam, sandbox/allowed recipients của nhà cung cấp và Auth/email logs.

SMTP mặc định có hạn chế gửi/người nhận; cấu hình SMTP riêng để nhóm test email thật. Thông tin SMTP chỉ ở Dashboard/server, không thêm vào env Flutter. [Tài liệu SMTP Supabase](https://supabase.com/docs/guides/auth/auth-smtp).

### 4.4. Secrets Gemini và Edge Functions

Sau khi tạo key ở mục 6 và điền `supabase/.env`, chạy riêng từng lệnh:

```sh
npx supabase secrets set --env-file supabase/.env
npx supabase functions deploy ai-quick-record
npx supabase functions deploy ai-advisor
```

Chưa có Gemini key có thể deploy Functions mà bỏ bước đặt Gemini secrets; ghi tay/fallback local vẫn dùng được, AI thật chưa hoạt động. Kiểm tra Functions và logs trong Dashboard.

`config.toml` cấu hình môi trường local; **`db push` không tự sao chép SMTP/email/Google settings local lên cloud**. Điền `.env` đúng URL/key project này rồi tới mục 8.

<a id="5-supabase-local"></a>

## 5. Supabase local

### 5.1. Docker và Google env cho config

Mở Docker Desktop, đợi engine chạy, kiểm tra `docker info`. Không `supabase init` lại vì repo đã có config/migrations.

Config đang bật Google provider và đọc hai biến shell. Chỉ test email thì đặt dummy **trước `start`** trong terminal hiện tại:

PowerShell:

```powershell
$env:GOOGLE_CLIENT_IDS='local-dummy.apps.googleusercontent.com'
$env:GOOGLE_CLIENT_SECRET='local-dummy'
```

macOS/Linux:

```sh
export GOOGLE_CLIENT_IDS='local-dummy.apps.googleusercontent.com'
export GOOGLE_CLIENT_SECRET='local-dummy'
```

Dummy chỉ giúp khởi động config local, không cho Google login thật. Muốn test Google thì dùng giá trị thật ở mục 7. Biến shell không tự truyền sang terminal mới; không mặc định `supabase/.env` tự được nạp trong hướng dẫn này.

```sh
npx supabase start
npx supabase status
```

Lần đầu cần mạng/tải Docker images. Local stack mới được áp migrations khi khởi tạo. Đọc giá trị trên máy:

| Giá trị CLI | Công dụng |
| --- | --- |
| API URL, thường `http://127.0.0.1:54321` | Backend; đổi host đúng thiết bị như mục 5.3 |
| Publishable key hoặc legacy anon key | `SUPABASE_ANON_KEY` của `.env.local`, không dùng secret/service-role |
| Studio, thường `http://127.0.0.1:54323` | Quản trị DB, SQL Editor, Storage |
| Mailpit, thường `http://127.0.0.1:54324` | Đọc OTP local, không gửi ra hộp thư thật |

CLI hiển thị cổng khác thì dùng cổng thực tế. Local stack đã có dữ liệu cần migration mới:

```sh
npx supabase migration up --local
```

Lệnh này giữ dữ liệu. `db reset` xóa/tạo lại dữ liệu, không dùng trong luồng nâng cấp cần giữ thông tin.

### 5.2. Env và Functions local

Tạo `.env.local` như mục 3.3, key từ `status`. Với AI, điền key mục 6 vào `supabase/functions/.env`; ở **terminal thứ hai** tại gốc repo:

```sh
npx supabase functions serve --env-file supabase/functions/.env
```

Giữ terminal serve mở khi test AI; `Ctrl+C` để dừng. Nếu CLI yêu cầu Google env, đặt lại mục 5.1 trong terminal đó. Không có Gemini key vẫn test nhập tay, offline, CSV, sổ nợ; ảnh có thể giữ để nhập tay nhưng Gemini chưa nhận dạng được, nhận xét AI chưa sinh được.

### 5.3. Chọn URL đúng nơi app chạy

| Thiết bị | URL backend local | Ghi chú |
| --- | --- | --- |
| Android Emulator chuẩn | `http://10.0.2.2:54321` | `localhost` trong máy ảo trỏ tới chính máy ảo |
| iOS Simulator trên Mac | `http://127.0.0.1:54321` | Dùng cổng CLI thực tế |
| Điện thoại thật | `http://IP_LAN_MAY_DEV:54321` | Cùng mạng; backend phải lắng nghe và firewall cho phép; cloud thuận tiện hơn |
| Bất kỳ thiết bị dùng cloud | `https://your-project-ref.supabase.co` | Không dùng IP emulator cho cloud |

Android debug đã cho HTTP trong `android/app/src/debug/AndroidManifest.xml`. iOS có thể yêu cầu cấu hình ATS/local network cho HTTP local; chỉ chỉnh cấu hình dev cần thiết theo nền tảng. Dùng cloud HTTPS khi test máy thật nếu không cần dev backend; không tắt TLS cho bản phát hành.

Dừng local: `npx supabase stop`. SQLite app và DB backend là hai nơi khác nhau; gỡ app/xóa app data có thể làm mất phần chưa đồng bộ trên máy.

<a id="6-tao-gemini-key-tuy-chon"></a>

## 6. Tạo Gemini key (tùy chọn)

1. Đăng nhập [Google AI Studio](https://aistudio.google.com/), chấp nhận điều khoản nếu được hỏi.
2. Mở **API keys / Get API key**. Chọn project, import Google Cloud project có sẵn hoặc tạo project mới theo giao diện.
3. Chọn **Create API key** cho đúng project, lưu key riêng. Kiểm tra quyền API, hạn mức và model project được phép gọi; quota/model không khả dụng phải xử lý tại project tương ứng.
4. Cloud: key vào `supabase/.env` rồi mục 4.4. Local: key vào `supabase/functions/.env` rồi mục 5.2.
5. `GEMINI_MODEL=` để trống dùng `gemini-flash-latest` theo `supabase/functions/_shared/gemini.ts`. Có thể điền tên model khác khả dụng mà không sửa Flutter.

Theo [hướng dẫn key của Google](https://ai.google.dev/gemini-api/docs/api-key). Key chỉ nằm ở server, không điền `.env` Flutter. Chưa cần key để cài source/test/ghi tay; cần trước khi nghiệm thu AI thật. Thay secrets server không cần build lại Flutter.

<a id="7-google-sign-in-tuy-chon"></a>

## 7. Google Sign-In (tùy chọn)

Bỏ qua nếu dùng email/mật khẩu; để hai Google client IDs trong env Flutter trống.

### 7.1. Project, consent và clients

Trong [Google Cloud Console](https://console.cloud.google.com/), chọn project. Ở **Google Auth Platform** (hoặc APIs & Services → OAuth consent screen/Credentials), cấu hình **Branding/Audience**, email liên hệ, scope cơ bản `openid`, `email`, `profile`. Nếu đang Testing, thêm email người test vào **Test users**.

Tạo các client:

| Loại | Đúng theo source hiện tại | Nơi dùng |
| --- | --- | --- |
| **Web application** | Server client ID dùng cả khi app chạy native; có secret riêng | ID → `GOOGLE_WEB_CLIENT_ID` và Supabase Google provider; secret chỉ server |
| **Android** | Package `com.example.tui_khon_mobile` + SHA-1 chứng chỉ ký bản đang chạy | Google nhận diện Android; source không có biến `GOOGLE_ANDROID_CLIENT_ID` |
| **iOS** | Bundle ID `com.example.tuiKhonMobile` | ID → `GOOGLE_IOS_CLIENT_ID` và danh sách Supabase chấp nhận |

Đổi application/bundle ID thì phải cập nhật OAuth tương ứng. SHA-1 debug và release có thể khác.

Lấy SHA-1 của variant debug:

PowerShell:

```powershell
cd android
.\gradlew.bat signingReport
cd ..
```

macOS/Linux:

```sh
cd android
chmod +x gradlew
./gradlew signingReport
cd ..
```

Không dùng SHA-1 từ máy tác giả. Nếu wrapper chưa có sau clone, kiểm tra Android SDK/JDK và chạy Flutter tooling/build một lần để tái tạo wrapper trước.

### 7.2. Supabase và iOS

- **Cloud:** Auth → Sign In/Providers → Google; nhập Web client ID/secret và các native IDs được chấp nhận. Nếu Web client cần redirect URI, copy callback URL do Supabase hiển thị vào Google Console.
- **Local:** đặt `GOOGLE_CLIENT_IDS` trong shell, Web đứng đầu, tiếp theo native IDs dùng thật, phân cách dấu phẩy; `GOOGLE_CLIENT_SECRET` là Web secret. Đổi config cần khởi động lại local Auth stack khi không làm gián đoạn người khác.
- Source native gọi `signInWithIdToken` không truyền nonce; cấu hình **Skip nonce checks** tương ứng theo [Google native của Supabase](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).
- iOS: thêm reversed iOS client ID vào `ios/Runner/Info.plist`, gộp với `CFBundleURLTypes` có sẵn, không tạo khóa trùng:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.REPLACE_IOS_CLIENT_ID_PREFIX</string>
    </array>
  </dict>
</array>
```

Lấy reversed client ID chính xác từ cấu hình OAuth iOS, không dùng nguyên placeholder. Điền IDs vào env Flutter rồi **stop/run lại** vì source dùng biến compile-time. Web secret không nằm trong Flutter.

<a id="8-chay-app-ide-va-build"></a>

## 8. Chạy app, IDE và build

### 8.1. Thiết bị và terminal

Mở Android emulator trong Device Manager hoặc cắm Android bật USB debugging/chấp nhận USB authorization. Trên Mac mở iOS Simulator; chạy iPhone cần cấu hình signing trong Xcode.

```sh
flutter devices
# Thay DEVICE_ID bằng id hiển thị; backend cloud:
flutter run -d DEVICE_ID --dart-define-from-file=.env
# Hoặc backend local, env đã đổi đúng host:
flutter run -d DEVICE_ID --dart-define-from-file=.env.local
```

Ví dụ emulator có id `emulator-5554`: `flutter run -d emulator-5554 --dart-define-from-file=.env.local`. iOS dùng id từ `flutter devices` trên Mac. Lần đầu cài source cần mạng để tải dependencies/toolchain; lần đầu đăng nhập cần backend để tải SQLite.

Trong terminal Flutter: `r` hot reload, `R` hot restart, `q` dừng. Đổi env/`--dart-define` hoặc plugin native phải stop/run lại; hot reload không nạp key mới.

### 8.2. Android Studio và VS Code

**Android Studio:** mở gốc repo như Flutter project → Run/Edit Configurations → Flutter, entrypoint `lib/main.dart`, working directory gốc repo; Additional run args: `--dart-define-from-file=.env` hoặc `.env.local`.

**VS Code:** cài Dart/Flutter extensions, dùng integrated terminal hoặc tự tạo `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Túi Khôn - cloud",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": ["--dart-define-from-file=.env"]
    },
    {
      "name": "Túi Khôn - local",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": ["--dart-define-from-file=.env.local"]
    }
  ]
}
```

Chọn config và thiết bị trước khi Run. Env thật không có trong Git, mỗi người tự tạo; không nhúng key vào launch config.

### 8.3. Build để test

APK debug Android dùng cloud:

```sh
flutter build apk --debug --dart-define-from-file=.env
```

File: `build/app/outputs/flutter-apk/app-debug.apk`. Chỉ dùng `.env.local` nếu thiết bị cài APK truy cập được backend đó; URL `10.0.2.2` không dành cho điện thoại thật.

Build iOS Simulator, chỉ trên macOS đã có Xcode:

```sh
flutter build ios --simulator --debug --dart-define-from-file=.env
```

iPhone thật cần team/signing trong Xcode. Đây là hướng dẫn test; ký và phát hành Store là bước riêng, không dùng cấu hình debug của repo làm cấu hình phát hành.

<a id="9-kiem-tra-sau-setup"></a>

## 9. Kiểm tra sau setup

### 9.1. Tự động

```sh
flutter analyze --no-fatal-infos
flutter test
```

SQL tests dùng PostgreSQL PGlite cô lập, không cần Docker/mật khẩu DB:

```sh
npm ci --prefix supabase/tests --ignore-scripts
node supabase/tests/run-offline-history.cjs
```

Logic/type-check Edge Functions, không gọi Gemini thật:

```sh
npx --yes deno test supabase/functions/ai-quick-record/result_test.ts supabase/functions/ai-advisor/period_test.ts
npx --yes deno check supabase/functions/ai-quick-record/index.ts supabase/functions/ai-advisor/index.ts
```

Công cụ có thể tải dependencies lần đầu. Xem [SQL tests](supabase/tests/README.md) cho phạm vi và kịch bản nhiều connection PostgreSQL thật; unit test hai thiết bị giả lập không thay thế hoàn toàn bước đó.

### 9.2. Checklist chạy app

- [ ] Đăng ký → OTP (Mailpit local hoặc email thật cloud) → Dashboard.
- [ ] Đăng nhập lại/quên mật khẩu bằng mã 6 số.
- [ ] Đợi tải đầu; ghi thu/chi, sửa/xóa, kiểm tra nguồn tiền, số dư, ngân sách.
- [ ] Tắt mạng → ghi thêm → đóng/mở app → bật mạng → Dữ liệu & Đồng bộ. Phần chưa đồng bộ vẫn phải còn trên máy.
- [ ] Hai thiết bị cùng tài khoản sửa cùng giao dịch: đối chiếu và chọn bản giữ; tài khoản khác không thấy dữ liệu nhau.
- [ ] Trả nợ từng phần → sửa/hoàn tác → kiểm tra giao dịch liên kết.
- [ ] CSV xuất/nhập xem trước, kiểm tra lỗi/ID trùng không âm thầm ghi đè.
- [ ] Khoản phải trả, giờ nhắc và báo cáo tháng. AI cần mạng/key/dữ liệu đã đồng bộ.
- [ ] Khi có Gemini: gõ nhiều khoản, mic, quét ảnh, kiểm tra bản nháp trước khi lưu.
- [ ] Khi có Google: login đúng test user và đúng client nền tảng.
- [ ] Avatar, thông báo, sinh trắc và trường hợp từ chối quyền.

Emulator Android: cài vân tay trong Settings/Security, giả lập Touch sensor ở Extended controls/Fingerprint. Mic: Extended controls/Microphone, dùng host audio input. Có thể kéo ảnh vào emulator để chọn gallery. Camera, mic, Face ID và thông báo nền nên thử thêm trên máy thật; mic iOS Simulator có thể khác iPhone.

### 9.3. Demo (chỉ tài khoản mới)

Đăng ký tài khoản demo **mới**, chưa sửa danh mục/nguồn tiền hoặc ghi dữ liệu. SQL Editor đúng backend, quyền quản trị:

```sql
select private.seed_demo_data('REPLACE_WITH_NEW_DEMO_EMAIL');
```

Thay email trước khi chạy. Helper nạp giao dịch, nguồn tiền, ngân sách, mục tiêu và nợ; từ chối reset/nạp lặp trên tài khoản đã có dữ liệu. Không dùng cho tài khoản thật. Kéo Dashboard xuống để đồng bộ; nếu đã hỏi nợ một lần trong phiên, mở lại app để kiểm tra nhắc khi vào app.

<a id="10-loi-thuong-gap"></a>

## 10. Lỗi thường gặp

| Hiện tượng | Kiểm tra / xử lý |
| --- | --- |
| Không tìm `pubspec.yaml` | Chạy sai thư mục; vào gốc `tui-khon-mobile`. |
| Thiếu `.env` / màn thiếu cấu hình Supabase | Tạo env mục 3, điền URL/key, kiểm tra working directory và `--dart-define-from-file`, stop/run lại. |
| CLI không chạy với Node cũ | Dùng Node ≥20; không cài bằng `npm install -g supabase`. |
| CLI thiếu Google env | Đặt biến shell mục 5.1; dummy chỉ cho khởi động local, không dùng để Google login. |
| Docker engine/API không kết nối | Mở Docker Desktop, đợi engine và kiểm tra `docker info`; dùng cloud thì không cần Docker. |
| `401` / invalid API key | URL và publishable key phải cùng project/môi trường; không dùng secret/service-role. |
| Emulator không gọi được local | Android `10.0.2.2`, iOS Simulator `127.0.0.1`; kiểm tra cổng/backend. Máy thật dùng cloud hoặc LAN phù hợp. |
| OTP cloud không tới | Confirm email, SMTP/sender/domain, sandbox người nhận, Spam và Auth/email logs; template giữ `{{ .Token }}`. |
| OTP local không tới email thật | Xem Mailpit từ `supabase status`; local không gửi ra hộp thư thật. |
| Google chưa cấu hình/`DEVELOPER_ERROR`/ID token bị từ chối | Web server client ID, package/SHA-1 của bản ký, bundle/URL scheme, test users, Supabase accepted IDs; không dùng dummy. |
| AI fallback/chưa cấu hình | Kiểm tra key ở server đúng môi trường, Functions deploy/serve, quota/model và log; không thêm Gemini key vào Flutter. |
| Không tìm `sync_pull` / `sync_push` | Backend thiếu migration offline hoặc app trỏ nhầm project; áp migration bổ sung đúng backend. |
| App cũ bị permission denied khi ghi bảng | Dùng app mới với RPC; không bỏ RLS/grant quyền để chữa tạm. |
| Kẹt tải dữ liệu lần đầu | Cần mạng, phiên đăng nhập và RPC hợp lệ; chưa có dữ liệu trước đó thì không thể dùng offline để bỏ bước này. |
| Dữ liệu chờ/xung đột | Mở Đồng bộ, sửa mục lỗi hoặc chọn bản giữ. Không xóa SQLite/gỡ app để xử lý vì có thể mất phần chưa đồng bộ. |
| Không thấy thông báo | Cấp quyền, bật nhóm nhắc, kiểm tra hạn tương lai và pin hệ thống; lịch trong app vẫn xem được khi từ chối quyền. |
| Mic/camera/sinh trắc không hoạt động | Kiểm tra quyền, hỗ trợ thiết bị và đã đăng ký vân tay/Face ID; thử máy thật. |
| Gradle lỗi desugaring | Giữ `coreLibraryDesugaring` trong `android/app/build.gradle.kts`; kiểm tra JDK/SDK bằng `flutter doctor -v`. |
| Gradle loopback connection trên Windows | Thử PowerShell thường, kiểm tra TEMP/TMP là đường dẫn Windows ghi được, không phải Unix hoặc quá dài; nếu cần đặt thư mục tạm ngắn cho riêng Java, không sửa mạng app. |
| Dependencies cần Flutter/Dart mới | Dùng ≥3.47/≥3.13 theo lockfile; mức tối thiểu cũ trong pubspec chưa phản ánh mọi dependencies khóa. |

Tên menu, quota và model có thể thay đổi theo phiên bản dịch vụ. Luôn lấy giá trị từ project của chính nhóm; không có key thật hoặc đường dẫn máy tác giả cần chép từ tài liệu này.


### Chạy thử ngay với backend local (không cần project cloud)

Nếu đã có Docker Desktop, từ thư mục gốc repository:

```powershell
$env:GOOGLE_CLIENT_IDS = 'local-dummy.apps.googleusercontent.com'
$env:GOOGLE_CLIENT_SECRET = 'local-dummy'
npx supabase start
npx supabase migration up --local
flutter run -d emulator-5554 --dart-define-from-file=.env.local
```

Điền URL/key thực tế từ `npx supabase status` vào `.env.local` trước khi chạy; URL trên Android emulator là `http://10.0.2.2:54321`. Hai Google client IDs trong env Flutter để trống khi chưa có OAuth. Biến dummy ở shell chỉ giúp dịch vụ local khởi động, không đăng nhập Google được.

- Đăng ký một tài khoản **local mới** trong app. Tài khoản cloud hoặc Google không tự tồn tại trong DB local.
- Mở Mailpit tại http://127.0.0.1:54324, chọn thư đúng email của mình, lấy mã OTP 6 số. Không dùng email/mật khẩu trong ảnh minh họa.
- Xác thực xong, đợi đồng bộ lần đầu rồi thử ghi thu/chi, thống kê, ngân sách, sổ nợ và offline.
- Quên mật khẩu cũng nhận OTP trong Mailpit. Local không gửi thư tới hộp Gmail thật.
- Google sẽ hiển thị “Chưa cấu hình” cho tới khi có OAuth thật; xem mục Google Sign-In. AI thật cần Gemini key phía server.
- Nếu báo không kết nối được máy chủ, kiểm tra Docker và cổng 54321, sau đó kiểm tra app có chạy bằng **`.env.local`** không. Đổi env cần dừng/chạy lại, hot reload không đổi biến compile-time.
- Không chạy `db reset`, xóa volume hay gỡ app để xử lý lỗi đăng nhập.

## Nâng cấp giao diện báo cáo và lịch sử trả nợ

Áp dụng bổ sung `20261028000002_debt_payment_editing.sql` trước khi dùng bản app mới.
Dùng `npx supabase migration up --local` với backend local, hoặc quy trình migration
cloud ở trên khi tự triển khai. Không chạy reset DB; migration này chỉ thay hàm,
không viết lại dữ liệu hay đổi ID giao dịch đang có.

Trong **Chi tiết khoản nợ**, nút dưới cùng mở form ghi trả/thu. Menu từng lần cho
sửa hoặc hoàn tác. Bật/tắt ghi kèm giữ cùng ID giao dịch; nguồn đã lưu trữ chỉ
được giữ cho lần ghi cũ, không chọn cho lần ghi mới.
**Báo cáo tháng** dùng SQLite theo giờ Việt Nam; “Xem tất cả” mở ngân sách của
đúng tháng đang chọn. AI vẫn cần đồng bộ hoàn tất và Gemini key phía server.

Kiểm thử bổ sung từ thư mục repository:

```sh
flutter test test/debt_payment_editing_test.dart test/report_debt_ui_test.dart test/monthly_report_test.dart
node supabase/tests/run-debt-concurrency.cjs
```

Lệnh Node cuối chỉ chạy khi Docker/Supabase local đang bật. Các bộ SQL trong
`supabase/tests` dùng cơ sở dữ liệu tạm hoặc tài khoản thử được dọn sau kiểm thử.
