# Nguồn bộ chọn tệp: EKA2L1 Menu Simbiam → UTM Lite v6

Người kiểm thử xác nhận bản EKA2L1 iOS vừa dùng để cài SYM.ROM thuộc **phai-nguyen/Eka2l1_bot_menu_simbiam**, không phải nhánh EKA2L1 Việt hóa.

## Đã kiểm chứng

- Các GitHub Actions workflows [HOMEONLY11](https://github.com/phai-nguyen/Eka2l1_bot_menu_simbiam/blob/codex/m3home-homeonly2-build/.github/workflows/build-homeonly11-homeactiveq1.yml) và [MENUUI36](https://github.com/phai-nguyen/Eka2l1_bot_menu_simbiam/blob/codex/m3home-homeonly2-build/.github/workflows/build-ios-symbian-systemapps1-menuui36-winfocus1-nojava-manic3.yml) sử dụng source/build iOS restore từ GitHub Actions cache, với đường dẫn frontend src/emu/ios/app/RootViewController.mm.
- [Mã frontend nền công khai](https://github.com/MuhannadYT/EKA2L1_IOS/blob/main/src/emu/ios/app/RootViewController.mm) dùng UIDocumentPickerViewController, delegate didPickDocumentsAtURLs, startAccessingSecurityScopedResource và sao chép vào Documents/imports.
- Khác với EKA2L1 SwiftUI Việt hóa (ESign Match), hướng frontend này có một đường nhập file UIKit cụ thể.
- Chưa xác định được chính xác source cache/commit của IPA vừa được người dùng ký, vì workflow tái sử dụng cache. Không tuyên bố đây là toàn bộ nguyên nhân file picker thành công.

## UTM hiện tại và v6

- UTM commit 7eadb056 dùng SwiftUI fileImporter trong Platform/Shared/VMWizardOSLinuxView.swift. Người dùng không chọn được Alpine ISO trên iPhone bằng ESign, bản v3 đổi UTType cũng không giải quyết.
- UTM Lite v6 thử UIKit UIDocumentPicker (asCopy true), delegate callbacks, lấy security-scoped URL, sao chép ISO vào Documents/NokiaUTMISOImports/UUID, sau đó gán URL nội bộ vào wizardState.bootImageURL.
- Linux wizard hiển thị trạng thái: Files callback đã nhận tệp hoặc tệp đã sao chép thành công. Nếu sao chép lỗi, busyWorkAsync hiện cảnh báo.
- macOS/visionOS vẫn dùng picker cũ. Bundle ID UTM giữ nguyên, không chiếm Bundle ID EKA2L1. Giữ đầy đủ 7 framework QEMU đã kiểm chứng trong Lite v2.
- Đây là thử nghiệm riêng trong PR #8, chưa được xác nhận bằng iPhone, chưa hỗ trợ firmware Nokia.

## Kiểm thử sau khi build

1. ESign ký IPA, cài đặt UTM Lite v6, mở Linux → Boot from ISO image → Browse.
2. Nếu Files chấp nhận Alpine ISO và hiện Đã nhập vào ứng dụng: alpine..., picker/copy coi là PASS, chưa cần Start.
3. Nếu chỉ hiện Đã nhận từ Files nhưng không hiện Đã nhập, kiểm tra thông báo copy lỗi.
4. Nếu tap ISO không có callback, cần kiểm tra entitlement của IPA đã ký; không được suy luận do Bundle ID một cách duy nhất.
5. Để tránh ảnh hưởng dữ liệu, giữ IPA v2 gốc và chụp lại kết quả trước khi thay đổi.

Safety: nghiên cứu tính tương thích giả lập Nokia/Symbian, không liên quan đến truy cập trái phép.