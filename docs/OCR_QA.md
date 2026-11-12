# Kiểm tra OCR và trợ lý dữ liệu

## Kiểm thử tự động

```powershell
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
npx --yes deno test --allow-env supabase/functions/_shared/gemini_test.ts supabase/functions/ai-quick-record/result_test.ts supabase/functions/ai-advisor/period_test.ts supabase/functions/ai-finance-query/plan_test.ts
npx --yes deno check supabase/functions/ai-quick-record/index.ts supabase/functions/ai-advisor/index.ts supabase/functions/ai-finance-query/index.ts
```

`receipt_ocr_test.dart` dùng chữ và tọa độ OCR fixture để kiểm tra parser; không
thay thế việc chạy ML Kit native trên ảnh thật. `finance_query_test.dart` dùng
SQLite memory và snapshot fixture, kiểm tra VND nguyên, kỳ Việt Nam, ngân sách,
nợ còn lại, kỳ khoản phải trả và không phát sinh thao tác ghi khi hỏi dữ liệu.

## Android native

Chỉ dùng AVD **Pixel_8 có sẵn** trên máy này; không tạo AVD mới, không gỡ app hoặc reset dữ liệu. Kiểm tra `adb -s emulator-5554 emu avd name` trước khi chạy và thay device ID nếu Pixel_8 dùng cổng khác. Chạy kiểm thử ảnh in
tổng hợp qua ML Kit, không đăng nhập, không gọi Gemini:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test-pixel8-ocr.ps1 -DeviceId emulator-5554
```

Để kiểm tra hóa đơn Co.op Food người dùng cung cấp, cần giữ ảnh gốc ngoài Git.
Mốc đối chiếu: tổng 62.700 VND, 01/11/2026 lúc 18:55 Việt Nam, Co.op Food
D512 Trường Thọ, nguồn Vietcombank nếu nguồn này đã tồn tại.
Tệp clipboard tạm trong chat có thể hết hạn; không coi nội dung chép tay từ ảnh
là kết quả OCR native đã đạt.

Script build entrypoint QA, cài bằng `adb install --no-streaming -r` và chỉ gắn driver vào app đã chạy. Không dùng launcher `flutter test -d` để cài vì Flutter có thể thử uninstall khi cài thất bại. Nếu installer từ chối, script dừng và giữ dữ liệu. Sau kiểm tra, build/cài lại APK Team entrypoint chính.

Sau khi cài APK Team đúng chứng chỉ trên Pixel_8:

```powershell
adb push "C:\Private\receipt.png" /data/local/tmp/tui-khon-qa-receipt.png
adb shell run-as com.example.tui_khon_mobile.team mkdir -p files
adb shell run-as com.example.tui_khon_mobile.team cp /data/local/tmp/tui-khon-qa-receipt.png files/receipt-qa.jpg
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test-pixel8-ocr.ps1 -DeviceId emulator-5554 -ProvidedReceipt
```

Ảnh được chuẩn hóa theo nội dung, nên file có đuôi `.jpg` vẫn nhận đầu vào PNG.
Test ghi bằng chứng OCR riêng trong sandbox QA tại `files/receipt-qa-ocr.txt`.
Không đưa ảnh gốc, nội dung OCR hoặc database QA lên Git.

## Những tình huống phải thử trên thiết bị

- Hóa đơn chụp nghiêng, ảnh screenshot, tổng bị mờ, tiền giảm giá/VAT/tiền thừa,
  ngày hoặc nguồn không rõ, bill không xác định được chiều tiền.
- Tắt mạng: OCR và câu hỏi phổ biến vẫn chạy; nút nhờ Gemini đọc thêm giữ ảnh và
  bản nháp cũ khi lỗi. Nguồn tiền không khớp không tự chọn nguồn đầu tiên.
- Chữ 200%, màn 320×568, bàn phím, điều hướng ba nút/gesture, sáng–tối,
  Việt–Anh, widget Quét ảnh. Mọi bản nháp còn thiếu cần sửa trước khi lưu.
- Đổi tài khoản khi AI đang chạy: không hiển thị kết quả cũ trong tài khoản mới.
- Cài cập nhật cùng package/chứng chỉ: SQLite, outbox và tùy chọn thiết bị còn nguyên.

## iOS và icon

iOS giữ deployment target 15.0 và SwiftPM. Build phase `Copy Latin OCR resources`
chép model Latin từ plugin được khóa trong `pubspec.lock`, không cần commit model
hoặc sửa Pub cache. Cần build và nghiệm thu native bằng macOS/Xcode riêng.

Sinh lại icon từ logo đã duyệt:

```powershell
dart run tool/prepare_launcher_icons.dart
dart run flutter_launcher_icons
```

Giữ icon nguồn và native resources trong Git; APK, model cache và dữ liệu QA
không nằm trong Git. Bản thường và Team dùng cùng icon, giữ package/chứng chỉ cũ.
