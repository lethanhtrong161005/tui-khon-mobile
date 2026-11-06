# Chạy Túi Khôn trên máy Windows của thành viên Nhóm 5

Nhóm dùng chung **backend cloud tui-khon-dev**, SMTP và Google OAuth đã cấu hình.
Không tạo project Supabase/Google mới, không chạy migration, không cần Docker,
Node.js, Supabase CLI hoặc mật khẩu quản trị chỉ để chạy app.

Bản **Túi Khôn (Nhóm 5)** có package `com.example.tui_khon_mobile.team`, cài song
song với app cũ. Hai app có SQLite, phiên đăng nhập, tùy chỉnh và widget riêng.
Nếu đăng nhập cùng tài khoản ở hai app, dữ liệu cloud của tài khoản đó vẫn đồng bộ.
Mỗi thành viên nên đăng ký tài khoản riêng; không dùng chung tài khoản của trưởng nhóm.

## 1. Cài công cụ một lần

- Git và **Flutter 3.47.7 stable** (đi kèm Dart 3.13.5); thêm Flutter `bin` vào PATH.
- Android Studio, Flutter/Dart plugins, Android SDK, Platform-Tools, Command-line
  Tools, SDK/NDK mà Gradle yêu cầu và một JDK tương thích. Dùng `flutter doctor -v`
  để kiểm tra; không sao chép đường dẫn SDK/JDK từ máy người khác.
- Tự đọc/chấp nhận giấy phép bằng `flutter doctor --android-licenses` nếu được yêu cầu.
- Emulator Android có **Google Play Services** để thử Google, hoặc điện thoại
  bật USB debugging và đã chấp nhận quyền kết nối máy tính.

Phiên bản tối thiểu của lockfile: Flutter >=3.47, Dart >=3.13,<4. Script cảnh báo
nếu khác bản đã kiểm thử 3.47.7. Không chạy `flutter pub upgrade` khi nhận source.
Lần đầu cần mạng tải packages/Gradle/SDK và đăng nhập/bootstrap dữ liệu.

## 2. Clone và nạp bộ cấu hình private

Nhận **TuiKhon-Team-Setup.zip** từ trưởng nhóm qua kênh riêng. ZIP chứa cấu hình
client và khóa ký **dev của nhóm**, không chứa mật khẩu tài khoản app hoặc secret
của Supabase/Gemini/Google/SMTP. Không đăng ZIP lên GitHub, gửi công khai hoặc thêm
vào commit. ZIP không được mã hóa; chỉ chia sẻ cho người trong nhóm.

```powershell
git clone --branch codex/team-windows-setup https://github.com/lethanhtrong161005/tui-khon-mobile.git
cd tui-khon-mobile
powershell -NoProfile -ExecutionPolicy Bypass -File tool/team.ps1 setup -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip"
powershell -NoProfile -ExecutionPolicy Bypass -File tool/team.ps1 run
```

`-ExecutionPolicy Bypass` chỉ áp dụng cho tiến trình chạy script này, không thay
đổi execution policy của Windows. Nếu máy đã cho chạy script, dùng ngắn gọn
`.\tool\team.ps1 setup -Bundle ...` và `.\tool\team.ps1 run`.

Setup kiểm tra ZIP/keystore, tạo `.env.team` cùng `.team/`, chạy `flutter pub get`
và `flutter gen-l10n`. Không ghi đè `.env`, `.env.local`, khóa debug cá nhân hoặc
dữ liệu app. Chạy lại cùng ZIP được; nếu file đã bị sửa hoặc ZIP khác, script dừng
để bạn tự sao lưu/đối chiếu thay vì tự ghi đè hay đổi khóa ký.

## 3. Chạy, chẩn đoán và build

```powershell
.\tool\team.ps1 doctor
.\tool\team.ps1 run
# Khi có nhiều thiết bị, chọn trong danh sách hoặc chỉ rõ:
.\tool\team.ps1 run -DeviceId emulator-5554
.\tool\team.ps1 build
```

APK Team nằm tại `build/team/tui-khon-team-debug.apk`. Chỉ là bản thử nội bộ;
khóa Team không dùng để phát hành store. Giữ nguyên khóa để cài cập nhật bản Team
mà không phải gỡ app hoặc mất dữ liệu chưa đồng bộ. Không gỡ app cũ để xử lý lỗi ký.

- **VS Code:** chọn `Túi Khôn (Nhóm 5) - cloud` và thiết bị Android rồi F5.
- **Android Studio:** mở gốc repo; chọn run configuration chia sẻ `Tui Khon Team - cloud`
  trong `.run/`. Nếu IDE chưa nhận cấu hình: tạo Flutter configuration, entrypoint
  `lib/main.dart`, Additional run args `--dart-define-from-file=.env.team`,
  Environment variables `TUI_KHON_TEAM=1`; working directory là gốc repo.
- **Terminal thủ công:** đặt `$env:TUI_KHON_TEAM='1'`, chạy
  `flutter run --debug --dart-define-from-file=.env.team`. Khi quay lại build cá nhân,
  xóa biến này bằng `Remove-Item Env:TUI_KHON_TEAM -ErrorAction SilentlyContinue`.
  Script `team.ps1` tự khôi phục biến môi trường sau khi kết thúc.

Không chỉ thêm `.env.team` mà bỏ biến Team: APK sẽ có package/chứng chỉ cá nhân,
không khớp OAuth đã đăng ký chung. Chế độ Team từ chối build release/profile.

## 4. Đăng nhập và dữ liệu

- Email/mật khẩu: đăng ký bằng email riêng, lấy OTP 6 số trong thư và xác nhận.
  Quên mật khẩu cũng dùng OTP. Chủ dự án đã cấu hình SMTP; thành viên không cần App password.
- Google: gửi **Gmail của mình** cho trưởng nhóm để thêm vào Test users vì OAuth
  đang ở Testing. Không cần tạo OAuth client hoặc lấy SHA-1 trên từng máy khi dùng
  đúng bundle Team. Người chưa có trong danh sách vẫn dùng email/OTP được.
- Đợi bootstrap đầu tiên khi có mạng, sau đó ghi chép offline. Khi thử đồng bộ,
  dùng cùng tài khoản trên các thiết bị của mình; RLS vẫn tách tài khoản khác.
- Gemini được gọi từ server: cả nhóm cùng dùng khi server được cấu hình. Bộ setup
  này không tự tạo Gemini key và không đánh dấu AI thật đã nghiệm thu.
- Widget Team: thêm từ launcher dưới app `Túi Khôn (Nhóm 5)`, ba nút
  **Chi | Quét ảnh | Thu**. Widget của app cũ vẫn thuộc app cũ.

## 5. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không tìm thấy Flutter | Cài 3.47.7, thêm `bin` vào PATH, mở lại terminal |
| Thiếu SDK/JDK/license | Xem `flutter doctor -v`; cài công cụ bằng Android Studio, tự chấp nhận licenses |
| Thiếu ZIP hoặc file Team | Nhận ZIP private, chạy lại `setup`; không copy `supabase/.env` |
| ZIP/checksum/keystore không khớp | Không dùng file lỗi; xin lại đúng ZIP, giữ bản hiện tại để đối chiếu |
| File Team đã thay đổi | Script không ghi đè; tự sao lưu và thống nhất cấu hình với trưởng nhóm |
| Không có thiết bị | Mở Device Manager/start emulator hoặc kết nối và cho phép USB debugging |
| Google không cho đăng nhập | Kiểm tra Gmail trong Test users, đúng profile Team và Google Play Services |
| Cài đè báo chữ ký khác | Không gỡ app/xóa dữ liệu; xác nhận đúng package Team và đúng ZIP gốc |
| Email OTP chậm | Kiểm tra Spam, chờ hạn gửi lại; trưởng nhóm xem SMTP/Auth logs và hạn mức chung |
| AI chưa hoạt động | Kiểm tra trạng thái Gemini phía server; ghi tay/fallback offline vẫn dùng được |

## 6. Dành cho người giữ cấu hình nhóm

```powershell
.\tool\team.ps1 pack
```

Lệnh lấy **chỉ** bốn biến client hợp lệ từ `.env`, tạo khóa Team mới lần đầu và
đóng gói vào thư mục **TuiKhon-Team-Private** cạnh checkout. Lần sau giữ nguyên
keystore/password; sao lưu thư mục private đó. Có thể chọn vị trí khác ngoài repo
bằng `-OutputDirectory`. Script không đọc hoặc đóng gói `supabase/.env`.

Đăng ký một OAuth Android cho package `com.example.tui_khon_mobile.team` với SHA-1
script in ra. Thêm client ID này vào Supabase Google provider, giữ Web client ID
đứng đầu và giữ nguyên client Android cũ. Thêm Gmail của thành viên vào Test users;
không ghi danh sách cá nhân hoặc credentials vào repo. Không cần cấp quyền quản
trị Supabase/Google để thành viên chạy Flutter.

Kiểm tra trước bàn giao: `flutter analyze --no-fatal-infos`, `flutter test`, build
và kiểm tra package/chữ ký APK; thử clone sạch với ZIP. Trạng thái nghiệm thu thực
tế được ghi trong [HANDOFF](HANDOFF.md); không suy ra AI/Google native đã qua chỉ
vì script hoặc APK build thành công.
