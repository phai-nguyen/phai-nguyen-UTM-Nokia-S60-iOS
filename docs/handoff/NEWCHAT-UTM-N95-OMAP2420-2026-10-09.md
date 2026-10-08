# HANDOFF — UTM SE Lite v8 đã BOOT PASS trên iPhone → nghiên cứu Nokia N95 / OMAP2420

**Ngày chốt:** 09/10/2026 (giờ Việt Nam).  
**Nguồn:** cuộc hội thoại UTM–Nokia S60 đã kiểm thử thực tế v1–v8 và bắt đầu khảo sát mã QEMU ARM32/OMAP2.  
**Mục đích:** chuyển sang hội thoại ChatGPT mới, **không bắt người dùng làm lại các phép thử đã PASS**.  
**Ngôn ngữ:** trao đổi và hướng dẫn trên iPhone **bằng tiếng Việt**, xưng anh/em. Người dùng chỉ sử dụng iPhone; nhờ GitHub Actions/Codex để build, ký IPA bằng ESign.

## 0. TRẠNG THÁI CHỐT — ĐỌC TRƯỚC

**ĐÃ PASS trên iPhone:** `Nokia UTM SE Lite v8 — Tiếng Việt` chạy trực tiếp trên iOS, không JIT; chọn và sao chép ISO bằng bộ chọn UIKit; lưu máy ảo với ISO nội bộ; boot Alpine Linux aarch64 tới serial console; đăng nhập root; nhận ổ 4 GiB và CD-ROM; DHCP/NAT/DNS/HTTP; `poweroff` và mở lại máy ảo bình thường. Giao diện tiếng Việt hoạt động, **còn một số mục tiếng Anh**.

**CHƯA THỰC HIỆN:** chưa có `qemu-system-arm`/ARM32 engine trong bản Lite v8, chưa có Nokia N95 machine/OMAP2420 trong IPA, chưa nạp/boot firmware Nokia N95; chưa chứng minh cài Linux vào ổ cứng hay độ bền dữ liệu sau restart. **Không đánh đồng ARM64 Alpine với Nokia N95 ARM32.**

**BƯỚC ĐANG DỞ:** mới bắt đầu khảo sát sự tồn tại và khả năng chuyển mã QEMU OMAP2/N-series cũ vào UTM/QEMU hiện tại. Chưa hoàn tất bảng tương thích mã nguồn, chưa sửa phần cứng, chưa build ARM32 hay IPA Nokia. Đừng tuyên bố đã triển khai OMAP2420.

## 1. Repo, nhánh, bản nền, đường dẫn

- **Repo dự án này:** https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS
- **Bản nguồn UTM pinned:** `utmapp/UTM` commit `7eadb056ae0f91d979059544d0ddcd2d5a40be92`.
- **Sysroot UTM SE iOS TCI/no JIT đã dùng để build:** upstream UTM GitHub Actions run `36090554968`, artifact `Sysroot-ios-tci-arm64`. Workflow trong repo clone upstream đúng commit và tải sysroot này, không build lại mọi thư viện nếu chỉ sửa frontend.
- **Thiết bị mục tiêu chạy app:** iPhone iOS 18.7 (người dùng kiểm thử); app yêu cầu tối thiểu iOS **15.0**, bundle ID UTM `com.phai.nokias60.UTM-SE`, ký IPA unsigned bằng **ESign**.
- **Bản iOS đã xác nhận trên máy:** `NokiaUTM-SE-Lite-v8-TiengViet-unsigned.ipa` từ [Actions #37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413), [IPA artifact #11554159956](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413/artifacts/11554159956); SHA256 `671535ffec7f866688537ee86db8c5eb53aeccbd78f3fc517dcb9dcf871e6caa`, IPA ~121.1 MiB. **Đây là artifact đã test; không coi commit docs mới hơn trên branch là binary mới đã test.**
- **Nhánh baseline UI:** `feat/vi-localization-lite-v8`; [PR #10](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/pull/10) đang **OPEN / DRAFT, chưa merge** (đã kiểm tra bằng GitHub API 09/10).
- **Nhánh nghiên cứu mới cần tiếp tục:** `research/n95-omap2420-arm32` (được tạo từ v8). **Không can thiệp hoặc tự merge baseline v8**.
- **Kế hoạch nghiên cứu đã commit:** [docs/nokia-n95-omap2420/STARTUP-PLAN.md](../nokia-n95-omap2420/STARTUP-PLAN.md).
- **Checkpoint kiểm thử chi tiết:** [docs/checkpoints/2026-10-08-ALPINE-AARCH64-DEVICE-BOOT-PASS.md](../checkpoints/2026-10-08-ALPINE-AARCH64-DEVICE-BOOT-PASS.md).
- **Độc lập:** `phai-nguyen/EKA2L1-S60-OMAP2420-iOS` là **repo khác**; không trộn code, trạng thái hoặc firmware giữa hai dự án.

## 2. Lịch sử v1–v8 và chẩn đoán quan trọng

| Bản | Build/PR | Kết quả thực tế / bài học |
|---|---|---|
| **v1 UTM SE full** | Actions [#37733615950](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950) | IPA ~206.8 MiB, cài ESign và mở app PASS. |
| **Lite v1** | PR #3 closed | **CRASH lúc mở** vì bỏ 6 QEMU frameworks nhưng Mach-O còn strong-linked. iOS dyld thiếu `qemu-m68k-softmmu.framework`. **Không xóa framework tùy tiện.** |
| **Lite v2 dyld-safe** | Actions [#37743881078](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37743881078), PR #4 merged | Giữ **đầy đủ 7 framework** và strip ký hiệu không cần thiết. IPA ~121.09 MiB; app launch DEVICE PASS. Đây là chiến lược Lite đúng. |
| **Lite v3 ISO picker** | Actions [#37746120740](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37746120740), PR #5 closed | Thay SwiftUI `.fileImporter` `UTType.data`→`.item`; build PASS nhưng **vẫn không chọn được ISO** trên iPhone ESign. |
| **Lite v4 Documents fallback** | Actions [#37753395372](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37753395372), PR #6 draft | Thử liệt kê ISO trong sandbox Documents để tránh picker; build PASS, **chưa có xác nhận device PASS**. |
| **v5 ESign Match research** | PR #7 draft | Công cụ tùy chọn đổi Bundle ID theo profile; **không phải fix được xác nhận, không có IPA device-PASS**. Phân tích binary EKA2L1 cho thấy mismatch Bundle ID/App ID **không nhất thiết** làm picker lỗi. Không gán cho UTM Bundle ID đang dùng bởi EKA2L1. |
| **Lite v6 UIKit** | Actions [#37761715233](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37761715233), PR #8 draft | Dùng `UIDocumentPickerViewController` + delegate `didPickDocumentsAtURLs` + security-scoped `copyItem` đến Documents. **Chọn và nhập Alpine ISO DEVICE PASS**, nhưng khi Save máy ảo lỗi `Failed to access drive image path.` |
| **Lite v7 bundled ISO** | Actions [#37769341815](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37769341815), PR #9 draft | Giữ picker UIKit; ISO là **CD nội bộ raw/read-only** nên UTM lưu trong `.utm/Data`, tránh bookmark CD bên ngoài. v8 kế thừa và **Save/Boot DEVICE PASS**. |
| **Lite v8 Vietnamese** | Actions [#37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413), PR #10 draft | Thêm `vi.lproj` lên IPA unsigned v7 đã build: 422 mục dịch, 409/905 key bản địa hóa catalog (~45%). Mã Mach-O và 7 QEMU frameworks giữ nguyên; **giao diện Việt hóa và toàn bộ boot/network/lifecycle DEVICE PASS**. Còn vài mục tiếng Anh. |

### Các file kỹ thuật trọng yếu đã có trong repo

- `scripts/build_utm_se.sh`: archive scheme `iOS-SE` từ upstream UTM pinned trên macOS/Xcode, tạo IPA unsigned.
- `scripts/build_dyld_safe_lite.sh`: giữ nguyên đủ **7 QEMU engines** (`aarch64`, `i386`, `x86_64`, `ppc`, `ppc64`, `riscv64`, `m68k`) và strip an toàn; kiểm tra DYLD và ZIP.
- `scripts/patch_utm_ios26.py`: vá API SwiftUI/iOS SDK không tương thích iOS deployment 15.
- `scripts/patch_utm_uikit_copy_picker.py`: fix ISO chọn tệp kiểu EKA2L1 trên **iOS Linux wizard**; giữ nguyên picker nền tảng khác.
- `scripts/patch_utm_bundled_iso_drive.py`: CD `isExternal=false`, `isRawImage=true`, `isReadOnly=true` cho iOS Linux ISO; **không bỏ bản vá này**.
- `scripts/add_vi_localization.py` + `localization/vi-base.json`, `vi-essential-extra.json`: đóng gói tài nguyên ngôn ngữ Việt vào IPA v7, không thay đổi binaries.
- Workflows: `.github/workflows/09-uikit-copy-picker-v6.yml`, `10-bundled-iso-drive-v7.yml`, `11-lite-v8-vietnamese.yml`.
- Phương án UIKit đã được xác minh trước bằng IPA thật của `phai-nguyen/Eka2l1_bot_menu_simbiam`: delegate `didPickDocumentsAtURLs`, `asCopy:YES`, `startAccessingSecurityScopedResource`, copy vào Documents. Báo cáo [docs/EKA2L1-MENU-SIMBIAM-UIKIT-ISO-V6.md](../EKA2L1-MENU-SIMBIAM-UIKIT-ISO-V6.md), [binary audit](../EKA2L1-IPA-BINARY-PICKER-AUDIT.md), [signed-IPA forensic report](../EKA2L1-SIGNED-IPA-FORENSICS-2026-10-08.md) ở các nhánh PR tương ứng; có thể link trực tiếp PR #8/#7 khi cần.
- **ESign lưu ý:** binary EKA2L1 user đã ký có `CFBundleIdentifier=com.eka2l1.emulator` nhưng `application-identifier=3V48279JP4.app.lavender1865.valley8348`; user vẫn chọn được ROM. Không tuyên bố mismatch là nguyên nhân chắc chắn của lỗi UTM. Không upload profile, chứng chỉ, IPA signed có dữ liệu cá nhân lên repo.

## 3. Kết quả device-test cuối cùng trên iPhone — đã kiểm chứng bằng ảnh/video

**Cấu hình chạy được**: Alpine Linux `alpine-virt-3.24.2-aarch64.iso`; QEMU ARM64 `aarch64`; machine `virt-10.0`; RAM 1024 MiB; 1 CPU; ổ đĩa 4 GiB; CD ISO nội bộ; UEFI Boot bật; không JIT/Hypervisor; Alpine `virt` dùng serial console (tắt `Enable display output` khi tạo VM để terminal thay đồ họa). Khi bật graphical console từng thấy `Display output is not active`; user **tự vuốt về màn hình chính**, ứng dụng **không crash**.

Các ảnh kiểm thử thực tế:
- Alpine `Welcome to Alpine Linux 3.24`, `Kernel 6.18.52-0-virt on aarch64 (/dev/ttyAMA0)`, `localhost login:`: **BOOT PASS**.
- Đăng nhập `root` thành công, shell chạy: `uname -m` → `aarch64`; `cat /etc/alpine-release` → `3.24.2`. `lsblk: not found` là thiếu tiện ích trong Alpine `virt`, **không phải lỗi disk**.
- `cat /proc/partitions`: `vda 4194304` KiB (4 GiB), `sr0 91118` KiB (~89 MiB ISO), `loop0 17328` KiB. **Virtual disk/CD-ROM enumeration PASS**. Chưa kiểm thử ghi và tính bền vững.
- `ip addr show` ban đầu `eth0 DOWN`; sau `ip link set eth0 up` và `udhcpc -i eth0 -n -q` có DHCP lease `10.0.2.15`, server/gateway `10.0.2.2`, lease 86400 giây.
- `ip route`: `default via 10.0.2.2 dev eth0 metric 202` và `10.0.2.0/24 dev eth0 ... src 10.0.2.15`. **NAT route PASS**.
- `wget --spider http://example.com` → `Connecting to example.com (104.20.23.154:80)` và `remote file exists`. **DNS + outbound HTTP PASS** (không suy rộng thành HTTPS đầy đủ).
- Người dùng xác nhận cuối cùng: **“Máy ảo đã tắt và mở lại bình thường”**. **Shutdown/Restart DEVICE PASS**.
- Giao diện tiếng Việt đã hiện tốt nhưng còn `Debug Logging`, `UEFI Boot`, `RNG Device`, `Balloon Device`, `MAINTENANCE` và một số mô tả chưa dịch.

**Tất cả PASS trên chỉ áp dụng cho máy ảo Alpine ARM64 hiện tại, KHÔNG phải Nokia N95 hay Symbian.**

## 4. Nokia N95 / OMAP2420 — hướng nghiên cứu và tiến độ chính xác

Mục tiêu: bổ sung mô hình phần cứng **Nokia N95 / SoC OMAP2420** để tiến tới boot Symbian S60 firmware thật, chạy trên iOS qua QEMU TCI/no-JIT. Phải xây từng thành phần tương thích ARM32/board; không giả định iPhone ARM64 có thể boot ROM Nokia trực tiếp.

**Tình trạng hiện tại:** đã tạo nhánh `research/n95-omap2420-arm32` và tài liệu `docs/nokia-n95-omap2420/STARTUP-PLAN.md`, **chưa có QEMU ARM32 build hoặc OMAP implementation**. 7 framework hiện đóng gói **không có `qemu-arm-softmmu`**, nên bước bổ sung ARM32 engine là bắt buộc.

**Các nguồn thực tế vừa bắt đầu kiểm tra:**
- Pinned UTM `utmapp/UTM@7eadb056...` có `Documentation/iOSDevelopment.md`, `Documentation/Dependencies.md`, `scripts/build_dependencies.sh`. Tài liệu yêu cầu recursive submodules và tải matching sysroot. Script `build_dependencies.sh` có biến `QEMU_SRC`, tùy chọn `-q qemu_path`, và tại cuối có `build $QEMU_DIR ...`. **Chưa tìm ra giá trị QEMU_SRC/version và chính xác fork/commit QEMU của sysroot đang dùng; phải xác minh tiếp ở nơi khai báo QEMU_SRC.**
- Đã truy cập GitHub repo upstream `qemu/qemu` cây tag `v9.1.0` và `v9.2.0` để làm đối chiếu. Kết quả mở tree là **bước định vị**, chưa rà chính xác các file `hw/arm/omap2.c`, `hw/arm/nseries.c`; không được báo cáo chúng có hoặc không có nếu chưa tìm/xác thực.
- Dấu vết lịch sử cần tìm: QEMU `hw/arm/omap2.c` và `hw/arm/nseries.c` cho Nokia **N800/N810**, nguồn tham khảo OMAP2 chứ không phải mô hình Nokia N95 hoàn chỉnh. Cần xác định commit cuối còn chứa chúng, giấy phép, header phụ thuộc, đường IRQ/timer/MMIO và chênh lệch API QEMU hiện tại.
- Cần phân biệt **CPU ARM1136 / ARMv6, SoC/board N95** với QEMU `aarch64` ARMv8 Generic Virt. Dù frontend UTM có liệt kê `ARM`, điều đó không chứng minh app có QEMU ARM32 backend tương ứng.
- Trình tự: (1) source inventory / bảng API compatibility; (2) build & đóng gói **`qemu-system-arm`** iOS TCI framework phù hợp (giữ 7 engines đang hoạt động); (3) boot ARM32 Linux mẫu hợp pháp; (4) xây OMAP2420 UART/IRQ/clock/timer/memory/ROM loader; (5) board N95-specific và log MMIO; (6) thử firmware có quyền sử dụng, **không phân phối ROM Nokia**.
- Sau mọi bản build thử, hồi quy v8: ESign mở app, ISO picker, Save, ARM64 Linux boot, network, shutdown. **Không thay baseline v8 hoặc merge PR v8/OMAP tùy tiện.**
- Quy định scope: nghiên cứu giả lập/compatibility Symbian, không phải khai thác, xâm nhập, malware, credential, persistence hay tấn công mạng. Tuân thủ license QEMU GPL/LGPL, UTM và các dependency.

## 5. VIỆC LÀM NGAY Ở CUỘC TRÒ CHUYỆN MỚI (CHƯA LÀM)

1. Đọc HANDOFF này cùng `docs/nokia-n95-omap2420/STARTUP-PLAN.md`, checkpoint v8. Kiểm tra HEAD branch `research/n95-omap2420-arm32` và Actions; đừng lẫn với repo `EKA2L1-S60-OMAP2420-iOS`.
2. Qua GitHub connector, tìm chỗ khai báo `QEMU_SRC`/revision trong mã `utmapp/UTM@7eadb056...` hoặc dependency manifest/patch scripts. So sánh với version thực tế trong sysroot `Sysroot-ios-tci-arm64`. Tìm API hỗ trợ QEMU `arm-softmmu`, danh sách `target-list`, cách iOS đóng gói frameworks và strong-link dependencies.
3. Qua GitHub/Exa, xác minh **commit/tag còn `hw/arm/omap2.c`, `hw/arm/nseries.c`**; đọc và lập bảng các khối SoC cùng API cũ cần chuyển sang QOM/sysbus/MemoryRegion modern. Đính kèm URL nguồn **có thể kiểm chứng**, đừng đoán tồn tại từ trí nhớ.
4. Commit báo cáo **`docs/nokia-n95-omap2420/QEMU-SOURCE-INVENTORY.md`** vào nhánh nghiên cứu; thêm bảng đối chiếu old source vs modern target và đề xuất prototype nhỏ (UART + boot path).
5. **Chưa build IPA Nokia v1** cho tới khi đạt source inventory + phương án ARM32 có thể build. Nếu người dùng yêu cầu build sớm, trước tiên lập workflow chẩn đoán ARM32 riêng (logs/artifacts/pass/fail), không nói đã giả lập Nokia thành công.

## 6. Lệnh mở cuộc trò chuyện mới

> Tiếp tục dự án UTM–Nokia S60 ở repo `phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS`, nhánh `research/n95-omap2420-arm32`. Đọc đầy đủ `docs/handoff/NEWCHAT-UTM-N95-OMAP2420-2026-10-09.md`, `docs/nokia-n95-omap2420/STARTUP-PLAN.md` và checkpoint Alpine ARM64 đã PASS. UTM SE Lite v8 là baseline device-PASS: ISO UIKit, Linux ARM64 boot, ổ đĩa, DHCP/DNS/HTTP, shutdown/restart. Giữ nguyên baseline và các PR draft. Bắt đầu bước **khảo sát chính xác mã QEMU OMAP2/N-series đời cũ và QEMU hiện tại**, tạo `QEMU-SOURCE-INVENTORY.md`. Chưa build firmware N95, chưa trộn với repo EKA2L1 OMAP.

---

**HANDOFF cuối cùng của cuộc trò chuyện dài; các kết quả trên phải được đối chiếu với GitHub và checkpoint lưu trong repo, không đoán thêm kết quả chưa được kiểm thử.**
