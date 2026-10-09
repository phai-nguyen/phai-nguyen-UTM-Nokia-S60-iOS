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

## Lượt CI #37920944620 FAIL ở bước kiểm tra máy, bản vá #37922317635 (09/10/2026)

- [Run #37920944620](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37920944620): **COMPLETED / FAILURE** ở **`LAST_STAGE=verify-embedded-machine-registrations`**, không phải lỗi trình biên dịch ARM1136.
- Log có bốn object `hw_arm_omap2420_diag_d2a.c.o` … `d2d.c.o`, `[2876/2878] Linking target libqemu-arm-softmmu.dylib`, đóng framework `fixup.sh` đã chạy; tool `strings "$FW/qemu-arm-softmmu" | grep 'omap2420-'` trả status 1.
- Đây có thể là **false negative của cách tìm chuỗi ở Mach-O**, hoặc bốn tên máy đã bị loại khỏi final framework: **chưa thể kết luận** khi không có báo cáo byte-scan. Cảnh báo linker khác: `ui_spice-display-metal.m.o` khai báo SDK iOS 26.5 mới hơn deployment target 15.0; cảnh báo không dừng link, nhưng cần theo dõi trước khi chạy trên iPhone iOS 18.7.
- [Log artifact #11612740448](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37920944620/artifacts/11612740448) gồm 30 tệp chẩn đoán.
- Patch commit `ea067e98d9220b3f4c3c2a23f3e84e2e6a761b1d` thay gate `strings` bằng **Python đọc bytes trực tiếp** trên *cả raw dylib và framework đã stage*, bắt buộc đủ bốn chuỗi máy kết thúc NUL; ghi `machine-registration-byte-audit.txt` kể cả khi fail. Không bỏ bất kỳ ràng buộc PASS nào.
- [Rerun (push) #37922317635](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37922317635) đã được tạo. **Đang chạy/chờ; chưa chứng minh framework PASS và chưa có IPA** tại thời điểm ghi.
- Giữ nguyên bảy engine cũ, v8/v9, tất cả firmware. **Chưa có kiểm thử iPhone hoặc Nokia N95/Symbian boot.**

## Phân tích chính xác lần 2 và sửa QOM audit (2026-10-09)

- Run [#37922317635](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37922317635) **COMPLETED / FAILURE**. Artifact [#11612479172](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37922317635/artifacts/11612479172).
- Cả bốn object `hw_arm_omap2420_diag_d2{a,b,c,d}.c.o` đã biên dịch; `libqemu-arm-softmmu.dylib` và `qemu-system-arm-unsigned` đều liên kết; `fixup.sh` tạo framework iOS. Bản byte-scan thứ nhất lại tìm `omap2420-earlydiag\0` và tương tự, báo thiếu trên cả raw Mach-O và framework.
- **Đã xác minh từ chính source QEMU `v10.0.12-utm`:** `include/hw/boards.h` khai báo `#define TYPE_MACHINE_SUFFIX "-machine"`, `#define MACHINE_TYPE_NAME(machinename) (machinename TYPE_MACHINE_SUFFIX)`; macro `DEFINE_MACHINE` dùng `MACHINE_TYPE_NAME(namestr)` làm QOM TypeInfo. Do đó binary chứa chuỗi type name `omap2420-earlydiag-machine\0` (và ba máy khác), chứ không cần có tên CLI nguyên văn + NUL.
- **Root cause của false negative:** kiểm bytes `name+b"\0"` thay vì `name+b"-machine\0"`. Không có căn cứ coi linker đã xóa machines chỉ từ kết quả này; phép thử cũ không đúng định dạng QOM ngay từ đầu.
- [Commit `d61bb4eed4b43ab9d7a3de55f4f6167021e5e24a`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/d61bb4eed4b43ab9d7a3de55f4f6167021e5e24a) sửa byte-scan trên **hai tệp** raw Mach-O + packaged framework để tìm chính xác chuỗi `-machine\0`; vẫn FAIL nếu thiếu bất kỳ chuỗi nào và vẫn buộc kiểm SHA 7 engine, dependency closure, kiến trúc arm64 host/iOS15+.
- [Run #37924268847](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847) được trigger; **chưa nhận kết quả PASS/FAIL tại lúc ghi note**. Chỉ cập nhật kết luận sau khi xem log hoàn tất.
- Chưa có IPA nghiên cứu v10, chưa có thử nghiệm OMAP2420 trên iPhone và chưa boot N95/Symbian; v8/v9 ổn định vẫn nguyên.

## Gate D2e chính thức PASS — 2026-10-09

- **[Run #37924268847](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847): COMPLETED / SUCCESS.** Bản sửa ở commit `d61bb4eed4b43ab9d7a3de55f4f6167021e5e24a`.
- [Framework artifact #11613786984](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613786984) tên `QEMU-OMAP2420-D2E-IOS-TCI-ARM32-RESEARCH-FRAMEWORK`; dung lượng zip khoảng 24.3 MB. Đây là **framework nghiên cứu**, **không phải IPA**.
- [Log artifact #11613886670](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613886670).
- Job trên macOS hoàn thành toàn bộ bước checkout, pin UTM/QEMU, sysroot, compile, đóng framework, đóng artifact. Log chứa:
  ```text
  raw_macho: omap2420-earlydiag=PASS
  raw_macho: omap2420-uartdiag=PASS
  raw_macho: omap2420-intcdiag=PASS
  raw_macho: omap2420-timerdiag=PASS
  staged_framework: omap2420-earlydiag=PASS
  staged_framework: omap2420-uartdiag=PASS
  staged_framework: omap2420-intcdiag=PASS
  staged_framework: omap2420-timerdiag=PASS
  D2E_FOUR_OMAP_MACHINE_BYTE_SCAN=PASS
  D2E_FOUR_OMAP_DIAGNOSTIC_MACHINE_NAMES_IN_IOS_FRAMEWORK=PASS
  SEVEN_FRAMEWORKS=UNCHANGED
  ARM32_DIAGNOSTIC_STATUS=PASS EXIT_CODE=0 STAGE=complete
  D2E_IOS_TCI_FRAMEWORK=PASS
  ```
- **Chỉ xác nhận compile/link/staging/binary name audit trên macOS**. Chưa chạy `-M omap2420-timerdiag` trên iPhone; nhắc lại kiểm tra chuỗi QOM trong Mach-O **không đồng nghĩa** máy ảo đã chạy. D2a-D2d đã chạy trên Ubuntu riêng.
- Linker vẫn đưa warning: `ui_spice-display-metal.m.o` được biên dịch với iOS SDK phiên bản 26.5 cao hơn deployment target iOS 15.0, nhưng không chặn kết quả. Cần test thực tế iOS 18.7 để xác minh runtime.
- Tiếp theo: build IPA v10 nghiên cứu **tách riêng** hoặc test framework với harness đủ dependencies, tên/bundle rõ ràng, hỗ trợ bare-metal ELF ARM1136; giữ nguyên v8/v9 và 7 engines. **Không có Nokia N95 Symbian boot**.
