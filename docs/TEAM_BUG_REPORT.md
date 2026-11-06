# Mẫu báo lỗi chung — Túi Khôn Nhóm 5

Chạy `.\tool\team.ps1 doctor` trước, đính kèm **`.team/diagnostics.json`** qua kênh
nhóm cùng nội dung bên dưới. Không gửi `.env`, ZIP private, JKS, signing properties,
backup, token đăng nhập hay mật khẩu. Ảnh lỗi cần che thông tin tài chính cá nhân.

- Người thử / thời điểm:
- Tên nhánh và commit (xem report):
- Source có sửa cục bộ không (`sourceDirty`):
- Thiết bị Android / phiên bản Android:
- Lệnh hoặc thao tác gây lỗi:
- Các bước lặp lại:
- Kết quả mong đợi:
- Kết quả thực tế / thông báo lỗi (đã che secret):
- Có mạng hay offline:
- Có xảy ra trên máy khác với cùng commit/bundle không:
- File đính kèm: diagnostics JSON, ảnh lỗi đã che dữ liệu.

Người hỗ trợ đối chiếu trước: `status`, `sourceCommit`, `sourceDirty`,
`bundleVersion`, `actualTools`, `backendProject`, `configSha256`,
`certificateSha1`, `checks`. Hash khác thì thống nhất lại bundle/toolchain trước
khi sửa source. `sourceDirty: true` cần so sánh diff dù commit giống nhau.
Report thất bại sớm có thể chưa có fingerprint; giữ thông báo lỗi đã che secret
để biết bước nào chưa chạy được. Không xóa DB, gỡ app hoặc xoay khóa để thử sửa lỗi.
