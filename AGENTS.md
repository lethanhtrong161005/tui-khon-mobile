# Túi Khôn — hướng dẫn tiếp tục phát triển

Đọc [docs/HANDOFF.md](docs/HANDOFF.md) để lấy context bàn giao; dùng
[SETUP.md](SETUP.md) để chạy source và [docs/NGHIEP_VU.md](docs/NGHIEP_VU.md)
để đối chiếu nghiệp vụ. Bản bàn giao nằm trên `feature/offline-ai-history`.

- Đây là sổ ghi chép tài chính, không phải ví điện tử. Không tự thêm thanh toán,
  liên kết ngân hàng, chia tiền nhóm hoặc gói PRO.
- UI đọc SQLite/Drift riêng từng tài khoản. Ghi dữ liệu và outbox phải atomic;
  giữ UUID, phiên bản, tombstone, idempotency và cơ chế chọn khi xung đột.
- Tiền VND dùng `int`/`bigint`; báo cáo theo giờ Việt Nam. Ngôn ngữ giao diện
  không quyết định loại tiền hay múi giờ nghiệp vụ.
- Đưa quy tắc trả nợ/giao dịch liên kết vào repository, không xử lý riêng trong UI.
- Chỉ dùng migration bổ sung. Không reset DB, xóa volume hoặc dữ liệu để sửa lỗi.
- Không commit env thật, key, token, DB/backup hoặc build artifacts. Gemini key
  chỉ nằm ở server; cấu hình Flutter lấy từ `--dart-define-from-file`.
- Tái sử dụng theme, font đóng gói và widget hiện có; kiểm tra màn nhỏ, chữ lớn,
  bàn phím và offline khi thay UI. Dark theme/i18n chưa có, xem HANDOFF trước khi thêm.
- Kiểm tra thay đổi bằng `flutter analyze --no-fatal-infos` và `flutter test`;
  khi sửa sync/migration, chạy thêm SQL tests trong `supabase/tests/README.md`.
- Tôn trọng diff của người dùng. Không tự merge, tạo PR, force-push hoặc viết lại
  lịch sử Git. Khi được yêu cầu commit, giữ danh tính Git của người dùng, không
  thêm AI/Claude co-author.
