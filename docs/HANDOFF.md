# Context bàn giao Túi Khôn

Cập nhật mới nhất **12/11/2026**: xem mục 15 về bản bàn giao GitHub và hướng dẫn tự triển khai; mục 14 mô tả safe area, OCR trên thiết bị, hỏi dữ liệu và launcher icon. Các mục trước giữ lịch sử các đợt bàn giao; trạng thái mới nhất được ưu tiên.

## 1. Đọc trước khi tiếp tục

- Repository: https://github.com/lethanhtrong161005/tui-khon-mobile
- Nhánh bàn giao setup v2: **`codex/shared-env-ai`**, review bằng PR vào `dev`,
  nền `f4bdd64`. Dùng `git log -1 --oneline` và `git status` để kiểm tra.
  `feature/offline-ai-history` là nhánh bàn giao ban đầu, không phải hướng dẫn lấy
  bộ Team v2 mới nhất.
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

## 12. Bộ chạy Windows cho Nhóm 5 — 06/11/2026

Nhánh `codex/team-windows-setup` bổ sung `tool/team.ps1` và
`docs/TEAM_SETUP.md`. Thành viên clone source, nhận ZIP private, chạy `setup`
rồi `run`; dùng backend cloud đã có, không dựng Supabase/SMTP/Functions lại.
Đã sửa hướng dẫn clone cũ vốn trỏ về nhánh trước theme/i18n/widget.

- Dùng Flutter 3.47.7 / Dart 3.13.5; minimum trong pubspec đã khớp lockfile
  (Flutter >=3.47, Dart >=3.13,<4). Không nâng dependency hoặc đổi lockfile.
- `.env.team` chỉ có URL, publishable/anon key và Google Web client ID; không có
  server secret. `.team/` giữ signing properties, JKS và manifest private.
- ZIP `TuiKhon-Team-Setup.zip` nằm trong thư mục `TuiKhon-Team-Private` cạnh
  checkout, không nằm trong Git và không mã hóa. Chủ dự án chia sẻ qua kênh riêng.
  Khóa Team mới chỉ dành cho debug; `pack` giữ khóa cũ khi đóng gói lại.
- `TUI_KHON_TEAM=1` bật package `com.example.tui_khon_mobile.team` và nhãn
  **Túi Khôn (Nhóm 5)**, dùng khóa Team. Namespace Kotlin và nghiệp vụ giữ nguyên.
  Build thường vẫn là `com.example.tui_khon_mobile` với chứng chỉ debug cá nhân
  ban đầu. Không ghi đè `.env` hoặc keystore trong thư mục Android cá nhân.
- Có cấu hình chạy Team cho VS Code và Android Studio; terminal có lệnh doctor,
  setup, run, build. Team từ chối task release/profile. Không tự cài SDK hay chấp
  nhận giấy phép, không gỡ app/xóa dữ liệu khi lỗi cài đặt.

Kiểm tra đã chạy:

- **431 Flutter test qua**, analyze 0 error/warning, 199 info lint.
- Clone sạch vào thư mục kiểm tra riêng: thiếu/corrupt ZIP bị từ chối; server key
  bị từ chối dù checksum đúng; setup/doctor thành công; setup lặp không đổi khóa
  hoặc `.env` cá nhân; file bị sửa không bị ghi đè; thiếu Flutter/SDK cũ báo lỗi.
- `pack` lặp giữ nguyên JKS/password; Team release signing bị chặn đúng điều kiện.
- Build APK Team thành công cả ở checkout chính và clone sạch, cùng package và
  cùng SHA-1; cấu hình client từ clone truy cập Auth cloud và thấy Google/email bật.
- Emulator riêng `TuiKhonWidgetQA`: cài Team song song với app cũ; cài cập nhật
  bằng APK build từ clone sạch giữ được file canary trong sandbox Team. Đã dọn
  canary và tắt emulator sau kiểm tra. Đây là kiểm tra installer giữ dữ liệu,
  chưa phải nghiệm thu SQLite/Google native/widget qua UI trên máy thành viên.
- Build thường vẫn có package và SHA-1 cá nhân ban đầu; MainActivity và receiver
  widget trong manifest Team vẫn trỏ đúng class Kotlin.

Sau khi người dùng xác nhận, đã tạo OAuth Android **Tui Khon Team Windows debug**
cho package Team và SHA-1 khóa chung. Client Team đã bổ sung vào Supabase Google
provider; mở lại form xác nhận đã lưu đủ ba client: Web đứng đầu, Android cá nhân
và Android Team. Giữ kiểm tra nonce, yêu cầu email và secret Web hiện tại.
Danh sách client trong `supabase/.env` private được cập nhật; `.env.team`, ZIP,
khóa ký và APK không thay đổi nên không phải phát lại bộ setup.

Gmail thành viên cần được chủ dự án thêm vào Test users; không ghi danh sách cá
nhân vào Git. Chưa nghiệm thu Google native trên máy thành viên hoặc thay trạng
thái Gemini; không suy ra chúng đã xong từ kết quả build/setup hay lưu OAuth.


## 13. Một `.env` và bộ setup Team v2 — 07/11/2026

Đã triển khai ở nhánh `codex/shared-env-ai`; bàn giao bằng PR vào `dev`, không tự merge.
Không đổi Flutter business code, API, schema, RPC, package, backend hoặc khóa ký.
Các hướng dẫn cũ dùng `.env.team` ở mục 12 là lịch sử v1; đường chạy hiện tại
chỉ dùng **`.env`**. Hướng dẫn duy nhất cho thành viên: [TEAM_SETUP](TEAM_SETUP.md);
mẫu báo lỗi: [TEAM_BUG_REPORT](TEAM_BUG_REPORT.md).

### Cấu hình và script

- Máy chủ dự án đã nhập chính ZIP v2, dùng cùng bốn biến app với thành viên:
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`.
  Đã sao lưu nguyên `.env` có các biến Firebase/VietQR cũ trước khi chuẩn hóa;
  backup ở `.team/backups/`, bị Git bỏ qua. Không đưa các giá trị cũ vào bundle.
- ZIP private chuẩn nằm tại thư mục `TuiKhon-Team-Private` cạnh checkout:
  `TuiKhon-Team-Setup.zip`, chứa đúng `.env`, manifest v2, signing properties và JKS.
  Bản ZIP/manifest/env v1 được giữ trong `backups/` private; env cũ không còn là
  cấu hình chạy. Không đóng gói Gemini key, OAuth secret hoặc SMTP password.
- `setup` hỗ trợ cả v1/v2; kiểm tra trước khi ghi, chuyển v1 sang `.env` chuẩn,
  sao lưu byte gốc và giữ nguyên khóa. Env khác yêu cầu `-ReplaceEnv` rõ ràng;
  tùy chọn này không cho phép thay signing material. `pack` chỉ dùng khóa có sẵn,
  không sinh khóa mới. Cùng bundle có thể nhập lại mà không đổi cấu hình.
- `doctor` khóa chính xác Flutter **3.47.7**, Dart **3.13.5**, Java **17**;
  đọc compile SDK **36** / NDK **28.2.13676358** từ Flutter, Gradle **9.3.1** từ
  wrapper. Phát hiện SDK path mâu thuẫn, SDK/NDK thiếu/lệch và file bị sửa.
- `run/build` chạy kiểm tra trước, luôn Team + `.env`. VS Code mặc định chỉ còn
  cấu hình Team, có pre-launch doctor; Android Studio dùng `.env` + Team và
  hướng dẫn chạy doctor trước trong Terminal. Không đổi cách build app cũ.
- Báo cáo `.team/diagnostics.json` chứa commit, sourceDirty, bundle/tool versions,
  backend host, SHA-256 cấu hình, SHA-1 cert và trạng thái; không chứa giá trị key,
  mật khẩu/token hoặc email thành viên. Có thể chia sẻ báo cáo đã kiểm tra qua
  kênh nhóm, không chia sẻ env/ZIP/backup để báo lỗi.

### Kiểm tra thực tế

- **21 kiểm tra tích hợp script qua** bằng PowerShell 5.1: v1/v2, setup lặp,
  explicit replacement + backup nguyên gốc, env sửa, chữ ký sửa, Flutter/Dart/
  NDK lệch, JDK không xác minh được, ZIP corrupt/path traversal, run/build đúng
  Team + `.env`, report không chứa credential. Runner dùng env/Flutter giả trong
  `.dart_tool/`, không thay SDK hoặc dữ liệu app thật.
- Clone Git cục bộ mới vào `.dart_tool/team-v2-clean-check`, sau đó áp cùng diff
  chưa commit để kiểm tra phiên bản source mới. **Đây không phải clone trực tiếp
  từ GitHub đã có các thay đổi v2**; hai report cùng commit nền và sourceDirty=true.
  Setup với ZIP thật v2, nhập ZIP v1 thật đã sao lưu rồi trở lại v2 đều qua;
  `pub get`/`gen-l10n` qua, không đổi lockfile/khóa.
- Máy chính và clone có cùng config SHA-256
  `708337C2A6C6543CBD88F8F1C3E52DD00252E366ACFFC4170F155E534A621482`, cùng backend,
  chứng chỉ và công cụ. SHA-1 Team vẫn
  `A9:A4:57:FB:2A:42:AB:AD:73:D0:F6:93:DB:D6:35:3A:8C:F0:38:5C`.
- Build APK Team thành công ở cả hai checkout; `aapt`/`apksigner` xác nhận cùng
  package `com.example.tui_khon_mobile.team`, compile SDK 36 và chứng chỉ trên.
- Emulator riêng `TuiKhonWidgetQA`: cài APK Team cũ từ clone v1, tạo canary trong
  sandbox, cập nhật lần lượt bằng APK máy chính và APK clone v2; canary vẫn còn.
  App cũ `com.example.tui_khon_mobile` và Team cùng tồn tại. Đã xóa riêng canary
  và tắt emulator. Đây là kiểm tra installer giữ file dữ liệu, **chưa nghiệm thu
  dữ liệu SQLite thật hoặc thao tác Google/widget trên máy thành viên**.
- **7 Edge Function test và type-check qua**. Không sửa Flutter hoặc sync/migration
  nên không chạy lại Flutter/SQL suites trong lượt này; số **431 Flutter test,
  6 nhóm SQL** ở trên là kết quả đã xác minh của lượt trước, không phải test mới.

### Google, Gemini và phần còn chưa qua

- Đã lưu thêm bốn địa chỉ do người dùng cung cấp vào Google Test users, giữ owner;
  mở lại Audience xác nhận **5 test users**. Danh sách cá nhân không đưa vào Git.
  Google native trên máy từng thành viên vẫn cần nghiệm thu riêng sau khi nhận
  đúng source/bundle; không suy ra đã qua từ kết quả OAuth Web trước đây.
- Đã đọc riêng Gemini key từ `supabase/.env`, đưa **chỉ key và model** lên Supabase,
  model `gemini-flash-latest`; file triển khai secret tạm đã xóa. Không đưa server
  env vào bundle. Hai Functions deploy ACTIVE version 3, giữ JWT + kiểm tra Auth
  phía server; không nới xác thực, không đổi quota hoặc billing.
- Fixture Auth mới có nonce riêng, xác minh email bằng Admin API để không gửi thư,
  đăng nhập thật và seed qua `sync_push`: 4 giao dịch cô lập, tháng 11 thu 12 triệu,
  chi 165.000 VND, tháng 10 chi 150.000 VND. Advisor vì vậy đi qua nhánh có chi tiêu,
  không dùng fallback tháng rỗng để báo AI thành công.
- Kết quả thật: ghi nhanh HTTP **504 AI_TIMEOUT**, ảnh hóa đơn mẫu **504 AI_TIMEOUT**,
  advisor **502 AI_UPSTREAM_ERROR**. Gọi trực tiếp cùng key/model hai lần riêng nhận
  **503 UNAVAILABLE**, thông báo high demand từ Google. Không nhận được kết quả AI
  hợp lệ nên **cả ba luồng AI thật còn chưa qua nghiệm thu**; không đổi model/nâng gói.
- Request thiếu đăng nhập bị từ chối 401. Snapshot giao dịch trước/sau ba lời gọi
  AI giống nhau, không tự thêm/sửa giao dịch. Kiểm tra UUID/email/metadata nonce
  trước khi xóa riêng fixture; Auth Admin API trả 404 khi kiểm tra lại. Không tác
  động tài khoản thật. Kết quả chi tiết chỉ ở `.dart_tool/prm393/`, bị Git bỏ qua.

Còn lại: thử lại ba luồng khi `gemini-flash-latest` hoạt động; nghiệm thu Google
native trên máy thành viên và UI/dữ liệu SQLite thật. Thành viên dùng v2 clone
đúng nhánh `codex/shared-env-ai` trong khi chờ PR merge vào `dev`;
không phát ZIP v2 kèm script v1. SMTP giữ cấu hình/nghiệm thu trước đó.


## 14. Safe area, OCR và hỏi dữ liệu — 08/11/2026

Các thay đổi ở working tree `codex/shared-env-ai`, chưa commit/push/PR. Không đổi
schema, migration, sync RPC, package, khóa ký, backend hoặc cấu hình Team. Chỉ thêm
`LocalStore.readSnapshot` là transaction chỉ đọc nhất quán, không ghi outbox.

### Giao diện và nhận dạng ảnh

- Menu thêm chừa safe area dưới; nút đóng luôn ở trên, tiêu đề và các thao tác
  cuộn chung để vẫn dùng được ở 320×568/chữ 200%. Bảng chọn nguồn ảnh dùng Material
  đặc theo semantic theme, không lộ nội dung màn AI qua nền trong suốt.
- Safe area nằm ngoài khung nhập; Scaffold xử lý bàn phím. Form sửa giao dịch hiển
  thị/chọn ngày theo giờ Việt Nam và giữ giờ của bản nháp khi sửa ngày.
- `google_mlkit_text_recognition` 1.0.1 đọc Latin/Vietnamese native Android/iOS;
  `image` 4.12.0 chuẩn hóa hướng, JPEG và kích thước tối đa 3200px. Chỉ ảnh gửi
  Gemini mới giảm còn 1920px. OCR không dùng quota và không cần Gemini.
- Ảnh lưu local trước, OCR tạo một bản nháp, chỉ người dùng xác nhận mới ghi giao
  dịch/outbox qua repository. Bộ phân tích ưu tiên tổng thanh toán, bỏ VAT, giảm
  giá, tiền khách đưa/thừa, mã hàng và số lượng; hỗ trợ `62,700.00`, khoảng trắng
  trong token và gộp dòng OCR theo tọa độ/độ nghiêng.
- Thiếu tổng/ngày/nguồn, độ tin cậy thấp hoặc chưa biết chiều chuyển khoản thì
  yêu cầu sửa, không tự chọn nguồn đầu tiên. Chỉ đề xuất nguồn đang hoạt động và
  khớp rõ. Bill chuyển khoản không thêm nghiệp vụ chuyển nội bộ/liên kết ngân hàng.
- Nút **Nhờ AI đọc thêm** là thao tác chủ động, gửi ảnh và OCR tới Function. Lỗi
  giữ nguyên bản nháp/ảnh để sửa tay. Hợp đồng cũ vẫn dùng được; thêm OCR/time và
  kiểm tra evidence, số nguyên, ngày, confidence, nguồn và chiều tiền ở server.

### Hỏi dữ liệu và AI

- Màn AI có **Ghi giao dịch / Hỏi chi tiêu**, chung nhập chữ/mic, lịch sử riêng
  trong phiên và xóa khi đổi tài khoản. Kết quả async của tài khoản cũ bị bỏ.
- `FinanceQueryRepository` tính từ snapshot SQLite, gồm dữ liệu chưa đồng bộ;
  kết quả có kỳ, bộ lọc, bằng chứng và nhãn cần cập nhật khi local revision đổi.
- Hỗ trợ thu/chi, so sánh kỳ liền trước, xếp hạng danh mục, tìm giao dịch, số dư
  hiện tại, ngân sách tháng, nợ còn lại, kỳ khoản phải trả và mục tiêu tiết kiệm.
  Nợ/mục tiêu không cộng vào thu/chi; ngân sách tổng và danh mục không cộng trùng.
- Mẫu phổ biến chạy local. Câu phức tạp dùng `ai-finance-query` để tạo kế hoạch
  chỉ đọc có allowlist, không sinh/chạy SQL. Chỉ gửi câu hỏi/ngữ cảnh và tên/ID bộ
  lọc; không gửi toàn bộ ledger hoặc để model tính tiền. Hỏi lại khi chưa rõ hoặc
  ngoài khả năng; không bỏ bộ lọc khó để trả kết quả rộng hơn. Dùng quota chat
  hiện có, giữ 50 chat / 20 scan / 10 advisor; không thêm paywall.
- Hai Functions cũ và Function mới đã deploy lên cloud chung, giữ JWT/Auth và model
  `gemini-flash-latest`. Transport retry tối đa một lần, tổng dưới 30 giây; quota
  chỉ trừ một lần cho request ứng dụng, không log nội dung ảnh/model/token.

### Icon và nghiệm thu

- `flutter_launcher_icons` 0.14.4 + script `tool/prepare_launcher_icons.dart` sinh
  icon Android thường/adaptive và iOS từ logo đã duyệt; nền sáng, vùng an toàn
  để launcher không cắt biểu tượng. Cả package thường và Team dùng resources này.
- **458 Flutter test qua**; analyze **0 error/warning**, còn 234 informational lint.
  **14 Deno test và type-check ba Functions qua**. Không sửa sync/migration nên
  không chạy lại SQL suites trong lượt này.
- Native mới nhất chỉ chạy trên **Pixel_8 có sẵn**, không tạo AVD mới: OCR ảnh in
  tổng hợp đọc đúng 62.700 VND, 01/11/2026 18:55, Vietcombank; menu chữ 200%, safe
  area, nền bảng chọn ảnh, nhập có bàn phím và hỏi dữ liệu local không ghi giao
  dịch đều qua. Đây là hai ca native; ca ảnh gốc được đánh dấu skip có chủ đích.
- Ảnh clipboard gốc trong chat không còn trên đĩa ở đường dẫn đính kèm. Nội dung
  chép tay của hóa đơn Co.op là fixture parser, không phải nghiệm thu OCR ảnh
  chụp gốc. Cần cung cấp lại ảnh để chạy ca `ProvidedReceipt`.
- APK Team entrypoint chính build/cài cập nhật trên Pixel_8 cùng chứng chỉ. Fixture
  SQLite cô lập giữ nguyên byte/hash, số tiền 62.700 và hai outbox entries sau cài;
  fixture đã dọn. Không dùng kết quả này để nhận đã kiểm tra dữ liệu tài khoản thật.
- APK thường cũng build thành công, kiểm tra khớp chứng chỉ với app thường đã có
  trên Pixel_8 và cài cập nhật bằng `-r`. Fixture SQLite riêng cũng giữ nguyên hash
  sau cập nhật và đã dọn; không đọc/ghi các bản ghi tài chính của tài khoản thật.
- iOS đã cập nhật icon, linker flags và build phase chép model Latin từ plugin
  khóa trong lockfile, giữ target 15.0. Chưa build/nghiệm thu iOS trên macOS.
- Hướng dẫn kiểm tra: [OCR_QA](OCR_QA.md). Script native chỉ chấp nhận Pixel_8,
  cài trực tiếp bằng `adb install --no-streaming -r` và attach driver vào app đã
  chạy, tránh cơ chế launcher Flutter thử uninstall khi installer lỗi. Nếu cài
  bị từ chối, dừng; không gỡ app hoặc reset dữ liệu để sửa lỗi.

Smoke Gemini thật ngày 08/11: chữ **503 AI_BUSY**, ảnh/cố vấn/hiểu câu hỏi **504
AI_TIMEOUT**. Bốn lời gọi không thay giao dịch fixture; request thiếu đăng nhập
bị chặn 401, fixture đã xóa với identity guard. **Gemini thật vẫn chưa qua nghiệm
thu**, không coi kết quả fallback local hoặc deploy thành công là AI đã hoạt động.
Bằng chứng private ở `.dart_tool/`, không đưa token/ảnh/DB/APK vào Git.

## 15. Bàn giao GitHub và tự triển khai — 12/11/2026

Theo yêu cầu của chủ dự án, bản bàn giao trên `codex/shared-env-ai` gom source
OCR/hỏi chi tiêu/icon ở mục 14 cùng hai tài liệu mới:

- [INDEPENDENT_SETUP](INDEPENDENT_SETUP.md): clone đúng bản, tạo Supabase mới,
  áp đủ migrations, SMTP/OTP, env, Gemini/Google riêng và signing/build APK/iOS.
- [AI_AGENT_PROMPTS](AI_AGENT_PROMPTS.md): prompt khởi động, thông tin người nhận
  cần điền, từng chặng thực hiện và prompt tiếp tục khi đổi Agent.

Người nhận tự dựng app riêng dùng các tài liệu này, không nhập ZIP Team, env,
cloud hoặc khóa ký của nhóm. README/SETUP đã có liên kết. Người gửi cung cấp
commit SHA đã push để người nhận đối chiếu; các ghi chú chưa commit ở mục 14
mô tả trạng thái lịch sử ngày 08/11.

Rà soát trước bàn giao đã khôi phục hai giá trị boolean
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` về `YES` sau khi
công cụ sinh icon ghi nhầm `AppIcon`; tên app icon vẫn ở setting riêng.

Kiểm tra ngày 12/11: **458 Flutter test**, **14 Deno test** và type-check ba
Functions qua; analyze không error/warning, còn **234 info lint**. Không sửa
schema/migration/sync và không thao tác backend trong lượt bàn giao. iOS native
và Gemini thật vẫn có giới hạn nghiệm thu đã nêu ở mục 14; không suy ra đã qua
từ commit/push hoặc từ các bộ test này.
