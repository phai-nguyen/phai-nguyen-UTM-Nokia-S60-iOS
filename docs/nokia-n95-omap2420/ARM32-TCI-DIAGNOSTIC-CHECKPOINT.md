# ARM32 TCI / iOS — Diagnostic checkpoint (2026-10-09)

## Mục tiêu

Kiểm tra khả năng **biên dịch và đóng khung framework QEMU `arm-softmmu` (ARM32 guest) trên macOS → iOS arm64 / TCI / no-JIT**, dùng đúng dependency sysroot của baseline UTM SE Lite v8. Đây là một phép thử source/build, **chưa chạy Linux ARM32 và chưa tạo Nokia N95 machine**.

## Đã tạo / nguồn

- Branch: `research/n95-omap2420-arm32`. **Không merge**, không thay `feat/vi-localization-lite-v8`, PR #10 hoặc artifact IPA v8 đã được thử.
- [Source inventory](QEMU-SOURCE-INVENTORY.md) xác nhận upstream QEMU v9.1 còn OMAP2/N800/N810 và fork UTM v10.0.12-utm đã loại bỏ.
- [Workflow `12-arm32-tci-diagnostic.yml`](../../.github/workflows/12-arm32-tci-diagnostic.yml): kích hoạt trên push của script/workflow ở nhánh nghiên cứu; cũng hỗ trợ `workflow_dispatch` khi GitHub cho phép.
- [Script `diagnose_qemu_arm32_tci.sh`](../../scripts/diagnose_qemu_arm32_tci.sh): dùng UTM pinned `7eadb056ae0f91d979059544d0ddcd2d5a40be92`, [sysroot từ UTM Actions #36090554968](https://github.com/utmapp/UTM/actions/runs/36090554968) và source tarball đúng `qemu-10.0.12-utm.tar.xz`.

## Các bước workflow

1. Checkout pinned UTM và tải nguyên sysroot `Sysroot-ios-tci-arm64`; **không gọi** `build_dependencies.sh` vì script ấy xóa sysroot trước khi biên dịch.
2. SHA256 inventory và kiểm tra bảy engine `aarch64,i386,x86_64,ppc,ppc64,riscv64,m68k` vẫn có đầy đủ.
3. Configure `arm-softmmu` riêng bằng `--enable-shared-lib`, `--enable-tcg-threaded-interpreter`, deployment target iOS 15.0; compile `ninja`. **Không biên dịch lại bảy engine, không build IPA, không sửa mã OMAP2.**
4. Nếu compiler/link thành công, tìm `libqemu-arm-softmmu.dylib`, kiểm tra kiến trúc ARM64-host, iOS build info, `otool -L`; chạy UTM `fixup.sh` tạo framework **chỉ trong bản sysroot tạm của runner**.
5. Đối chiếu SHA256 của bảy engine trước/sau; xuất artifact `Nokia-N95-ARM32-TCI-DIAGNOSTIC-LOGS` mọi kết quả, và `QEMU-ARM32-TCI-RESEARCH-FRAMEWORK` **chỉ khi PASS**. Framework này không phải IPA có thể cài.
6. Nếu lỗi configure, collector EXIT lưu `qemu-config.log` và `meson-log.txt` để phân tích. Lưu `BUILD-STATUS.txt`, `LAST_STAGE`, log configure/compiler/dyld và provenance.

## Trạng thái / tiêu chí

- **SOURCE INVENTORY: DONE**; tài liệu đã commit riêng.
- **SCRIPT/WORKFLOW: COMMITTED** ở nhánh nghiên cứu ngày 09/10/2026.
- **ARM32 COMPILE RESULT: NOT YET CONFIRMED**; không suy ra pass từ `BOOTSTRAP-CHECK` (workflow khác).
- **iPhone ARM32 guest: NOT RUN**, **N95 OMAP2420 hardware: NOT IMPLEMENTED**, **Symbian: NOT BOOTED**.
- Baseline Lite v8 unsigned IPA SHA256 `671535ffec7f866688537ee86db8c5eb53aeccbd78f3fc517dcb9dcf871e6caa` giữ nguyên.

### Tiêu chí PASS của phép thử build

`BUILD-STATUS.txt` phải ghi `STATUS=PASS`; có Mach-O ARM64 iOS `qemu-arm-softmmu.framework`, đầy đủ imports, `SEVEN_FRAMEWORKS=UNCHANGED`. Đây chỉ là **compiler/framework candidate PASS**, không phải chạy ARM32 hay Nokia firmware PASS.

### Nếu GitHub không khởi chạy workflow tự động

Kiểm tra [GitHub Actions của repo](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions) và lọc nhánh nghiên cứu. Có thể cần cho phép workflow mới theo chính sách repository/GitHub hoặc dùng `workflow_dispatch` khi GitHub hiện nút Run workflow. **Đừng đánh đồng workflow `BOOTSTRAP-CHECK` thành ARM32 diagnostic**.

### Công việc kế tiếp khi build PASS

Tạo phép thử guest Linux ARM32 hợp pháp trên machine ARM32 sẵn có và xác thực đầu ra serial/exit; sau đó mới sang UART/IRQ/clock của OMAP2420 với board `nokia-n95-diag`. Mỗi bước phải có log và hồi quy v8.

## Quy định dự án

Nghiên cứu giả lập/compatibility; không liên quan xâm nhập, malware hay credential. Không đưa firmware Nokia có bản quyền lên repo. Repository EKA2L1-S60-OMAP2420-iOS hoàn toàn độc lập.
