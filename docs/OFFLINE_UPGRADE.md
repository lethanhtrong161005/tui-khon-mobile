# Nâng cấp offline, AI và lịch sử

## Cài đặt và giữ dữ liệu

1. Lấy nhánh `feature/offline-ai-history`, chạy `flutter pub get`.
2. Sao lưu project Supabase theo quy trình của nhóm trước khi nâng cấp môi trường dùng thật. Không chạy `db reset` trên dữ liệu cần giữ.
3. Với Supabase local đang có dữ liệu: `npx supabase migration up --local`. Với project cloud đã link: `npx supabase db push`.
4. Deploy lại `ai-quick-record` và `ai-advisor`. Migration mới bổ sung version/journal/tombstone, lịch sử trả nợ và khoản phải trả; không sửa các migration đã áp dụng trước đó.
5. Chạy `flutter run --dart-define-from-file=.env` (hoặc `.env.local` cho emulator).
6. Đăng nhập khi có mạng và đợi tải dữ liệu lần đầu. Mở chế độ máy bay để kiểm tra ghi chép; bật lại mạng và xem **Cá nhân → Dữ liệu & Đồng bộ**.

App mới dùng RPC cho thay đổi dữ liệu tài chính. Sau migration, bản app cũ ghi trực tiếp vào bảng sẽ bị từ chối: cập nhật các thiết bị của nhóm cùng đợt. Đăng nhập, hồ sơ và ảnh đại diện vẫn dùng API riêng của Supabase.

Khoản đã trả trước nâng cấp được giữ nguyên tổng tiền và chuyển thành bản lịch sử cũ. Không có thông tin chi tiết từng lần nên hiển thị nhãn riêng; không tạo thêm thu/chi. Việc sửa/hoàn tác bản cũ vẫn chỉ điều chỉnh số ghi chép nợ.

## Cách vận hành

- Giao diện đọc SQLite, gồm số dư, thống kê và báo cáo. Mỗi tài khoản có file DB riêng trong application support, không lưu trong source hoặc `shared_preferences`.
- Ghi dữ liệu và hàng đợi cùng transaction. Mỗi thao tác có UUID bền vững; mất phản hồi rồi gửi lại không tạo thêm bản ghi.
- Đồng bộ khi mở/quay lại app, có mạng, kiểm tra định kỳ khi app hoạt động và khi người dùng bấm nút. Hệ điều hành đóng app có thể ngừng đồng bộ; mở lại để tiếp tục.
- Xoá dùng tombstone và journal để thiết bị khác biết mục đã xoá. Chọn bản local/server khi xung đột; các mục khác vẫn tiếp tục đồng bộ.
- Lỗi xác thực hoặc mạng không xoá DB. Đăng xuất có thay đổi chờ sẽ cảnh báo và giữ chúng trên máy; đăng nhập lại đúng tài khoản để tiếp tục. Không có tài khoản khách cho lần mở app đầu tiên.
- Ảnh hoá đơn lưu trên máy trước, hash nội dung giúp nhận ra ảnh đã dùng. Upload chờ mạng; không tự gọi AI khi mạng trở lại. Người dùng chủ động quét lại khi cần nhận dạng.
- Cảnh báo trùng là gợi ý, có quyền **Vẫn lưu**. Chống gửi lại cùng thao tác là cơ chế độc lập và bắt buộc.

## AI và Gemini key

Không cần key để chạy unit/widget test hoặc nhập tay/offline. Cần key để thử Gemini thật.

Local: tạo `supabase/functions/.env` chứa `GEMINI_API_KEY=...`, sau đó:

```sh
npx supabase functions serve --env-file supabase/functions/.env
```

Cloud: tạo file riêng `supabase/.env` từ mẫu, rồi:

```sh
npx supabase secrets set --env-file supabase/.env
npx supabase functions deploy ai-quick-record
npx supabase functions deploy ai-advisor
```

Key không nằm trong Flutter, không gửi vào chat và không commit. Giới hạn lượt hằng ngày giữ nguyên. AI ghi nhanh trả tối đa 10 bản nháp, người dùng xác nhận từng mục hoặc lưu các mục đã chọn. Chỉ học phân loại sau khi bản sửa được lưu; quản lý quy tắc trong Cá nhân.

Báo cáo tháng tính số liệu tại máy theo giờ Việt Nam; nhận xét AI chỉ tạo khi dữ liệu đã đồng bộ. Cache gắn với dữ liệu, báo cần cập nhật khi dữ liệu đổi. Không có AI vẫn xem được báo cáo.

## Nghiệp vụ mới

- **Trả nợ:** thêm/sửa/hoàn tác một lần trả cập nhật tổng đã trả và giao dịch liên kết cùng transaction. Hai thiết bị cùng ghi vượt số nợ: server từ chối thao tác vượt, giữ lỗi trên máy để sửa trong lịch sử.
- **Khoản phải trả:** một lần/tuần/tháng, ngày cuối tháng được chặn theo số ngày thực tế. Chỉ nhắc; xác nhận rồi mới ghi chi hoặc chỉ đánh dấu đã trả. Mỗi kỳ có mã cố định chống xác nhận trùng.
- **Thông báo:** mặc định nhắc ghi chép tắt, bật lên dùng 21:00 và có thể chọn lại giờ. Nợ/khoản phải trả trước hạn một ngày và đúng ngày lúc 08:00. Báo cáo nhắc ngày đầu tháng. Từ chối quyền thông báo không ngăn ghi chép; lịch trong app vẫn xem được.
- **CSV:** theo mẫu trong app, UTF-8 BOM, số nguyên VND, ngày giờ có múi giờ. Xem trước lỗi/trùng, ánh xạ nguồn tiền/danh mục và xác nhận tạo mục mới. ID đã tồn tại không bị ghi đè. File không chứa ảnh hay thông tin đăng nhập; đây không phải bản backup toàn bộ app.

## Kiểm thử

```sh
flutter analyze --no-fatal-infos
flutter test
npm ci --prefix supabase/tests --ignore-scripts
node supabase/tests/run-offline-history.cjs
```

SQL runner dùng PostgreSQL PGlite cô lập, so sánh ảnh chụp dữ liệu trước/sau migration và kiểm tra rollback. Không kết nối project thật. Kiểm thử khoá đồng thời nhiều connection trên PostgreSQL thật có hướng dẫn riêng ở `supabase/tests/README.md`; PGlite không thay thế bước này.

Kiểm tra thiết bị: lần đầu tải dữ liệu, tắt mạng → nhập/sửa/xoá → đóng/mở lại → bật mạng; thử hai thiết bị sửa cùng giao dịch; trả nợ sửa/hoàn tác; CSV xuất/nhập lại; thông báo và đường dẫn khi mở app từ notification. Gemini thật và thông báo nền cần kiểm tra trên thiết bị với cấu hình thật.
