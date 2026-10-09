# Gate D2e — Cross-build QEMU ARM1136/OMAP2 diagnostic framework for iPhone

**Ngày:** 2026-10-09 (ICT)  
**Repo:** phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS  
**Nhánh:** `research/n95-omap2420-gate-d2e-ios-tci`  
**Trạng thái:** build framework iOS **đang kiểm chứng**, không gán PASS trước kết quả GitHub Actions.

## Nguồn đã đạt Gate D2a–D2d trên Linux host

- iPhone UTM SE Lite **v8**: Alpine Linux ARM64, Vietnamese UI, file picker, disk/network và restart được người dùng kiểm chứng PASS.
- iPhone UTM SE Lite **v9**: máy QEMU `virt`, CPU Cortex-A15 ARM32, Alpine Linux ARMv7 `armv7l` chạy shell và restart PASS.
- QEMU ARM1136 ARMv6 baseline **D1**: KZM i.MX31 CPU/UART PASS Linux host.
- [D2a run #37904307368](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37904307368): machine `omap2420-earlydiag`; SRAM/SDRAM, ELF ARMv6 PASS Linux host.
- [D2b run #37906747406](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406): machine `omap2420-uartdiag`; UART1 TX MMIO `0x4806A000`, vendor regs PASS Linux host.
- [D2c run #37911548247](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37911548247): `omap2420-intcdiag`; UART RX loopback, INTC IRQ72 và ARM1136 IRQ exception PASS Linux host.
- [D2d run #37917633717](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37917633717) và [rerun #37918426141](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37918426141): `omap2420-timerdiag`; PRCM diagnostic subset, GPTimer1 `0x48028000`, INTC IRQ37, reset và hồi quy D2a–D2c PASS Linux host.
- **Chú ý:** chỉ test trên Ubuntu host ở bốn machine OMAP chẩn đoán, chưa có xác nhận thực thi trên iPhone, Nokia N95 hoặc Symbian.

## Gate D2e: các file và thao tác đã đưa lên GitHub

- [`scripts/diagnose_omap2420_d2e_ios_tci.sh`](../../scripts/diagnose_omap2420_d2e_ios_tci.sh): tái sử dụng `diagnose_qemu_arm32_tci.sh` đã BUILD PASS, ghim `utmapp/UTM@7eadb056ae0f91d979059544d0ddcd2d5a40be92`, QEMU `v10.0.12-utm`, sysroot `Sysroot-ios-tci-arm64` run `36090554968`; dựng thêm bốn machine QEMU từ mã D2a-D2d rồi build `arm-softmmu` với `-target arm64-apple-ios15.0` và `--enable-tcg-threaded-interpreter`. Đóng `qemu-arm-softmmu.framework` thông qua `fixup.sh -p ios-tci`.
- [`.github/workflows/21-n95-omap2420-gate-d2e-ios-tci.yml`](../../.github/workflows/21-n95-omap2420-gate-d2e-ios-tci.yml): job **macOS-26**, giữ nguyên 7 engine baseline và kiểm SHA256 trước/sau. Cần framework iOS arm64, min iOS 15, và 4 tên machine có trong binary đã stage; phát hành riêng diagnostics và **framework thử nghiệm**, không phải IPA.
- **Build đầu:** [Actions #37920944620](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37920944620). Kiểm tra trạng thái/log mỗi khi chạy; không dùng kết quả Linux host làm thay thế iOS cross-build.
- Điều kiện PASS: `STATUS=PASS`, `D2E_FOUR_OMAP_DIAGNOSTIC_MACHINE_NAMES_IN_IOS_FRAMEWORK=PASS`, `LINKED_FRAMEWORK_CLOSURE=PASS`, `SEVEN_FRAMEWORKS=UNCHANGED`, framework nhúng có binary Mach-O arm64 được `lipo`/vtool xác nhận. Không khẳng định boot guest trên iPhone chỉ từ tên machine nằm trong `strings`.

## Phạm vi đã giả lập tối giản

| Chức năng | Địa chỉ / IRQ | Giới hạn |
|---|---|---|
| ARM1136 ARMv6 | QEMU `arm-softmmu` | emulator; không phải iPhone chạy ARM11 trực tiếp |
| SRAM/SDRAM | `0x40200000` / `0x80000000` | 128 MiB SDRAM mặc định |
| UART1 | `0x4806A000` IRQ72 | core QEMU 16550 + subset regs |
| INTC | `0x480FE000` | IRQ72/IRQ37; chưa đầy đủ priority/FIQ/96-device timing |
| GPTimer1 | `0x48028000` IRQ37 | QEMU virtual clock, không cycle-accurate |
| PRCM | `0x48008000` | basic wakeup gate, không đầy đủ clock tree |

## Tiếp theo, chỉ khi framework Gate D2e PASS

1. Kiểm tra iOS dynamic libraries/rpath, danh sách machine, TCI/no-JIT và integrity; giữ artifact framework riêng.
2. Tạo IPA **nghiên cứu độc lập** từ baseline v9, thêm một lựa chọn tên rõ `OMAP2420 diagnostic (chưa phải Nokia N95)`, và hỗ trợ nạp bare-metal ELF ARM1136 để xuất UART1 serial. Không đổi firmware và không ghi đè v8/v9. **Không gọi là iOS DEVICE PASS trước khi người dùng cài/ký ESign và gửi log/video.**
3. Nếu không biên dịch được framework, sửa từ log nguyên nhân, không tiếp tục IPA.
4. Để boot Nokia N95/Symbian cần thêm clock tree/reset, GPMC/NAND, OMAP peripheral map và board-specific thiết bị ngoài phần chẩn đoán; chưa có ở D2e.

**Scope/Safety:** chỉ nghiên cứu giả lập để tương thích máy cổ; không phải malware, credential, persistence, xâm nhập, khai thác hoặc tấn công mạng. Không đưa ROM Nokia thương mại vào GitHub.
