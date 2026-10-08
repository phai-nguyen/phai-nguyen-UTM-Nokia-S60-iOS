# UTM–Nokia S60 iOS

Dự án nghiên cứu **UTM/QEMU trên iPhone**, phát triển ứng dụng IPA độc lập để từng bước thử nghiệm khả năng giả lập phần cứng Nokia S60. Không thay đổi EKA2L1.

> **Trạng thái: v1 UTM SE IPA — GitHub Actions PASS. Chưa kiểm thử cài đặt trên iPhone, chưa có Nokia machine và chưa boot được firmware Nokia.**

## Kết quả v1 (08/10/2026)

- [GitHub Actions #37733615950 — SUCCESS](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950).
- [Tải artifact IPA unsigned](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950/artifacts/11531076995) (tên artifact `NokiaUTM-SE-v1-unsigned-IPA`).
- [Tải artifact log](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950/artifacts/11530998207).
- Tệp bên trong artifact: `NokiaUTM-SE-v1-unsigned.ipa`.
- iOS deployment target: **15.0**; kiến trúc **ARM64**, chế độ **QEMU TCI không JIT**.
- Bundle ID: `com.phai.nokias60.UTM-SE` (độc lập với UTM gốc).
- Mã SHA256 của tệp IPA: `f86838595f971f8694d817bb5f402fd9822be6a16f18453375102801df729a9a`.
- Chưa ký IPA; cần ESign ký hợp lệ. Chưa xác minh chức năng trên thiết bị.

## Cách thử trên iPhone

1. Vào link artifact IPA phía trên, tải tệp ZIP GitHub Actions về iPhone và giải nén trong ứng dụng Tệp.
2. Trong ESign, chọn `NokiaUTM-SE-v1-unsigned.ipa`, ký bằng chứng chỉ của anh và cài đặt.
3. Mở app, kiểm tra màn hình chính UTM SE, tạo thử máy ảo Linux/DOS nhỏ nếu muốn đánh giá QEMU, rồi gửi ảnh hoặc log lỗi.

**Không nạp trực tiếp firmware N95/N82/5800 vào bản v1**; machine Nokia chưa được xây dựng.

## Build tái lập

- UTM upstream: commit `7eadb056ae0f91d979059544d0ddcd2d5a40be92`.
- Sysroot chính thức từ [UTM upstream Actions #36090554968](https://github.com/utmapp/UTM/actions/runs/36090554968), artifact `Sysroot-ios-tci-arm64`.
- [Workflow UTM-SE-IPA](.github/workflows/02-utm-se-ipa.yml) tự tải đúng artifact của UTM, kiểm tra SHA nguồn và build bằng macOS 26 / Xcode 26.
- [Patch SDK iOS 26](scripts/patch_utm_ios26.py) chỉ xử lý các API giao diện iOS 27 và toolbar không tương thích deployment iOS 15.
- [Script build](scripts/build_utm_se.sh) tạo unsigned IPA và ghi console log.
- Khi workflow fail, đọc artifact log. **Không build lại toàn bộ dependency** nếu chỉ sửa frontend; sysroot được tái sử dụng.

## Roadmap

Xem [docs/ROADMAP.md](docs/ROADMAP.md). Bước kế tiếp sau khi xác nhận IPA chạy trên iPhone: phục hồi mã OMAP2420 QEMU đời cũ trên nhánh nghiên cứu để bắt đầu `nokia-n95` machine. Đây là hướng nghiên cứu, không cam kết boot firmware.

## Phạm vi / Safety clarification

Đây là dự án giả lập và tương thích hệ điều hành Symbian nhằm nghiên cứu phần cứng và khả năng boot firmware Nokia. Không liên quan đến khai thác lỗ hổng, xâm nhập, malware, credential, persistence hoặc tấn công mạng.

## Bản quyền

UTM chịu Apache-2.0, QEMU và các phụ thuộc có thể chịu GPL/LGPL cùng giấy phép khác. Khi phân phối phải duy trì thông báo bản quyền và đáp ứng nghĩa vụ cung cấp mã nguồn của thành phần tương ứng. Không đưa firmware/ROM Nokia khi không có quyền phân phối vào repo.
