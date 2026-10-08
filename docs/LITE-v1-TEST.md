# Nokia UTM SE Lite v1 — size-reduction experiment

**Trạng thái:** IPA Lite đóng gói **PASS**, chưa có kết quả chạy thử trên iPhone.

## Kết quả đã đo

- Bản gốc UTM SE v1 từ Actions [#37733615950](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950)
  - IPA unsigned thực tế: `216806097` bytes (206.76 MiB).
  - Nội dung ZIP chưa nén: ~1610.62 MiB.
- Bản thử Lite từ Actions [#37742667371](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37742667371)
  - IPA unsigned: `76660953` bytes (~73.11 MiB).
  - Giảm **64.64%** dung lượng IPA thực tế.
  - SHA256: `a698588403d7dfe32bff6e423f537d3db4b8fecbe1a12a48b6735d7a3ca88ec6`.
  - Artifact [NokiaUTM-SE-Lite-v1-IPA](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37742667371/artifacts/11534009753).

## Phương pháp

Script `scripts/make_lite_ipa.py` lấy từ IPA đã build PASS, **không rebuild QEMU**. Chỉ loại các bundles guest CPU: `i386`, `x86_64`, `ppc`, `ppc64`, `riscv64`, `m68k`. Giữ `qemu-aarch64-softmmu.framework`, các thư viện phụ thuộc và ROM/firmware QEMU khác; không xóa dữ liệu người dùng hoặc thay đổi firmware Nokia.

Ứng dụng vẫn dùng bundle ID `com.phai.nokias60.UTM-SE`. Không cài cùng lúc Lite và v1 vào cùng bundle ID nếu muốn giữ nguyên v1.

## Giới hạn và quy trình thử máy thật

- Dù có QEMU AArch64, **chưa có machine Nokia, chưa chắc hỗ trợ những CPU ARM32 dùng trong Nokia S60**. Có thể cần bổ sung `arm-softmmu` và QEMU device models về sau.
- Giao diện UTM chưa bị giới hạn danh sách máy ảo: x86/PPC/RISC-V/M68K có thể còn hiện nhưng **không chạy được** vì engine bị loại.
- Chưa kiểm tra phụ thuộc runtime, ký ESign hoặc chạy VM trên iOS. Không nên đưa Lite làm mặc định trước thử nghiệm thiết bị.
- **Cách thử:** tải artifact ZIP, giải nén IPA, ký bằng ESign, cài và mở app. Kiểm tra màn hình danh sách máy ảo, thử tạo VM ARM và gửi ảnh/video/log khi app crash.
- Khi phát hiện crash, giữ log và đối chiếu với IPA v1; nếu cần revert bằng việc dùng artifact v1 vẫn còn.

## Phần tiếp theo

Sau device PASS: loại tài nguyên QEMU của guest x86/PPC/RISC-V theo danh sách kiểm chứng, kiểm tra dyld dependencies và giới hạn lựa chọn kiến trúc trong frontend. Sau đó mới nghiên cứu việc build QEMU ARM32 và OMAP2420 của Nokia N95.

Đây là dự án tương thích/giả lập Symbian, không liên quan đến khai thác, xâm nhập, malware hay persistence.
