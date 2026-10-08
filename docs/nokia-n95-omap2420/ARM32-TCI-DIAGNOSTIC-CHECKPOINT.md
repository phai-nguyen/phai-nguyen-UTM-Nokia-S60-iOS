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

## CI incident — lượt ARM32 đầu tiên FAIL, sửa pkgconf (2026-10-09 ICT)

- [Run #37855683131](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37855683131) **FAIL** ở bước `Compile qemu-arm-softmmu and inspect experimental framework`; `BUILD-STATUS.txt`: `LAST_STAGE=configure-arm-softmmu`. Các bước checkout UTM, tải sysroot, cài công cụ, giải nén sysroot đều PASS. Artifact log: [#11584356313](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37855683131/artifacts/11584356313).
- **Lỗi chặn đầu tiên** tại `meson.build:1064`: `Dependency lookup for glib-2.0 with method 'pkg-config' failed: Pkg-config for machine host machine not found`. Log Meson xác nhận có tìm thấy `.../sysroot-ios-tci-arm64/host/bin/pkg-config` nhưng không chạy được; **không phải do thiếu mã OMAP2**. Các thăm dò Xen thiếu thư viện chỉ là kết quả feature probing, chưa phải lỗi dừng chính.
- Root cause thao tác: script từng đưa `$PREFIX/host/bin` vào đầu `PATH` rồi lấy `command -v pkg-config`, khiến Meson dùng bản `pkg-config` không chạy được trong sysroot đã tải xuống.
- **Đã sửa** trong commit [`a2005a8e51380a36382cbee96d48b0d8415c9bb7`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/a2005a8e51380a36382cbee96d48b0d8415c9bb7): chỉ định `$(brew --prefix pkgconf)/bin/pkgconf` (tool macOS runner), kiểm tra `glib-2.0` qua `--modversion/--cflags/--libs` trước configure; tiếp tục đọc metadata `.pc` của sysroot iOS.
- [Run **#37856375355**](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37856375355) tự kích hoạt sau commit sửa lỗi. **Khi ghi checkpoint: đang chạy**, chưa có compile PASS/FAIL mới, không khẳng định phát hành IPA Nokia.
- Baseline v8 và 7 framework đã kiểm chứng trên iPhone **không thay đổi**. Bản ARM32 chỉ là nghiên cứu riêng, không có firmware N95 và không thử trên thiết bị.

