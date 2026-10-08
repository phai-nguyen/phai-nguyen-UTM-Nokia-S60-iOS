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

## Handoff hiện tại — 08/10/2026

- Build UTM SE baseline **PASS** tại [GitHub Actions #37733615950](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950).
- Artifact `NokiaUTM-SE-v1-unsigned-IPA` và log đã có; mục tiêu iOS 15, bundle ID `com.phai.nokias60.UTM-SE`.
- Xcode 26 SDK yêu cầu patch SwiftUI API iOS 27, `ToolbarSpacer` iOS 26; script `scripts/patch_utm_ios26.py` đã dùng thành công.
- **Chưa có xác nhận cài/mở ứng dụng thực tế bằng ESign trên iPhone**. Chưa có Nokia machine/firmware loader và không chạy ROM Nokia.
- Build UTM upstream từ commit cố định, tải sysroot chính thức qua Actions run `36090554968`. Không sao chép repo UTM nặng vào GitHub này.
- Bước kế tiếp: kiểm thử IPA trên thiết bị trước khi chuyển sang OMAP2420/N95 MACHINE1. Các repo EKA2L1 được giữ nguyên.
