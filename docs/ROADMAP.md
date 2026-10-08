# Lộ trình UTM–Nokia S60

**Ngày khởi tạo:** 2026-10-08
**Repo:** `phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS`
**Mốc UTM upstream:** `7eadb056ae0f91d979059544d0ddcd2d5a40be92`

## Quy tắc kỹ thuật
1. Không sửa EKA2L1 hiện tại; không dùng chung tên bundle ID với UTM SE chính thức.
2. Mọi bản build lưu status, log và thông tin phiên bản QEMU/UTM, không xoá log khi lỗi.
3. Build tách hai phần: prebuilt sysroot QEMU/dependencies và frontend iOS để tránh compile lại khi chỉ sửa UI.
4. Không tuyên bố hỗ trợ Nokia cho tới khi tự kiểm thử boot ROM bằng log.
5. Không đưa firmware/ROM có bản quyền vào kho mã.

## Mốc công việc

| Mốc | Đầu ra | Điều kiện hoàn thành |
|---|---|---|
| v1 BOOTSTRAP | Tài liệu + source audit + pipeline thử build UTM SE iOS 15+ | GitHub Actions source audit xanh, log artifact |
| v2 UTM-SE-BASE | IPA UTM SE unsigned, bundle ID tách biệt | Build xanh, người dùng ký ESign và xác nhận mở app |
| v3 OMAP2420 | Khôi phục/port model từ QEMU cũ vào QEMU UTM riêng | Smoke-test thiết bị, RAM/IRQ/timer |
| v4 NOKIA-N95-MACHINE1 | Machine Nokia N95 thực nghiệm, ROM loader + MMIO trace | CPU bắt đầu chạy firmware và ghi PC/MMIO |
| v5 S60-BOOT | Xử lý các khối còn thiếu theo log | Có bằng chứng boot tuần tự, không giả định |
| nhánh nghiên cứu RM-356 | Khảo sát Freescale MXC300-30, đối chiếu i.MX31 | Có báo cáo register/memory-map trước khi code |

## Handoff
Trạng thái hiện tại chỉ là bootstrap. `UTM.xcodeproj`, frontend thực, các thư viện QEMU lớn và firmware không nằm trong repo này: workflow checkout UTM đúng commit để build. `build_utm_se.sh` chưa được kiểm thử trên macOS runner; không có IPA sẵn và không có machine Nokia. Bản `main` của các repo khác không bị thay đổi.
