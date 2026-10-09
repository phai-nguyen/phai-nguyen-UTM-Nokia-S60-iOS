# Gate D2d — PRCM/GPTimer1 chẩn đoán + IRQ37 (QEMU 10 / ARM1136)

**Ngày:** 2026-10-09 (ICT)  
**Nhánh:** `research/n95-omap2420-gate-d2d`  
**Nguồn QEMU:** `utmapp/qemu@v10.0.12-utm` (ghim bản, source QEMU tạm do GitHub Actions dựng)  
**Trạng thái:** **Gate D2d PASS trên Ubuntu GitHub Actions**, chưa có bản IPA iOS D2d hay Symbian/N95 boot.

## Kết quả kiểm chứng

- **[Workflow D2d #37917633717](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37917633717): SUCCESS**. Log build và chạy guest ARMv6:
  ```text
  D2D_PINNED_QEMU10_SOURCE_PATCH=PASS
  D2D_MACHINE_ARM1136_GPTIMER1_PRCM_BUILD=PASS
  D2D_PRCM_GPT1_CLOCK_GATING=PASS
  D2D_GPT1_OVERFLOW_TISR_TIER=PASS
  D2D_GPT1_INTC_IRQ37_PENDING_MASK_ACK=PASS
  D2D_ARM1136_GPT1_IRQ_EXCEPTION=PASS
  D2D_GPT1_SOFTRESET=PASS
  D2D_D2A_ARMV6_MEMORY=PASS
  D2D_FULL_OMAP_CLOCK_TREE=NOT_IMPLEMENTED
  QEMU_EXIT_CODE=0
  D2C_UART_RX_IRQ72_BASELINE_REGRESSION=PASS
  D2B_UART1_TX_BASELINE_REGRESSION=PASS
  D2A_BASELINE_REGRESSION=PASS
  D2D_RAM_GUARD=PASS
  GATE_D2D_STATUS=PASS
  ```
- **[Log artifact #11610751871](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37917633717/artifacts/11610751871)**: lưu ý artifact của **lượt đầu** mang nhãn D2c-UART1 do sơ suất tên trong workflow, nhưng nội dung là thư mục `out/omap2420-d2d/diagnostics` và có các marker D2d nêu trên. Tên artifact đã được chỉnh trong workflow cho lượt sau.
- **[ELF artifact #11610936786](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37917633717/artifacts/11610936786)**: payload kiểm thử ARMv6 từ dự án, **không phải firmware Nokia**.

## Mô hình D2d

Mã nguồn [`tests/omap2420/omap2420_diag_d2d.c`](../../tests/omap2420/omap2420_diag_d2d.c) tạo **machine chẩn đoán `omap2420-timerdiag`**, giữ ARM1136 + SRAM/SDRAM + QEMU serial-MMIO UART1 + INTC subset của D2a–D2c, đồng thời bổ sung:

| Thành phần | MMIO/IRQ | Hành vi trong D2d |
|---|---|---|
| PRCM subset | `0x48008000` | `CM_FCLKEN_WKUP +0x400`, `CM_ICLKEN_WKUP +0x410`; cho phép/chặn timer qua bit 0 |
| GPTimer1 subset | `0x48028000` | `TIDR`, `TISTAT`, `TISR`, `TIER`, `TCLR`, `TCRR`, `TLDR`, `TTGR`, soft reset qua `TIOCP_CFG` |
| GPTimer1 IRQ | IRQ **37** → INTC bank **1**, bit **5** → CPU ARM1136 IRQ | TISR overflow / TIER enable / MIR mask/ack + ARM vector `0x18` |
| UART1 | `0x4806A000`, IRQ **72** | UART TX để in marker, D2b/D2c hồi quy |

Bộ timer sử dụng `QEMU_CLOCK_VIRTUAL` (bộ hẹn giờ QEMU), bước mô phỏng xấp xỉ **32.768 kHz** để chứng minh ngắt timer hoạt động; **chưa phải mô hình cycle-accurate của clock tree OMAP2420**. Gate D2d chỉ xác nhận các bit clock gate có trong bài test; chưa xác minh mọi trạng thái idle/gating của silicon.

Chương trình [`tests/omap2420/arm1136_d2d_prcm_gpt1.S`](../../tests/omap2420/arm1136_d2d_prcm_gpt1.S) ARMv6 kiểm thử:

1. GPT1 reset status, clock PRCM mặc định tắt; đặt TCRR gần tràn, TIER overflow và TCLR start. Chứng minh **không đếm khi clock gate tắt**.
2. Bật PRCM FCLKEN/ICLKEN, chờ sự kiện timer thực tế theo QEMU virtual clock.
3. Đọc TISR/ITR/PENDING, xác nhận IRQ37 bị mask, **MIR_CLEAR1** unmask và SIR_IRQ trả **37**.
4. Mở CPU IRQ, vào **handler IRQ thực ở vector 0x18**, clear TISR + ACK INTC rồi ghi cờ SRAM. Không in marker bằng semihosting (chỉ dùng `SYS_EXIT`).
5. Soft reset timer, kiểm reset TCRR/TIER/TISR và PRCM gating off; kiểm SRAM/SDRAM + lệnh ARMv6 `REV`.
6. Workflow [`20-n95-omap2420-gate-d2d.yml`](../../.github/workflows/20-n95-omap2420-gate-d2d.yml) chạy lại **D2c UART RX IRQ72, D2b UART TX, D2a SRAM/SDRAM**, guard RAM 256 MiB.

## Kết quả trước đó vẫn nguyên

- **iPhone v8:** Alpine Linux ARM64, file picker/iOS, network/disk, restart DEVICE PASS.
- **iPhone v9:** QEMU ARM32 Cortex-A15, Alpine ARMv7 `armv7l`, shell/reboot DEVICE PASS.
- **D1 QEMU Linux:** ARM1136/KZM i.MX31 instruction/UART PASS.
- **D2a:** ARM1136 + OMAP2420-style SRAM/SDRAM PASS.
- **D2b:** UART1 TX/MMIO và vendor register subset PASS.
- **D2c:** UART1 RX loopback, INTC IRQ72 và CPU ARM1136 IRQ handler PASS.

**Không sửa nhánh app v8/v9, không merge sang IPA đang hoạt động, không thay firmware Nokia.** Các tính năng trên chỉ chạy ở source machine thử nghiệm của QEMU trên Ubuntu CI.

## Chưa được tuyên bố

- **Chưa có đầy đủ** PRCM/clock tree, silicon timer prescalers/autoidle, device reset topology, multiple IRQ priority/FIQ, L4/GPMC/NAND, màn hình, DMA, pin mux và dữ liệu ROM Nokia N95.
- **Không có** máy `-M n95`, Symbian S60/EKA2 boot, smartphone home screen, và **không có** D2d DEVICE PASS trên iPhone.
- Chưa có bộ QTest MMIO độc lập ngoài các bài test ARMv6 guest; test Linux-host hiện dùng ELF guest thật và log serial.

## Tài liệu đối chiếu

- [QEMU upstream 9.1 `hw/timer/omap_gptimer.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/timer/omap_gptimer.c) — register offset TISR/TIER/TCLR/TCRR/TLDR.
- [QEMU upstream 9.1 `hw/arm/omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c) — GPTimer1 tại `0x48028000`, clock PRCM, IRQ routing.
- [QEMU upstream 9.1 `include/hw/arm/omap.h`](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h) — `OMAP_INT_24XX_GPTIMER1 = 37`.
- [QEMU UTM pinned `v10.0.12-utm`](https://github.com/utmapp/qemu/tree/v10.0.12-utm) — interface QEMUTimer / TCG ARM1136.

## Bước kế tiếp đề xuất: D2e

1. Chuẩn hóa cấu trúc patch QEMU10 D2a–D2d thành source bundle dễ tái lập; tăng cường MMIO/reset/QTest và đo stability trên CI.
2. Build riêng `qemu-arm-softmmu.framework` iOS TCI **có máy `omap2420-timerdiag`** và test linkage/kiến trúc ARM64 host. Không đụng 8-engine IPA v9 đã DEVICE PASS.
3. Khi framework compile/link và bundle audit PASS, tạo **IPA nghiên cứu riêng** để thử bare-metal ELF ARM1136 trên iPhone; phải có log DEVICE trước khi khẳng định.
4. Sau đó mới mở rộng SoC và nghiên cứu firmware N95. **Không coi Gate D2d tương đương N95/Symbian boot.**

**Scope / Safety:** chỉ nghiên cứu giả lập hệ thống cũ và phần cứng tương thích; không liên quan khai thác, xâm nhập, malware, credential, persistence hay tấn công mạng.
