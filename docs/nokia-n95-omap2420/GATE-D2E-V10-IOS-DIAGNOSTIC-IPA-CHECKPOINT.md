# Gate D2e — UTM SE Lite v10 OMAP2420 Diagnostic IPA

**Ngày:** 2026-10-09 (ICT)  
**Nhánh độc lập:** `feat/utm-se-lite-v10-omap2420-diagnostic`  
**CI:** [GitHub Actions #37927091862](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37927091862) — chưa xác nhận hoàn tất tại thời điểm ghi.

## Mục tiêu chính xác

Đóng gói một ứng dụng unsigned cho ESign cài riêng, **không sửa v8/v9** và không dùng firmware Nokia, để kiểm thử framework QEMU D2e trên iPhone iOS 18.7 (min iOS 15). Chỉ khi người dùng thấy marker ARM1136/GPT1 IRQ37/serial qua iPhone mới ghi DEVICE PASS.

### Căn cứ đã PASS

- v8 UTM SE Lite: Vietnamese UI, UIKit picker, Alpine ARM64, disk/network/shutdown/restart DEVICE PASS.
- v9 UTM SE Lite: ARMv7 QEMU `virt` trên iPhone, Alpine Linux ARM32 `armv7l`, shell/restart DEVICE PASS (dùng quoting workaround). v9.1 đã BUILD PASS.
- D2a–D2d: bốn máy ARM1136 diagnostic đã chạy guest ARMv6/baremetal trên Ubuntu QEMU 10.0.12-utm, cả CPU/SRAM/SDRAM, UART1, INTC IRQ72, GPT1 IRQ37 và PRCM minimal đều PASS.
- [D2e framework #37924268847](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847): iOS ARM64 host, ARM32 ARM1136 guest TCI/no JIT; bốn QOM machine (hậu tố `-machine`) có mặt trong final framework; bảy engine gốc không thay đổi. **Framework BUILD PASS**, chưa chạy trên iPhone.

### File mới nhánh v10

- [`scripts/patch_utm_omap2420_diagnostic_v10.py`](../../scripts/patch_utm_omap2420_diagnostic_v10.py): patch UTM pin `7eadb056ae0f91d979059544d0ddcd2d5a40be92`, enum `QEMUTarget_arm` thêm bốn loại `omap2420-earlydiag`, `omap2420-uartdiag`, `omap2420-intcdiag`, `omap2420-timerdiag`; wizard có mục Việt hóa **OMAP2420 Diagnostic – ARM1136 (chưa phải Nokia N95)**. Nếu chọn trong Linux wizard, ép CPU arm1136, 1 core, 128MiB, tắt USB/display/network/sound, serial only, không tạo disk rỗng/UEFI; nạp **baremetal ARMv6 ELF** bằng picker `Boot from Kernel`, KHÔNG phải Linux ARMv7 hay Nokia ROM.
- [`scripts/overlay_omap2420_v10_vi_locale.py`](../../scripts/overlay_omap2420_v10_vi_locale.py): chỉ overlay Vietnamese resource đã device-PASS từ v8, không thay đổi executable/framework; **bundle ID v10 riêng `com.phai.nokias60.omapdiag.UTM-SE`** và `CFBundleDisplayName=UTM OMAP Diag v10`.
- [`.github/workflows/22-lite-v10-omap2420-diagnostic-ipa.yml`](../../.github/workflows/22-lite-v10-omap2420-diagnostic-ipa.yml): macOS26, iOS15 deployment, ghim UTM và sysroot bảy engine, lấy framework D2e PASS #37924268847, giữ tám engine, tải guest ELF D2d #37917633717; kiểm SHA v8, plist, final IPA 4 QOM machine có hậu tố `-machine\0`, archive match framework, Vietnamese, zip. Xuất **unsigned IPA**, ELF, và log ngay cả khi FAIL.
- Build công cụ sử dụng lại bản v9.1 cho UIKit copy picker và `-append` fix ARM32 virt, không thay đổi v8/v9.

### Tiêu chí nhận kết quả

`Xcode archive PASS`, `8_ENGINES_IN_IPA=PASS`, `V10_OMAP2420_FOUR_QOM_MACHINES_IN_FINAL_IPA=PASS`, `MinimumOSVersion=15.0`, bundle ID riêng, đủ vi strings, QEMU TCI iOS. Build thành công cũng **không chứng minh** ARM1136 chạy trên iPhone; cần test thiết bị.

### Trình tự thử trên iPhone (chỉ sau khi IPA PASS)

1. Dùng ESign ký IPA v10 và cài **cạnh v8/v9**, không xóa máy ảo cũ.
2. Tải/extract artifact ELF `arm1136_d2d_prcm_gpt1.elf` qua app Tệp trên iPhone.
3. Tạo máy ảo → Linux → Boot from Kernel, chọn ELF, bỏ initramfs và boot args, CPU preset `OMAP2420 Diagnostic – ARM1136`, RAM 128MiB, một CPU, màn hình đồ họa OFF, serial terminal ON, không tạo ổ đĩa.
4. Khởi động; mong đợi từ **serial UART1**:
   ```text
   D2D_PRCM_GPT1_CLOCK_GATING=PASS
   D2D_GPT1_OVERFLOW_TISR_TIER=PASS
   D2D_GPT1_INTC_IRQ37_PENDING_MASK_ACK=PASS
   D2D_ARM1136_GPT1_IRQ_EXCEPTION=PASS
   D2D_GPT1_SOFTRESET=PASS
   D2D_D2A_ARMV6_MEMORY=PASS
   D2D_FULL_OMAP_CLOCK_TREE=NOT_IMPLEMENTED
   ```
5. Gửi ảnh/video, UTM debug log nếu lỗi. Chỉ ghi **DEVICE PASS** khi có bằng chứng thiết bị.

### Những gì v10 **không** hỗ trợ

Không có mô hình bo mạch Nokia N95 đầy đủ, Symbian OS/S60/EKA2 startup, firmware/ROM Nokia, NAND/GPMC/display/input/UI hoàn chỉnh. SoC là subset chẩn đoán ARM1136 + UART + INTC + PRCM/GPTimer1, chưa phải phần cứng cycle-accurate.

**Scope/Safety:** dự án nghiên cứu tương thích trình giả lập cho phần cứng cũ, không liên quan tấn công mạng/xâm nhập, malware, credential, persistence; không phân phối firmware có bản quyền.

## Gate v10 build #37927091862 và sửa lỗi đóng gói (2026-10-09 ICT)

- Run [#37927091862](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37927091862) **COMPLETED / FAILURE** dù Xcode ghi rõ `** ARCHIVE SUCCEEDED **`, framework `qemu-arm-softmmu.framework` có SHA256 khớp sau inject `ARM32_FRAMEWORK_STAGED_BEFORE_IPA=PASS`, và IPA cơ sở `NokiaUTM-SE-v1-unsigned.ipa` đã đóng gói. Các patch SDK/UIKit/ARM32 wizard/OMAP wizard đều PASS. Lỗi xảy ra tại `test -s out/diagnostics/omap2420-v10-injected-framework.sha256` sau khi helper `scripts/build_utm_se.sh` thực tế ghi `out/diagnostics/arm32-v9-injected-framework.sha256`. Đây là **lỗi hợp đồng tên file report giữa script v9 và workflow v10**, không phải compiler/ARM1136/linker.
- [Commit `64176e24e3e26fa7b66d86e6acc10faff19512be`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/64176e24e3e26fa7b66d86e6acc10faff19512be) thay cả report SHA256 và `otool` sang `omap2420-v10-injected-framework.*` trên **nhánh v10 riêng**; không ảnh hưởng các nhánh v8/v9.
- Kiểm tra bổ sung tìm thấy script overlay locale v10 chưa gán `CFBundleDisplayName` nhưng workflow final-IPA bắt buộc tên riêng `UTM OMAP Diag v10`. [Commit `2b92b418cc11168664a0718a25237eccdaaba902`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/2b92b418cc11168664a0718a25237eccdaaba902) gán và hậu kiểm tên hiển thị đúng trong `Info.plist`; không sửa resource Việt hóa gốc v8, executable hay framework.
- **Run mới nhất:** [#37931130662](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37931130662), từ commit cuối; cần xác minh hoàn tất, artifacts IPA + ELF + logs, bundle ID, 8 engines, 4 QOM machine names. Run trung gian [#37931117994](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37931117994) chứa **chỉ sửa log** nhưng chưa sửa display name, nên không dùng làm mốc chính.
- **Không ghi BUILD PASS hay DEVICE PASS trước khi run mới nhất hoàn tất và xác minh.** Chưa có bằng chứng chạy bare-metal ARM1136 trên iPhone; Nokia N95/Symbian chưa được giả lập.
