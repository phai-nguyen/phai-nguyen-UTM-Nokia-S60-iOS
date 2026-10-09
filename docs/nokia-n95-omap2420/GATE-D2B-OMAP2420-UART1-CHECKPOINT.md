# Gate D2b — OMAP2420 UART1 MMIO / ARM1136 / QEMU10

**Ngày:** 2026-10-09 ICT  
**Nhánh:** `research/n95-omap2420-gate-d2b`  
**Phạm vi:** chạy **UART1 thật qua MemoryRegion/serial-mm của QEMU** theo sơ đồ tham khảo OMAP2420. Không nạp firmware Nokia, không chạy Symbian, không thay bản IPA UTM v8/v9.

## Baseline đã chứng minh

- **Gate C2 iPhone ARM32:** UTM SE Lite v9 với `-append` sửa bằng dấu ngoặc kép, Alpine Linux ARMv7 `armv7l`, lệnh shell và tắt/mở lại PASS. [Checkpoint v9](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/feat/arm32-linux-lite-v9/docs/nokia-n95-omap2420/UTM-LITE-V9-ARM32-DEVICE-TEST.md).
- **Gate D1 ARM1136:** QEMU fork v10.0.12-utm, máy **KZM/i.MX31**, chạy ARMv6 + UART i.MX31 trên Ubuntu PASS. Đây không phải OMAP2420.
- **Gate D2a ARM1136 với OMAP2 memory map:** QEMU 10 đã chạy machine `omap2420-earlydiag`/ELF ARMv6, đọc/ghi SRAM `0x40200000`.. `0x4029FFFF`, SDRAM `0x80000000`.. `0x87FFFFFF`, `REV`, exit 0, RAM guard PASS ở [run #37904307368](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37904307368).
- Nguyên mẫu nghiên cứu QEMU 9.1.0 có mã [`hw/arm/omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c), [`hw/char/omap_uart.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/char/omap_uart.c), [`include/hw/arm/omap.h`](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h). Hỗ trợ này đã bị xóa/thu gọn trong UTM/QEMU 10 fork.

## Thực hiện Gate D2b

Các file mới:

- [`tests/omap2420/omap2420_diag_d2b.c`](../../tests/omap2420/omap2420_diag_d2b.c): machine `omap2420-uartdiag`, CPU `arm1136`, bộ nhớ D2a và UART1 tại `0x4806A000`. Dùng **QEMU v10 `serial_mm_init(..., regshift=2)`** cho lõi UART 16550 8 thanh ghi / TX/RX/FIFO, nối `-serial stdio` thực, **không dùng UART Freescale i.MX31**. Một MemoryRegion riêng `base+0x20` mô phỏng subset thanh ghi vendor OMAP2 `MDR1`, `MDR2`, `SCR`, `EBLR`, `MVR`, `SYSC`, `SYSS`, `WER`, `CFPS`. Có xử lý reset vendor qua `SYSC` bit 1.
- [`tests/omap2420/arm1136_d2b_uart.S`](../../tests/omap2420/arm1136_d2b_uart.S): ARMv6 bare-metal, kiểm `LSR.THRE`, `MVR`, `SYSS`, WER/SCR read-write, WER trở về mặc định sau soft-reset; chạy lại SRAM/SDRAM và REV. **Tất cả marker được ghi bằng `STRB` vào UART1 THR `0x4806A000`**. ARM semihosting chỉ dùng để `SYS_EXIT` (tắt process QEMU), không dùng để in marker.
- [`scripts/test_omap2420_uart_gate_d2b.sh`](../../scripts/test_omap2420_uart_gate_d2b.sh): ghim `utmapp/qemu@v10.0.12-utm`, build QEMU `arm-softmmu` + cả hai machine D2a/D2b trong cây nguồn QEMU tạm, `select SERIAL_MM` trong Kconfig, chạy test, kiểm negative RAM guard, chạy lại D2a regression.
- [`.github/workflows/18-n95-omap2420-gate-d2b.yml`](../../.github/workflows/18-n95-omap2420-gate-d2b.yml): workflow Linux GitHub Actions riêng, xuất artifact log ngay cả khi FAIL và ELF công khai.

**Run D2b:** [GitHub Actions #37906747406](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406). Chưa tuyên bố PASS trước khi có log/chạy xong.

Marker yêu cầu:

```text
D2B_UART1_16550_TX_MMIO=PASS
D2B_UART1_VENDOR_REGS=PASS
D2B_SRAM_SDRAM_REGRESSION=PASS
D2B_ARM1136_ARMV6_REV=PASS
D2B_UART1_RX=NOT_TESTED
D2B_OMAP2_INTC_IRQ=NOT_IMPLEMENTED
QEMU_EXIT_CODE=0
D2A_BASELINE_REGRESSION=PASS
D2B_RAM_GUARD=PASS
GATE_D2B_STATUS=PASS
```

## Những gì chưa được giả lập

- **RX/interrupt chưa được chứng minh:** lõi QEMU 16550 có logic RX, nhưng D2b mới kiểm UART TX + vendor regs. Output IRQ chỉ nối tới sink chẩn đoán, **không nối CPU qua OMAP2 INTC**; chưa được tính là xử lý ngắt thật.
- Không dựng clock tree PRCM, L4 interconnect, GPMC/OneNAND, timer, DMA, USB, keypad, màn hình, baseband của N95.
- Không dùng `-M virt` để giả làm OMAP2, không tuyên bố đã chạy firmware Nokia N95 hay Symbian. Địa chỉ OMAP2 căn cứ mã QEMU 9.1 tham khảo, chưa có trace phần cứng N95 xác nhận.

## Gate tiếp theo

Nếu D2b PASS: bổ sung test RX/loopback và mô hình OMAP2 INTC + UART IRQ (Gate D2c), tiếp đến clock/timer/MMIO validation. Chỉ đóng gói IPA thử nghiệm **riêng** sau các gate source/boot được xác minh, không ghi đè v8/v9 ổn định.

## Scope / Safety

Đây là nghiên cứu giả lập phần cứng phục vụ tương thích hệ điều hành cổ, không liên quan xâm nhập, malware, credential, persistence, khai thác hoặc tấn công. Không tải/phân phối ROM Nokia có bản quyền và không trộn repo EKA2L1.

## Gate D2b — COMPLETED / SUCCESS, xác minh 2026-10-09 (ICT)

**GitHub Actions [#37906747406](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406): COMPLETED / SUCCESS.**

- [Log artifact #11605330239 — N95-OMAP2420-GATE-D2B-UART1-DIAGNOSTIC-LOGS](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406/artifacts/11605330239)
- [Diagnostic ELF artifact #11604867816 — OMAP2420-D2B-ARM1136-UART1-TEST-ELF](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406/artifacts/11604867816)
- QEMU fork `v10.0.12-utm` build máy `omap2420-uartdiag` và CPU `arm1136` thành công.
- ELF ARMv6 dùng `STRB` tại thanh ghi TX của UART1 QEMU `serial-mm` thực ở `0x4806A000`; output qua `-serial stdio`. Semihosting chỉ phục vụ `SYS_EXIT`, không in kết quả.
- Marker từ log, không suy đoán:
  ```text
  D2B_PINNED_QEMU10_SOURCE_PATCH=PASS
  D2B_MACHINE_ARM1136_SERIAL_MM_BUILD=PASS
  D2B_UART1_16550_TX_MMIO=PASS
  D2B_UART1_VENDOR_REGS=PASS
  D2B_SRAM_SDRAM_REGRESSION=PASS
  D2B_ARM1136_ARMV6_REV=PASS
  D2B_UART1_RX=NOT_TESTED
  D2B_OMAP2_INTC_IRQ=NOT_IMPLEMENTED
  QEMU_EXIT_CODE=0
  D2A_BASELINE_REGRESSION=PASS
  D2B_RAM_GUARD=PASS
  GATE_D2B_STATUS=PASS
  ```
- **Kết luận có giới hạn:** Gate D2b TX + thanh ghi vendor/reset PASS **trên Ubuntu GitHub**, không chứng minh UART RX/IRQ, hệ clock/timer, đầy đủ OMAP2420/N95, boot Symbian hay chạy Gate D2b trên iPhone.
- Bản UTM SE Lite v8/v9 đã DEVICE PASS vẫn được giữ nguyên và không phải cài lại IPA.

**Bước kế:** Gate D2c ưu tiên mô hình OMAP2 interrupt controller/IRQ UART, thử RX loopback và interrupt pending/mask/ack; sau đó mới clock/timer/PRCM theo nguồn QEMU 9.1, và chỉ tích hợp iOS khi phần cứng giả lập vượt các bài kiểm thử host.
