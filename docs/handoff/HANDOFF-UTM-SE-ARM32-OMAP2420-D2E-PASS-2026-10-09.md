# HANDOFF — UTM SE Lite ARM32 → OMAP2420 / Nokia N95 (checkpoint 2026-10-09)

> **Dành cho cuộc trò chuyện ChatGPT tiếp theo.** Đọc mục 0 và 9 trước khi sửa bất kỳ mã nguồn nào.
>
> **Trạng thái mới nhất:** GATE D2e BUILD PASS. QEMU `qemu-arm-softmmu.framework` cho iOS/ARM64 host đã cross-compile với bốn machine chẩn đoán ARM1136/OMAP2, và bảy framework gốc được bảo toàn. **Chưa có IPA v10, chưa chạy OMAP2420 trên iPhone, chưa boot Nokia N95/Symbian.**

## 0. Mục tiêu, phạm vi và các bất biến

- **Repo chính:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS
- **Nhánh hiện tại cần tiếp tục:** `research/n95-omap2420-gate-d2e-ios-tci`.
- **Nhánh khởi nguồn đã DEVICE PASS:** UTM SE Lite **v8** (ARM64 Linux Alpine) và nhánh thử nghiệm **v9** `feat/arm32-linux-lite-v9` (ARM32/ARMv7 Linux Alpine); **KHÔNG chạm, KHÔNG merge code chưa test vào, KHÔNG làm hỏng hai baseline này**.
- **Các bản thử nghiệm mới phải tách nhánh và bundle ID riêng** để iPhone có thể giữ bản v8/v9. Bundle ID trước đó:
  - v8: `com.phai.nokias60.UTM-SE`.
  - v9: `com.phai.nokias60.arm32.UTM-SE`.
  - v10: **chưa đặt/chưa build**; chọn một bundle ID mới không trùng hai bản cũ.
- **Máy thử:** iPhone iOS 18.7; người dùng ký IPA bằng ESign, chỉ có iPhone, muốn giao diện/hướng dẫn tiếng Việt; mục tiêu minimum iOS 15.0 và QEMU TCI không JIT.
- **QEMU nguồn được ghim:** `utmapp/qemu@v10.0.12-utm`. **UTM nguồn được ghim:** commit `7eadb056ae0f91d979059544d0ddcd2d5a40be92`. Có sysroot iOS ARM64 TCI đã dựng, giữ 7 engine nguyên bản.
- Đây là **nghiên cứu giả lập hệ thống cũ**, không phân phối firmware/ROM Nokia có bản quyền, không liên quan khai thác, xâm nhập, malware, credentials, persistence hay tấn công mạng.
- **Phân biệt bằng chứng:**
  1. Build PASS: source/compile/link/artifacts;
  2. Linux host device simulation PASS: QEMU chạy guest ARMv6 và thực thi MMIO ở runner Linux;
  3. iPhone DEVICE PASS: máy ảo chạy trực tiếp trên điện thoại với log/screenshot;
  4. **Symbian/N95 boot PASS chưa có**. Tuyệt đối không đánh đồng các mức.

## 1. Kiến trúc và mốc chạy trên iPhone

### 1.1. v8: bản ổn định được người dùng thử
- UTM SE Lite đã Việt hóa, chọn tệp qua file picker UIKit, chạy Alpine Linux ARM64, ổ đĩa/network và tắt/khởi động lại hoạt động. Giữ nguyên 7 engine QEMU gốc.
- Không dùng nhánh v8 để thử thay đổi model CPU/SoC.

### 1.2. v9: ARM32/ARMv7 thật trên iPhone — DEVICE PASS
- Tích hợp **engine thứ 8** `qemu-arm-softmmu.framework` (iPhone ARM64 host → QEMU TCI/no JIT → ARMv7 guest), chạy QEMU `-M virt -cpu cortex-a15` với Alpine Linux ARMv7 initramfs.
- [Run v9 #37890960534](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534), [IPA artifact #11598800821](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534/artifacts/11598800821).
- Bộ Alpine ARMv7 đã Linux-host SMOKE PASS [run #37887218792](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37887218792), [boot-kit #11596817132](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37887218792/artifacts/11596817132).
- Thiết lập iPhone đã dùng: ARM32 (aarch32), `virt`, CPU 1, RAM khoảng 256 MiB, serial-only, kernel `vmlinuz-lts` + `initramfs-armv7.cpio.gz`, TCI/no JIT, không cần màn hình đồ họa. Kết quả guest:
  ```text
  ALPINE_ARM32_BOOT=PASS
  ALPINE_ARCH=armv7l
  ALPINE_RELEASE=3.24.2
  ALPINE_ARM32_SMOKE_PASS
  ~ # uname -m
  armv7l
  ~ # cat /etc/alpine-release
  3.24.2
  ```
- Người dùng **đã xác nhận tắt rồi khởi động lại PASS** qua ảnh mới; shell/bàn phím thực thi lệnh PASS. **Đây là ARMv7 Cortex-A15 trên machine virt, không phải ARM1136 hoặc OMAP2420**.
- Cấu hình v9 lúc đầu bị `QEMU exited with code -1` vì parser UTM tách chuỗi sau `-append`. Workaround thiết bị PASS là **bao nguyên chuỗi lệnh kernel trong đôi ngoặc kép**: `"console=ttyAMA0,115200 rdinit=/init loglevel=5"`; không đưa dấu ngoặc tròn.
- Nhánh `fix/arm32-linux-bootargs-v9-1` sửa parse -append, [run #37895064248](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37895064248) BUILD PASS, [IPA #11600685549](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37895064248/artifacts/11600685549). **v9.1 chưa được xác nhận DEVICE PASS; kết quả thiết bị là v9 + workaround**.
- [Checkpoint kết quả v9 trên iPhone](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/feat/arm32-linux-lite-v9/docs/nokia-n95-omap2420/UTM-LITE-V9-ARM32-DEVICE-TEST.md).

## 2. Tại sao cần máy giả lập riêng cho N95

- CPU Nokia N95 thuộc họ **ARM1136/ARMv6**, SoC OMAP2420; **không thể lấy boot Alpine ARMv7/Cortex-A15 trên máy `virt` làm bằng chứng** hỗ trợ firmware N95.
- QEMU UTM `v10.0.12-utm` vẫn có CPU `arm1136`, `arm1136-r2` và máy KZM dùng SoC **Freescale i.MX31**. **KZM không phải OMAP2420/N95**.
- Các nguồn OMAP2420 tham khảo trong QEMU 9.1.0: [`hw/arm/omap2.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/arm/omap2.c), [`hw/char/omap_uart.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/char/omap_uart.c), [`hw/timer/omap_gptimer.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/timer/omap_gptimer.c), [`hw/intc/omap_intc.c`](https://github.com/qemu/qemu/blob/v9.1.0/hw/intc/omap_intc.c), [`include/hw/arm/omap.h`](https://github.com/qemu/qemu/blob/v9.1.0/include/hw/arm/omap.h).
- QEMU 10 fork không có nguyên vẹn các máy N800/N810, OMAP2; không port nguyên source cũ thiếu phụ thuộc và cũng không quảng bá chúng là N95. Dự án tạo machine **chẩn đoán phần cứng tối giản** theo từng Gate.

## 3. Các Gate D1 đến D2d: đều Linux CI PASS (không phải iPhone)

| Gate | Chức năng Linux-host được chứng minh | GitHub Actions SUCCESS |
|---|---|---|
| D1 | ARM1136/ARMv6 lệnh `REV`, UART thật trên **KZM/i.MX31**, kết thúc QEMU sạch | [#37897640183](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37897640183) |
| D2a | Machine `omap2420-earlydiag`; ARM1136, ELF, SRAM/SDRAM read/write, RAM guard | [#37904307368](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37904307368) |
| D2b | `omap2420-uartdiag`; UART1 16550 TX thật qua serial-MMIO và vendor registers + hồi quy D2a | [#37906747406](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37906747406) |
| D2c | `omap2420-intcdiag`; UART1 RX loopback, INTC IRQ72 pending/mask/ack, ngoại lệ IRQ ARM1136 thật, hồi quy D2a/b | [#37911548247](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37911548247) |
| D2d | `omap2420-timerdiag`; PRCM clock gate, GPTimer1 virtual-clock/overflow IRQ37, CPU IRQ handler, soft-reset, hồi quy D2a/b/c | [#37917633717](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37917633717) |

### Địa chỉ và IRQ chẩn đoán

| Khối | MMIO / IRQ | Phạm vi thử |
|---|---|---|
| SRAM | `0x40200000`, độ dài `0xA0000` | RAM đầu/cuối vùng |
| SDRAM | `0x80000000`, 128 MiB mặc định | RAM, ELF tại `0x80010000` |
| UART1 | `0x4806A000`, IRQ **72** | 16550/serial-mm + vendor registers subset |
| OMAP2 INTC | `0x480FE000` | Ba bank 32 nguồn; IRQ72 và IRQ37, mask/ack, không phải full priority/FIQ |
| PRCM | `0x48008000` | clock enable subset cho GPT1 |
| GPTimer1 | `0x48028000`, IRQ **37** | QEMU virtual-clock ~32.768 kHz, overflow, reset |

### Tệp gốc D2a–D2d trên nhánh D2e (được kế thừa)

- `tests/omap2420/omap2420_diag_d2a.c` → `omap2420-earlydiag`.
- `tests/omap2420/omap2420_diag_d2b.c` → `omap2420-uartdiag`.
- `tests/omap2420/omap2420_diag_d2c.c` → `omap2420-intcdiag`.
- `tests/omap2420/omap2420_diag_d2d.c` → `omap2420-timerdiag`.
- `tests/omap2420/arm1136_d2a_memory.S`, `arm1136_d2b_uart.S`, `arm1136_d2c_intc_uart.S`, `arm1136_d2d_prcm_gpt1.S`: bare-metal ARMv6 ELF diagnostics, dùng thật UART khi có; semihosting chỉ để kết thúc process.
- `scripts/test_omap2420_prcm_gptimer_gate_d2d.sh` và workflow `.github/workflows/20-n95-omap2420-gate-d2d.yml`: kiểm thử Linux host bằng source ghim và regression của các Gate.
- [Checkpoint D2a](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2a/docs/nokia-n95-omap2420/GATE-D2A-EARLYDIAG-MACHINE-CHECKPOINT.md), [D2b](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2b/docs/nokia-n95-omap2420/GATE-D2B-OMAP2420-UART1-CHECKPOINT.md), [D2c](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2c/docs/nokia-n95-omap2420/GATE-D2C-UART1-RX-INTC-IRQ72-CHECKPOINT.md), [D2d](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2d/docs/nokia-n95-omap2420/GATE-D2D-PRCM-GPTIMER1-IRQ37-CHECKPOINT.md).

## 4. Gate D2e: cross-compile framework iOS — BUILD PASS CUỐI CÙNG

- **Nhánh:** `research/n95-omap2420-gate-d2e-ios-tci`.
- **Script:** `scripts/diagnose_omap2420_d2e_ios_tci.sh`.
- **Workflow:** `.github/workflows/21-n95-omap2420-gate-d2e-ios-tci.yml`.
- Pin UTM commit `7eadb056ae0f91d979059544d0ddcd2d5a40be92`, QEMU `v10.0.12-utm`. MacOS GitHub runner, sysroot iOS ARM64 TCI. Chèn bốn machine D2a–D2d vào **cây QEMU tạm**, biên dịch `arm-softmmu` thành Mach-O arm64 + đóng `qemu-arm-softmmu.framework`, min iOS 15, không JIT.
- **Run cuối [#37924268847](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847): COMPLETED / SUCCESS**. Run head commit `d61bb4eed4b43ab9d7a3de55f4f6167021e5e24a`; checkpoint được cập nhật ở commit `2f14afc26d424e062885cfb9a2d78793369c5e89`.
- **Framework artifact [#11613786984](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613786984):** `QEMU-OMAP2420-D2E-IOS-TCI-ARM32-RESEARCH-FRAMEWORK`; zip ~24.3 MB, **không phải IPA**.
- **Logs [#11613886670](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613886670):** `Nokia-N95-OMAP2420-D2E-IOS-TCI-DIAGNOSTIC-LOGS`.

Các marker được xác nhận trong log cuối:

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

**Diễn giải chính xác:** D2e chứng minh build/link/stage/framework có đăng ký bốn QOM machine trên iOS ARM64 host. Việc tìm tên QOM trong Mach-O **không phải** chạy máy OMAP2420 trên iPhone.

## 5. Lịch sử lỗi D2e đã sửa: KHÔNG lặp lại

1. **Run #37920944620 — FAILURE** tại `verify-embedded-machine-registrations`. QEMU biên dịch xong bốn object, link thành `libqemu-arm-softmmu.dylib`, đóng framework, nhưng `strings "$FW/qemu-arm-softmmu" | grep 'omap2420-'` báo thiếu. Đây không phải compiler failure.
2. **Run #37922317635 — FAILURE**: chuyển sang Python quét binary nhưng **vẫn tìm sai** `b"omap2420-earlydiag\\0"`, báo thiếu cả raw/staged.
3. **Nguyên nhân gốc:** macro `DEFINE_MACHINE` QEMU đặt tên QOM nội bộ qua `MACHINE_TYPE_NAME(name) = name + "-machine"`, từ [`include/hw/boards.h` QEMU10](https://github.com/utmapp/qemu/blob/v10.0.12-utm/include/hw/boards.h). Tên đăng ký thực tế, ví dụ `omap2420-earlydiag-machine\\0`.
4. **Commit sửa cuối `d61bb4e`** đổi phép quét exact byte sequence thành `name + b"-machine\\0"` trên cả raw Mach-O và packaged framework, **giữ kiểm tra đủ 4 machine** và 7 engine nguyên bản. Run #37924268847 SUCCESS.
5. **Cảnh báo linker cần theo dõi:** `ui_spice-display-metal.m.o` được build với SDK iOS 26.5, cao hơn deployment target iOS 15.0. Không chặn link, nhưng **iPhone 18.7 runtime vẫn cần test thật**. Không dùng warning này làm kết luận chạy hay crash.
6. [Checkpoint D2e đã cập nhật kết quả PASS](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2e-ios-tci/docs/nokia-n95-omap2420/GATE-D2E-IOS-TCI-FRAMEWORK-CHECKPOINT.md).

## 6. Những thứ CHƯA ĐƯỢC THỰC HIỆN

- **Chưa có IPA v10** cài bằng ESign để chạy OMAP diagnostic trên iPhone.
- **Chưa có ARM1136/OMAP2 runtime DEVICE PASS trên iPhone**: chỉ ARMv7/`virt` v9 đã chạy.
- **Chưa có đầy đủ OMAP2420/Nokia N95**: thiếu hệ clock/PRCM production, L4, GPMC/OneNAND, đầy đủ timer/IRQ/FIQ/priority, DMA, màn hình, input/keypad, audio, USB, các thiết bị ngoại vi/N95 board specifics và quy trình ROM/firmware.
- **Chưa boot Symbian, chưa vào Home S60** và không được tuyên bố làm được.
- Không dùng kernel Alpine **ARMv7** hiện tại để test ARM1136 **ARMv6**. Bài thử tiếp theo phải dùng ELF ARMv6 bare-metal phù hợp hoặc Linux ARMv6 được chuẩn bị riêng.
- Không chuyển sang dự án EKA2L1/CompatBoot; repo này dành cho hướng UTM/QEMU phần cứng.

## 7. Phương án triển khai ngay tiếp theo: UTM SE Lite v10 — OMAP2420 Diagnostic (IPA riêng)

**Điều kiện đầu vào đã đáp ứng:** framework D2e BUILD PASS, 4 QOM names tồn tại trong framework iOS đã stage, 7 framework gốc bảo toàn.

**Các bước thực hiện đề xuất:**

1. Tạo nhánh **riêng từ D2e**, tên gợi ý `feat/omap2420-diagnostic-ipa-v10`; đặt **bundle ID riêng** (ví dụ `com.phai.nokias60.omapdiag.UTM-SE`, chỉ là đề xuất, chưa được đăng ký/build); dựa trên cấu trúc app v9 **đã DEVICE PASS**, UI Việt hóa và iOS file picker đã hoạt động.
2. Sử dụng framework ARM32/OMAP TCI từ artifact D2e cùng sysroot khớp; **kiểm dependencies/rpath/code-signature/linkage**, cấu hình `-M omap2420-timerdiag -cpu arm1136` chạy trong engine ARM32, không đổi tên `virt` thành OMAP.
3. Thêm một **mẫu VM chẩn đoán rõ nhãn** “OMAP2420 Diagnostic (ARM1136, chưa phải Nokia N95)” hoặc hỗ trợ QEMU Arguments tùy chỉnh chọn machine. Không thể hứa UTM wizard hiện đã có machine này: phải thêm nguồn cấu hình/đường chạy đúng nếu thiếu.
4. Bảo đảm có thể chọn tệp **ELF ARMv6 chẩn đoán D2d** bằng file picker iOS. Chương trình D2d xuất marker qua UART1 serial-MMIO và dùng semihosting để exit; kiểm xử lý serial/console và không bị parser tách argv `-kernel`, `-M`, `-semihosting-config` hoặc đường tệp.
5. Chạy GitHub Actions build IPA: CI checks framework ARM64 Mach-O, 4 machine registrations, 7 framework integrity, đúng provisioning/ESign packaging, bản tiếng Việt, iOS min 15; xuất build log và IPA artifact riêng.
6. Sau khi IPA build PASS, người dùng cài bản **v10 song song v8/v9** bằng ESign trên iPhone 18.7, khởi chạy ELF chẩn đoán và gửi log/video. Chỉ công bố **D2e DEVICE PASS** khi thấy marker UART/INTC/PRCM/GPTimer và app không crash; nếu fail sửa từ crash/log.
7. Chỉ khi iPhone ARM1136/OMAP diagnostic PASS mới lên kế hoạch đầy đủ phần cứng N95 cho Symbian. Tiếp tục giữ tách riêng baseline.

**Điều không được làm:** dùng lại bundle ID v8/v9, thay framework engine 7 bản gốc, thay firmware người dùng, gộp branch thử nghiệm chưa pass vào app ổn định, hoặc tuyên bố N95 boot chỉ vì framework build.

## 8. Link điều hướng nhanh

- **Repo:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS
- **Nhánh D2e:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/tree/research/n95-omap2420-gate-d2e-ios-tci
- **Build D2e PASS:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847
- **Framework D2e:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613786984
- **Logs D2e:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37924268847/artifacts/11613886670
- **D2e checkpoint:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/blob/research/n95-omap2420-gate-d2e-ios-tci/docs/nokia-n95-omap2420/GATE-D2E-IOS-TCI-FRAMEWORK-CHECKPOINT.md

## 9. LỆNH MỞ CUỘC TRÒ CHUYỆN MỚI (sao chép nguyên văn)

```text
Tiếp tục dự án UTM SE Lite ARM32 → Nokia N95/OMAP2420 theo HANDOFF:
docs/handoff/HANDOFF-UTM-SE-ARM32-OMAP2420-D2E-PASS-2026-10-09.md
trong repo phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS,
nhánh research/n95-omap2420-gate-d2e-ios-tci.

Trạng thái cuối: Gate D2e BUILD PASS, GitHub Actions #37924268847.
Framework QEMU ARM32 iOS TCI có bốn máy chẩn đoán:
omap2420-earlydiag, omap2420-uartdiag, omap2420-intcdiag,
omap2420-timerdiag; artifact #11613786984; log #11613886670;
bảy framework gốc không đổi.

Gate D1-D2d PASS trên Linux-host CI, chưa có OMAP2420 DEVICE PASS
trên iPhone. UTM SE Lite v8 ARM64 và v9 ARMv7 đã DEVICE PASS
trên iPhone và phải giữ nguyên.

Hãy triển khai bước tiếp theo: chuẩn bị build IPA v10 OMAP2420 Diagnostic
tách nhánh và bundle ID riêng, hỗ trợ chọn ELF ARMv6, khởi động
-M omap2420-timerdiag -cpu arm1136 qua engine iOS TCI/no-JIT,
thêm logging/artifact và kiểm lỗi theo Actions. Không thay v8/v9,
không đổi firmware, không gọi đây là Symbian/Nokia N95 boot.
Giao tiếp hoàn toàn bằng tiếng Việt.
```

---

**Kết luận chuyển giao:** D2e đã giải quyết được cross-compile iOS framework và xác nhận 4 QOM machine registrations; việc cần làm **kế tiếp là tích hợp IPA v10 và thử thật trên iPhone**, tuyệt đối không lặp lại các bài CPU/Linux đã PASS hay đánh tráo mức chứng cứ.
