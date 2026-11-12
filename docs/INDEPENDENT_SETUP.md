# Tự dựng Túi Khôn từ A–Z với backend và app riêng

Dành cho người nhận source muốn dùng tài khoản dịch vụ, dữ liệu và khóa ký của
chính mình. Có thể dùng Antigravity hoặc AI Agent có quyền đọc/sửa repo và chạy
terminal. Gửi kèm [bộ prompt cho Agent](AI_AGENT_PROMPTS.md).

Đối chiếu lại checkout ngày **12/11/2026**, dựa trên bàn giao tính năng 08/11.
Tài liệu này mô tả quy trình thực hiện;
không phải xác nhận đã triển khai trên tài khoản của người nhận. Tên menu, SDK,
quota và yêu cầu Store có thể đổi; khi gặp khác biệt, đối chiếu nguồn chính thức
ở cuối tài liệu và file thực tế trong checkout.

Đi nhanh theo phần: [source](#source) · [công cụ](#tools) ·
[định danh](#identity) · [Supabase/SQL](#backend) · [SMTP](#email) ·
[env/chạy app](#run) · [AI](#ai) · [Google](#google) ·
[kiểm thử](#checks) · [APK](#android) · [iOS](#ios).

## 1. Kết quả cần đạt và tài nguyên cần tự có

Luồng: clone → công cụ → định danh app → Supabase mới → migrations → email/SMTP
→ chạy app → AI/Google nếu cần → kiểm thử → ký và build APK hoặc iOS.

| Thành phần | Người nhận tự chuẩn bị | Bắt buộc khi nào |
| --- | --- | --- |
| Source | Quyền đọc repo hoặc fork riêng; nhánh/commit do người gửi chốt | Luôn cần |
| Supabase | Tài khoản, organization/project mới, mật khẩu DB, URL và publishable key | Đăng nhập và đồng bộ |
| Email | SMTP của chính mình, sender/domain được xác minh | Luồng email OTP đầy đủ |
| Gemini | Project/key Google AI Studio và quota riêng | AI cloud |
| Google OAuth | Google Cloud project, consent screen và OAuth clients riêng | Đăng nhập Google |
| Android | SDK, thiết bị/emulator; keystore riêng để phát hành | APK/AAB |
| Apple | Mac + Xcode; Apple Account/team và signing riêng | iOS; TestFlight/Store cần Developer Program |

Không nhập ZIP Team, `.team/`, env, tài khoản test, OAuth client hoặc khóa ký của
người gửi. Không chạy `tool/team.ps1 setup/run/build`; script đó dành cho backend
và signing chung của nhóm. Chưa cấu hình Google thì để hai Google IDs trống.

Ứng dụng dùng Flutter + Riverpod + SQLite/Drift + Supabase. Không cần backend
Java, Firebase hay dịch vụ thanh toán. Docker chỉ cần nếu muốn thêm môi trường
Supabase local; đường chính bên dưới dùng cloud riêng.

AI Agent làm được phần đọc source, chạy CLI, viết cấu hình, sửa signing và kiểm
thử. Người nhận trực tiếp xử lý đăng nhập dịch vụ, OTP/2FA, tạo tài khoản, chấp
nhận điều khoản, xác minh domain và các bước thanh toán nếu chọn dịch vụ có phí.
Không cần gửi password/key/token vào cuộc chat: nhập trong Dashboard hoặc file
private trên máy. Dùng từng prompt trong tài liệu kèm theo, theo đúng chặng.

<a id="source"></a>

## 2. Chốt source để người khác clone đúng bản

**Người gửi:** gửi URL repo, tên nhánh và **commit SHA đầy đủ**. Kiểm tra trước:

```sh
git status --short
git branch --show-current
git log -1 --format=%H
```

Bản bàn giao có hướng dẫn này nằm trên **`codex/shared-env-ai`**, gồm OCR,
hỏi chi tiêu và icon mới. Người gửi cung cấp commit SHA đã push cùng link nhánh
để người nhận kiểm tra đúng phiên bản. Không ZIP nguyên thư mục làm việc vì có
thể lẫn env, DB, backup và keystore.

`codex/team-windows-setup` là nhánh setup Team trước đó. Không mặc định nhánh này,
`dev` hoặc nhánh mặc định đã có toàn bộ tính năng mới. Ưu tiên commit người gửi
đã xác nhận; không tự merge các nhánh tính năng cũ để ghép bản bàn giao.

**Người nhận:** dùng nhánh bên dưới hoặc URL fork riêng; thay commit placeholder
bằng SHA người gửi cung cấp. Repo private cần được cấp quyền hoặc có fork/bản
source hợp lệ.

```sh
git clone --branch codex/shared-env-ai https://github.com/lethanhtrong161005/tui-khon-mobile.git tui-khon-personal
cd tui-khon-personal
git switch --detach REPLACE_FULL_COMMIT_SHA
git switch -c codex/personal-app
git log -1 --format=%H
git status --short
```

Nếu SHA chưa có ở máy, `git fetch origin` rồi kiểm tra lại. Lỗi không thấy SHA/
nhánh cần hỏi người gửi, không bỏ qua để dùng ngẫu nhiên một bản khác.

Agent đọc `AGENTS.md`, `docs/HANDOFF.md` (mục mới nhất được ưu tiên), `SETUP.md`,
`docs/NGHIEP_VU.md` và tài liệu này. Mục Team trong tài liệu cũ là context lịch sử,
không phải cấu hình cho app riêng.

<a id="tools"></a>

## 3. Cài công cụ và khôi phục dependencies

| Công cụ | Mốc của bản bàn giao |
| --- | --- |
| Flutter / Dart | Flutter **3.47.7**, Dart đi kèm **3.13.5** |
| Android | Android Studio, SDK Platform/Build-Tools, Platform-Tools, Command-line Tools; JDK **17** |
| SDK / NDK | Bản bàn giao dùng compile SDK **36**, NDK **28.2.13676358**; đối chiếu Flutter và Gradle thực tế |
| Node / npm | Node **≥20**; dùng `npx supabase`, không `npm install -g supabase` |
| iOS | macOS, Xcode tương thích Flutter/plugins, Command Line Tools và Simulator runtime |

Tải Flutter đúng phiên bản từ [SDK archive](https://docs.flutter.dev/install/archive),
thêm `flutter/bin` vào PATH rồi mở terminal mới. Android Studio → SDK Manager cài
các thành phần thiếu; Device Manager tạo/mở emulator, hoặc bật USB debugging và
chấp nhận kết nối trên điện thoại thật.

```sh
git --version
flutter --version
dart --version
java -version
node --version
npx supabase --version
flutter doctor -v
flutter doctor --android-licenses
flutter pub get
flutter gen-l10n
```

Đọc và chấp nhận licenses bằng chính tài khoản của mình. Dùng Java mà
`flutter doctor -v` báo, không chỉ Java trong PATH. Giữ `pubspec.lock`; không
`pub upgrade`, sửa minimum SDK hoặc hạ plugin để né lỗi toolchain.

Windows build Android được; iOS cần Mac. Có thể làm Android trước rồi chuyển
cùng commit sang Mac. Không cần xử lý cảnh báo Xcode trên máy chỉ build Android.

<a id="identity"></a>

## 4. Chọn định danh app riêng trước OAuth và signing

Ví dụ bên dưới là placeholder: `vn.tenban.sotaychitieu`. Chọn ID thực của bạn,
không giữ chuỗi ví dụ. ID không cần bằng tên package Dart trong `pubspec.yaml`.

Trước mỗi phiên build, bỏ biến bật Team trong terminal hiện tại:

```powershell
# Windows PowerShell
Remove-Item Env:TUI_KHON_TEAM -ErrorAction SilentlyContinue
```

```sh
# macOS/Linux
unset TUI_KHON_TEAM
```

| Nơi sửa trong fork | Cách sửa |
| --- | --- |
| `android/app/build.gradle.kts` | Nhánh thường của `applicationId` đổi thành ID riêng; `appLabel` đổi thành tên riêng |
| `ios/Runner.xcodeproj/project.pbxproj` hoặc Xcode | Bundle Identifier của Runner ở Debug/Profile/Release thành ID riêng; RunnerTests dùng hậu tố riêng tương ứng |
| `ios/Runner/Info.plist` | `CFBundleDisplayName` thành tên hiển thị mới |
| ARB, assets và email templates | Đổi thương hiệu khi cần; chuỗi UI dùng `appL10n(context)`, chạy lại `gen-l10n` |

Android có thể **giữ namespace Kotlin** `com.example.tui_khon_mobile` và đường
dẫn/class Kotlin; chỉ `applicationId` quyết định app cài độc lập. Không replace
toàn repo chuỗi package. Manifest đang dùng `.MainActivity` và `.QuickRecordWidget`:
nếu đổi cả namespace, phải cập nhật class/receiver/import/test tương ứng và kiểm
tra widget. Đổi `applicationId` không đổi MethodChannel một cách tùy tiện.

VS Code `.vscode/launch.json` và cấu hình IDE bàn giao có thể đang bật
`TUI_KHON_TEAM=1` và Team doctor. Dùng terminal bên dưới, hoặc tạo cấu hình Flutter
riêng với `lib/main.dart`, `--dart-define-from-file=.env`, không có Team pre-launch
task; đặt `TUI_KHON_TEAM=0` nếu cần ghi đè biến từ tiến trình IDE.

Chốt package/bundle và khóa ký trước khi dùng thật. Đổi package tạo app/sandbox
mới; dữ liệu SQLite không tự chuyển theo. Không đăng nhập backend khác từ một
app còn outbox chưa đồng bộ để thử đổi môi trường.

<a id="backend"></a>

## 5. Tạo Supabase cloud mới và nạp SQL từ repo

### 5.1. Tạo project

1. Đăng nhập [Supabase Dashboard](https://supabase.com/dashboard) bằng tài khoản
   của bạn; tạo organization/project riêng, chọn region phù hợp.
2. Lưu mật khẩu database trong nơi quản lý bí mật của bạn, chờ project sẵn sàng.
3. Lấy **Project reference**, **Project URL** và **publishable key** từ Connect/
   Project Settings/API Keys. Ref nằm trong host `REF.supabase.co`.
4. Ghi lại ref không bí mật để đối chiếu mọi thao tác deploy. Không lấy ref hoặc
   URL cloud nhóm từ `HANDOFF.md` làm giá trị mới.

Project mới bắt đầu rỗng: không có tài khoản app, ảnh hoặc lịch sử tài chính của
người gửi. Tài khoản quản trị Supabase khác tài khoản đăng nhập trong app.

### 5.2. Link CLI và áp migrations theo thứ tự

Từ gốc repo, thay ref bằng project **vừa tạo của bạn**:

```sh
npx supabase login
npx supabase link --project-ref REPLACE_WITH_YOUR_NEW_PROJECT_REF
npx supabase migration list --linked
npx supabase db push --linked --dry-run
npx supabase db push --linked
npx supabase migration list --linked
```

Nhập mật khẩu khi CLI hỏi, không nhét mật khẩu vào command hay log gửi Agent.
Kiểm tra ref mà CLI link trước `db push`. Khi thiếu biến Google do parser đọc
config local, chỉ đặt dummy trong shell để CLI đọc được config:

```powershell
# PowerShell — chỉ khắc phục parser config local
$env:GOOGLE_CLIENT_IDS = 'local-dummy.apps.googleusercontent.com'
$env:GOOGLE_CLIENT_SECRET = 'local-dummy'
```

```sh
# macOS/Linux
export GOOGLE_CLIENT_IDS='local-dummy.apps.googleusercontent.com'
export GOOGLE_CLIENT_SECRET='local-dummy'
```

Dummy không dùng cho Google thật và không đưa lên Dashboard hoặc chạy `config
push`. Repo đã có `supabase/config.toml`; không `supabase init` lại. CLI thay đổi
flags thì xem `npx supabase db push --help`, giữ đích là project đã link.

Ở mốc source này có **7 migrations**, CLI tự sắp theo tên timestamp:

```text
20261024000001_init_schema.sql
20261024000002_rls_policies.sql
20261024000003_functions_triggers.sql
20261024000004_debt_reminders_cron.sql
20261024000005_demo_data.sql
20261028000001_offline_history.sql
20261028000002_debt_payment_editing.sql
```

Đây là cách nạp SQL chính thức từ `supabase/migrations/`. Không copy lẻ schema
đầu tiên vào SQL Editor rồi bỏ phần còn lại; cũng không chạy toàn bộ các file
`supabase/tests/*.sql` như migrations. `seed.sql` chủ yếu là chú thích, không phải
backup hoặc bản thay thế schema. Migration demo chỉ tạo helper, không tự nạp
giao dịch vào tài khoản của bạn. Nếu checkout mới hơn có migration bổ sung thì
áp đầy đủ migration hợp lệ trong checkout đó, không khóa cứng ở số 7.

Nếu đã chạy SQL thủ công hoặc lịch sử không khớp, dừng để đối chiếu schema và
history. Không sửa migration đã áp, không tự `migration repair` để lờ lỗi,
không `db reset`, xóa volume hoặc xóa DB. Dùng migration bổ sung khi cần sửa.

### 5.3. Kiểm tra backend vừa dựng

Trong Dashboard đúng project, kiểm tra:

- Public tables có RLS; có các bảng `profiles`, `wallets`, `transactions`,
  `debts`, `debt_payments`, `payables` và các bảng nghiệp vụ còn lại.
- Functions DB có `sync_push` và `sync_pull`; không cấp lại quyền ghi bảng trực
  tiếp để né lỗi sync.
- Storage: `receipts` **private**, `avatars` public, có policies từ migrations.
- Cron: job `tuikhon-debt-reminders`, lịch `0 1 * * *` UTC = **08:00 Việt Nam**.
  Migration có thể bỏ qua scheduler khi `pg_cron` không có; lúc đó phải xử lý
  lịch server riêng và ghi nhận bước nhắc server chưa hoàn tất.

Có thể chạy truy vấn quản trị chỉ đọc trong SQL Editor:

```sql
select tablename, rowsecurity
from pg_tables where schemaname = 'public' order by tablename;

select proname from pg_proc
where pronamespace = 'public'::regnamespace
  and proname in ('sync_push', 'sync_pull');

select id, public from storage.buckets where id in ('receipts', 'avatars');
```

Sau khi đọc [SQL test README](../supabase/tests/README.md), chạy nguyên file
`supabase/tests/cloud_readiness.sql` trong SQL Editor project mới. Đây là smoke
test admin có fixture và `BEGIN`/`ROLLBACK`, kiểm tra cô lập tài khoản và RPC.
Lỗi assertion là thất bại; nếu kết nối còn transaction lỗi, `ROLLBACK` trước khi
dùng lại. Test này không thay thế SMTP, AI, Storage trên máy thật hoặc concurrency.

<a id="email"></a>

## 6. Email OTP và quên mật khẩu

Trong Authentication của **project mới**:

1. Bật Email signup và Confirm email; OTP 6 số, hết hạn 600 giây, gửi lại tối
   thiểu 60 giây để khớp giao diện hiện tại.
2. Tạo dịch vụ SMTP của bạn (ví dụ Resend hoặc nhà cung cấp bạn có), xác minh
   sender/domain và DNS theo yêu cầu nhà cung cấp. Vào Custom SMTP điền sender,
   host, port, username và password; chọn đúng TLS/port của dịch vụ.
3. Confirm signup dùng `supabase/templates/confirmation.html`; Reset password
   dùng `supabase/templates/recovery.html`. Giữ `{{ .Token }}` để thư chứa mã 6 số.
4. Thử đăng ký bằng hộp thư nhận được, nhập OTP, đăng nhập lại, rồi thử quên mật
   khẩu và nhập mã recovery. Kiểm tra Spam, Auth logs và SMTP logs khi lỗi.

SMTP mặc định của Supabase bị giới hạn người nhận/rate, không phù hợp để nghiệm
thu email cho người dùng bên ngoài. Thư chỉ có link xác nhận không khớp màn nhập
mã. Nếu chưa có SMTP, dùng Supabase local + Mailpit theo [SETUP mục 5](../SETUP.md#5-supabase-local)
để phát triển; không coi email cloud đã xong. Không tắt xác thực email như cách
khắc phục mặc định. Xem [SMTP chính thức](https://supabase.com/docs/guides/auth/auth-smtp).

`db push` không tự cấu hình SMTP, email templates cloud, Google provider hay URL
Configuration. Đặt Site URL/redirect allowlist theo domain/callback bạn sở hữu
nếu dùng các luồng link; không chép localhost của tác giả rồi coi app đã có deep
link. Luồng OTP hiện tại nhập mã trực tiếp trong app.

<a id="run"></a>

## 7. Env Flutter và lần chạy đầu

Copy `.env.example` thành `.env` ở gốc repo bằng editor hoặc lệnh phù hợp:

```powershell
Copy-Item .env.example .env
```

```sh
cp .env.example .env
```

Chỉ chạy **một** trong hai lệnh trên theo shell, không ghi đè `.env` đã có. Nội
dung dành cho cloud mới:

```dotenv
SUPABASE_URL=https://REPLACE_NEW_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=REPLACE_NEW_PROJECT_PUBLISHABLE_KEY
GOOGLE_WEB_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

Giữ tên `SUPABASE_ANON_KEY` vì source đọc tên đó; giá trị là publishable key của
cùng project. Không đưa `sb_secret_...`, `service_role`, password DB, SMTP,
OAuth Web secret hoặc Gemini key vào app. `.env` là compile-time config; đổi env
phải dừng/chạy hoặc build lại, hot reload không thay backend.

```sh
git check-ignore .env supabase/.env android/key.properties
flutter devices
flutter run -d REPLACE_DEVICE_ID --dart-define-from-file=.env
```

Giữ Team mode tắt theo mục 4. Cloud dùng HTTPS như nhau cho emulator và điện
thoại thật; không dùng `10.0.2.2` hay `127.0.0.1` cho APK cloud.

Đăng ký **tài khoản app mới** → nhận OTP → xác thực → đợi bootstrap/sync đầu →
ghi một khoản chi và kiểm tra báo cáo. Sau bootstrap mới test offline. Clone
repo không mang SQLite hoặc phiên đăng nhập cũ sang máy của bạn.

Dữ liệu demo là tùy chọn, chỉ trên tài khoản demo vừa đăng ký, chưa chỉnh danh
mục/nguồn hoặc ghi dữ liệu. SQL Editor đúng project, thay email của chính bạn:

```sql
select private.seed_demo_data('REPLACE_WITH_YOUR_NEW_DEMO_EMAIL');
```

Không dùng trên tài khoản thật, không truyền cờ reset; sau đó đồng bộ app.

<a id="ai"></a>

## 8. Gemini và Edge Functions của riêng bạn

Ghi tay, báo cáo local và parser cơ bản không cần Gemini. Nếu checkout có OCR
native mới, OCR trên máy cũng không cần Gemini; “Nhờ AI đọc thêm” mới gọi cloud.

1. Vào [Google AI Studio](https://aistudio.google.com/), tạo/chọn project của
   bạn và tạo Gemini API key. Kiểm tra API/quota và quyền model của project.
2. Tạo `supabase/.env` private chỉ chứa hai biến dưới đây; không copy nguyên
   Google placeholders từ mẫu rồi đẩy tất cả lên secrets.

```dotenv
GEMINI_API_KEY=REPLACE_WITH_YOUR_SERVER_GEMINI_KEY
GEMINI_MODEL=gemini-flash-latest
```

`gemini-flash-latest` là mặc định source tại mốc bàn giao, không đảm bảo model
luôn sẵn sàng hoặc có quota. Nếu model thay đổi, chọn model thực sự được cấp
cho project, kiểm tra hỗ trợ ảnh/JSON và thử lại; không tự bật billing.

```sh
npx supabase secrets set --env-file supabase/.env --project-ref REPLACE_NEW_PROJECT_REF
npx supabase functions deploy ai-quick-record --project-ref REPLACE_NEW_PROJECT_REF
npx supabase functions deploy ai-advisor --project-ref REPLACE_NEW_PROJECT_REF
```

Nếu **thực sự có** `supabase/functions/ai-finance-query/index.ts` trong phiên bản
bàn giao, triển khai thêm:

```sh
npx supabase functions deploy ai-finance-query --project-ref REPLACE_NEW_PROJECT_REF
```

Nếu thiếu file thì bản clone chưa có tính năng này; không tạo Function rỗng cho
đủ tên. Kiểm tra Functions list/logs ở project mới. Runtime tự cấp biến kết nối
Supabase cho Functions; không copy service-role của tác giả vào secrets/app.

Giữ cấu hình xác thực hiện tại (`verify_jwt=true` và `getUserClient` gọi
`auth.getUser`). Project mới có thể dùng signing keys/gateway khác bản cũ. Nếu
Auth đăng nhập được nhưng Function bị 401 trước handler, xem logs, loại access
token và [tài liệu xác thực Functions](https://supabase.com/docs/guides/functions/auth).
Không thay publishable key bằng user JWT hoặc tắt JWT để chữa thử. Nếu cần thích
nghi gateway theo tài liệu mới, Agent phải sửa có kiểm chứng: vẫn xác minh user
server-side trước quota/AI, giữ RLS và kiểm tra thiếu/sai/hết hạn token đều bị từ
chối. Đây là thay đổi riêng cần kiểm thử, không phải bước bật public endpoint.

Nghiệm thu thật từng luồng: ghi nhanh chữ → AI draft; ảnh → chủ động nhờ AI;
cố vấn tháng có giao dịch đã sync; câu hỏi phức tạp → Function lập kế hoạch nếu
có tính năng mới. Model không tự lưu giao dịch. Gọi không đăng nhập phải bị 401.
Fallback local, deploy ACTIVE hoặc model trả 503/timeout **không chứng minh AI
đã chạy được**. Đợt kiểm tra source gần nhất còn gặp AI busy/timeout; người nhận
cần kiểm tra bằng key/project của mình. Không retry liên tục làm tốn quota.

<a id="google"></a>

## 9. Google Sign-In riêng — tùy chọn

Có thể hoàn thành bản email/password trước. Khi bật Google, dùng **Google Cloud
project của bạn**, không dùng client ID/secret hay danh sách test users của nhóm.

1. Cấu hình Google Auth Platform/consent screen: tên app, email hỗ trợ, audience
   và Test users nếu đang Testing. Chọn scopes cần thiết cho đăng nhập.
2. Tạo OAuth client **Web**; Web client ID đi vào `GOOGLE_WEB_CLIENT_ID`, Web
   secret chỉ nhập trong Google provider của Supabase. Nếu cần redirect URI,
   dùng callback Dashboard mới cung cấp, thường là
   `https://REF_MOI.supabase.co/auth/v1/callback`.
3. Android: tạo client **Android** cho `applicationId` mới + SHA-1 của **đúng
   chứng chỉ ký APK**. Debug máy bạn, release riêng và Play App Signing có thể
   có SHA-1 khác nhau; đăng ký các bản bạn thực sự dùng. Lấy SHA bằng Gradle
   signingReport trong thư mục `android` (`.\gradlew.bat signingReport` trên
   Windows; `./gradlew signingReport` trên Mac), hoặc `keytool -list -v` trên JKS.
4. iOS: tạo client **iOS** khớp bundle ID mới; điền `GOOGLE_IOS_CLIENT_ID`. Thêm
   reversed iOS client ID chính xác vào URL Types trong Info.plist/Xcode, không
   tạo trùng khóa `CFBundleURLTypes`.
5. Supabase mới → Auth → Google: bật provider, nhập Web ID/secret và accepted
   IDs cho các client dùng thật, Web ID đứng đầu. Đối chiếu tùy chọn nonce với
   `AuthRepository.signInWithGoogle`: source hiện gọi native `signInWithIdToken`
   không truyền nonce; config local đang `skip_nonce_check=true`. Không sao chép
   cấu hình nonce của luồng OAuth khác mà chưa kiểm tra source.
6. Dừng/build lại app, thử Google trên từng nền tảng và từng kiểu signing.

Không cần dựng Firebase chỉ để đăng nhập Google. Android OAuth client không
thay thế Web server client ID. Lỗi `DEVELOPER_ERROR` thường cần kiểm tra package,
SHA-1 và Web client ID; lỗi chỉ xuất hiện ở release thường do dùng SHA debug.
Đọc [Google Sign-In Supabase](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).

<a id="checks"></a>

## 10. Kiểm thử trước khi đóng gói

```sh
flutter analyze --no-fatal-infos
flutter test
npm ci --prefix supabase/tests --ignore-scripts
node supabase/tests/run-offline-history.cjs
npx --yes deno test supabase/functions/ai-quick-record/result_test.ts supabase/functions/ai-advisor/period_test.ts
npx --yes deno check supabase/functions/ai-quick-record/index.ts supabase/functions/ai-advisor/index.ts
```

Checkout mới có các file dưới đây thì chạy thêm:

```sh
npx --yes deno test --allow-env supabase/functions/_shared/gemini_test.ts supabase/functions/ai-finance-query/plan_test.ts
npx --yes deno check supabase/functions/ai-finance-query/index.ts
```

Chỉ dùng đường dẫn thực sự có trong source. Khi sửa sync/migration
phải đọc và chạy thêm các SQL tests phù hợp trong `supabase/tests/README.md`,
gồm concurrency trên PostgreSQL thử nghiệm khi cần; không chạy trên dữ liệu thật.

Checklist trên app của bạn, ghi rõ ca chưa test thay vì đánh dấu thay:

- [ ] Email đăng ký/OTP, đăng nhập lại và recovery đúng project mới.
- [ ] Thu/chi, số dư, ngân sách, sửa/xóa; tiền VND nguyên và kỳ Việt Nam.
- [ ] Tắt mạng → ghi → đóng/mở app → còn dữ liệu → bật mạng → sync không trùng.
- [ ] Hai tài khoản cô lập; hai thiết bị cùng tài khoản đồng bộ và chọn xung đột.
- [ ] Trả nợ/sửa/hoàn tác và giao dịch liên kết; CSV xuất/nhập có preview.
- [ ] Avatar, hóa đơn private, camera/mic/thông báo/sinh trắc và khi từ chối quyền.
- [ ] Theme/ngôn ngữ, màn nhỏ/chữ 200%/bàn phím; widget Android sau đổi package.
- [ ] OCR native nếu có, AI cloud thật và Google thật nếu chọn dùng.
- [ ] Cài bản cập nhật cùng package/chữ ký giữ dữ liệu, không gỡ app để kiểm tra.

<a id="android"></a>

## 11. Android: từ APK thử đến bản release ký riêng

### 11.1. APK debug để chạy ngay

```sh
flutter build apk --debug --dart-define-from-file=.env
adb -s REPLACE_DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
```

Đầu ra: `build/app/outputs/flutter-apk/app-debug.apk`. Lệnh `adb` dùng Android
device ID; xem `adb devices`. Nếu chỉ có một thiết bị có thể bỏ `-s ...`.
Debug dùng chứng chỉ máy của bạn khi Team tắt. Trên điện thoại có thể mở file APK
và cấp quyền cài từ nguồn được chọn. Dừng nếu installer báo sai chữ ký/package;
không gỡ app có dữ liệu chưa sync để ép cài.

### 11.2. Tạo khóa release và sửa Gradle trong fork

**Source hiện tại gán `release` vào signing config `debug`. Chỉ chạy
`flutter build apk --release` chưa tạo bản phát hành được ký riêng.**

Tạo keystore mới **một lần**, kiểm tra đường dẫn chưa có trước khi chạy:

```sh
keytool -genkeypair -v -keystore android/app/personal-upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keytool thuộc JDK; nếu chưa có trong PATH dùng đường dẫn tương ứng Java mà
Flutter chọn. Nhập password tương tác, không ghi nó vào prompt hoặc lệnh shell.
Giữ backup keystore/password riêng, không tự sinh lại ở lần build tiếp theo.

Tạo `android/key.properties` private (đường dẫn dưới đây tính từ `android/app`):

```properties
storePassword=REPLACE_PRIVATE_STORE_PASSWORD
keyPassword=REPLACE_PRIVATE_KEY_PASSWORD
keyAlias=upload
storeFile=personal-upload-keystore.jks
```

Trong `android/app/build.gradle.kts`, sau `plugins` và trước `android {}`, nạp
properties; file đã import `java.util.Properties`:

```kotlin
val releaseSigningFile = rootProject.file("key.properties")
val releaseSigning = Properties()
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use { releaseSigning.load(it) }
}
```

Trong `android {}`, thêm `signingConfigs` trước `buildTypes`; giữ các thiết lập
Java/desugaring/SDK hiện có và logic Team debug nếu fork còn giữ nó:

```kotlin
signingConfigs {
    create("release") {
        if (releaseSigningFile.isFile) {
            keyAlias = releaseSigning.getProperty("keyAlias")
            keyPassword = releaseSigning.getProperty("keyPassword")
            storeFile = file(releaseSigning.getProperty("storeFile"))
            storePassword = releaseSigning.getProperty("storePassword")
        }
    }
}
```

Thay **dòng signing trong release hiện có**, không thêm block release thứ hai:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

Thiếu signing file phải làm release thất bại, không fallback debug. Kiểm tra
`git check-ignore android/key.properties android/app/personal-upload-keystore.jks`;
chỉ commit phần code cấu hình khi bạn muốn, không commit file private.

### 11.3. Build và xác minh

```sh
flutter build apk --release --dart-define-from-file=.env
# Chỉ khi cần tải lên Google Play:
flutter build appbundle --release --dart-define-from-file=.env
```

| Định dạng | Đầu ra | Dùng cho |
| --- | --- | --- |
| APK | `build/app/outputs/flutter-apk/app-release.apk` | Cài trực tiếp Android |
| AAB | `build/app/outputs/bundle/release/app-release.aab` | Tải lên Google Play, không cài trực tiếp như APK |

Dùng `apksigner verify --print-certs PATH_TO_APK` trong Android SDK Build-Tools,
đối chiếu SHA-1/SHA-256 với `keytool -list -v` của keystore riêng; kiểm tra package
bằng APK Analyzer. Cài/thử release thật, gồm Google với SHA release. Play App
Signing dùng cert phân phối của Play nên đăng ký SHA của cert đó khi phát Store.

Debug và release thường khác chữ ký, không nâng cấp đè lẫn nhau. Quyết định bản
dùng lâu dài trước khi nhập dữ liệu thật; không xóa app đang dùng để né lỗi ký.
Tăng build number trong `pubspec.yaml` khi cập nhật. Phát hành Play còn cần tài
khoản developer, metadata, quyền riêng tư/Data safety và yêu cầu Store tại lúc
gửi; build AAB thành công chưa đồng nghĩa đã xuất bản.

<a id="ios"></a>

## 12. iOS: Simulator, iPhone và IPA

Thực hiện trên **Mac** với cùng commit và env của project riêng. Không chép
build/generated/SDK path từ Windows. Cài Xcode và platform/runtime theo
`flutter doctor -v`; người dùng hoàn tất license và tải components cần thiết.

```sh
xcodebuild -version
flutter doctor -v
flutter pub get
flutter gen-l10n
flutter build ios --simulator --debug --dart-define-from-file=.env
open ios/Runner.xcworkspace
```

Trong checkout hiện tại iOS dùng **Swift Package Manager**, không có `ios/Podfile`;
đừng mặc định lỗi vì thiếu Podfile hoặc chạy `pod install`. Nếu bản/plugin thực
sự cần CocoaPods, xử lý theo toolchain thực tế và tài liệu Flutter. Giữ target
iOS **15.0** hoặc minimum cao hơn mà dependencies thực tế yêu cầu. Nếu có OCR
mới, giữ build phase `Copy Latin OCR resources` và
`tool/copy_mlkit_resources.py`; kiểm tra Python 3 ở đường dẫn build phase dùng,
model Latin có trong app sau build. Không xóa phase để ép build xanh.

Trong Xcode, Runner → Signing & Capabilities:

1. Chọn bundle ID đã chốt, Team Apple của bạn và signing/provisioning phù hợp
   cho các build configurations. Không dùng Team/certificate của người gửi.
2. Kiểm tra tên, icon, deployment target, camera/mic/photo/speech/Face ID usage
   descriptions và Google reversed URL scheme nếu bật Google iOS.
3. Cắm iPhone, Trust máy/Mở Developer Mode khi hệ thống yêu cầu. Chọn device,
   kiểm tra signing rồi chạy qua Flutter với env:

```sh
flutter devices
flutter run -d REPLACE_IPHONE_ID --dart-define-from-file=.env
```

Chạy Simulator không tạo IPA cho iPhone. Apple Account cá nhân có thể có tùy
chọn chạy development giới hạn theo chính sách Apple; không thay thế quyền
phân phối TestFlight/App Store.

Khi có Apple Developer Program và distribution signing hợp lệ:

```sh
# TestFlight/App Store
flutter build ipa --release --dart-define-from-file=.env

# Hoặc chọn MỘT phương thức khác phù hợp tài khoản/profile:
flutter build ipa --release --export-method development --dart-define-from-file=.env
flutter build ipa --release --export-method ad-hoc --dart-define-from-file=.env
```

Đầu ra archive: `build/ios/archive/`; IPA: `build/ios/ipa/`. Với ad hoc phải đăng
ký thiết bị và có profile phù hợp. IPA không cài tự do trên mọi iPhone như APK.
Với TestFlight/Store, tạo App ID/app record cùng bundle ID ở App Store Connect,
tăng build number, upload qua Xcode Organizer/Transporter, chờ processing và
nghiệm thu TestFlight; App Store còn có quy trình review và metadata/privacy.
Nếu Flutter/Xcode đổi tên export method, xem `flutter build ipa --help` và chọn
trong Xcode Organizer, không sửa signing bừa để vượt lỗi.

Source đã chỉnh cấu hình/icon iOS nhưng **chưa được build/nghiệm thu trên Mac**
ở mốc bàn giao. Chỉ đánh dấu hoàn tất sau build và thử thật camera/OCR/mic,
notification, sinh trắc, Google nếu bật, đồng bộ và offline trên iOS.

## 13. Các lỗi dễ gặp và cách tiếp tục

| Hiện tượng | Kiểm tra trước |
| --- | --- |
| IDE đòi ZIP Team | Run config/biến `TUI_KHON_TEAM`; dùng mục 4 và lệnh Flutter thường |
| Clone thiếu OCR/hỏi dữ liệu | Commit/nhánh thực tế; diff chưa commit của người gửi không có trên GitHub |
| CLI báo thiếu Google env | Dummy shell ở mục 5.2; không đẩy dummy thành Google cloud |
| Không có `sync_pull`/bị chặn ghi bảng | Đúng project và đủ migrations; không nới RLS/grants |
| Email không tới/chỉ có link | SMTP riêng, sender/domain, template Token, rate limits, logs |
| Function 401 dù đã login | URL/key cùng project, user session/JWT và gateway signing; mục 8 |
| AI timeout/503/quota | Secrets server, quyền model, quota/logs; giữ bản nháp và khả năng ghi tay |
| Google debug được, release lỗi | Package và SHA của chính APK release/Play App Signing |
| APK báo signature mismatch | Khác khóa hoặc app đang có; không uninstall để chữa, kiểm tra cert |
| iOS không có Podfile | Checkout dùng SwiftPM; không tự tạo Podfile/ghi đè thư mục iOS |
| iOS build được nhưng OCR lỗi | Model bundle/build phase, plugin khóa, target và quyền ảnh/camera |
| Dữ liệu chưa sync/xung đột | Vào Đồng bộ, xử lý lỗi/chọn bản; giữ SQLite/outbox |

## 14. Bàn giao sau khi Agent hoàn thành

Yêu cầu Agent báo lại: commit và diff, versions toolchain, ref Supabase mới,
package/bundle, cách chạy, kết quả tests, đường dẫn APK/IPA, fingerprint chứng
chỉ công khai và danh sách ca đã/chưa thử. Không đưa password/token/key hoặc
nội dung tài chính vào báo cáo. Giữ backup secrets và signing ngoài repo.

Các mốc tách biệt: **build được** → **đăng nhập/sync được** → **AI/Google thật
nếu chọn** → **cài bản ký riêng được** → **phân phối được nếu yêu cầu**. Không
dùng kết quả của cloud tác giả để đánh dấu backend mới đã đạt.

## 15. Nguồn chính thức để tra khi dịch vụ thay đổi

- [Flutter installation](https://docs.flutter.dev/install),
  [Android signing/build](https://docs.flutter.dev/deployment/android),
  [iOS archive/signing/TestFlight](https://docs.flutter.dev/deployment/ios).
- [Flutter Swift Package Manager](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers).
- [Supabase CLI](https://supabase.com/docs/reference/cli/introduction),
  [migrations](https://supabase.com/docs/guides/deployment/database-migrations),
  [API keys](https://supabase.com/docs/guides/api/api-keys).
- [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp),
  [email templates](https://supabase.com/docs/guides/auth/auth-email-templates),
  [Function auth](https://supabase.com/docs/guides/functions/auth),
  [Google OAuth](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).
- [Gemini API keys](https://ai.google.dev/gemini-api/docs/api-key),
  [models và trạng thái hỗ trợ](https://ai.google.dev/gemini-api/docs/models).
