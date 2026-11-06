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
flutter gen-l10n
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

<a id="6-giao-dien-va-i18n"></a>

## 6. Giao diện và i18n (29/10/2026)

Đã triển khai trong working tree trên `feature/offline-ai-history`; đợt này
**chưa commit/push/PR**. Không suy ra clone remote đã có các thay đổi chưa commit.

- Theme Sáng / Tối / Theo hệ thống (mặc định hệ thống), Việt / Anh / Theo hệ thống
  (mặc định Việt, OS không hỗ trợ fallback Việt).
- `lib/core/theme/appearance.dart`: Riverpod + SharedPreferences theo thiết bị,
  nạp trước `runApp`, theo dõi locale OS; lưu lỗi rollback state/cache. Đăng xuất
  chỉ xóa offline account ID, không xóa display preferences.
- `lib/main.dart`: nối themeMode, locale, delegates, supportedLocales và overlay
  status/navigation bar; thay lựa chọn không thay Navigator hoặc AuthGate.
- `lib/core/theme/app_theme.dart`, `semantic_colors.dart`, `widgets/glass.dart`:
  palette sáng/tối, thẻ/sheet opaque đủ đọc, kính nhẹ; giữ màu danh mục và asset gốc.
- Profile có nhóm Giao diện & Ngôn ngữ; Auth có hai nút sáng/tối và dịch riêng.
- `lib/l10n/app_vi.arb`, `app_en.arb`, `l10n.yaml`: source bản dịch. Chạy
  `flutter gen-l10n` sau clone/sửa ARB; generated được Git bỏ qua.
- `appL10n(context)` là accessor dùng trong UI. `CodedFailure` giữ mã/tham số,
  trình bày qua `friendlyError(error, context: context)`; không dịch bằng so sánh
  nội dung tiếng Việt hoặc lộ lỗi backend nguyên văn làm thông báo chính.
- CSV có mã lỗi từng dòng để dịch ở UI; header, dữ liệu và file xuất giữ hợp đồng.
- Đổi locale làm mới nhóm thông báo local đang bật; giữ ID/lịch/route, không xin
  quyền. Giữ các nhóm tách biệt. Không dịch nội dung server, AI hoặc tên/ghi chú.
- Ngôn ngữ chỉ đổi cách trình bày số. Vẫn VND nguyên, ngày tài chính dd/MM/yyyy,
  kỳ Việt Nam. Ghi nhanh/mic tiếp tục ưu tiên tiếng Việt, English có lời giải thích.

Kiểm thử thêm: `appearance_behavior_test.dart` (persistence, lỗi lưu, đổi ngay trong
form, OS, ARB/plural, số tiền, outbox/CSV không đổi, thông báo) và
`localization_screens_test.dart` (28 màn, 112 tổ hợp theme/ngôn ngữ chuẩn và 140
trường hợp responsive/chữ lớn/bàn phím). Các fixture chỉ ở SQLite memory, không
nạp vào tài khoản thật. Giữ các test nghiệp vụ offline/nợ/CSV trước đó khi mở rộng.

Thêm ngôn ngữ mới cần ARB, quy tắc fallback, supportedLocales và kiểm thử tương ứng.
Thêm màn phải dùng semantic palette và ARB ngay từ đầu. Không khôi phục luồng
ProfileSession/API Java cũ để lấy theme. Google/Gemini thật và iOS vẫn cần nghiệm thu
ở môi trường cấu hình thật như phần 5; theme/i18n không thay các hợp đồng đó.

Kiểm tra working tree ngày 29/10: 410 Flutter test qua trong bản sao source sạch,
đã tái sinh localization từ ARB mà không mang env/generated từ máy cũ.
SQL regression 6 nhóm qua. Android build/cài cập nhật giữ dữ liệu; chưa build iOS.

## 8. Supabase cloud — 30/10/2026

- Organization **Túi Khôn** (Free), project **tui-khon-dev**, region Singapore
  (`ap-southeast-1`), project ref `ncqgbvsbtlqhpasoegja`.
- Dashboard: <https://supabase.com/dashboard/project/ncqgbvsbtlqhpasoegja>.
  URL API: `https://ncqgbvsbtlqhpasoegja.supabase.co`.
- CLI đã link trên máy hiện tại; `.env` riêng đã điền URL và publishable key.
  Máy khác lấy key từ Dashboard và tự link; các file private không theo Git.
  `.env.local` và database Docker giữ nguyên, không chuyển tài khoản hoặc dữ liệu
  local sang cloud. Cloud bắt đầu với dữ liệu mới.
- Đã dry-run và áp đủ 7 migration hiện có. Kiểm tra cloud: 13 bảng public đều có
  RLS, RPC `sync_push`/`sync_pull`, bucket receipts private và avatars public;
  cron nhắc nợ chạy `0 1 * * *` UTC (08:00 Việt Nam).
- `ai-quick-record` và `ai-advisor` đã deploy, trạng thái ACTIVE,
  `verify_jwt=true`. Request POST không đăng nhập bị từ chối 401.
  Gemini key chưa đặt; triển khai function không đồng nghĩa AI đã hoạt động.
- Email signup và Confirm email bật; OTP length 6, expiration 600 giây.
  Google provider vẫn tắt, chưa có OAuth thật.
- Người dùng chọn email mặc định để test trước. Free hiện khóa sửa template khi
  chưa có SMTP riêng: email mặc định gửi link xác nhận, chỉ gửi cho thành viên
  quản trị organization và giới hạn khoảng 2 email/giờ. Cần SMTP riêng và hai
  template trong repo để nghiệm thu OTP/quên mật khẩu đúng luồng app; xem SETUP 4.3.
- Smoke test trên cloud đã qua: trigger khởi tạo, RLS giữa hai người dùng,
  push/pull và retry không tạo trùng. Test nằm trong transaction có rollback,
  không để lại tài khoản hoặc giao dịch của bộ test.
- Sau đó người dùng đăng ký tài khoản cloud và bấm link xác nhận. Đã kiểm tra
  `email_confirmed_at` có giá trị. Trình duyệt chuyển về localhost không có web
  server nên báo lỗi; tài khoản vẫn đã xác nhận, có thể quay lại app đăng nhập.
  Màn OTP hiện tại chưa khớp email cloud mặc định; chưa nghiệm thu OTP/quên mật khẩu.
- Khi chuyển app giữa local và cloud, dùng emulator riêng hoặc đồng bộ hết rồi
  đăng xuất môi trường cũ trước. Không dùng phiên/offline account của local để
  ghi vào cloud. Tài khoản quản trị Supabase và tài khoản đăng nhập app là riêng.

Còn nghiệm thu: đăng nhập và đồng bộ trên app, đồng bộ giữa hai thiết bị,
OTP/quên mật khẩu sau khi có SMTP, Google OAuth, Gemini thật và iOS.
Chưa commit/push hoặc tạo PR cho các thay đổi đang ở working tree.

## 9. Widget Android và kiểm tra triển khai — 05/11/2026

Các thay đổi đợt này tiếp tục ở working tree, chưa commit/push/PR; giữ nguyên
những diff theme/i18n có trước. Không thay schema, RPC hoặc migration.

- Widget native Kotlin/RemoteViews mặc định 4×2, ba nút có icon theo thứ tự
  **Chi | Quét ảnh | Thu**. Dùng PendingIntent immutable trỏ MainActivity và
  MethodChannel `tui_khon/home_widget`, không thêm dependency Flutter.
- `lib/core/home_widget/`: nhận cold/warm launch, chỉ giữ yêu cầu mới nhất,
  chặn replay, đợi bootstrap/sinh trắc/foreground và đợi editor hiện tại đóng.
  Quét ảnh dùng QuickRecordScreen với initialAction scan, mở bộ chọn nguồn ảnh.
  Giữ quickRecord trong hợp đồng nội bộ để tương thích action cũ.
- Home dùng repository hiện có để ghi, không có native/background writer.
  Đăng xuất/đổi tài khoản xóa yêu cầu cũ. Nhắc nợ tự động đợi thao tác widget.
  Khóa khi quay lại từ nền che cả route đang mở và giữ input của bản nháp.
- Nhãn widget lấy ARB Việt–Anh; cache native chỉ có theme/ngôn ngữ/nhãn, không có
  ID tài khoản, token hay số dư. Cá nhân có hướng dẫn thêm widget Android.
- `vnd_amount_input.dart` định dạng hàng nghìn lúc nhập ở giao dịch, trả nợ và
  MoneyField dùng chung (ngân sách, mục tiêu, nguồn tiền, khoản phải trả...).
  Giữ VND nguyên, giới hạn 13 chữ số khi nhập, không đổi CSV/outbox. Không dùng
  chuỗi trình bày làm payload; từ chối paste số lẻ/số mũ/shorthand trong ô nhập tay.
- Logo mới `assets/images/tui_khon_logo_v1.png`: PNG nền trong suốt tạo bằng
  imagegen, sổ tay mint kết hợp bóng đèn; prompt ở `docs/LOGO_PROMPT.md`.
  Chưa thay asset/icon launcher đang có vì yêu cầu hiện tại là thiết kế ảnh logo.

Cloud hiện đã **ACTIVE_HEALTHY**, API Auth truy cập được. Đã kiểm tra đủ 7
migrations, RLS bật trên 13 bảng public, sync_push/sync_pull, receipts private,
avatars public và cron nợ `0 1 * * *`. Hai Functions từ chối request không có
đăng nhập bằng 401. Smoke test mới `supabase/tests/cloud_readiness.sql` đã qua
trên project cloud và rollback toàn bộ fixture; không thay tài khoản thật.

Người dùng mở rộng yêu cầu: cần **Gemini thật và Google OAuth thật**. Hiện chờ
người dùng tạo key/OAuth và điền `supabase/.env` (server) cùng Google Web client ID
trong `.env` Flutter. Đã hướng dẫn tạo Web + Android OAuth bằng package/SHA-1 từ
signingReport của máy này. Không ghi secret vào tài liệu hoặc Flutter. Người dùng
xác nhận **chưa có SMTP**: OTP/quên mật khẩu email cloud vẫn còn chờ SMTP và
template; không đánh dấu hoàn tất chỉ vì Google được cấu hình sau này.

Kiểm tra tự động đến hiện tại: **429 Flutter test qua**, gồm 19 test mới cho
widget/nhập tiền và ma trận responsive/theme/ngôn ngữ cũ. Analysis không có
error/warning; còn informational lint. SQL in-memory và Edge tests của bản kiểm
tra trước vẫn giữ nguyên source. Kiểm thử concurrency PostgreSQL chưa chạy lại
vì Docker không hoạt động; không suy ra cloud smoke là concurrency test.

Nghiệm thu Android dùng emulator riêng `TuiKhonWidgetQA` và entrypoint fixture
chỉ ở `.dart_tool/widget-checks/`, không nạp vào tài khoản thật. Đã đặt widget trên
launcher, mở Thu/Chi/Ghi nhanh (trước đổi nút giữa sang Quét ảnh), thử chạm lặp,
lưu một khoản 65.000 VND đúng một transaction/outbox, cài cập nhật giữ SQLite.
Emulator software GPU phải chạy fixture với `--ez enable-impeller false` do
Impeller không vẽ trên môi trường này; không đổi renderer production.

Chưa nghiệm thu: Google/Gemini thật khi có cấu hình, SMTP/email OTP, đăng nhập
và sync trên app cloud giữa hai thiết bị thật, camera/mic/sinh trắc máy thật,
iOS và phát hành store. APK debug không đồng nghĩa sẵn sàng phát hành store.

## 10. Nghiệm thu cloud trên hai emulator — 05/11/2026

Đã dùng `TuiKhonWidgetQA` và `TuiKhonCloudQA` với **một tài khoản Auth fixture
riêng**, xác nhận bằng Admin API, không gửi email và không dùng tài khoản thật.
Entrypoint kiểm tra chỉ ở `.dart_tool/widget-checks/`, dùng Supabase Auth,
SQLite, repository và SyncController thật; không đưa vào APK bàn giao.

- Cả hai máy bootstrap đủ 22 danh mục và một nguồn tiền từ cloud.
- Máy thứ nhất tắt mạng, tạo khoản `1234567` VND qua repository thật: một bản ghi
  và một outbox; cloud còn 0 giao dịch. Force-stop/mở lại khi offline vẫn giữ
  nguyên số tiền, UUID và hàng đợi. Bật mạng, cả hai máy nhận cùng UUID/version 1;
  lặp đồng bộ vẫn chỉ có một giao dịch trên cloud.
- Hai máy sửa offline từ cùng version. Đã thao tác **Giữ bản trên máy** trong UI
  và đồng bộ kết quả sang máy còn lại. Lặp kịch bản, chọn **Giữ bản server**;
  cả hai nhánh xử lý hết xung đột, không tự ghi đè khi chưa chọn.
- Cài cập nhật APK từ `lib/main.dart` khi máy thứ hai còn xung đột: SQLite và hai
  bản local/server còn nguyên. Màn đồng bộ nay format tiền `1.800.000 ₫` /
  `1.700.000 ₫`, gồm cả số dư ban đầu khi xung đột nguồn tiền. Ghi chú không bị
  định dạng lại. Ảnh kiểm tra ở `docs/screenshots/cloud-conflict-amounts.png`.
- Đã đặt hai instance widget trên launcher; instance mới mở đúng form Chi.
  Nhập `1234567` trên Android hiển thị `1.234.567` ngay trong ô; hủy không ghi
  thêm giao dịch. Ảnh: `docs/screenshots/widget-android-vi.png`,
  `widget-android-en-200.png`, `vnd-input-android.png`.
- Sửa lỗi formatter từng bỏ dấu âm khi không bật showSign: số dư âm luôn giữ
  dấu trừ; showSign chỉ quyết định dấu cộng cho số dương. Không đổi dữ liệu/CSV.
- Đã đăng xuất cả hai máy (máy thứ hai qua UI thật), sau đó xóa **chỉ** tài khoản
  fixture có identity guard. Kiểm tra còn 0 user/giao dịch/sync operation/journal/
  AI usage của fixture; xóa file credential tạm. Không thay dữ liệu người dùng.

Kiểm tra mới nhất: **431 Flutter test qua**; analyze không có error/warning,
còn 197 info lint; APK debug từ `lib/main.dart` build thành công. Hai regression
mới kiểm tra tiền trên màn xung đột theo Việt–Anh và dấu âm. Giữ nguyên kết quả
6 nhóm SQL in-memory, 7 Edge Function test và type-check đã qua ở phần trước.

Gemini **vẫn chưa được cấu hình**: đã thử gọi bằng JWT người dùng Auth thật,
Function trả `500 / AI_NOT_CONFIGURED`; đây không phải nghiệm thu AI thành công.
Không có Gemini secret trên cloud, Google provider vẫn tắt và các file env chưa
có client/secret thật. SMTP vẫn chưa có như người dùng xác nhận. Hướng dẫn tạo
Gemini key/Google Web + Android OAuth ở SETUP mục 6–7; credentials chỉ điền vào
file private/server. Google, Gemini và OTP email vẫn là phần cần hoàn tất sau
khi có cấu hình. Chưa nghiệm thu iOS, thiết bị vật lý hoặc concurrency SQL nhiều
connection; hai emulator sửa offline không thay thế test đó.

## 11. Cấu hình Google và SMTP thật — 06/11/2026

Đã tạo project Google Cloud riêng **Tui Khon PRM393**
(`amazing-chemist-513912-e6`), không sửa các project Google khác. Google Auth
Platform dùng External/Testing, chỉ khai báo `openid`, `userinfo.email` và
`userinfo.profile`; đã thêm tài khoản chủ dự án vào danh sách người thử.

- Đã tạo OAuth Web với callback của đúng project Supabase và OAuth Android cho
  `com.example.tui_khon_mobile`, khớp SHA-1 của APK ký trên máy này. Máy khác hoặc
  chứng chỉ ký khác cần đăng ký OAuth Android tương ứng theo SETUP.
- Supabase Google provider đã bật, chấp nhận Web ID đứng đầu rồi Android ID.
  Giữ kiểm tra nonce và yêu cầu có email; không nới các thiết lập này.
- Web client ID đã điền vào `.env`; danh sách client IDs và Web secret nằm trong
  `supabase/.env` private và cấu hình Auth cloud. Không ghi giá trị secret vào Git,
  tài liệu, ảnh nghiệm thu hoặc APK. Không dùng Edge Function secrets để thay cho
  cấu hình Google provider.
- Đã nghiệm thu Google OAuth thật qua trình duyệt bằng PKCE: đổi authorization
  code thành phiên Supabase, gọi Auth `/user`, xác nhận identity Google và email
  đã xác minh. Phiên QA được đăng xuất với `scope=local`; không đăng xuất các
  phiên khác hoặc sửa dữ liệu tài chính. Đây là nghiệm thu OAuth Web/server,
  **chưa thay thế đăng nhập Google native trên Android**.
- Gmail SMTP đã lưu trên cloud: host `smtp.gmail.com`, cổng 587, sender Túi Khôn.
  Chủ dự án tự tạo và nhập App password; mật khẩu không được lấy về source.
  Hai mẫu Confirm signup / Reset password đã áp HTML từ `supabase/templates/`
  với `{{ .Token }}`. Cloud đang dùng OTP 6 số, hết hạn sau 600 giây.
- APK debug từ `lib/main.dart` đã build lại thành công với
  `--dart-define-from-file=.env`; chứng chỉ APK khớp OAuth Android đã đăng ký.

Đã nghiệm thu SMTP thật bằng một tài khoản Auth fixture mới, dùng Gmail plus
alias có nonce riêng, sau khi người dùng cho phép gửi và đọc đúng hai email thử:

- Email đăng ký và khôi phục đều được Gmail nhận trong **Inbox**. Nội dung đúng
  template tiếng Việt, mã OTP 6 số; không đưa mã vào log, ảnh hoặc tài liệu.
- Xác nhận OTP đăng ký thành công, sau đó đăng nhập email/mật khẩu thành công.
- Xác nhận OTP khôi phục, đổi mật khẩu ngẫu nhiên của **chỉ fixture** và đăng nhập
  bằng mật khẩu mới đều thành công. Các phiên thử được đăng xuất `scope=local`.
- Đã kiểm tra identity guard (UUID, đúng email và nonce trong user metadata)
  trước khi xóa riêng fixture; Auth Admin API trả 404 khi kiểm tra lại user đó.
  Không thay mật khẩu hoặc xóa tài khoản thật, không sửa dữ liệu tài chính thật.
- Đây là nghiệm thu Auth API và email thật; chưa phải kiểm thử thao tác đầy đủ
  trên màn đăng ký/khôi phục của APK mới.

Bộ QA tạm và bằng chứng chi tiết ở `.dart_tool/prm393/`, bị Git bỏ qua. Các tab
Gmail/QA và server kiểm tra được dọn sau khi lưu bằng chứng; không lưu token hoặc
mật khẩu fixture. Chưa có thiết bị Android kết nối trong lượt này để nghiệm thu
Google native/cài cập nhật APK mới. Gemini chưa nghiệm thu ở lượt cấu hình này;
không suy ra cấu hình Google OAuth là đã có Gemini key.
