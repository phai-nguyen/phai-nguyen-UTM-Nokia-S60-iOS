# Gate D2 — Mô hình OMAP2420 tối thiểu: tiêu chí và nguồn xác minh

**Trạng thái:** lập phương án theo mã QEMU thật, chưa thực hiện build Gate D2 hoặc tích hợp vào IPA. **Không ghi "OMAP2420 PASS" trước khi phần cứng chạy và có log.**

## Tiến độ tiền đề

- **C1/C2 iPhone ARM32 ARMv7 = PASS:** UTM SE Lite v9 chạy Alpine ARMv7, terminal, lệnh và restart được người dùng xác nhận.
- **D1 QEMU 10 ARM1136 ARMv6 CPU + i.MX31 UART = PASS:** [Actions #37897640183](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37897640183), [log #11601416370](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37897640183/artifacts/11601416370). Machine **KZM là i.MX31**, không phải Nokia.
- Không trộn nhánh EKA2L1 và không sửa v8/v9. D2 dùng fork QEMU `utmapp/qemu@v10.0.12-utm`, nguồn tham khảo OMAP2 `qemu/qemu@v9.1.0`.

## Nguồn cho memory map và thanh ghi

| Thành phần cần mô hình | Địa chỉ vật lý tham chiếu | Chứng cứ mã QEMU 9.1 | Mức D2 |
|---|---|---|---|
| CPU ARM1136 (ARMv6) | CPU core | [`omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) / [`cpu32.c` 10](https://github.com/utmapp/qemu/blob/v10.0.12-utm/target/arm/tcg/cpu32.c) | Kiểm mô hình CPU và reset |
| OMAP2 SRAM | `0x40200000` | [`omap.h` 9.1](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h) `OMAP2_SRAM_BASE` | MemoryRegion riêng |
| OMAP2 SDRAM | `0x80000000` | [`omap.h` 9.1](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h) `OMAP2_Q2_BASE` | MemoryRegion RAM và reset |
| L4 bus | `0x48000000` | [`omap.h` 9.1](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h) `OMAP2_L4_BASE` | Giữ vùng trống/định tuyến tới device thật |
| UART1 | `0x4806A000` | [`omap2.c` 9.1, L4 target 57](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) | TX/RX/MMIO + reset; không dùng UART i.MX31 |
| UART2 | `0x4806C000` | [`omap2.c` 9.1, L4 target 59](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) | Thử sau UART1 |
| UART3 | `0x4806E000` | [`omap2.c` 9.1, L4 target 61](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) | Thử sau UART1 |
| Interrupt controller OMAP2 | `0x480FE000` | [`omap2.c` 9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) | Mô hình register/IRQ (UART IRQ 72–74), không nối IRQ trực tiếp vào CPU như giải pháp thay thế |
| UART vendor registers | `MDR1 +0x20`, `SYSC +0x54`, `SYSS +0x58`, `WER +0x5c` | [`hw/char/omap_uart.c` 9.1](https://github.com/qemu/qemu/blob/v9.1.0/hw/char/omap_uart.c) | Kiểm read/write/reset, khác UART 16550 thường |

Các địa chỉ là **tham chiếu mô hình OMAP2 QEMU 9.1**, không phải kiểm nghiệm trace boot trên máy Nokia N95. Không tuyên bố đầy đủ timing hoặc phiên bản silicon N95.

## Bước triển khai D2 theo thứ tự giảm rủi ro

1. **D2a, QOM/MemoryRegion:** thêm machine *chẩn đoán* tên riêng (ví dụ `omap2420-earlydiag`) vào bản fork QEMU **riêng**. Có CPU ARM1136, SRAM và SDRAM đúng địa chỉ, không xung đột OMAP1 còn trong QEMU 10. Bài test đọc/ghi SRAM và truy cập PC reset từ ELF ARMv6 tại RAM/SRAM. Chưa nạp Symbian.
2. **D2b, UART thật:** tái hiện hành vi register OMAP2 UART1 tối thiểu (chuyển 8250 serial + các thanh ghi vendor/reset), đọc/ghi byte và xuất dấu mốc chẩn đoán. **Không** chỉ thay base address của UART i.MX31 thành địa chỉ OMAP rồi gọi là hoàn thiện.
3. **D2c, INTC/clock/timer:** gắn IRQ 72/73/74 qua controller với pending/mask/ack và reset. Thêm timer/clock gating tối thiểu; bài test gửi IRQ và kiểm tra xác nhận trên CPU. Chưa tuyên bố thời gian/PRCM chuẩn firmware.
4. **D2d, validation/QTest:** check danh sách `-M help`, `-cpu help`, UART reset/width/read/write, SRAM/SDRAM boundaries, IRQ routing, boot ELF và timeout. Xuất binary chẩn đoán công khai + QEMU log + trạng thái PASS/FAIL.
5. **D2e, iOS TCI:** chỉ khi D2a–d PASS trên QEMU 10 native Linux mới biên dịch máy mới vào `qemu-arm-softmmu.framework` iOS và build IPA thử nghiệm **riêng**; v8/v9 vẫn giữ nguyên.

## Không thuộc Gate D2

- Không cài firmware Nokia N95, không dùng `-M n800` hay `-M n810` để quảng cáo N95.
- Không có Symbian EKA2 process scheduling, màn hình chính S60 hay cảm ứng Nokia.
- Không chép nguyên `hw/arm/omap2.c` 9.1 sang fork 10 mà bỏ qua các ngoại vi đã xóa (L4/INTC/UART/clock/SDRC/GPMC/GPTimer/DMA4).
- Nghiên cứu này chỉ về giả lập phần cứng tương thích, không liên quan khai thác, xâm nhập, malware, credential hoặc persistence.

## Quyết định kỹ thuật

**Chọn D2a ở vòng kế tiếp**, dùng chương trình ARMv6/ELF chẩn đoán tương tự Gate D1, nhưng trên map SRAM/SDRAM OMAP2420 và UART đúng thiết bị. Mỗi Gate đòi kiểm thử máy Linux trước, iPhone sau; không đổi firmware và không sử dụng fallback `virt` để giả chứng minh OMAP2.
