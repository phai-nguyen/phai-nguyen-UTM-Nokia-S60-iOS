# Phân tích IPA EKA2L1 đã ký bằng ESign (2026-10-08)

## Nguồn dữ liệu và giới hạn

- IPA chưa ký do người dùng cung cấp: `EKA2L1-NATIVEBOOT2-CURRENT-FAST-NOJAVA-MANIC3-unsigned.ipa`; SHA256 `544097305cc97f8bb053cb5e5651c442ca076ce17d1e1a317f68397d27b292a9`.
- IPA cùng ứng dụng đã ký bằng ESign: `EKA2L1_1.0_1791453228.ipa`; SHA256 `91d68b2a4c0a2a1831f5bc6d713f8381b9a01af07fb5e9ab01760a8e9196bba1`.
- Chỉ phân tích **tĩnh** ZIP, Mach-O code-signing blobs và CMS provisioning profile; không thực hiện validation bằng iOS AMFI/thiết bị hay xác minh certificate chain của Apple.
- KHÔNG đưa IPA, embedded.mobileprovision, UDID hoặc chứng chỉ của người dùng lên GitHub.

## Những gì ESign thật sự đã thay đổi

| Thành phần | IPA unsigned | IPA signed |
|---|---|---|
| Bundle ID (`Info.plist`) | `com.eka2l1.emulator` | `com.eka2l1.emulator` |
| MinimumOSVersion | `15.0` | `10.0` |
| UIFileSharingEnabled | `true` | `true` |
| LSSupportsOpeningDocumentsInPlace | `true` | `true` |
| Embedded provisioning profile | absent | present |
| `_CodeSignature/CodeResources` | absent | present |
| Mach-O `LC_CODE_SIGNATURE` | absent | present |

- 132 tệp tồn tại trong cả hai IPA; 130 nội dung giống nhau, chỉ file thực thi Mach-O và `Info.plist` thay đổi.
- IPA đã ký thêm ba entry: provisioning profile, `_CodeSignature/CodeResources`, `SignedByEsign`.
- Phần executable gốc và bản đã ký trùng byte-for-byte kể từ offset `8192` đến hết vùng mã cũ; ngoài header/load commands, khác biệt chính là chữ ký Mach-O được thêm phía cuối. Điều này cho thấy mã xử lý `UIDocumentPicker` không bị sửa bởi ESign.
- Đặc biệt, không nên hạ `MinimumOSVersion` UTM theo ESign: target build UTM vẫn giữ iOS 15.0.

## Thông tin ký thực sự nhúng trong IPA đã ký

- CodeDirectory identifier trong Mach-O: `com.eka2l1.emulator`.
- `CFBundleIdentifier` trong `Info.plist`: `com.eka2l1.emulator`.
- **Cả provisioning profile lẫn embedded XML entitlements trong chữ ký Mach-O** đều ghi `application-identifier = 3V48279JP4.app.lavender1865.valley8348`.
- Mã Team ID là `3V48279JP4`.
- Do đó **Bundle ID và suffix của application-identifier KHÔNG TRÙNG**, ngay trong IPA đã ký mà người dùng xác nhận chọn được firmware bằng iOS Files.

## Kết luận kỹ thuật cho UTM

1. Không thể khẳng định một cách tổng quát rằng nếu Bundle ID không trùng App ID thì `UIDocumentPicker` chắc chắn không hoạt động. Chính bản EKA2L1 ESign working có hai giá trị khác nhau.
2. Cũng chưa được phép kết luận entitlement mismatch hoàn toàn không liên quan đến UTM: hai ứng dụng dùng UI framework và cách trình bày picker khác nhau; cần kiểm tra **IPA UTM đã ký** để so sánh.
3. Nguồn tác động khả dĩ cao hơn để thử có kiểm soát là frontend UIKit: `UIDocumentPickerViewController`, `didPickDocumentsAtURLs`, security-scoped access, sao chép file vào `Documents` và gán URL nội bộ. Cơ chế này được xác nhận trong bản binary EKA2L1 unsigned trước đó, và mã thực thi không bị ESign thay đổi.
4. Bản UTM Lite v6 đang thử kiến trúc UIKit theo hướng này, nhưng dùng SwiftUI `.sheet` host UIKit; còn EKA2L1 gọi từ `UIViewController` trực tiếp. Nếu v6 còn lỗi, tập trung kiểm tra callback và presentation trước, không đổi Bundle ID mò mẫm.
5. PR ESign Match v5 chỉ nên coi là **công cụ thử nghiệm có điều kiện**, chưa chứng minh là cách sửa lỗi chọn ISO.

## Bước kiểm thử tiếp theo

- Dùng UTM Lite v6 đã được ký ESign: Linux → Browse → chọn Alpine ISO; xem trạng thái `Đã nhận từ Files` / `Đã nhập vào ứng dụng`.
- Nếu callback vẫn không hoạt động, đề nghị người dùng gửi **IPA UTM đã ký** để so sánh `Info.plist`, CodeDirectory identifier, embedded entitlements và provisioning profile với EKA2L1. Giữ IPA riêng tư; không commit vào repo.
- Chưa có Nokia machine hay khả năng boot firmware Nokia trong UTM Lite.
