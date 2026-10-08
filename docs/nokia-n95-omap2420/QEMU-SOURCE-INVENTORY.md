# QEMU SOURCE INVENTORY — Nokia N95 / OMAP2420 / ARM32

**Ngày:** 2026-10-09 (ICT)  
**Nhánh chỉ dùng nghiên cứu:** `research/n95-omap2420-arm32`  
**Trạng thái:** SOURCE REVIEW / DESIGN ONLY — **chưa sửa engine, chưa biên dịch ARM32, chưa có board N95 hay boot firmware**.  
**Nguồn kiểm tra:** GitHub source blob tại ref/tag xác định; không phải phép thử chạy QEMU 10 trên iPhone.

## 0. Ranh giới dự án và baseline bất biến

- Repository duy nhất của nghiên cứu này: [phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS).
- **KHÔNG** đưa mã/nhánh/trạng thái từ repository độc lập `phai-nguyen/EKA2L1-S60-OMAP2420-iOS` vào đây.
- Baseline iPhone: **Nokia UTM SE Lite v8 — Tiếng Việt**, [Actions #37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413), [IPA artifact #11554159956](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413/artifacts/11554159956), SHA256 `671535ffec7f866688537ee86db8c5eb53aeccbd78f3fc517dcb9dcf871e6caa`.
- USER DEVICE PASS đã có: iOS 18.7 / ESign, UI Việt hóa một phần, UIDocumentPicker UIKit + sandbox-copy ISO, lưu VM, Alpine 3.24.2 aarch64 với serial console, 4 GiB `vda`, `sr0`, DHCP 10.0.2.15, default NAT 10.0.2.2, DNS + HTTP, poweroff và khởi động lại. **Chưa test ghi/persistence ổ đĩa**.
- iOS tối thiểu 15.0, TCI/no-JIT. **Không đụng** `feat/vi-localization-lite-v8`, PR #10, IPA đã được kiểm thử, 7 frameworks, hay firmware Nokia.
- Nguồn xác nhận: [HANDOFF 2026-10-09](../handoff/NEWCHAT-UTM-N95-OMAP2420-2026-10-09.md), [STARTUP-PLAN](STARTUP-PLAN.md), [checkpoint device](../checkpoints/2026-10-08-ALPINE-AARCH64-DEVICE-BOOT-PASS.md).

## 1. Khóa phiên bản hiện đại — thông tin đã xác minh

| Đầu mục | Giá trị / bằng chứng | Kết luận |
|---|---|---|
| UTM frontend pinned | [utmapp/UTM@`7eadb056ae0f91d979059544d0ddcd2d5a40be92`](https://github.com/utmapp/UTM/tree/7eadb056ae0f91d979059544d0ddcd2d5a40be92) | Không thay đổi baseline |
| QEMU nguồn do pinned UTM **khai báo** | [`patches/sources` cùng ref](https://github.com/utmapp/UTM/blob/7eadb056ae0f91d979059544d0ddcd2d5a40be92/patches/sources): `QEMU_SRC=https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz` | **UTM QEMU v10.0.12-utm** là mốc port phù hợp |
| Script build | [`scripts/build_dependencies.sh` cùng ref](https://github.com/utmapp/UTM/blob/7eadb056ae0f91d979059544d0ddcd2d5a40be92/scripts/build_dependencies.sh): source `patches/sources`, `-q` override local QEMU source, `--enable-shared-lib` | Phải bảo toàn UTM fork và shared-library packaging |
| Sysroot iOS TCI đã dùng | [UTM Actions #36090554968](https://github.com/utmapp/UTM/actions/runs/36090554968), artifact `Sysroot-ios-tci-arm64` | Đã dùng trong build v8. **Chưa đối chiếu trực tiếp hash/metadata bên trong binary của sysroot** với tarball `v10.0.12-utm`; không tuyên bố binary identity đã xác nhận |
| `ios-tci` ARM64 target list trong script pinned | `--enable-tcg-threaded-interpreter --target-list=aarch64-softmmu,i386-softmmu,ppc-softmmu,ppc64-softmmu,riscv64-softmmu,x86_64-softmmu,m68k-softmmu` | **Không chứa `arm-softmmu`** |
| Lite v8 framework packaging | [`scripts/build_dyld_safe_lite.sh`](../../scripts/build_dyld_safe_lite.sh) yêu cầu 7 frameworks: aarch64/i386/x86_64/ppc/ppc64/riscv64/m68k | Việc frontend liệt kê ARM không tạo ra ARM32 emulator; thêm `arm-softmmu` sẽ cần build, đóng gói, tích hợp launch/config và ký đúng dyld |

## 2. Nguồn lịch sử — mốc tồn tại và mốc loại bỏ

**Nguồn chính ưu tiên để khảo sát:** QEMU upstream **v9.1.0** (mã OMAP2 đã sử dụng một số API QOM, SysBus và MemoryRegion, gần hiện đại hơn QEMU 1.x). Không nhầm `nseries.c` với board N95.

| Mốc | `hw/arm/omap2.c` | `hw/arm/nseries.c` | Trạng thái |
|---|---|---|---|
| [QEMU v7.2.0](https://github.com/qemu/qemu/tree/v7.2.0) | [có](https://github.com/qemu/qemu/blob/v7.2.0/hw/arm/omap2.c) | [có](https://github.com/qemu/qemu/blob/v7.2.0/hw/arm/nseries.c) | cũ, không cần ưu tiên |
| [QEMU v8.2.0](https://github.com/qemu/qemu/tree/v8.2.0) | [có](https://github.com/qemu/qemu/blob/v8.2.0/hw/arm/omap2.c) | [có](https://github.com/qemu/qemu/blob/v8.2.0/hw/arm/nseries.c) | tham khảo |
| [QEMU v9.0.0](https://github.com/qemu/qemu/tree/v9.0.0) | [có](https://github.com/qemu/qemu/blob/v9.0.0/hw/arm/omap2.c) | [có](https://github.com/qemu/qemu/blob/v9.0.0/hw/arm/nseries.c) | board đã deprecated |
| **[QEMU v9.1.0](https://github.com/qemu/qemu/tree/v9.1.0)** | **[có; blob `d9683276…`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c)** | **[có; blob `35364312…`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c)** | **Tag cuối xác minh có cả hai tệp; chọn làm nguồn port** |
| [QEMU v9.2.0](https://github.com/qemu/qemu/tree/v9.2.0) | không còn ở `hw/arm/omap2.c` | không còn ở `hw/arm/nseries.c` | Loại bỏ OMAP2/n800/n810 |
| **[UTM QEMU v10.0.12-utm](https://github.com/utmapp/qemu/tree/v10.0.12-utm)** | **không còn** | **không còn** | Cần port/thiết kế lại; `hw/arm/meson.build` không liệt kê |

**Commit xóa chính xác**:
- [`2406e1e79f76d8a9296105ef99dee7665e2f4fb4`](https://github.com/qemu/qemu/commit/2406e1e79f76d8a9296105ef99dee7665e2f4fb4) — *hw/arm: Remove 'n800' and 'n810' machines*, xóa `hw/arm/nseries.c`, loại cấu hình/build board.
- [`5a5425998a039e3e80400dc81ecf4178d0442abe`](https://github.com/qemu/qemu/commit/5a5425998a039e3e80400dc81ecf4178d0442abe) — *hw/arm: Remove omap2.c*, xóa file SoC và đăng ký Meson, giảm `omap.h`.
- QEMU upstream [Removed features / Arm machines (9.2)](https://www.qemu.org/docs/master/about/removed-features.html) xác nhận nguyên nhân: SoC OMAP2/PXA2xx cũ thiếu bảo trì, cản trở hiện đại hóa các API, không có người duy trì. Đây là loại bỏ có chủ đích, **không phải chỉ là đổi đường dẫn file**.

**Hệ máy có thật trong `nseries.c` v9.1**: `n800` = Nokia N800 **RX-34** và `n810` = Nokia N810 **RX-44**, cùng SoC OMAP2420, CPU mặc định `arm1136-r2`, RAM mặc định 128 MiB; đây là **Nokia Internet Tablet / Linux Maemo, không phải N95 chạy Symbian S60**. Hàm board `n8x0_init()` gọi `omap2420_mpu_init()` và tạo nhiều phần cứng riêng N800/N810. Thấy rõ ở [`nseries.c` cuối file](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c#L1277-L1474).

## 3. So sánh thành phần OMAP2 v9.1 vs UTM/QEMU 10

Đối chiếu trực tiếp với code fork [utmapp/qemu v10.0.12-utm](https://github.com/utmapp/qemu/tree/v10.0.12-utm). "Còn file" **không đồng nghĩa còn phần logic OMAP2**: nhiều file bị cắt xuống phần OMAP1.

| Thành phần | Nguồn QEMU 9.1 | Fork UTM 10.0.12-utm | Việc cần làm |
|---|---|---|---|
| SoC OMAP2420 core, PRCM, bus L4, STI, phối hợp MMIO | [`hw/arm/omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) | **Đã xóa** | Port chọn lọc/thiết kế module mới, không copy nguyên tệp |
| Board N800/N810, boot tags, ngoại vi | [`hw/arm/nseries.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c) | **Đã xóa** | Dùng làm ví dụ cấu trúc board/boot, **không đổi tên thành `nokia-n95`** |
| Định nghĩa OMAP2 / IRQ / hàm init | [`include/hw/arm/omap.h`](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h) | [File vẫn có](https://github.com/utmapp/qemu/blob/v10.0.12-utm/include/hw/arm/omap.h), nhưng **đã loại nhiều định nghĩa OMAP2** (vd `omap2420_mpu_init`, `TYPE_OMAP2_GPIO`) | Tạo header riêng có chọn lọc, tránh xung đột OMAP1 |
| UART | [`hw/char/omap_uart.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/char/omap_uart.c) có OMAP2 register logic | [còn file, nhưng chỉ 66 dòng](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/char/omap_uart.c), không có OMAP2 register cases | Port UART2 OMAP và ánh xạ chardev/IRQ theo API v10 |
| INTC | [`hw/intc/omap_intc.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/intc/omap_intc.c) có `omap2_inth_*` | [còn file, ~407 dòng](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/intc/omap_intc.c), chỉ quan sát phần OMAP1 còn lại | Thêm OMAP2 INTC model/IRQ input/output, không nhầm với OMAP1 |
| GPTimer | [`hw/timer/omap_gptimer.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/timer/omap_gptimer.c) | **File đã xóa** | Port timer + QEMUClock/PTimer + IRQ |
| Clock tree | [`hw/misc/omap_clk.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/misc/omap_clk.c), hỗ trợ 242X | [còn file, ~745 dòng](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/misc/omap_clk.c), bỏ `CLOCK_IN_OMAP242X` | Khôi phục nhánh clock 2420 hoặc module riêng, không làm hỏng OMAP1 |
| L4 target agents | [`hw/misc/omap_l4.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/misc/omap_l4.c) | **File đã xóa** | Port hoặc thay bằng MemoryRegion/sysbus mappings |
| DMA | [`hw/dma/omap_dma.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/dma/omap_dma.c) chứa logic DMA OMAP2 | [còn file, ngắn hơn](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/dma/omap_dma.c) | OMAP DMA4 đã bị loại; *defer* cho prototype UART |
| MMC/SD | [`hw/sd/omap_mmc.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/sd/omap_mmc.c) | [còn file](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/sd/omap_mmc.c) | Kiểm tra cụ thể OMAP2 MMC methods, *defer* |
| Meson/Kconfig | [Meson 9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/meson.build), [Kconfig 9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/Kconfig): `CONFIG_NSERIES`, `CONFIG_OMAP`, đăng ký `omap2.c` | [Meson fork 10](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/arm/meson.build), [Kconfig fork 10](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/arm/Kconfig): chỉ `omap1.c` với `CONFIG_OMAP`, **không có `CONFIG_NSERIES`** | Tạo `CONFIG_NOKIA_N95` / `CONFIG_OMAP2420` độc lập, không gắn model mới tùy tiện vào OMAP1 |

**Chú ý:** nhiều phụ thuộc khác bị xóa/thay đổi trong chuỗi commit QEMU 9.2: GPIO OMAP2, SDRC, GPMC, sync timer, SPI, OneNAND, display, USB/TUSB, DMA4. Việc khôi phục `omap2.c` đơn lẻ **không thể link thành công**. Đọc [QEMU arm removal pull merge](https://github.com/qemu/qemu/commit/062cfce8d4c077800d252b84c65da8a2dd03fd6f) và từng commit xóa để nhận diện các API/phụ thuộc trước khi port.

## 4. Đối chiếu kiến trúc / API và cạm bẫy

| Hạng mục | Căn cứ trong 9.1 | Kỳ vọng khi port lên fork 10 |
|---|---|---|
| CPU ARM32 | `n800_class_init`/`n810_class_init` dùng `ARM_CPU_TYPE_NAME("arm1136-r2")`; `omap2420_mpu_init` dùng `cpu_create(cpu_type)` | Kiểm tra CPU type có trong build `arm-softmmu` của fork 10, TCI ARMv6 và MMU; **không** dùng CPU AArch64 của Alpine làm đại diện |
| Board/QOM | Đã dùng `MachineClass`, `TypeInfo`, `TYPE_MACHINE`, `machine->ram`; ngoại vi trộn QOM/SysBus với hàm C ad-hoc | Tạo machine riêng `nokia-n95-diag` và SoC/Device phù hợp; kiểm tra API/chữ ký hàm của fork v10, không bê board N800 |
| Memory map | 9.1: `OMAP2_SRAM_BASE=0x40200000`, `OMAP2_L4_BASE=0x48000000`, `OMAP2_Q2_BASE=0x80000000`, SRAM 242X `0x000a0000`; INTC `0x480fe000` | Đây là **map tham khảo của code emulation 9.1**, chưa xác nhận đầy đủ cho đúng board/bootchain N95. Tránh trùng MemoryRegion; kiểm thử vùng reset ROM/SRAM/SDRAM riêng |
| IRQ | `qdev_new("omap2-intc")`, `sysbus_realize_and_unref`, `sysbus_connect_irq`, `qdev_get_gpio_in`; IRQ/FIQ nối CPU | Restore OMAP2 INTC implementation; xác thực IRQ indexes và reset behavior trên fork 10 |
| UART | `omap2_uart_init` đi qua L4, clock `uart*_fclk/iclk`, DMA requests, `serial_hd()`; UART1 IRQ `OMAP_INT_24XX_UART1_IRQ=72` | Prototype đường serial TX trước, sau đó RX/IRQ; nối `-serial stdio`/chardev tương đương; không fake UART bằng PL011 của `virt` |
| Timer/clock | `omap_clk_init`, `omap_gp_timer_init`, `omap_synctimer_init`, PRCM | Dùng API timer/clock của fork 10, xử lý reset/gating; UART POC có thể dùng nhịp cố định **chỉ trong diagnostic harness, không được giả là mô hình firmware-accurate** |
| Boot | `n8x0_init` hỗ trợ `arm_load_kernel()` và nhánh `secondary.bin` kiểu NOLO, địa chỉ N800/N810 cố định, N-series ATAG | Là **ví dụ cho Linux N800/N810**; firmware Nokia N95/Symbian có bootchain, format và board IDs riêng chưa khảo sát. Không nạp tùy tiện NOLO N800 vào N95 |
| Công cụ build | QEMU 9.1 có Meson/Kconfig; UTM 10 có patch shared-lib/iOS và QAPI/frontend riêng | Port theo từng module vào **UTM fork phù hợp**, cấu hình Meson, Kconfig, target list, config frontend, dynamic framework và dyld |

Dù OMAP2 v9.1 đã dùng một phần API tương đối hiện đại như `MemoryRegionOps` và `SysBusDevice`, **không thể tuyên bố chuyển mã không tốn công**, vì QEMU 9.2 còn xóa hàng loạt thiết bị và interfaces liên đới.

## 5. Bản quyền & dữ liệu

- Header [`omap2.c` v9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) và [`nseries.c` v9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c) ghi bản quyền Nokia Corporation và điều khoản **GNU GPL, version 2 hoặc version 3 (theo header tệp)**. Khi sao chép/biên dịch/phân phối phải bảo tồn notice, đối chiếu license từng tệp và nghĩa vụ tương ứng; không ngầm coi toàn bộ tệp OMAP cũ có cùng điều khoản.
- Không đưa firmware/ROM/bootloader Nokia không có quyền phân phối lên GitHub hoặc IPA. Chỉ dùng firmware do người thử nghiệm có quyền sử dụng cho test nội bộ.
- Phạm vi: nghiên cứu tương thích phần cứng / giả lập Symbian; không liên quan xâm nhập, malware, persistence, credential hay khai thác.

## 6. Kế hoạch prototype theo gate (CHƯA TRIỂN KHAI)

### Gate A — ARM32 engine độc lập; **sau inventory**

1. Tạo nhánh triển khai riêng từ nhánh research đã chốt báo cáo; **không** sửa `feat/vi-localization-lite-v8` và không merge PR #10.
2. Pinned `utmapp/qemu v10.0.12-utm`; workflow Actions `ios-tci-arm64` test thêm **`arm-softmmu`** trong `--target-list`, giữ nguyên bảy target cũ, lưu `configure`/Meson output, compiler logs, architecture/file/signature/dependency inventory, PASS/FAIL.
3. Xác minh framework/shared library ARM32, tất cả `@rpath`/strong-links, ký bằng ESign và frontend launch selection. Không cho phép đóng gói IPA nếu dyld closure thiếu.
4. Test `qemu-system-arm` với guest ARM32 nhỏ, được phép chia sẻ (ví dụ kernel+initramfs Linux trên machine ARM32 đang có) và chứng minh serial output/exit. Đây **không** phải Nokia boot PASS.
5. Hồi quy 7 frameworks, import ISO, Save, Alpine ARM64 boot/network/poweroff/restart theo checkpoint v8.

### Gate B — OMAP2420 minimal diagnostic SoC (sau Gate A)

- Tạo `nokia-n95-diag` **không dùng firmware đóng gói**; khởi đầu CPU `arm1136-r2`, SRAM/SDRAM map, reset vector/diagnostic image, MMIO logging.
- Port có thứ tự: (i) clock/reset tối thiểu, (ii) UART1 MMIO + serial TX; (iii) OMAP2 INTC + UART IRQ; (iv) timer/synctimer/PRCM; (v) boot path; (vi) DMA, MMC, GPMC, GPIO, I²C/SPI, display v.v. khi có bằng chứng firmware cần.
- Viết phép thử read/write register UART, IRQ raise/ack, timer tick, bad MMIO, overlap detection, reset/reboot. Không xem UART tự in một chuỗi là firmware Symbian boot.
- Đối chiếu board N95 khác N800/N810: GPIO, flash/ROM, địa chỉ khởi động, SDRAM, modem/peripheral, interrupt routing và định dạng firmware; **không** dùng ATAG/NOLO N800 làm N95 mặc định.

### Gate C — kiểm thử Nokia firmware có quyền sử dụng

- Khi ARM32 + SoC + board được mô hình hóa, nạp firmware N95 do người dùng có quyền sử dụng, lưu log UART/MMIO/CPU exception/restart và công khai **chỉ log không chứa dữ liệu riêng tư/copyright**.
- Báo cáo mức tiến triển bằng bằng chứng thực nghiệm, không khẳng định có Home S60 nếu chưa boot và hiển thị thực tế trên iPhone.

## 7. Các vấn đề còn mở, không suy đoán

- Cần kiểm tra **nội dung nhị phân sysroot** từ Actions #36090554968 (`qemu --version`/build-id/manifest/hash) trước khi kết luận chính xác về phiên bản QEMU đã liên kết v8; `patches/sources` là khai báo source ở pinned UTM, chưa phải SHA xác thực mọi binary.
- Chưa biết `arm-softmmu` trong fork 10 có build/TCI/link iOS sạch; **chưa chạy compiler hoặc unit test**.
- Chưa kiểm tra đầy đủ ABI bridge/frontend QAPI cho engine mới hay kiểm thử ESign với 8 frameworks.
- Chưa xác minh board N95-specific register map, reset ROM và firmware format bằng tài liệu/sơ đồ đáng tin cậy.
- Chưa import bất kỳ mã OMAP2 nào vào UTM; **đây là kiểm kê nguồn và thiết kế cổng chuyển mã, không phải implementation**.

## 8. Kết luận / Quyết định

1. **Nguồn port khuyến nghị:** QEMU upstream `v9.1.0` cho `omap2.c`, `nseries.c`, kèm các module phụ thuộc trước khi bị xóa bởi QEMU 9.2.
2. **Target API/build:** `utmapp/qemu v10.0.12-utm` theo `QEMU_SRC` của pinned UTM, giữ QEMU fork của UTM và workflow iOS TCI/no-JIT.
3. **Thứ tự ưu tiên:** ARM32 engine với Linux nhỏ **trước**; sau đó OMAP2420 MMIO/UART/IRQ/boot minimal; cuối cùng N95 board/firmware.
4. **Không sửa baseline Lite v8**, không trộn EKA2L1, không build hoặc tuyên bố có IPA Nokia N95 cho tới khi các gate có log PASS.

**Inventory complete at source-review level.** Các bước build, refactor, test và compatibility firmware vẫn **PENDING**.
