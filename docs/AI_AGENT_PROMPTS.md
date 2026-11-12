# Prompt giao Túi Khôn cho Antigravity hoặc AI Agent

Dùng cùng [hướng dẫn setup độc lập](INDEPENDENT_SETUP.md). Mở **gốc repo** trong
Agent, gửi prompt khởi động; sau đó gửi từng prompt theo chặng còn thiếu. Không
cần Agent cùng hãng với tác giả. Agent cần có khả năng đọc/sửa file và chạy
terminal; nếu không có quyền vào Dashboard, bạn tự làm phần Dashboard mà Agent
chỉ dẫn. Không dán secrets vào prompt.

## 1. Prompt khởi động — copy nguyên khối

```text
Tôi muốn dùng source Túi Khôn này để tự build một app của riêng mình từ A–Z.
Hãy thực hiện công việc trong checkout này, không chỉ đưa ra kế hoạch chung.

Mục tiêu: backend Supabase mới của tôi, tài khoản/dữ liệu riêng, cấu hình dịch
vụ riêng và app có định danh/khóa ký riêng. Đầu ra là APK cài được; nếu tôi có
Mac/signing phù hợp thì thêm app iPhone/IPA. Chỉ coi xuất bản Store là phạm vi
nếu tôi yêu cầu. Không dùng cloud, env, ZIP Team, .team, keystore, SMTP, OAuth
client, Gemini key hay tài khoản của người gửi source.

Đầu tiên đọc AGENTS.md, docs/HANDOFF.md (ưu tiên mục cập nhật mới nhất),
SETUP.md, docs/NGHIEP_VU.md, docs/INDEPENDENT_SETUP.md và docs/AI_AGENT_PROMPTS.md.
Kiểm tra git status/branch/commit và nội dung thực tế; không bỏ diff có sẵn.
Xác nhận commit bàn giao với thông tin tôi cung cấp, không tự merge nhánh cũ.

Hỏi một lần các thông tin còn thiếu: Windows hay Mac; Android/iOS cần làm;
tên app và applicationId/bundle ID; commit bàn giao; tôi đã có Supabase riêng,
SMTP, Gemini, Google OAuth và Apple signing nào. Không yêu cầu gửi secret vào
chat. Hãy tiếp tục việc độc lập trong khi chờ thông tin còn thiếu.

Sau đó triển khai lần lượt: công cụ/dependencies → định danh riêng → Supabase
mới và migrations → email OTP/SMTP → env Flutter → chạy app → Gemini/Google
nếu tôi chọn → kiểm thử → ký/build APK và iOS nếu máy đáp ứng. Tắt TUI_KHON_TEAM
và dùng Flutter thường; sửa/tạo cấu hình IDE riêng nếu đang gọi Team doctor.

Tôi tự đăng nhập/2FA, tạo tài khoản, nhập secrets qua file private/Dashboard,
xác minh domain và chấp nhận điều khoản. Hướng dẫn chính xác từng thao tác
Dashboard tôi phải làm rồi tiếp tục khi đã có kết quả. Chỉ nhắm project Supabase
mới đã xác minh ref trước các lệnh db push/secrets/deploy. Không tự mua dịch vụ
hoặc bật billing. Chọn cloud riêng làm đường chính, Docker/local là tùy chọn.

Giữ kiến trúc: UI đọc SQLite/Drift theo tài khoản; ghi dữ liệu/outbox atomic;
giữ UUID, version, tombstone, idempotency và lựa chọn xung đột; tiền VND int/
bigint, báo cáo giờ Việt Nam. Nghiệp vụ nợ/giao dịch liên kết ở repository.
Chỉ migration bổ sung; không reset DB, xóa volume, SQLite, app hay dữ liệu để
sửa lỗi. Không nới RLS/quyền ghi trực tiếp hoặc bỏ xác thực để làm test qua.
App là sổ tài chính; không thêm thanh toán, liên kết ngân hàng, nhóm hay PRO.
UI tái dùng theme/font/widget, semantic colors và ARB Việt–Anh. Theme/ngôn ngữ
lưu theo thiết bị và không bị xóa khi đổi tài khoản.

Không commit env thật, key/token/password, JKS, cert/profile, DB/backup,
build artifacts hoặc lib/l10n/generated. Gemini chỉ ở server; Flutter dùng
--dart-define-from-file. Không log secrets khi chẩn đoán. Không tự commit,
push, PR/merge, force-push hoặc viết lại Git history.

Giữ pubspec.lock; chạy flutter pub get, flutter gen-l10n,
flutter analyze --no-fatal-infos và flutter test. Chạy SQL tests theo README
khi sửa sync/migration; chạy test/type-check Functions liên quan khi sửa server.
Kiểm tra thủ công màn nhỏ, chữ lớn, bàn phím và offline nếu đổi UI.

Lưu ý source hiện còn dùng debug signing cho Android release: phải cấu hình
keystore release riêng và xác minh certificate APK trước khi gọi đó là bản
release của tôi. iOS cần Mac/Xcode/signing thật; kiểm tra SwiftPM và OCR build
phase trong checkout, không mặc định tạo Podfile hoặc chạy pod install.

Mỗi chặng báo kết quả đã kiểm chứng, lỗi còn lại và bước cần tôi làm. Cuối cùng
trả commit/diff, cách chạy, kết quả tests, package/bundle, ref backend mới,
đường dẫn APK/IPA và những gì chưa nghiệm thu. Deploy thành công, fallback local
hay build xanh không được coi là AI thật/Google thật/iOS thật đã hoạt động.
```

## 2. Thông tin người nhận điền — không chứa secrets

```text
Máy của tôi: [Windows / macOS + phiên bản]
Tôi cần: [APK debug / APK release ký riêng / AAB / iOS development / TestFlight]
Repo và nhánh bàn giao: [...]
Commit SHA người gửi xác nhận: [...]
Tên hiển thị app: [...]
Android applicationId mới: [...]
iOS bundle ID mới, nếu làm iOS: [...]
Supabase mới: [chưa tạo / đã tạo, project ref công khai ...]
SMTP riêng: [chưa có / đã có nhà cung cấp và sender, không gửi password]
Gemini: [để sau / cần làm, key sẽ nhập trong file server private]
Google Sign-In: [để sau / Android / iOS / cả hai]
Apple: [chưa có Mac / có Mac / có team development / có Developer Program]
Signing Android: [chưa tạo / có keystore riêng, không gửi mật khẩu]
```

## 3. Chặng công cụ và định danh

```text
Hãy thực hiện mục 2–4 của docs/INDEPENDENT_SETUP.md. Xác minh source/commit và
toolchain, giữ diff hiện có. Cài/khôi phục dependencies bằng pub get và gen-l10n;
đừng tự nâng dependencies. Báo công cụ tôi còn phải cài hoặc giấy phép tôi phải
chấp nhận. Đổi applicationId/bundle/tên app theo thông tin tôi đã cung cấp trong
fork này, giữ namespace Kotlin nếu không cần đổi và kiểm tra manifest/widget.
Tạo cấu hình IDE thường không phụ thuộc Team nếu cần. Chưa có ID/tên thì hỏi
tôi, không ghi placeholder làm ID thật. Chạy analyze/test và báo lỗi cụ thể.
```

## 4. Chặng Supabase và OTP

```text
Hãy dựng backend riêng theo mục 5–7 của docs/INDEPENDENT_SETUP.md. Hướng dẫn tôi
tạo project bằng tài khoản của tôi nếu chưa có. Sau khi có ref, xác minh CLI
link đúng project mới, dry-run rồi áp đủ migrations từ source theo thứ tự và
kiểm tra migration history. Không copy schema lẻ hoặc sửa history để né lỗi.
Kiểm tra RLS, sync_push/sync_pull, Storage receipts private/avatars public và
cron. Đọc và chạy cloud_readiness.sql trên backend mới khi đã xác minh đích.

Chỉ rõ cách tôi cấu hình SMTP/sender và dán hai email templates của repo để
nhận OTP 6 số, cả signup và recovery. Không tự lấy SMTP cũ hay tắt Confirm email.
Tạo env Flutter private từ mẫu, chỉ URL/publishable key và Google IDs nếu có.
Không in key/token/password vào chat/log. Chạy app với env mới, thử tài khoản
app mới, bootstrap, ghi tay, offline và sync. Ghi rõ phần SMTP hoặc test thủ
công đang chờ tôi, không đánh dấu hoàn tất thay.
```

## 5. Chặng Gemini và Google tùy chọn

```text
Hãy làm mục 8–9 của docs/INDEPENDENT_SETUP.md cho các tính năng tôi đã chọn.
Tôi sẽ tự tạo/nhập Gemini key server và OAuth secrets qua file private hoặc
Dashboard. Xác minh ref trước secrets/deploy; deploy các Functions thực sự có
trong checkout, gồm ai-finance-query chỉ khi có source. Giữ quota, RLS, user
authentication và quyền đọc dữ liệu như hiện tại. Nếu gateway/signing keys của
project mới không tương thích, chẩn đoán bằng logs/tài liệu hiện hành; không
tắt xác thực để chữa thử. Mọi sửa thích nghi phải kiểm tra request thiếu/sai/
hết hạn token bị từ chối và user thật vẫn hoạt động dưới RLS.

Google phải dùng Web/native clients riêng đúng applicationId/bundle ID và SHA
của từng bản debug/release/Play; kiểm tra URL scheme và cấu hình nonce khớp
source. Test người dùng Google của tôi trên app thật. Test riêng AI chữ/ảnh/
cố vấn có dữ liệu và hiểu câu hỏi nếu có. Không dùng fallback, cached report
hoặc HTTP timeout làm bằng chứng AI thành công; AI không tự lưu giao dịch.
```

## 6. Chặng Android release

```text
Hãy tạo bản Android ký riêng theo mục 10–11 của docs/INDEPENDENT_SETUP.md.
TUI_KHON_TEAM phải tắt. Kiểm tra khóa riêng đã có trước khi tạo; không sinh lại
hoặc ghi đè khóa của tôi. Nếu chưa có, hướng dẫn nhập password tương tác.
Cấu hình android/key.properties private và Gradle signingConfigs.release;
thay việc release đang dùng debug, không fallback debug khi thiếu file.
Chạy analyze/test, build APK release bằng .env backend mới; build AAB nếu tôi
yêu cầu. Xác minh applicationId và fingerprint bằng apksigner/keytool, cập
nhật OAuth SHA riêng nếu tôi bật Google. Cài/thử release trên thiết bị nếu có,
không gỡ app hoặc xóa dữ liệu khi certificate không khớp. Trả đường dẫn file,
SHA certificate công khai và kết quả thực tế; chưa publish Store.
```

## 7. Chặng iOS trên Mac

```text
Hãy thực hiện mục 12 của docs/INDEPENDENT_SETUP.md trên Mac này. Kiểm tra Xcode,
Flutter, SwiftPM/plugins, Python và build phase/model OCR nếu checkout có nó;
không tái tạo thư mục ios hoặc mặc định chạy pod install. Dùng bundle ID và
Apple Team của tôi, giữ secrets/signing private. Build Simulator bằng env
backend riêng trước; sau đó cấu hình signing và chạy iPhone thật nếu có.

Nếu tôi có quyền distribution phù hợp, build archive/IPA với export method
đúng mục đích. Hướng dẫn bước đăng ký device/ad hoc hoặc App Store Connect/
TestFlight còn cần tôi làm. Không khẳng định Windows build được iOS, IPA cài
trên mọi iPhone, hay build chưa ký là app đã phân phối được. Test camera/OCR,
mic, notifications, biometrics, offline/sync và Google nếu bật; ghi rõ ca chưa
thử. Không tải lên/phát hành Store khi tôi chưa yêu cầu.
```

## 8. Prompt tiếp tục khi đổi Agent hoặc hết context

```text
Hãy đọc AGENTS.md, docs/INDEPENDENT_SETUP.md và báo cáo tiến độ tôi gửi kèm.
Kiểm tra git status/commit cùng file thực tế trước khi tiếp tục. Giữ những
việc đã hoàn thành, không tạo lại project/key/keystore, không reset hay đổi
môi trường để bắt đầu lại. Không yêu cầu tôi gửi secrets vào chat. Đối chiếu
những mục đã kiểm chứng và tiếp tục chặng còn thiếu tới đầu ra đã yêu cầu.
Chỉ xác nhận thành công dựa trên lệnh/test hoặc thao tác thật đã quan sát.
```

Mẫu tiến độ người nhận có thể lưu ngoài repo hoặc trong ghi chú không bí mật:

```text
Commit / diff đang dùng:
Máy và versions toolchain:
Nền tảng và đầu ra cần đạt:
Tên app / applicationId / bundle ID:
Supabase project ref mới (không key):
Env/signing private đã tạo ở đâu (chỉ đường dẫn, không nội dung):
Các chặng đã kiểm chứng, kèm lệnh/kết quả:
Test thủ công đã thử:
Lỗi hiện tại đã che secrets:
Việc còn thiếu / thao tác chủ tài khoản cần làm:
Artifact đã build (đường dẫn) và signing đã xác minh:
```
