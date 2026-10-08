# UTM–Nokia S60 iOS

Dự án **nghiên cứu giả lập phần cứng Nokia/Symbian bằng UTM + QEMU trên iPhone**, phát triển độc lập với EKA2L1.

> **Trạng thái: v1 BOOTSTRAP — chưa có IPA được kiểm thử, chưa có Nokia machine, chưa chạy được firmware Nokia.**

## Mục tiêu và phạm vi

- Xây dựng **IPA UTM SE riêng** với bundle ID khác UTM chính thức, hỗ trợ iOS 15+ và không yêu cầu JIT.
- Sử dụng mã nguồn UTM upstream tại commit cố định `7eadb056ae0f91d979059544d0ddcd2d5a40be92`. Phụ thuộc QEMU/sysroot phải khớp commit.
- Giai đoạn tiếp theo: nghiên cứu Nokia **N95/N82/N93/E90** dùng OMAP2420; tham khảo QEMU N800/N810 đời cũ (đã bị gỡ khỏi upstream mới).
- Giai đoạn riêng sau đó: nghiên cứu MXC300-30 của **Nokia 5800 RM-356**.
- Không tác động repo EKA2L1, không tải lên firmware/ROM có bản quyền, không tuyên bố boot thành công trước khi thử thực tế.

## Phần đã khởi tạo

| Thành phần | Chức năng |
|---|---|
| [Lộ trình và handoff](docs/ROADMAP.md) | Theo dõi các mốc v1–v5 và giới hạn kỹ thuật |
| [BOOTSTRAP-CHECK](.github/workflows/01-bootstrap-check.yml) | CI Ubuntu kiểm tra phiên bản, cấu trúc UTM, iOS 15, scheme iOS SE; xuất artifact log |
| [UTM-SE-IPA](.github/workflows/02-utm-se-ipa.yml) | Workflow macOS, chạy **thủ công** khi có sysroot iOS-TCI ARM64 khớp phiên bản |
| [build_utm_se.sh](scripts/build_utm_se.sh) | Archive ứng dụng UTM SE với bundle prefix `com.phai.nokias60`, đóng gói IPA unsigned và log |

## Build

1. Chạy **BOOTSTRAP-CHECK**. Đây là bước kiểm tra mã nguồn, **không tạo IPA**.
2. Chuẩn bị `sysroot.tgz` chứa `sysroot-ios-tci-arm64` được build từ nguồn/dependencies UTM khớp commit cố định.
3. Chạy workflow **UTM-SE-IPA**, nhập HTTPS URL truy cập được của sysroot tương ứng. Workflow sẽ thử build unsigned IPA và lưu log (thất bại vẫn giữ log khi có).
4. IPA phải ký lại bằng ESign trước khi cài iPhone. Đã build IPA cũng **chưa** có nghĩa Nokia firmware tương thích.

## Phạm vi / Safety clarification

Đây là dự án **giả lập và tương thích hệ điều hành Symbian** (phục vụ khởi động firmware Nokia), không liên quan đến khai thác, xâm nhập, malware, credential, persistence hay tấn công mạng.

## Bản quyền

UTM chịu Apache-2.0; QEMU và nhiều thư viện phụ thuộc chịu GPL/LGPL hoặc các giấy phép khác. Cần duy trì ghi công và hoàn thành nghĩa vụ giấy phép khi phân phối ứng dụng. Không đưa firmware Nokia không có quyền phân phối vào repo.
