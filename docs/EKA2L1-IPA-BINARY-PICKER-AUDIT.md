# Phân tích tĩnh IPA EKA2L1 — xác minh UIKit picker từ nhị phân (2026-10-08)

**Bản người dùng cung cấp:** `EKA2L1-NATIVEBOOT2-CURRENT-FAST-NOJAVA-MANIC3-unsigned.ipa` (không lưu/đưa IPA hoặc ROM lên GitHub).

- SHA256 của IPA: `544097305cc97f8bb053cb5e5651c442ca076ce17d1e1a317f68397d27b292a9`.
- Mach-O: ARM64, executable `Payload/EKA2L1.app/eka2l1` ~22.3 MB.
- `Info.plist`: `CFBundleIdentifier=com.eka2l1.emulator`, `UIFileSharingEnabled=true`, `LSSupportsOpeningDocumentsInPlace=true`.
- IPA nguyên bản không có `embedded.mobileprovision`; Mach-O không có lệnh `LC_CODE_SIGNATURE`. **Không thể kết luận entitlements sau khi ESign ký từ file unsigned này.**

## Bằng chứng ngay trong Mach-O

Phân tích bảng symbol, Objective-C selectors và disassembly đã xác nhận ba hàm thực (không chỉ chuỗi văn bản):

| Hàm Objective-C | Địa chỉ VM ARM64 | Bằng chứng lệnh gọi |
|---|---|---|
| `-[RootViewController presentPicker]` | `0x10003BA4C` | `typeWithFilenameExtension:`, `initForOpeningContentTypes:asCopy:`, `setDelegate:`, `setAllowsMultipleSelection:`, `presentViewController:animated:completion:` |
| `-[RootViewController importFileAtURL:]` | `0x10003B790` | `createDirectoryAtPath`, `startAccessingSecurityScopedResource`, `copyItemAtURL:toURL:error:`, `stopAccessingSecurityScopedResource` |
| `-[RootViewController documentPicker:didPickDocumentsAtURLs:]` | `0x1000474FC` | `firstObject`, `importFileAtURL:`, `setPendingRomPath:`, `promptForRpkg`, `runDeviceInstallWithRpkg:rom:installRpkg:` |

**Chi tiết quyết định:** tại `0x10003BB34`, code nạp tham số `w3=1` trước lệnh gọi stub `_objc_msgSend$initForOpeningContentTypes:asCopy:` (`0x10003BB38`). Đây là bằng chứng trực tiếp **`asCopy=YES`** trong `RootViewController`, không phải suy đoán từ source upstream. Loại UTI được xác định từ `typeWithFilenameExtension:` cho ROM/RPKG; có đường fallback, không chỉ `.item` như giả định trước.

Tại `0x10003B8BC/0x10003B908/0x10003B92C`: code lần lượt gọi `startAccessingSecurityScopedResource`, `copyItemAtURL:toURL:error:`, `stopAccessingSecurityScopedResource`. Bộ chọn gọi delegate trước khi trình cài đặt firmware xử lý local file.

## Ứng dụng vào UTM Lite v6

- v6 đã dùng `UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)`, delegate, `startAccessingSecurityScopedResource`, copy vào app `Documents`, gán URL nội bộ vào `wizardState.bootImageURL` — **khớp kiến trúc mà binary EKA2L1 thực tế dùng**.
- Khác biệt cần lưu ý: EKA2L1 trình bày picker trực tiếp từ `UIViewController`, còn v6 của UTM nhúng UIKit picker vào SwiftUI `.sheet`/`UIViewControllerRepresentable`. Vì vậy vẫn có thể xảy ra lỗi presentation/ESign; phải thử iPhone.
- EKA2L1 chọn UTI dựa trên phần mở rộng ROM/RPKG rồi gọi UIKit picker; UTM v6 hiện dùng `.item` tổng quát để người dùng chọn ISO. Nếu v6 vẫn không nhận được callback, nên kiểm tra các khác biệt này, entitlement sau khi ký và đường import SwiftUI; không kết luận chỉ do Bundle ID.
- Hai khóa sharing của `Info.plist` đã có trong UTM Lite, vì thế không giải quyết lỗi nếu chỉ chép từ EKA2L1.
- Không sao chép firmware/ROM, chứng chỉ, mobileprovision, App ID EKA2L1 hay dữ liệu cá nhân vào repo.

## Kiểm thử còn thiếu

Kiểm tra trên iPhone (ESign signed): `Linux → Boot from ISO image → Browse → alpine-virt-...aarch64.iso` → xem thông báo `Đã nhận từ Files` và `Đã nhập vào ứng dụng`. Build PASS chỉ xác nhận biên dịch/đóng gói, chưa chứng minh bộ chọn hoạt động.