# UTM SE Lite v9 — Linux ARM32 trên iPhone (thử nghiệm)

**Ngày:** 2026-10-09 (ICT)  
**Nhánh triển khai:** `feat/arm32-linux-lite-v9` (độc lập với baseline v8)  
**Thiết bị mục tiêu:** iOS 15.0+ ARM64, ESign, TCI/no-JIT  
**Trạng thái:** đang xác minh GitHub Actions, chưa có DEVICE PASS.

## Phân biệt các mốc

1. **Gate A PASS:** [ARM32 QEMU iOS TCI framework #37856923827](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37856923827), xác minh biên dịch và đóng framework trên macOS, 7 engine cũ nguyên SHA256.
2. **Gate A2 PASS trên máy Linux của GitHub:** [Alpine ARM32 virt smoke #37887218792](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37887218792). Log có `ALPINE_ARM32_BOOT=PASS`, `ALPINE_ARCH=armv7l`.
3. **Gate B, v9 iOS IPA:** [workflow `14-lite-v9-arm32-linux-ipa.yml`](../../.github/workflows/14-lite-v9-arm32-linux-ipa.yml), lấy sysroot UTM 7 engine và ARM32 framework trên, biên dịch frontend UTM có preset máy ảo ARM32, chép tài nguyên Việt hóa từ v8, đóng IPA và lưu log. **BUILD PASS phải được kiểm tra trên workflow, không suy ra từ A/A2.**
4. **Gate C, iPhone:** anh cài v9 bằng ESign và kiểm tra Linux ARM32 thực sự khởi động trên iPhone. **Không tuyên bố pass trước khi có log/video từ thiết bị.**

## Hàng rào baseline v8

- **Không sửa** nhánh `feat/vi-localization-lite-v8`, IPA run #37788063413, 7 framework v8 đã test.
- v9 dùng bundle ID khác: `com.phai.nokias60.arm32.UTM-SE`, nên dự định cài song song với v8.
- v9 sử dụng chung mã UTM upstream pinned `7eadb056ae0f91d979059544d0ddcd2d5a40be92`, nhưng thêm framework `qemu-arm-softmmu.framework` vào **sysroot tạm của riêng GitHub runner** và thêm lựa chọn ARM32 trong `VMWizardHardwareView.swift`.
- Giao diện chọn file UIKit kiểu v8 có thể nhập cả kernel/initramfs; v9 giữ workaround ISO từ v7 và các tệp Việt hóa của v8.
- v9 **chưa có** board OMAP2420, firmware Nokia N95, Symbian S60 hoặc boot N95. Không trộn repository EKA2L1 OMAP2420.

## Hai file Linux cần tải trên iPhone

Tải [`Alpine-3.24.2-ARM32-QEMU-VIRT-BOOT-KIT` từ GitHub Actions #37887218792](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37887218792/artifacts/11596817132). Giải nén ZIP trong **Tệp (Files)**; chọn:

- `vmlinuz-lts` — Linux kernel ARMv7;
- `initramfs-armv7.cpio.gz` — hệ thống Alpine ARMv7 có sẵn script khởi động.

Không chọn file ZIP trực tiếp để boot, không dùng file ISO Alpine ARMv7 trên v8.

## Hướng dẫn test sau khi **v9 IPA build PASS**

1. Tải IPA v9 từ artifact workflow `UTM-SE-LITE-V9-ARM32-LINUX-IPA`, ký và cài bằng ESign. Kiểm tra iPhone còn bản v8 đã PASS.
2. Tạo máy ảo mới → **Linux** → **Khởi động bằng kernel** (Boot from kernel image).
3. Bấm chọn **Linux kernel** → chọn `vmlinuz-lts`; **Initial RAM disk** → chọn `initramfs-armv7.cpio.gz`; **Boot Arguments** nhập `console=ttyAMA0,115200 rdinit=/init loglevel=5`.
4. Ở mục **Hardware → Machine**, chọn `Linux ARM32 (ARMv7) — QEMU virt [thu nghiem]`. Giữ **RAM 256 MiB**, **1 CPU**, không bật JIT/Hypervisor. Nếu muốn thử hiệu năng ban đầu, không bật GPU 3D.
5. Kiểm tra mục **Display Output** nên tắt xuất hình (serial console) để quan sát boot ARM32. Lưu máy ảo và khởi động.
6. Trong terminal, tìm `ALPINE_ARM32_BOOT=PASS`, `ALPINE_ARCH=armv7l`, `ALPINE_ARM32_SMOKE_PASS`. Thử gõ `uname -m` (mong đợi `armv7l`), `cat /etc/alpine-release` (mong đợi `3.24.2`), sau đó `poweroff -f`.
7. Thử tắt và khởi động lại; nếu có crash, gửi log, ảnh/video. Test duy nhất là trên IPA v9, không làm mất baseline v8.

## Tiêu chí và lỗi cần lưu

- **BUILD PASS:** đủ 8 framework; `qemu-arm-softmmu.framework` được nhúng trong IPA; `Info.plist` có iOS 15.0+ và bundle v9 khác v8; log build xuất riêng.
- **DEVICE PASS:** VM ARM32 chạy lệnh ARMv7 thật trên iPhone, không crash, serial/terminal hiện log; tắt/mở lại ổn. Chưa đánh giá thực thi ARM1136 hay Nokia OMAP2420.
- **Nếu máy ảo không khởi động:** cần log `QEMU` và video trạng thái console; không kết luận boot PASS từ việc cài IPA thành công.
- **Nếu máy ảo không thể chọn kernel/initramfs:** ghi nhận lỗi UIKit import cụ thể; ứng dụng v8 đã PASS với ISO nhưng đường đi kernel/initrd cần device test riêng.

## Liên kết

- [Source/checkpoint ARM32](ARM32-TCI-DIAGNOSTIC-CHECKPOINT.md)
- [GitHub Actions của repo](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions)
- [Nokia N95 QEMU source inventory](QEMU-SOURCE-INVENTORY.md)

## CI lần 1 và bản sửa — 2026-10-09

- [Run `#37888483886`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37888483886): **FAIL** ở bước `Verify ARM32 engine actually embedded in Xcode archive` sau khi `Build independently installable ARM32 v9 app` hoàn tất **SUCCESS**. Xcode archive đã xây dựng được app với bundle ID `com.phai.nokias60.arm32.UTM-SE`, nhưng kiểm tra ngay sau đó thoát 1 trước khi đọc bundle ID (phép thử đầu tiên: `test -s .../Frameworks/qemu-arm-softmmu.framework/qemu-arm-softmmu`). Vì vậy `IPA v9` **chưa xuất**.
- Nguyên nhân gần: Xcode `iOS-SE` không tự chép `qemu-arm-softmmu.framework` trong sysroot vào `.app/Frameworks` dù framework ARM32 đã được tải và xác minh đúng kiến trúc host ARM64 trước build. Không phải lỗi Swift compile.
- [Commit `1cd545f0`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/1cd545f08281c91b028c65c66ddfceaa5d2aeeff): opt-in `ARM32_EXTRA_FRAMEWORK` vào `scripts/build_utm_se.sh`, copy `qemu-arm-softmmu.framework` sau khi archive xong nhưng **trước khi đóng gói IPA gốc**, so sánh bytes bằng `cmp`, xuất SHA256 và `otool`. Không ảnh hưởng quy trình v8.
- [Commit `b6575c81`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/b6575c81796edabb985de4c6cb1e274fdfaa1604): `REQUIRE_ARM32=1` buộc script strip/xác minh **8** frameworks v9, giữ mặc định 7 cho nhánh khác.
- [Commit `b64194c2`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/b64194c226bf87ddf7da11910ff462cb4fd62f04): workflow truyền opt-in, xác minh SHA256 của ARM32 trong archive, kiểm tra IPA chứa đủ 8 engine và giao diện Việt hóa.
- [Commit `00d21195`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/commit/00d21195d913e61e4dc59c077968f0a4466dc208): CI chỉ chạy commit thử nghiệm mới nhất thay vì chờ hết lượt build cũ (`cancel-in-progress: true`).
- [Run v9 đã sửa `#37890960534`](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534): **chưa có kết luận build PASS/FAIL** khi ghi checkpoint; cần kiểm tra đủ các bước để lấy artifact IPA hoặc lỗi mới.
- **V8 baseline:** giữ nguyên `feat/vi-localization-lite-v8`, hash IPA đã device-PASS; **chưa cần người dùng cài v9 hoặc test Nokia**. Chỉ thông báo `DEVICE PASS` sau khi iPhone thật chạy Linux ARMv7 (`uname -m` = `armv7l`).

## Gate B — iOS ARM32 v9 IPA BUILD PASS (2026-10-09 ICT)

- **Run [#37890960534](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534) COMPLETED / SUCCESS** trên branch `feat/arm32-linux-lite-v9`, commit `00d21195d913e61e4dc59c077968f0a4466dc208`.
- **IPA unsigned:** [`NokiaUTM-SE-Lite-v9-ARM32-Viet-IPA` artifact #11598800821](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534/artifacts/11598800821). Dung lượng GitHub artifact 138361490 bytes. Tải file ZIP từ artifact, giải nén để lấy `NokiaUTM-SE-Lite-v9-ARM32-Viet-unsigned.ipa`, ký ESign rồi mới cài iPhone.
- **Chẩn đoán:** [`NokiaUTM-SE-Lite-v9-ARM32-BUILD-LOGS` artifact #11599120066](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37890960534/artifacts/11599120066).
- Log bảo đảm: `ARM32_FRAMEWORK_STAGED_BEFORE_IPA=PASS`; `ARM32_EMBEDDED_SHA256_MATCH=PASS`; `STRIP=PASS ENGINE_COUNT=8`; `ARM32_8_ENGINES_IN_IPA=PASS`; `ARM32_IPA_CONTENT_CHECK=PASS`; `STATUS=PASS`.
- v9 có bundle ID riêng `com.phai.nokias60.arm32.UTM-SE`, minimum iOS 15.0 và nội dung tiếng Việt sao chép từ bản v8 device-PASS.
- **Không đồng nghĩa DEVICE PASS:** log xác định `IPHONE_DEVICE_BOOT=NOT_YET_TESTED`. Thiết bị iPhone phải chạy kernel và initramfs Alpine ARMv7 thử nghiệm, quan sát `ALPINE_ARCH=armv7l` rồi tắt/khởi động lại để xác nhận.
- Không có Nokia N95/OMAP2420/Symbian firmware. v8 baseline vẫn nguyên, không thay đổi.

## Gate C1 — ARM32 Linux kernel+initramfs DEVICE BOOT PASS (2026-10-09 ICT)

**Bằng chứng do người kiểm thử cung cấp:** ảnh chụp màn hình terminal từ UTM SE Lite **v9** trên iPhone, sau khi áp dụng workaround cho `-append`: giữ toàn bộ chuỗi `"console=ttyAMA0,115200 rdinit=/init loglevel=5"` trong một đối số. Ảnh ghi rõ:

```text
=== Alpine Linux ARM32 QEMU virt ===
ALPINE_ARM32_BOOT=PASS
ALPINE_ARCH=armv7l
ALPINE_RELEASE=3.24.2
ALPINE_ARM32_SMOKE_PASS
Goi lenh: uname -m ; cat /etc/alpine-release ; poweroff -f
/bin/sh: can't access tty; job control turned off
~ #
```

- **Gate C1 PASS:** iPhone đã thực thi Linux ARMv7 thật trong `qemu-arm-softmmu.framework` TCI/no-JIT và vào shell BusyBox/Alpine. Kết quả vượt mốc build-only, chưa phải Nokia/Symbian emulation.
- Các cảnh báo `Spectre v2`, `/cpus/cpu@0 missing clock-frequency`, `/bin/sh: can't access tty; job control turned off` xuất hiện nhưng không cản boot hay shell.
- **Gate C2 pending:** người kiểm thử cần gõ `uname -m` (`armv7l`), `cat /etc/alpine-release` (`3.24.2`), `poweroff -f`, và khởi động lại lần nữa. Không gán DEVICE STABILITY PASS trước khi nhận kết quả.
- **Root cause v9 đã xác nhận bằng test thực tế:** khi dùng dấu ngoặc kép để giữ kernel command line thành một `-append` argv, Linux boot thành công. Bản v9.1 sửa parser được build riêng để loại bỏ bước workaround; chưa phải bản được người dùng thử trong ảnh này.
- Giữ nguyên baseline v8, firmware Nokia N95 và OMAP2420 vẫn `NOT_IMPLEMENTED`. Tập trung bước tiếp theo vào iPhone ARM32 shutdown/restart và sau đó khám phá đường hỗ trợ ARM1136 / OMAP2420 ở nhánh nghiên cứu riêng.

## Gate C1b — ARM32 Linux shell command execution PASS (2026-10-09 ICT)

Ảnh chụp màn hình iPhone do người kiểm thử cung cấp ngay sau Gate C1 cho thấy `~ # uname -m` trả về chính xác `armv7l` và `~ # cat /etc/alpine-release` trả về `3.24.2` trên UTM SE Lite v9. Bàn phím iPhone được mở và terminal nhận/thực thi lệnh thực tế. Đây là **bằng chứng thực thi lệnh ARM32 trên thiết bị**, vượt qua việc chỉ in marker từ startup script.

Lệnh gõ sai `cat /etc:` trước đó trả về `No such file or directory`; thử lại đường dẫn chính xác thành công, đây là lỗi nhập lệnh thông thường, không phải lỗi VM.

**Gate C1b = PASS: shell commands / ARMv7l / Alpine 3.24.2 / iPhone keyboard.**

**Gate C2 = PENDING:** chưa nhận bằng chứng lệnh `poweroff -f`, VM tắt, sau đó `Play` và khởi động lần thứ hai. Không đánh dấu STABILITY PASS trước bằng chứng đó.

Giữ nguyên baseline v8 và ranh giới Nokia N95 OMAP2420 = NOT_IMPLEMENTED.
