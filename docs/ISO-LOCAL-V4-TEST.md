# iOS ISO selection: v3 failed; v4 Documents fallback

**08/10/2026 — DEVICE TEST v3 FAILED:** Trên iPhone với ESign, UTM Lite v3 vẫn không chọn được Alpine ISO trong iOS Files ngay cả sau khi đổi bộ lọc `.data` thành `.item`. Không hợp nhất PR #5.

## Manh mối từ nguồn UTM

- [UTM issue #7553](https://github.com/utmapp/UTM/issues/7553), [Discussion #7556](https://github.com/utmapp/UTM/discussions/7556): tác giả UTM nhận định việc không chọn được ISO trong iOS Files có liên hệ với phương thức ký app không được hỗ trợ.
- [Tài liệu UTM iOS](https://docs.getutm.app/installation/ios/): UTM SE không cần JIT, tương thích nhiều cách ký; đây chưa phải bằng chứng ESign chắc chắn bị lỗi.
- Ghi chú phát hành cũ của UTM từng nêu entitlement `application-identifier` không hợp lệ có thể làm trình chọn tệp iOS không hoạt động. Cần xem chứng chỉ/entitlements của **IPA sau khi ký**, không chỉ IPA unsigned được build ở GitHub.

## Thử nghiệm v4 độc lập với UIDocumentPicker

Khi ứng dụng được ký và cài bằng ESign:

1. Mở UTM Lite v4 một lần rồi vào Linux → Boot from ISO image để app tạo `COPY-ISO-HERE.txt` trong thư mục Documents của chính nó.
2. Mở ứng dụng **Tệp** trên iPhone, vào **Duyệt → Trên iPhone của tôi → UTM SE** (tên thư mục có thể theo tên hiển thị app).
3. Sao chép (không phải di chuyển bản duy nhất) `alpine-virt-3.24.2-aarch64.iso` vào thư mục có `COPY-ISO-HERE.txt`.
4. Trở lại UTM Lite v4 → Linux → Boot from ISO image. Ở phần **Chọn ISO từ bộ nhớ ứng dụng (không dùng Browse)**, nhấn **Làm mới danh sách ISO trong ứng dụng** và chạm tên Alpine ISO.
5. Kiểm tra dấu chọn và đường dẫn ISO xuất hiện; chưa cần Start máy ảo. Gửi ảnh nếu thất bại.

Nếu không thấy thư mục UTM SE trong Files: đừng kết luận bộ lọc ISO lỗi. Gửi ảnh danh mục “Trên iPhone của tôi” và phương pháp/chứng chỉ ký trong ESign (không gửi khóa riêng). Vấn đề có thể ở quyền ứng dụng/entitlement cần kiểm tra đúng từ IPA **đã ký**. Có thể thử UTM SE App Store để phân biệt lỗi hệ thống Files với IPA ký lại; App Store không có bản Nokia Lite của chúng ta.

## Bảo toàn baseline

- Lite v2 đã DEVICE PASS phần **mở app**, 121.09 MiB.
- Lite v3 chọn ISO FAILED, PR #5 đóng.
- Lite v4 chỉ bổ sung trình liệt kê ISO/IMG từ sandbox Documents, không sửa hệ thống hoặc đăng ký quyền riêng tư bổ sung.
- Các thư viện QEMU liên kết tĩnh/dyld cần thiết đều được giữ lại, như v2. Không cam kết firmware Nokia có thể chạy trên QEMU lúc này.

**Scope:** Nghiên cứu giả lập/khả năng tương thích Symbian; không liên quan khai thác, xâm nhập, malware hoặc persistence.
