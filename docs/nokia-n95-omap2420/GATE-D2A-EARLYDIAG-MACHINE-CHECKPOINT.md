# Gate D2a — Mô hình ARM1136 / OMAP2420 SRAM+SDRAM tối giản

**Ngày:** 2026-10-09 (ICT)  
**Nhánh:** `research/n95-omap2420-gate-d2a`  
**Giới hạn:** Đây là bo mạch `omap2420-earlydiag` **chỉ thử CPU + memory map + ELF**. Không có Nokia N95 ROM, Symbian, L4, UART, INTC, clock/timer, GPMC hoặc màn hình. Bản UTM iPhone v8/v9 vẫn giữ nguyên.

## Đã xác minh trước khi bắt đầu D2a

1. UTM SE Lite v8: Alpine ARM64 UI/picker/disk/network/reboot DEVICE PASS.
2. UTM SE Lite v9: Alpine ARMv7 (`armv7l`) boot, lệnh console, và shutdown/restart DEVICE PASS — [checkpoint v9](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/feat/arm32-linux-lite-v9/docs/nokia-n95-omap2420/UTM-LITE-V9-ARM32-DEVICE-TEST.md).
3. Gate D1: ARM1136/ARMv6 trong QEMU 10 dùng máy KZM i.MX31 với UART thật của i.MX31 PASS trên máy Linux GitHub — [run #37897640183](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37897640183), [checkpoint D1](../nokia-n95-omap2420/GATE-D1-ARM1136-KZM-CPU-UART-CHECKPOINT.md). **KZM không phải OMAP2420.**

## Mã nguồn mới trên nhánh D2a

- [`tests/omap2420/omap2420_diag_d2a.c`](../../tests/omap2420/omap2420_diag_d2a.c): đăng ký machine `omap2420-earlydiag` trong fork QEMU 10.0.12-utm, đúng CPU ARM1136, **SRAM 0x40200000 (0xA0000 bytes)** và **SDRAM 0x80000000 (128 MiB mặc định)**; thực hiện `arm_load_kernel` với ELF baremetal và chặn `-m` không hợp lệ. Không có fake UART hoặc chipset ngoài map tối thiểu.
- [`tests/omap2420/arm1136_d2a_memory.S`](../../tests/omap2420/arm1136_d2a_memory.S) và [`arm1136_d2a_memory.ld`](../../tests/omap2420/arm1136_d2a_memory.ld): ELF ARMv6 entry `0x80010000`, ghi/đọc ô đầu và ô cuối SRAM/SDRAM, kiểm lệnh ARMv6 `REV`. Marker in qua **semihosting SYS_WRITE0**. Đây không phải UART OMAP2; test UART thuộc D2b.
- [`scripts/test_omap2420_earlydiag_gate_d2a.sh`](../../scripts/test_omap2420_earlydiag_gate_d2a.sh): tải nguồn có pin `utmapp/qemu@v10.0.12-utm`; chỉ vá cây source QEMU **tạm trên Linux CI**, thêm Kconfig/Meson cho machine mới, biên dịch `arm-softmmu`, chạy ELF ARMv6, kiểm kernel ELF entry/cả vùng RAM, kiểm guard từ chối RAM 256 MiB, xuất source SHA256, logs và payload.
- [`.github/workflows/17-n95-omap2420-gate-d2a.yml`](../../.github/workflows/17-n95-omap2420-gate-d2a.yml): workflow Ubuntu độc lập, không ảnh hưởng ipa v8/v9.

**Run D2a:** [GitHub Actions #37903814895](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37903814895).

Các marker cần thấy khi runtime thành công:

```text
D2A_OMAP2420_SRAM=PASS
D2A_OMAP2420_SDRAM=PASS
D2A_ARM1136_REV=PASS
D2A_BOOT_ELF=PASS
D2A_UART=NOT_IMPLEMENTED
QEMU_EXIT_CODE=0
D2A_RAM_BOUNDARY_GUARD=PASS
GATE_D2A_STATUS=PASS
```

**Không được tự ghi PASS** trước khi Actions hoàn tất và log có đầy đủ marker. D2a chỉ chứng minh độ đúng của map bộ nhớ *tham chiếu QEMU 9.1* trên machine độc lập; không đảm bảo tương thích firmware Nokia N95.

## Nguồn kỹ thuật và bản quyền

- [QEMU 9.1.0 `omap.h`](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h): vùng OMAP2 SRAM `0x40200000` và SDRAM `0x80000000`.
- [QEMU 9.1.0 `omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c): SoC và memory map tham chiếu cho OMAP2420.
- [UTM QEMU 10.0.12 `cpu32.c`](https://github.com/utmapp/qemu/blob/v10.0.12-utm/target/arm/tcg/cpu32.c): mô hình ARM1136.
- Mã machine riêng dùng SPDX **GPL-2.0-or-later** tương thích QEMU; đoạn ELF chẩn đoán do dự án viết, SPDX MIT. Không phân phối Nokia firmware và không đưa code từ repo EKA2L1 vào.
- **Scope/Safety:** nghiên cứu khả năng tương thích trình giả lập; không liên quan exploit, credential, persistence, malware hoặc tấn công mạng.

## Kế hoạch kế tiếp sau D2a PASS

Gate D2b: UART OMAP2420 thật tại `0x4806A000` (UART1; UART2/3 `0x4806C000` / `0x4806E000`) theo map QEMU 9.1; port thiết bị với thanh ghi, reset, TX/RX/IRQ, sau đó log qua UART. D2c: OMAP2 INTC/clock/timer; D2d: qtest/stability; D2e: iOS TCI IPA **riêng**, không ghi đè v8/v9. Không gọi machine `nokia-n95` trước khi có bo mạch phù hợp.
