# Túi Khôn — một bộ setup chung cho Nhóm 5 (Windows)

Cả nhóm, kể cả máy chủ dự án, dùng cùng `.env`, backend cloud, Google Web client
ID, package và khóa ký Team. Mỗi người đăng nhập **tài khoản app riêng**. Dữ liệu
SQLite/RLS vẫn tách theo tài khoản; dùng chung cấu hình không phải dùng chung dữ liệu.

Không cần tạo lại Supabase, SMTP, Google OAuth hoặc Gemini; không cần Docker,
Node.js hay Supabase CLI chỉ để chạy Flutter. Không chạy migration trên cloud nhóm.

## 1. Công cụ cố định

| Công cụ | Phiên bản |
| --- | --- |
| Flutter stable | **3.47.7** |
| Dart đi kèm | **3.13.5** |
| JDK mà Flutter sử dụng | **Java 17** |
| Android compile SDK | Theo Flutter này: **36** |
| Android NDK | Theo Flutter này: **28.2.13676358** |
| Gradle | Wrapper trong source: **9.3.1** |

Cài Git, Android Studio, Flutter/Dart plugins, SDK Platform, Platform-Tools,
Command-line Tools và SDK/NDK trong bảng. Không sao chép đường dẫn SDK từ máy khác.
Script đọc SDK/NDK từ chính Flutter đã cài và kiểm tra đường dẫn của
`android/local.properties` có thống nhất với Flutter không.

```powershell
flutter --version
flutter doctor -v
# Nếu Flutter chọn JDK khác, dùng đường dẫn JDK 17 thực tế trên máy mình:
flutter config --jdk-dir "C:\duong-dan\jdk-17"
# Tự đọc và chấp nhận giấy phép nếu Flutter yêu cầu:
flutter doctor --android-licenses
```

Không chạy `flutter pub upgrade` hoặc thay Gradle để vượt qua doctor. Lần setup
đầu cần mạng tải packages/Gradle. Dùng emulator có Google Play Services hoặc điện
thoại Android đã bật và cho phép USB debugging.

## 2. Clone source và nhập đúng ZIP private

Nhận phiên bản source bàn giao và **TuiKhon-Team-Setup.zip** qua kênh riêng.
Nhánh bàn giao bộ v2 là `codex/shared-env-ai`, đang được review bằng PR vào `dev`.
Nhánh phải chứa `tool/team.ps1` hỗ trợ **bundleVersion 2**; bản script cũ v1 không
đọc được ZIP mới. Trong khi PR chưa merge, clone đúng nhánh dưới đây.

```powershell
git clone --branch codex/shared-env-ai https://github.com/lethanhtrong161005/tui-khon-mobile.git
cd tui-khon-mobile
powershell -NoProfile -ExecutionPolicy Bypass -File tool/team.ps1 setup -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip"
powershell -NoProfile -ExecutionPolicy Bypass -File tool/team.ps1 run
```

`ExecutionPolicy Bypass` chỉ áp dụng cho tiến trình này. Nếu máy đã cho phép chạy
script, có thể dùng `.\tool\team.ps1 setup ...` và `.\tool\team.ps1 run`.

ZIP v2 có đúng bốn file gốc: `.env`, `manifest.json`, `signing.properties` và
`team-debug.jks`. `.env` có **đúng bốn biến**, thứ tự cố định, UTF-8 không BOM/LF:

```dotenv
SUPABASE_URL=<backend cloud dùng chung>
SUPABASE_ANON_KEY=<publishable hoặc anon key>
GOOGLE_WEB_CLIENT_ID=<Web client ID dùng chung>
GOOGLE_IOS_CLIENT_ID=
```

Không tự điền các placeholder trên; setup lấy giá trị thật từ ZIP. Gemini key,
OAuth Web secret và SMTP password chỉ ở server, không cần gửi cho thành viên.
ZIP chứa khóa ký dev/password ký, **không mã hóa**; chỉ chia sẻ riêng trong nhóm,
không đăng GitHub hoặc đưa ZIP, `.env`, `.team/`, backup vào commit.

Setup kiểm tra checksum, chứng chỉ, cấu hình và công cụ trước khi nạp; sau đó chạy
`flutter pub get` và `flutter gen-l10n`. Cùng ZIP có thể setup lại mà không đổi khóa.
Nếu `.env` hiện có khác chuẩn, setup dừng và **không ghi đè**. Sau khi đối chiếu:

```powershell
.\tool\team.ps1 setup -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip" -ReplaceEnv
```

Lựa chọn này sao lưu **nguyên file cũ** tại `.team/backups/<mốc-thời-gian>/`
trước khi thay `.env`. Nó không cho phép thay khóa ký khác. Nếu khóa khác, dừng
và xin lại đúng ZIP; không gỡ app để sửa lỗi chữ ký.

ZIP v1 chứa `.env.team` vẫn được hỗ trợ: kiểm tra bản cũ trước, chuyển đúng bốn
biến sang `.env`, giữ nguyên JKS/password, nâng manifest cài đặt lên v2 và giữ
nguyên env cũ trong backup. `.env.team` ở gốc được sao lưu rồi loại khỏi đường
chạy. Từ đây chỉ dùng `.env`, không duy trì hai cấu hình song song.

## 3. Một cách chạy và chẩn đoán

```powershell
.\tool\team.ps1 doctor
.\tool\team.ps1 run
.\tool\team.ps1 run -DeviceId emulator-5554
.\tool\team.ps1 build
```

`run` và `build` luôn kiểm tra công cụ/env/chứng chỉ trước, bật `TUI_KHON_TEAM=1`
và dùng `--dart-define-from-file=.env`. APK nằm tại
`build/team/tui-khon-team-debug.apk`. Profile Team chỉ cho debug; không dùng khóa
này phát hành store. Giữ nguyên khóa để cài cập nhật mà không gỡ/xóa dữ liệu.

- **VS Code:** chọn `Túi Khôn (Nhóm 5) - cloud`, chọn thiết bị rồi F5. Task doctor
  chạy trước khi launch; không chọn bỏ qua lỗi task.
- **Android Studio:** chạy `doctor` trong Terminal trước mỗi lần Run/Build, rồi chọn
  `Tui Khon Team - cloud`. Cấu hình chia sẻ trong `.run/` dùng `.env`, entrypoint
  `lib/main.dart`, debug và environment `TUI_KHON_TEAM=1`. Ưu tiên script cho build
  để luôn có kiểm tra và báo cáo đầy đủ; không dùng build release của IDE.

Bản Team có package `com.example.tui_khon_mobile.team`, nhãn **Túi Khôn (Nhóm 5)**,
cài song song với `com.example.tui_khon_mobile` cũ. Mỗi app có phiên đăng nhập,
SQLite, tùy chỉnh và widget riêng. Nếu cùng đăng nhập một tài khoản thì dữ liệu
cloud của tài khoản đó vẫn đồng bộ.

## 4. Báo lỗi để so sánh các máy

Mỗi lệnh ghi `.team/diagnostics.json`, kể cả khi kiểm tra thất bại. Có thể chọn
file khác trong `.team/` bằng `-Report .team/review-diagnostics.json`.
Báo cáo chứa commit và trạng thái source có diff, phiên bản bundle/công cụ,
backend host, SHA-256 **của cả file cấu hình**, SHA-1 chứng chỉ và kết quả kiểm tra;
không chứa giá trị key/password/token. Hash giúp đối chiếu, không phải bản sao env.

Hai máy cùng bộ setup phải có cùng `configSha256`, `certificateSha1`, backend và
phiên bản công cụ. Commit cũng phải khớp; `sourceDirty: true` nghĩa là cần đối chiếu
thêm diff, không được suy ra source giống chỉ từ commit. Không gửi `.env` hoặc
`.team/backups/` để báo lỗi. Dùng [mẫu báo lỗi](TEAM_BUG_REPORT.md).

| Lỗi | Xử lý |
| --- | --- |
| Flutter/Dart/JDK lệch | Cài đúng bản trong bảng; kiểm tra JDK được Flutter chọn |
| SDK/NDK thiếu hoặc lệch | Cài đúng SDK/NDK bằng SDK Manager; đối chiếu `local.properties` |
| `.env` khác hoặc bị sửa | Xin đúng ZIP; dùng `-ReplaceEnv` có chủ đích để sao lưu/thay |
| Chữ ký/checksum sai | Không đổi khóa; xin lại bundle gốc, giữ dữ liệu app |
| Không thấy thiết bị | Mở emulator hoặc cho phép USB debugging |
| Google từ chối đăng nhập | Đúng email trong Test users, đúng Team ZIP và Play Services |
| OTP chậm | Xem Inbox/Spam, hạn gửi lại và hạn mức SMTP chung |
| Gemini bận/hết thời gian | Dùng nhập tay/fallback offline; giữ hạn mức, thử lại sau |

## 5. Dịch vụ chung và giới hạn nghiệm thu

- Supabase, Google provider và Gmail SMTP đã cấu hình từ trước. Email/OTP đã có
  nghiệm thu API thật; không cần App password trên máy thành viên.
- Đã bổ sung bốn email thành viên được cung cấp vào Google Test users, giữ chủ dự
  án (tổng 5). Không ghi danh sách email cá nhân vào repo. Google native trên từng
  máy thành viên vẫn cần thử riêng sau setup; OAuth Web đã qua không thay thế bước này.
- Đã đưa Gemini key riêng lên server, đặt `GEMINI_MODEL=gemini-flash-latest` và
  deploy `ai-quick-record`, `ai-advisor`. Giữ nguyên quota, không bật billing.
- Lượt kiểm tra ngày 07/11/2026: API có xác thực hoạt động nhưng ba kết quả AI thật
  **chưa nghiệm thu được**: ghi nhanh/ảnh hết thời gian, advisor lỗi upstream.
  Gọi trực tiếp cùng model nhận HTTP 503 `UNAVAILABLE`/high demand. Không coi deploy
  thành công là AI đã qua. Fixture có chi tiêu thật cô lập đã được dọn với identity
  guard; các lời gọi AI không làm tăng/sửa giao dịch. Xem [HANDOFF](HANDOFF.md).
- Widget Team lấy từ launcher dưới app Nhóm 5: **Chi | Quét ảnh | Thu**.

## 6. Người giữ bộ setup

```powershell
.\tool\team.ps1 pack
# Hoặc chọn thư mục private đã có khóa Team gốc, nằm ngoài checkout:
.\tool\team.ps1 pack -OutputDirectory "C:\Private\TuiKhon-Team-Private"
```

`pack` lấy riêng bốn biến app từ `.env`, yêu cầu **khóa Team hiện có**, không sinh
khóa mới và không đọc `supabase/.env`. Bản ZIP/manifest/env private trước đó được
sao lưu vào `backups/` cạnh ZIP trước khi đóng lại. Nạp ZIP v2 vào chính máy chủ dự
án bằng setup; nếu env cũ còn biến thừa thì dùng `-ReplaceEnv` để giữ bản sao đầy đủ.

Kiểm tra script độc lập (cần ZIP private để dùng đúng chứng chỉ, không gọi cloud):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test-team-setup.ps1 -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip"
```

Tests tạo fixture và Flutter giả trong `.dart_tool/`, dùng env giả, không sửa SDK
hay dữ liệu app thật. Build và clone với công cụ thật là nghiệm thu bổ sung.
Không nâng quyền quản trị Google/Supabase cho thành viên chỉ để chạy app.
