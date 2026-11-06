# Túi Khôn — Nghiệp vụ

**Túi Khôn là sổ ghi chép tài chính cá nhân, không phải ví điện tử.**
- App không giữ tiền, không liên kết ngân hàng, không chuyển khoản, không thanh toán.
- Người dùng tự ghi lại tiền vào/ra của mình. App giúp ghi nhanh (giọng nói, chữ tự nhiên, ảnh hóa đơn), nhắc nhở và tổng hợp lại.
- Mọi chức năng đều miễn phí. Không có gói trả phí.

## 1. Khái niệm

| Khái niệm | Quy tắc |
| --- | --- |
| **Giao dịch** | Một khoản thu hoặc chi do user tự ghi: số tiền (VND, số nguyên), danh mục, nguồn tiền, ghi chú, thời điểm. Không có giao dịch nào tự sinh từ ngân hàng. |
| **Nguồn tiền** | Nhãn do user tự tạo để biết tiền đang nằm ở đâu: Tiền mặt, TK Vietcombank, Ví MoMo… Có số dư ban đầu tự khai. **Số dư = số dư ban đầu + tổng thu − tổng chi đã ghi.** Không đồng bộ với tài khoản thật. |
| **Danh mục** | Đăng ký xong có sẵn 22 danh mục (15 chi, 7 thu). User được thêm, sửa, xoá. Xoá danh mục thì giao dịch cũ vẫn còn, chuyển thành "Chưa phân loại"; ngân sách của danh mục đó bị xoá theo. |
| **Ngân sách** | Hạn mức chi trong một tháng: cho tổng chi tiêu hoặc từng danh mục. Khi tổng chi tới **80%** và **100%** hạn mức, app tạo thông báo (mỗi mức một lần; chi giảm lại thì được nhắc lại). |
| **Sổ nợ** | Ghi chú "**Tôi nợ** A 500k" hoặc "B **nợ tôi** 200k", kèm hạn trả và ghi chú. Mặc định **không ảnh hưởng số dư**. |
| **Mục tiêu tiết kiệm** | Tên, số tiền mục tiêu, hạn, số đã để dành. "Nạp thêm" / "Rút bớt" chỉ thay đổi con số ghi chú, không trừ nguồn tiền nào. Để dành đủ thì mục tiêu tự chuyển "Hoàn thành" và có thông báo. |
| **AI (Gemini)** | Chỉ **đề xuất**: đọc câu nói hoặc ảnh hóa đơn thành bản nháp giao dịch, và viết nhận xét chi tiêu. User luôn xác nhận trước khi lưu. Mỗi ngày có giới hạn dùng hợp lý (ghi nhanh 50, quét hóa đơn 20, phân tích 10) để kiểm soát chi phí; đây không phải gói trả phí. Khi AI không khả dụng, app dùng bộ phân tích tiếng Việt offline. |

## 2. Luồng chính

### Ghi giao dịch
1. Chọn một trong ba cách ghi:
   - **Gõ hoặc nói**: Ghi nhanh AI → nhập "ăn phở 65k" hoặc bấm mic.
   - **Quét hóa đơn**: chụp ảnh → ảnh lưu vào kho riêng của user, Gemini đọc tổng tiền.
   - **Nhập tay**: nút ✎ trong màn Ghi nhanh.
2. App hiện thẻ xác nhận gồm số tiền, danh mục và nguồn tiền. User có thể bấm **Sửa**.
3. Bấm **Lưu** → số dư, ngân sách và thống kê được cập nhật.

### Lịch sử giao dịch
- Mở từ Trang chủ → **Xem tất cả**.
- Lọc theo tháng, Thu/Chi, danh mục, nguồn tiền; tìm theo ghi chú.
- Bấm vào một giao dịch để sửa, vuốt sang trái để xoá. Giao dịch có ảnh hóa đơn thì xem lại được.

### Sổ nợ và nhắc hạn
1. Kế hoạch → Sổ nợ → **Thêm khoản nợ**: chọn "Tôi nợ" hoặc "Nợ tôi", nhập người, số tiền, hạn trả.
2. App nhắc lúc **08:00 ngày trước hạn** và **08:00 ngày đến hạn**:
   - Thông báo trên điện thoại, lên lịch ngay trên máy.
   - Thông báo trong app, do server tạo hằng ngày. Nhắc thêm một lần nữa nếu đã quá hạn.
3. **Khi mở app**: nếu có khoản đến hạn hôm nay hoặc đã quá hạn, app hỏi "Đã trả / Đã nhận chưa?" (mỗi phiên một lần).
4. Khi trả xong, user tự xác nhận:
   - **Đã trả hết / Đã nhận đủ**: khoản nợ chuyển sang "Đã tất toán".
   - **Ghi trả một phần**: nhập số tiền đã trả, khoản nợ còn lại tiếp tục được theo dõi.
   - Tuỳ chọn **"Ghi kèm vào giao dịch"**: tôi trả nợ thì thêm một khoản chi "Trả nợ"; người khác trả tôi thì thêm một khoản thu "Thu nợ".

### Ngân sách
- Kế hoạch → Ngân sách → chọn tháng → **Thêm ngân sách** (tổng hoặc theo danh mục).
- Thanh tiến độ đổi màu xanh → cam (≥ 80%) → đỏ (≥ 100%).
- Nút **Từ tháng trước** sao chép các hạn mức của tháng trước sang.

### Bảo mật
- Đăng nhập bằng email + mật khẩu (xác thực email bằng mã OTP 6 số) hoặc Google. Quên mật khẩu thì đặt lại bằng mã OTP.
- **Khoá bằng Face ID / vân tay** (bật trong Cá nhân): mỗi lần mở app, hoặc quay lại sau hơn 60 giây ở nền, phải xác thực sinh trắc học. Nút "Đăng nhập bằng mật khẩu" sẽ đăng xuất và quay về màn đăng nhập.
- Mỗi user chỉ đọc/ghi được dữ liệu của chính mình (Row Level Security trên Supabase). Ảnh hóa đơn nằm trong kho riêng tư, chỉ xem qua link có hạn 15 phút.

## 3. Ghi chép offline và tính năng mở rộng

- Toàn bộ thu/chi, nguồn tiền, danh mục, ngân sách, nợ và mục tiêu được đọc/ghi SQLite sau lần tải dữ liệu đầu. Hàng đợi tự đồng bộ khi có mạng; xung đột hai thiết bị được giữ để người dùng chọn bản đúng.
- Sổ nợ lưu từng lần trả: ngày, số tiền và ghi chú. Sửa/hoàn tác cập nhật cả khoản thu/chi liên kết nếu có. Lịch sử cũ được giữ thành bản tổng trước nâng cấp, không tự tạo thêm giao dịch.
- AI hiểu tối đa 10 khoản mỗi câu, có thẻ hỏi bổ sung riêng và lưu các mục được chọn. Quy tắc phân loại học từ bản sửa đã lưu, có thể tắt/xoá. Mọi đề xuất vẫn cần xác nhận.
- Khoản phải trả (một lần, tuần, tháng) chỉ nhắc người dùng. Khi xác nhận, có thể chỉ đánh dấu hoặc mở form chi điền sẵn. Ngày cuối tháng được điều chỉnh theo lịch, không tự trừ tiền.
- Nhắc ghi chép hằng ngày mặc định tắt; mặc định 21:00 khi bật, có thể đổi giờ. Báo cáo nhắc đầu tháng; thu/chi, danh mục, ngân sách và so sánh tháng trước tính offline. Nhận xét AI cần mạng và dữ liệu đã đồng bộ; bản lưu có nhãn cần cập nhật khi dữ liệu đổi.
- CSV chỉ trao đổi giao dịch, có xem trước, kiểm tra lỗi/trùng và ánh xạ danh mục/nguồn tiền. Không ghi đè ID đã có. Dữ liệu nhập được lưu offline trước khi đồng bộ.
- Từ chối quyền thông báo không chặn dùng app. Sinh trắc học là khoá truy cập app, không thay thế Supabase Auth cho đồng bộ.

Chi tiết kỹ thuật, cài key Gemini và quy trình nâng cấp giữ dữ liệu: [OFFLINE_UPGRADE.md](OFFLINE_UPGRADE.md).

## 4. Ngoài phạm vi

Những thứ sau **không làm** vì app chỉ là sổ ghi chép:
- Liên kết tài khoản ngân hàng hoặc ví điện tử, đọc số dư thật.
- Chuyển khoản, thanh toán, mã VietQR. Luồng "chọn ngân hàng → mở app ngân hàng → đọc thông báo biến động số dư" bị loại vì rủi ro bảo mật, cần quyền đọc thông báo của app khác và phụ thuộc API từng ngân hàng.
- Chia tiền nhóm.
- Giao dịch định kỳ tự động.
- Gói trả phí (PRO), xuất bản backup toàn bộ tài khoản, trang quản trị (admin).
