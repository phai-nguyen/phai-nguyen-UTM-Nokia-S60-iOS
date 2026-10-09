# Gate D1: ARM1136 CPU / ARMv6 / UART — research checkpoint

**Ngày:** 2026-10-09 (ICT)  
**Repo:** `phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS`  
**Nhánh riêng:** `research/n95-arm1136-gate-d1`  
**Phạm vi:** Kiểm thử CPU ARMv6 và UART trên hệ máy *tham chiếu* đã có sẵn trong QEMU; không giả mạo hỗ trợ Nokia N95.

## 1. Baseline đã được người dùng test trên iPhone

- UTM SE Lite **v8** chạy Alpine Linux ARM64, UI Việt hóa, picker iOS, ổ đĩa, NAT và reboot PASS; không sửa baseline.
- UTM SE Lite **v9** [Actions #37890960534](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534) đóng đủ 8 framework ARM32 và 7 engine trước, và đã **boot Linux Alpine ARM32 trong máy ảo trên iPhone**.
- Thiết bị báo `ALPINE_ARM32_BOOT=PASS`, `ALPINE_ARCH=armv7l`, `ALPINE_RELEASE=3.24.2`, `ALPINE_ARM32_SMOKE_PASS`; thao tác `uname -m`, `cat /etc/alpine-release`, terminal/bàn phím, và tắt + khởi động lại được **người dùng xác nhận PASS**. Mốc đã được ghi trên [branch v9 checkpoint](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/feat/arm32-linux-lite-v9/docs/nokia-n95-omap2420/UTM-LITE-V9-ARM32-DEVICE-TEST.md).
- Lỗi `-append` của v9 đã được chữa tạm bằng cách thêm đôi ngoặc kép cho kernel cmdline. Bản v9.1 đã BUILD PASS để xử lý runtime tự động; kết quả thiết bị PASS trên là **v9 với workaround**, chưa xác nhận v9.1 DEVICE PASS.
- Những kết quả v9 trên chỉ là ARMv7 **Cortex-A15 / machine `virt`**, chưa phải ARM1136 hay OMAP2.

## 2. Nguồn kiểm tra và CPU tương thích

QEMU đang pin [`utmapp/qemu@v10.0.12-utm`](https://github.com/utmapp/qemu/tree/v10.0.12-utm). Nguồn lịch sử [`qemu/qemu@v9.1.0`](https://github.com/qemu/qemu/tree/v9.1.0) còn hệ thống OMAP2420 cũ (tham khảo mô hình Nokia N800/N810, **không** phải N95):

- [`target/arm/tcg/cpu32.c`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/target/arm/tcg/cpu32.c): hai CPU `arm1136` và `arm1136-r2`, revision có khác biệt; không đánh đồng.
- [`hw/arm/kzm.c`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/arm/kzm.c): `kzm` = **Kyoto Microcomputer KZM-ARM11-01 / Freescale i.MX31**, dùng ARM1136; hỗ trợ QEMU 10.
- [`hw/arm/fsl-imx31.c`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/arm/fsl-imx31.c): tạo CPU `ARM_CPU_TYPE_NAME("arm1136")`.
- [`include/hw/arm/fsl-imx31.h`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/include/hw/arm/fsl-imx31.h): `UART1_BASE=0x43F90000` i.MX31.
- [`hw/char/imx_serial.c`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/hw/char/imx_serial.c): `UTXD` tại offset `0x40`, có thể ghi ký tự ra chardev `-serial stdio`. **Không phải thanh ghi UART OMAP2420**.
- [`hw/arm/omap2.c` 9.1.0](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) và [`nseries.c` 9.1.0](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/nseries.c) là nguồn kiến trúc tham khảo, đã bị xóa khỏi QEMU 10 fork. Không đưa trực tiếp hoặc gắn nhãn `-M n95` trước khi mô hình có thiết bị thật.

## 3. Gate D1: Linux-host QEMU10 ARM1136 ARMv6 thực thi

Các file mới (chỉ trên nhánh nghiên cứu):

- [`tests/arm1136/kzm_armv6_uart.S`](../../tests/arm1136/kzm_armv6_uart.S): ELF khởi động tại `0x80010000`, ghi thông điệp tới MMIO i.MX31 UART1 tại `0x43F90040`, thực thi một lệnh ARMv6 `REV` và so sánh kết quả byte-swap để phát hiện giả lập sai, rồi semihosting `SYS_EXIT` kết thúc QEMU.
- [`tests/arm1136/kzm_armv6.ld`](../../tests/arm1136/kzm_armv6.ld): linker layout máy KZM, **không dùng ROM Nokia**.
- [`scripts/test_arm1136_qemu10_kzm_gate_d1.sh`](../../scripts/test_arm1136_qemu10_kzm_gate_d1.sh): fetch source chính xác QEMU `v10.0.12-utm`, kiểm source KZM/ARM1136, build native `arm-softmmu` ở GitHub Linux runner, cross assemble bare-metal ARMv6, chạy machine `-M kzm -cpu arm1136`, kiểm marker UART/ARMv6 và exit code.
- [`.github/workflows/16-n95-arm1136-gate-d1.yml`](../../.github/workflows/16-n95-arm1136-gate-d1.yml): xuất artifact log đầy đủ dù lỗi, ELF thử nghiệm độc lập.

[**GitHub Actions Gate D1 #37897640183**](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37897640183) — *status cần xác minh từ run, không coi build PASS khi chưa có log*.

Marker mong đợi:

```text
ARM1136_KZM_UART_MMIO=PASS
ARM1136_ARMV6_REV_INSTRUCTION=PASS
ARM1136_BAREMETAL_BOOT=PASS
```

Điều kiện: source đúng pin, `-M help` có KZM, `-cpu help` có ARM1136, chạy chương trình ARMv6, UART trên QEMU Linux, và process thoát 0. Không tuyên bố chipset Nokia hay iPhone ARM1136 PASS từ kết quả này.

## 4. Các bước tiếp theo

1. **Gate D1 PASS** trên QEMU Linux host rồi xem source nào có thể dùng để thực thi ARM1136 trong bản IPA iOS thử nghiệm độc lập; không thay thế Linux ARMv7 trong v9 bằng kernel ARMv7 trên ARMv6 (khác ISA).
2. **Gate D2: OMAP2420 minimal diagnostic**, nghiên cứu memory map và tương thích API QEMU 10, tạo SoC/board độc lập theo từng cụm **SRAM + SDRAM + IRQ + clock + UART**, trước cả loader Nokia. Dùng QEMU 9.1 làm reference (N800/N810 không đại diện N95).
3. **Gate D3: Nokia N95 board model** chỉ khi D2 có bài kiểm tra MMIO/IRQ/timer nghiêm túc, và có dữ liệu phù hợp phiên bản firmware N95 từ người dùng; không phân phối firmware có bản quyền.

## Scope / Safety clarification

Nghiên cứu giả lập phần cứng để chạy hệ điều hành cũ; không liên quan đến khai thác, xâm nhập, malware, credential, persistence hoặc tấn công mạng. Không giả lập nguồn ROM Nokia trong GitHub. Giữ nguyên UTM SE Lite v8/v9, app Việt hóa, ESign, iOS 15.0, TCI/no-JIT.
