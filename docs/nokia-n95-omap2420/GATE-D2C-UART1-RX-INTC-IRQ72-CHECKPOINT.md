# Gate D2c — ARM1136 + OMAP2 UART1 RX + INTC IRQ72

**Ngày:** 09/10/2026 (ICT)  
**Nhánh tách biệt:** `research/n95-omap2420-gate-d2c`  
**Build:** [GitHub Actions #37911501299](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37911501299)  
**Trạng thái:** CI được khởi động; chỉ tuyên bố PASS khi xem log đầy đủ.

## 1. Các baseline được bảo toàn

- **v8 iPhone:** UTM SE Lite giao diện Việt hóa, Alpine ARM64, picker, network/disk/reboot đã DEVICE PASS.
- **v9 iPhone:** Alpine ARMv7 32-bit `armv7l`, shell, serial, shutdown/restart DEVICE PASS (v9 dùng workaround `-append`).
- **D1 ARM1136 trên QEMU Linux:** instruction ARMv6 + KZM i.MX31 UART PASS.
- **D2a:** `omap2420-earlydiag`, ARM1136, SRAM `0x40200000`, SDRAM `0x80000000` PASS ở run #37904307368.
- **D2b:** `omap2420-uartdiag`, UART1 `0x4806a000`, TX qua QEMU serial-mm, OMAP vendor registers/read/write/reset PASS ở [run #37906747406](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406).

## 2. Thành phần Gate D2c

- [`tests/omap2420/omap2420_diag_d2c.c`](../../tests/omap2420/omap2420_diag_d2c.c): thêm machine `omap2420-intcdiag`, ARM1136 và memory map của D2a/D2b. UART1 sử dụng **lõi QEMU 16550/serial-mm**, nối tín hiệu của UART IRQ72 vào INTC chẩn đoán rồi vào `ARM_CPU_IRQ`.
- Bộ điều khiển INTC tối giản tại `0x480fe000`, ba bank 32-bit. Subset các thanh ghi OMAP2 tham khảo QEMU 9.1: `INTC_REVISION +0x00`, `SIR_IRQ +0x40`, `CONTROL +0x48`, `MIR2 +0xc4`, `MIR_CLEAR2 +0xc8`, `MIR_SET2 +0xcc`, `ITR2 +0xc0`, `PENDING_IRQ2 +0xd8`. UART IRQ72 = bank 2, bit 8. Chưa có ưu tiên IRQ/FIQ đầy đủ.
- MemoryRegion vector tại `0x00000000` (thử nghiệm riêng, **không phải Nokia ROM**). ARMv6 test đặt IRQ vector ở `0x18`, đặt stack IRQ riêng và có handler đọc RX data, ACK vào INTC, ghi cờ trong SRAM.
- [`tests/omap2420/arm1136_d2c_intc_uart.S`](../../tests/omap2420/arm1136_d2c_intc_uart.S): kiểm UART RX nội bộ bằng **MCR_LOOP** trên 16550, test `LSR.DR`, `RBR`, ITR/MIR/PENDING/SIR, mask/unmask và sự kiện CPU IRQ thật. Chương trình dùng ARM semihosting **chỉ để kết thúc QEMU**, còn output marker qua UART1 TX thật.
- [`scripts/test_omap2420_intc_gate_d2c.sh`](../../scripts/test_omap2420_intc_gate_d2c.sh): download mã QEMU `utmapp/qemu@v10.0.12-utm`; chèn machine D2a/D2b/D2c vào build tạm Linux, compile ARMv6 ELF, chạy 3 bài regression + kiểm giới hạn RAM, lưu log/ELF.
- [`.github/workflows/19-n95-omap2420-gate-d2c.yml`](../../.github/workflows/19-n95-omap2420-gate-d2c.yml): GitHub Actions Ubuntu với artifact log ngay cả khi FAIL.

Các marker bắt buộc trước khi PASS:

```text
D2C_UART1_RX_LOOPBACK=PASS
D2C_INTC_IRQ72_RAW_MASK_PENDING=PASS
D2C_INTC_MIR_CLEAR_ACK=PASS
D2C_ARM1136_CPU_IRQ_EXCEPTION=PASS
D2C_D2A_MEMORY_ARMV6_REGRESSION=PASS
D2C_OMAP2_CLOCK_TIMER=NOT_IMPLEMENTED
QEMU_EXIT_CODE=0
D2B_UART1_TX_BASELINE_REGRESSION=PASS
D2A_BASELINE_REGRESSION=PASS
D2C_RAM_GUARD=PASS
GATE_D2C_STATUS=PASS
```

## 3. Phạm vi không được tuyên bố quá mức

Mô hình INTC mới là tập con dành cho chẩn đoán IRQ72; **chưa tương đương OMAP2420 INTC sản xuất** vì thiếu đầy đủ 96 nguồn ngắt/priority/FIQ/ILR, hành vi clock/reset chi tiết, hệ PRCM/timer, L4, GPMC/NAND, GPU, màn hình và các thiết bị Nokia N95. UART RX đã dùng loopback nội bộ; chưa kiểm RX từ bàn phím/đầu cuối vật lý và luồng modem Nokia.

Kết quả của GitHub Actions (dù PASS) chỉ là **Linux host QEMU10**, không phải build engine/DEVICE PASS OMAP2420 trên iPhone và tuyệt đối không phải Symbian/N95 boot. Bản UTM v8/v9 không bị sửa. Không dùng/phân phối firmware Nokia.

## 4. Hướng tiếp theo sau khi D2c PASS

Gate D2d: mở rộng IRQ controller (mask/ack/retrigger/multiple IRQ và FIQ nếu cần), clock/timer/PRCM tối thiểu, kiểm định MMIO qua guest/QTest, test reboot và reset. Sau đó mới nghiên cứu iOS framework và đóng IPA nghiên cứu riêng.
