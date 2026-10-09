# UTM SE Lite v9.1 — ARM32 -append argv fix / device log finding

**Ngày:** 2026-10-09 (ICT)  
**Repo:** phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS  
**Branch:** `fix/arm32-linux-bootargs-v9-1`  
**Mục tiêu:** sửa lỗi QEMU ARM32 không khởi động Alpine Linux trên iPhone. **Không đưa firmware Nokia N95 vào repo.**

## Bằng chứng từ log iPhone v9 (đã lược bỏ mọi đường dẫn/UUID)

- UTM v9 chạy `qemu-system-arm` với `-machine virt -cpu cortex-a15 -m 256 -kernel …/vmlinuz-lts -initrd …/initramfs-armv7.cpio.gz`.
- `Loading qemu-arm-softmmu.framework/qemu-arm-softmmu` — framework ARM32 **đã được nạp qua dyld** trên iPhone. Không nhầm với xác nhận Linux boot PASS.
- Tập lệnh ghi trong log: `-append console=ttyAMA0,115200 rdinit=/init loglevel=5`, thiếu quote/argv grouping. Lỗi QEMU **trực tiếp**: `qemu-arm-softmmu: rdinit=/init: Could not open 'rdinit=/init': No such file or directory`. Kế tiếp là `QEMU exited with code -1: (no message)` và `SPICE … Connection refused`.
- UTM cũng báo `Failed to access bookmark data` vài lần và Objective-C trùng `SpiceDisplayMetal` ở 2 framework. Chưa có chứng cứ các cảnh báo này là nguyên nhân trực tiếp của lượt boot thất bại. Đánh giá lại sau khi sửa `-append`.
- **KHÔNG upload log thô iPhone** lên GitHub; đây chỉ là tổng hợp lỗi đã ẩn thông tin đường dẫn container.

## Root cause (đối chiếu upstream UTM `7eadb056…`)

- `Platform/Shared/VMWizardState.swift`: khi boot kernel, wizard lưu `QEMUArgument("-append")` và `QEMUArgument(linuxBootArguments)` vào `config.qemu.additionalArguments`.
- `Configuration/UTMQemuConfiguration+Arguments.swift` → `parsedUserArguments`: regex tách mỗi string theo khoảng trắng, trừ khi có đôi ngoặc kép.
- Vì vậy QEMU nhận ba argv riêng `console=ttyAMA0,115200`, `rdinit=/init`, `loglevel=5` thay vì **một argv sau `-append`**. QEMU coi `rdinit=/init` là một tên file ảnh đĩa, báo không thể mở.
- **Workaround trên v9:** `Cài đặt → QEMU → Arguments`; giữ `-append`, sửa dòng ngay bên dưới thành `"console=ttyAMA0,115200 rdinit=/init loglevel=5"`, rồi lưu.
- **Fix bền v9.1:** script [`scripts/patch_arm32_qemu_append_v9_1.py`](../../scripts/patch_arm32_qemu_append_v9_1.py) sửa parser: nếu kiến trúc `.arm`, machine `virt` và QEMUArgument ngay sau `-append`, **giữ nguyên toàn bộ chuỗi** làm một argv, bỏ hai ngoặc kép ở ngoài nếu người dùng đã dùng workaround. Những kiến trúc/argument khác giữ hành vi upstream. Fix áp dụng lúc chạy, nên có hiệu lực với máy ảo v9 đã lưu.

## Build / device test

- [Workflow `15-lite-v9-1-arm32-bootargs-fix.yml`](../../.github/workflows/15-lite-v9-1-arm32-bootargs-fix.yml) dựng IPA v9.1 độc lập từ UTM pinned, framework ARM32 iOS TCI, 7 engine còn lại, bản vi.lproj v8 đã device-PASS, cùng các vá UIKit.
- [GitHub Actions build v9.1 #37895064248](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37895064248) — chưa xác nhận kết quả tại thời điểm ghi.
- Bản v9.1 dùng cùng `com.phai.nokias60.arm32.UTM-SE` để nâng cấp/thay thế bản v9 khi IPA PASS; **không ghi đè v8** (`com.phai.nokias60.UTM-SE`).
- Tiêu chí DEVICE PASS: trên iPhone mở máy ảo ARM32 đã tạo trong v9, khởi động bằng kernel + initramfs Alpine ARMv7, log có `ALPINE_ARCH=armv7l` và `ALPINE_ARM32_SMOKE_PASS`; thử `uname -m`, tắt và mở lại.
- **Không khẳng định Linux boot PASS** từ BUILD PASS hoặc đã nạp engine QEMU thành công; lỗi mới nếu có phải thu debug.log bổ sung.
