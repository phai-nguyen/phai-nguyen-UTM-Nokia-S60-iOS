# UTM Lite v7 — ISO đã chọn được nhưng Save báo Failed to access drive image path

## Device evidence (2026-10-08)

- Người dùng thử UTM Lite v6 trên iPhone, nhập `alpine-virt-3.24.2-aarch64.iso` ~93 MB qua UIDocumentPicker UIKit thành công.
- Video cho thấy trạng thái `Đã nhập vào ứng dụng: alpine-virt-...aarch64.iso`, sau đó người dùng điều chỉnh ARM64, RAM, storage và bấm Save.
- Khi trở về màn hình chính UTM SE, cảnh báo: `Failed to access drive image path.`
- Chứng minh UIKit file picker và copy vào sandbox đạt **device PASS**; lỗi hiện tại là **tạo/saving VM, gắn ổ đĩa/bookmark**, không phải lọc ISO.

## Root cause path from exact pinned UTM source

- `Platform/Shared/VMWizardState.swift`: với `bootDevice == .cd`, tạo `UTMQemuConfigurationDrive(..., isExternal: true)` và gán `bootDrive.imageURL` tới file ISO đã nhập vào Documents.
- `Platform/iOS/VMWizardView.swift`: Save tạo config rồi `data.create(config:)`.
- `Platform/UTMData.swift` + `Services/UTMVirtualMachine.swift`: `create -> save -> config.save(to:) -> updateRegistryFromConfig()`.
- `Services/UTMSpiceVirtualMachine.swift`: external drive với URL sẽ gọi `changeMedium(drive, to:)`.
- `Services/UTMQemuVirtualMachine.swift`: `changeMedium -> UTMProcess.accessData(withBookmark:)` rồi ném `accessDriveImageFailed` nếu bookmark hoặc path thất bại.
- Đúng chuỗi hiển thị `Failed to access drive image path.`. Có **thêm** đường VirtFS share cùng mã lỗi, nhưng trong video Shared Directory để trống nên khả năng lỗi đến từ bookmark external CD cao hơn. Chưa có runtime stack trace nên ghi nhận đây là **nguồn lỗi rất có cơ sở, chưa chứng minh duy nhất**.

## v7 fix (không can thiệp picker)

- Giữ nguyên UIKit picker v6 đã device-PASS.
- Sau khi UTM tạo CD cho Linux trên iOS, đặt: `bootDrive.isExternal = false`, `bootDrive.isRawImage = true`, `bootDrive.isReadOnly = true` và **giữ nguyên** `bootDrive.imageType = .cd`.
- `UTMConfigurationDrive.saveData(to:)` của upstream sẽ sao chép ISO vào gói VM `.utm/Data/`, tránh đăng ký bookmark ngoài và không chuyển ISO sang QCOW2.
- Fix chỉ áp dụng trên `#if os(iOS)` và `operatingSystem == .Linux && bootDevice == .cd`; Windows, macOS, image khác và platform khác không thay đổi.
- Dự kiến IPA tương tự v6 vì logic chỉ vài dòng. iOS 15+, QEMU TCI không JIT, 7 QEMU framework vẫn nguyên.

## Kiểm thử

1. Ký và cài IPA v7 bằng ESign (cùng cách đã dùng v6).
2. Linux, ARM64, Boot from ISO image, Browse chọn Alpine ISO; đợi xuất hiện `Đã nhập vào ứng dụng`.
3. Tiếp tục Storage (~2 GiB nếu có đủ dung lượng), Shared Directory để trống, Save.
4. Nếu danh sách VM xuất hiện và **không còn báo Failed to access drive image path**, đánh dấu bước tạo VM PASS.
5. Chưa khởi động Linux cho tới khi bước Save PASS; nếu VM vẫn lỗi, ghi lại ảnh hoặc video và nên thu thêm log UTM để xác định có phải bookmark VirtFS/EFI hay không.

PR này **DRAFT**, không merge cho tới khi user xác nhận kiểm thử trên máy thật; giữ main/Lite v2 ổn định.