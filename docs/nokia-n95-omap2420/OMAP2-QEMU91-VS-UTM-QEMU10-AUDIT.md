# Báo cáo kiểm kê QEMU OMAP2420 / Nokia N95 (2026-10-09)

## Kết luận ngắn

**Đã xác định chính xác nguồn dùng để nghiên cứu OMAP2420:** `qemu/qemu` **tag `v9.1.0`**, trước đợt loại bỏ N800/N810 và OMAP2 vào QEMU 9.2. Dự án UTM SE Lite v8 lại được xây dựng từ **`utmapp/qemu` tag `v10.0.12-utm`**, khai báo trong mã UTM pinned `7eadb056ae0f91d979059544d0ddcd2d5a40be92`.

Không hạ cấp toàn bộ QEMU, không thay đổi IPA v8, không trộn mã/ROM Nokia N95 vào baseline.

### Nguồn xác minh

- UTM [`patches/sources`](https://github.com/utmapp/UTM/blob/7eadb056ae0f91d979059544d0ddcd2d5a40be92/patches/sources): `QEMU_SRC=https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz`.
- UTM [`scripts/build_dependencies.sh`](https://github.com/utmapp/UTM/blob/7eadb056ae0f91d979059544d0ddcd2d5a40be92/scripts/build_dependencies.sh#L1046-L1061): iOS TCI ARM64 chỉ biên dịch `aarch64-softmmu,i386-softmmu,ppc-softmmu,ppc64-softmmu,riscv64-softmmu,x86_64-softmmu,m68k-softmmu`, **không có `arm-softmmu`**.
- [QEMU 9.1.0 `hw/arm/nseries.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c) và [`hw/arm/omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) vẫn còn đầy đủ nguồn tham khảo.
- [QEMU 9.1.0 `hw/arm/Kconfig`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/Kconfig) chứa `config NSERIES`; [`hw/arm/meson.build`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/meson.build) đưa `nseries.c` và `omap2.c` vào hệ thống build.
- [`utmapp/qemu@v10.0.12-utm` `hw/arm/Kconfig`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/arm/Kconfig) vẫn có `config OMAP` cho OMAP1, nhưng không còn `NSERIES` hoặc hệ thống OMAP2.
- [QEMU 9.2 removed n800/n810, commit `2406e1e`](https://github.com/qemu/qemu/commit/2406e1e79f76d8a9296105ef99dee7665e2f4fb4) và [CBUS removal `9022e80`](https://github.com/qemu/qemu/commit/9022e80a4235f272799720ee4e9037f6dae7cf0e).
- [QEMU 10 ARM32 CPU definitions](https://github.com/utmapp/qemu/blob/v10.0.12-utm/target/arm/tcg/cpu32.c) vẫn định nghĩa cả `arm1136` và `arm1136-r2` (hai revision khác nhau). **Bộ CPU còn, nhưng chưa được build vào UTM Lite.**

## So sánh tồn tại mã nguồn

Kiểm tra Git tree cho `qemu/qemu@v9.1.0` và `utmapp/qemu@v10.0.12-utm`:

| Nhóm | Nguồn cũ 9.1.0 | Trạng thái bản mới 10.0.12-utm |
|---|---|---|
| Nokia N800/N810 board | `hw/arm/nseries.c` | **Thiếu** |
| TI OMAP2420 SoC | `hw/arm/omap2.c` | **Thiếu** |
| OMAP display subsystem | `hw/display/omap_dss.c` | **Thiếu** |
| Nokia RETU/TAHVO CBUS | `hw/misc/cbus.c`, `include/hw/misc/cbus.h` | **Thiếu** |
| OMAP GPMC/NAND interface | `hw/misc/omap_gpmc.c` | **Thiếu** |
| OMAP L4 interconnect | `hw/misc/omap_l4.c` | **Thiếu** |
| OMAP SDRC | `hw/misc/omap_sdrc.c` | **Thiếu** |
| OMAP TAP | `hw/misc/omap_tap.c` | **Thiếu** |
| OMAP SPI | `hw/ssi/omap_spi.c` | **Thiếu** |
| OMAP GPTIMER | `hw/timer/omap_gptimer.c` | **Thiếu** |
| OMAP sync timer | `hw/timer/omap_synctimer.c` | **Thiếu** |
| OMAP1 core/UART/GPIO/MMC/I2C/interrupt/DMA/clock | Nhiều file khác nhau | **Còn file, cần kiểm tra tương thích API** |
| ARM1136 CPU | `target/arm/tcg/cpu32.c` | **Còn mô hình CPU nhưng chưa có `arm-softmmu` trong sysroot iOS** |

**12 trong 23 tệp có tên OMAP/N-series/CBUS trong bản 9.1.0 không còn ở bản QEMU đang dùng** (có tính `include/hw/...`, danh sách kiểm tra chính xác tại script audit). Chỉ so sánh *đường dẫn tệp*, không có nghĩa 11 tệp còn lại tương thích nhị phân hoặc đã hỗ trợ OMAP2420.

## Đường phụ thuộc và API cần chuyển

- `nseries.c` 9.1.0 khởi tạo `omap2420_mpu_init(machine->ram, machine->cpu_type)`, cấu hình GPIO/CBUS/OneNAND, touchscreen, màn hình, MMC, USB, bộ phận ngoại vi riêng N800/N810, và nạp boot Linux bằng `arm_load_kernel(...)`. **Đây không phải cấu hình bo mạch N95**.
- `omap2.c` 9.1.0 rất lớn (~2716 dòng), dựng ARM1136 CPU, SRAM, interrupt controller, DMA, UART, I2C, GPIO, timer, MMC, các clock/PRCM và bộ nhớ MMIO. Các khai báo và khởi tạo dùng giao diện QEMU thời 9.1; phải audit với QOM/MemoryRegion/IRQ/qdev/clock API của 10.0.12.
- `config NSERIES` 9.1.0 chọn nhiều thiết bị `BLIZZARD`, `ONENAND`, `TSC210X`, `TSC2005`, `LM832X`, `TWL92230`, `TUSB6010`; cần audit thêm tính sẵn có/bị xóa/đổi API. Có thể **không mang nguyên cả mô hình N800/N810** vào N95, chỉ dùng các khối OMAP2 tương thích.
- `config OMAP` và Meson QEMU 10 phải được bổ sung các nguồn OMAP2 cần thiết, *không* chỉ đặt thêm `CONFIG_NSERIES=y` vào Kconfig; file hiện đã mất.
- Phải xây dựng `arm-softmmu` cho nền iOS **TCI/no-JIT**, bảo toàn bảy QEMU frameworks đang liên kết trong UTM SE. Dự kiến còn phải cập nhật đăng ký framework, danh sách CPU/hệ máy và gói IPA/dyld; không thể đơn thuần thay chuỗi `--target-list` trong bản IPA v8 đã đóng gói.
- Tách **SoC OMAP2420** và **board Nokia N95**; chưa có chứng cứ từ mã nguồn QEMU 9.1 rằng firmware Symbian N95 có thể boot trực tiếp bằng `-M n800`/`-M n810`.
- Phải lựa chọn chính xác biến thể firmware N95 (N95 thường/N95 8GB, RM khác nhau) và khảo sát loader/boot chain trước khi tạo máy N95 thật.
- Rà soát giấy phép QEMU/các nguồn mượn từ bản 9.1.0, giữ thông báo bản quyền của từng file, phân phối nguồn sửa đổi và tài liệu giấy phép phù hợp trước khi phát hành bất kỳ IPA nào có mã QEMU được chuyển.

## Thứ tự triển khai đã chọn

1. **Gate A — Automated source audit:** chạy CI xác nhận 2 phiên bản và 12 tệp bị thiếu, ARM1136 CPU vẫn có, TCI sysroot chưa có arm32. **Không sửa IPA**.
2. **Gate B — QEMU ARM32 engine smoke test:** tạo nhánh chuyên biệt để build/test `arm-softmmu` QEMU 10 TCI, dùng guest ARM32 mở được giấy phép, chạy kiểm tra `-M help` / CPU list / UART trước; bảo toàn seven existing QEMU engines.
3. **Gate C — Minimal OMAP2420 board/QOM:** chuyển dần MMIO + UART + clocks + IRQ + SDRAM + boot image theo mô hình SoC tối thiểu, compile/test mỗi bước.
4. **Gate D — N95 board and firmware:** xác định biến thể N95, port cụm ngoại vi thực sự cần, đo boot bằng log UART/MMIO; **chưa hứa giao diện S60**.
5. **Regression gate:** luôn so sánh với [UTM Lite v8 BOOT PASS](../checkpoints/2026-10-08-ALPINE-AARCH64-DEVICE-BOOT-PASS.md).

## Phạm vi an toàn

Giả lập phần cứng, phục vụ nghiên cứu tính tương thích Symbian. Không đính kèm firmware Nokia có bản quyền vào GitHub, không làm việc về khai thác, xâm nhập, credential hay persistence.
