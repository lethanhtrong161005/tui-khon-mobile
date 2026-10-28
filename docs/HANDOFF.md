# Context bàn giao Túi Khôn — 28/10/2026

## 1. Đọc trước khi tiếp tục

- Repository: https://github.com/lethanhtrong161005/tui-khon-mobile
- Nhánh bàn giao: **`feature/offline-ai-history`**. Dùng `git log -1 --oneline`
  để xác định commit đang làm; không mặc định clone xong là đã ở đúng nhánh.
- Bản bàn giao giữ 9 commit nền trước đó, bổ sung toàn bộ UI, sửa nghiệp vụ trả nợ
  và tài liệu mới. Không merge vào `dev`, chưa tạo PR; không tạo `main` trong đợt này.
- `feature/supabase-backend` là bản trước offline. Ba nhánh PRM-3, PRM-4 và
  transaction-management phát triển từ bản cũ, chưa được merge; không merge nguyên
  chúng vào bản này để lấy theme/profile/giao dịch vì khác kiến trúc và có xung đột.
- Hướng dẫn đầy đủ: [SETUP](../SETUP.md), [nghiệp vụ](NGHIEP_VU.md),
  [nâng cấp offline giữ dữ liệu](OFFLINE_UPGRADE.md), [SQL tests](../supabase/tests/README.md).

## 2. Các quyết định đã chốt

Túi Khôn là **sổ ghi chép tài chính cá nhân**, giúp người dùng tự ghi thu/chi và
theo dõi kế hoạch. App không giữ tiền, chuyển khoản, đọc thông báo ngân hàng hoặc
liên kết tài khoản ngân hàng. Nguồn tiền chỉ là nhãn và số dư do người dùng tự khai.

- Đã loại bỏ chia tiền nhóm và mua gói PRO. Các chức năng hiện có đều miễn phí;
  AI có quota để kiểm soát chi phí, không phải paywall.
- Stack hiện tại: Flutter/Riverpod, SQLite qua Drift, Supabase Auth/Postgres/RLS/
  Storage/Edge Functions, Gemini chỉ gọi phía server. Backend Java đã bỏ khỏi
  phạm vi; không cần dựng `tui_khon_be` hoặc dự án tham khảo Graduation-Project.
- Tiền VND là số nguyên (`int` trong Dart, `bigint` trong DB). Ngày báo cáo,
  lịch trả nợ và kỳ tháng theo giờ Việt Nam; timestamp gửi server dùng UTC.
- AI chỉ tạo đề xuất/bản nháp, người dùng kiểm tra rồi xác nhận lưu. Không tự
  đoán số tiền còn thiếu hoặc tự ghi chi khi đến hạn.

## 3. Dữ liệu và luồng kỹ thuật

```text
UI / Riverpod → repository → SQLite theo tài khoản
                                  ↕ dữ liệu + outbox cùng transaction
                             sync controller
                                  ↕ sync_push / sync_pull
                         Supabase Postgres + RLS

Auth → Supabase Auth; ảnh → local trước, Supabase Storage sau
AI → Edge Functions → Gemini (key không nằm trong Flutter)
```

- `lib/core/offline/`: LocalStore, các repository offline, đồng bộ và xung đột.
  Giao diện/dashboard/báo cáo đọc local, không thay bằng truy vấn Supabase trực
  tiếp khi thêm màn mới.
- Lần đăng nhập và bootstrap đầu cần mạng. Sau đó có thể ghi offline và giữ dữ
  liệu khi token hết hạn; cần đăng nhập lại để đồng bộ. Không hứa sync liên tục
  khi hệ điều hành đóng app.
- Mỗi thao tác dùng operation ID cố định khi retry; bản ghi có version và dấu
  xóa. `sync_pull` theo cursor server. Xung đột giữ cả local/server để user chọn,
  không tự ghi đè số tiền. Lỗi trả vượt nợ giữ thao tác lỗi để chỉnh, không cắt tiền.
- Ảnh hóa đơn lưu local trước và upload sau. Nhận dạng ảnh chỉ chạy khi có mạng
  và người dùng yêu cầu; thiếu AI vẫn ghi tay được.
- Không reset dữ liệu để nâng cấp. Migration mới nhất là
  `20261028000002_debt_payment_editing.sql`; local cũ đã áp và kiểm tra dữ liệu
  trước/sau không đổi. Laptop mới áp đủ migrations của repo.

### Các chức năng đã có

| Khu vực | Luồng hiện tại |
| --- | --- |
| Auth | Đăng ký → OTP email → bootstrap local → Home; email/password, quên mật khẩu, Google khi có OAuth; khóa sinh trắc học tùy chọn |
| Trang chủ / Thống kê | Tổng thu/chi, số dư ghi chép, tiến độ ngân sách, giao dịch gần đây, biểu đồ; nút + giữa gom các thao tác phụ |
| Ghi nhanh | Gõ/nói tiếng Việt, ảnh hóa đơn, AI tối đa 10 bản nháp; sửa/chọn trước khi lưu; hỏi lại, học phân loại và cảnh báo trùng |
| Giao dịch / CSV | Lọc/tìm/sửa/xóa; xem ảnh; xuất và nhập CSV có preview, ánh xạ và kiểm tra trùng, tối đa 10.000 dòng/file |
| Kế hoạch | Ngân sách tổng/từng danh mục, mục tiêu tiết kiệm, sổ vay/cho vay và lịch sử trả/thu |
| Nhắc nhở | Nhắc ghi chép, hạn nợ, khoản phải trả một lần/tuần/tháng; xác nhận đã trả riêng cho mỗi kỳ |
| Báo cáo tháng | Tổng quan → so sánh toàn tháng trước → donut top 5 + Khác → ngân sách → nhận xét AI có cache |
| Cá nhân | Hồ sơ/avatar, nguồn tiền, danh mục, quy tắc phân loại, CSV, nhắc nhở, báo cáo, đồng bộ/xung đột và đăng xuất |

### Các quy tắc mới của sổ nợ

- `PlanningRepository.settleDebt` nhận thêm `paidAt`, `note`, `walletId` tùy chọn;
  `updateDebtPayment` và `undoDebtPayment` sở hữu nghiệp vụ sửa/hoàn tác.
- Một lần trả có tối đa một giao dịch liên kết. ID có sẵn được giữ nguyên;
  lần đầu bật ghi kèm khi sửa dùng ID xác định từ ID lần trả, giống nhau local/SQL.
  Tắt ghi kèm tombstone giao dịch, bật lại khôi phục cùng ID.
- Tiền/ngày/ghi chú/nguồn tiền cập nhật cả lịch sử và giao dịch; tổng nợ, trạng
  thái và outbox được cập nhật atomic. Vay ghi chi; cho vay ghi thu.
- Sửa không vượt tổng nợ trừ các lần trả khác. Nguồn đã lưu trữ chỉ được giữ cho
  bản ghi cũ, không chọn mới. Bản trước nâng cấp sửa được nhưng không tạo thu/chi.
- Ngày hiển thị `dd/MM/yyyy · HH:mm` theo giờ Việt Nam. Ưu tiên trạng thái:
  tất toán → quá hạn → hôm nay → sắp đến hạn trong 3 ngày → đang còn nợ.

## 4. Bắt đầu trên laptop mới

```sh
git clone --branch feature/offline-ai-history https://github.com/lethanhtrong161005/tui-khon-mobile.git
cd tui-khon-mobile
git branch --show-current
git log -1 --oneline
flutter doctor -v
flutter pub get
flutter test
```

Dùng **Flutter 3.47.7**, Dart đi kèm, Node.js ≥20 và Android SDK/JDK 17.
iOS cần macOS/Xcode. Giữ `pubspec.lock`, không `pub upgrade` khi chỉ tái lập
môi trường; mức tối thiểu cũ trong pubspec thấp hơn yêu cầu lockfile thực tế.

Theo [SETUP mục 5](../SETUP.md#5-supabase-local): bật Docker, đặt Google dummy
trong terminal khi chưa dùng OAuth, chạy `npx supabase start`, lấy URL/key từ
`npx supabase status`, áp `npx supabase migration up --local`. Không init lại
config hoặc reset DB đã có dữ liệu.

Tạo `.env.local` từ `.env.example`, điền key của **backend mới trên laptop mới**.
Android emulator dùng `http://10.0.2.2:54321`; iOS Simulator dùng
`http://127.0.0.1:54321` với cổng thực tế của CLI.

```sh
flutter run -d DEVICE_ID --dart-define-from-file=.env.local
```

Đăng ký một tài khoản mới trong app, lấy OTP ở Mailpit (thường
`http://127.0.0.1:54324`), xác thực và đợi bootstrap. Trước khi tự sửa danh mục/
nguồn tiền hoặc ghi dữ liệu, mở Studio → SQL Editor và chạy:

```sql
select private.seed_demo_data('REPLACE_WITH_NEW_DEMO_EMAIL');
```

Thay placeholder bằng email vừa đăng ký. Sau đó đồng bộ trong app. Seeder chỉ
dành cho tài khoản demo mới, không reset hoặc chạy lặp để xóa dữ liệu cần giữ.
Bộ demo này không phải bộ nhiều tháng đã tạo riêng trên máy cũ.

**Git clone không mang theo `.env`, Docker DB, tài khoản local, phiên đăng nhập,
SQLite, ảnh đã upload hoặc bộ dữ liệu mẫu trên máy cũ.** Đã chọn tạo dữ liệu mới,
không có gói backup/restore trong lần bàn giao này.

## 5. Trạng thái kiểm thử và phần chưa nghiệm thu

Đã kiểm tra trên Windows/Android emulator ngày 28/10/2026:

- **141 Flutter test qua**. Static analysis không có error/warning, còn các
  informational lint; dùng `--no-fatal-infos`, không bỏ qua error/warning.
- 5 SQL suites PGlite và trường hợp thiếu seeder tùy chọn qua; kiểm tra migration
  giữ dữ liệu, ownership, idempotency, legacy, liên kết và rollback.
- PostgreSQL local với các phiên đồng thời: trả vượt nợ bị từ chối và rollback
  cash entry, sửa cùng lần trả trả conflict, retry chỉ tạo một lần trả/giao dịch.
- Build APK debug bằng env local và cài cập nhật giữ dữ liệu. UI kiểm tra tại
  390×844, 411×914, 320×568, chữ 140%/200%, bàn phím; chụp thực tế trên emulator riêng.
- Google OAuth thật và Gemini thật **chưa cấu hình/nghiệm thu**. Email/OTP local,
  ghi tay, offline và dữ liệu báo cáo không cần các key này. AI unit/widget test
  dùng phản hồi giả; key Gemini chỉ đặt trong env Functions/Secrets phía server.
- Không suy ra đã build iOS hoặc nghiệm thu thiết bị thật từ kết quả Android.

Lệnh kiểm tra:

```sh
flutter analyze --no-fatal-infos
flutter test
npm ci --prefix supabase/tests --ignore-scripts
node supabase/tests/run-offline-history.cjs
# Chỉ khi Supabase local đã chạy và áp đủ migration:
node supabase/tests/run-debt-concurrency.cjs
flutter build apk --debug --dart-define-from-file=.env.local
```

Các fixture trong `test/support/` phục vụ kiểm thử, không tự nạp vào user thật.
Screenshot/DB tạm của máy cũ không phải dependencies của source và không nằm trong Git.

## 6. Điểm bắt đầu cho dark theme và i18n

**Chưa có dark theme, themeMode lưu lựa chọn, locale selector, ARB hoặc gen-l10n.**
`intl` hiện chỉ giúp format; không có nghĩa giao diện đã được dịch.

- `lib/main.dart`: `MaterialApp` mới có `theme: AppTheme.light`, chưa có
  `darkTheme`, `themeMode`, `locale`, delegates hoặc danh sách locales.
- `lib/core/theme/app_theme.dart`, `lib/core/constants/app_colors.dart` và
  `lib/core/widgets/glass.dart`: nơi bắt đầu gom semantic colors/surfaces.
  Nhiều màn, form, background và custom chart vẫn dùng màu trắng/mint literal;
  chỉ thêm `ThemeData.dark()` sẽ chưa làm các màn này phù hợp dark mode.
- `lib/features/profile/presentation/profile_settings_screen.dart`: vị trí tự
  nhiên cho lựa chọn giao diện/ngôn ngữ; chưa có logic hoặc persistence của chúng.
- Chuỗi tiếng Việt nằm trực tiếp trong widget, validation/error helpers,
  thông báo local và một số phản hồi server. Cần khảo sát cả các nguồn này khi
  thêm i18n, không chỉ thay nhãn trong `MaterialApp`.
- Ngôn ngữ giao diện là việc khác với đa tiền tệ và múi giờ. Giữ VND nguyên,
  kỳ tháng Việt Nam và dữ liệu cũ; font Plus Jakarta Sans đã đóng gói có giấy phép.
- Nếu tham khảo dark theme/onboarding ở nhánh PRM-4, tích hợp riêng vào AuthGate
  và thiết kế hiện tại. Không khôi phục `ProfileSession`, API Java hoặc repository
  local cũ để lấy chức năng này.

Lần phát triển tiếp theo cần chốt danh sách ngôn ngữ và hành vi chọn theme trước
khi triển khai. Yêu cầu hiện tại chỉ bàn giao context, không triển khai hai tính năng đó.
