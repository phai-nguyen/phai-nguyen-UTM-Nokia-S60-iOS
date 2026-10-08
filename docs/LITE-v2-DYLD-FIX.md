# Lite v2: sửa crash khi khởi động (08/10/2026)

## Nguyên nhân bản Lite v1 hỏng

Người kiểm thử xác nhận bản UTM SE v1 đầy đủ mở được trên iPhone 18.7, bản Lite v1 (xóa CPU frameworks) crash ngay về Home. Cả **4** báo cáo `.ips` từ 14:25:31 đến 14:25:34 +0700 cho cùng một nguyên nhân:

```
exception.type: EXC_CRASH
exception.signal: SIGABRT
termination.namespace: DYLD
termination.indicator: Library missing
Library not loaded: @rpath/qemu-m68k-softmmu.framework/qemu-m68k-softmmu
Referenced from: UTM SE.app/UTM SE
```

Đây là **liên kết động mạnh (strong-linked dylib)**. Việc xóa thư viện QEMU M68K khi binary chính vẫn liên kết khiến dyld không thể launch process; crash không liên quan đến firmware Nokia. PR #3 (Lite v1 lỗi) đã **đóng, KHÔNG cài**.

## Cách sửa v2 (giữ thư viện)

Không xóa 6 framework như v1. Trích bản v1 gốc đã PASS [run #37733615950](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37733615950), dùng macOS `xcrun strip -S -x` trên **7** QEMU CPU frameworks để giảm local/debug symbols, giữ dynamic exports, danh sách tệp trong IPA và link libraries. Tệp sau thay đổi vẫn cần ký ESign.

Workflow: [UTM-SE-LITE-V2-DYLD-SAFE #37743881078](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37743881078)

- **Run: PASS**; `DYLD_PRECHECK=PASS`, `DYLD_POSTCHECK=PASS`; 7 QEMU engines hiện diện; ZIP integrity PASS.
- IPA gốc: 216,806,097 bytes (**206.76 MiB**).
- IPA Lite v2: 126,974,521 bytes (**121.09 MiB**).
- Tiết kiệm **41.43%** dung lượng IPA.
- SHA256 v2: `cc3ea51698d9e6c19b997114796c6a4969c75db46887ce80320c885d64fff5a2`.
- Artifact IPA: [NokiaUTM-SE-Lite-v2-unsigned-IPA](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37743881078/artifacts/11534938198)
- Artifact logs: [NokiaUTM-SE-Lite-v2-DYLD-LOGS](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37743881078/artifacts/11534329786)

## Kiểm thử thực tế ngày 08/10/2026

Người kiểm thử đã ký và cài bản Lite v2 trên iPhone, xác nhận **ứng dụng vào giao diện bình thường, không crash về Home ở bước mở ứng dụng**. Đây là **DEVICE LAUNCH/UI PASS**, đồng thời khắc phục lỗi dyld ngay khi khởi động trong Lite v1.

**Chưa kiểm thử:** tạo và chạy VM ARM, các chức năng nhập liệu/hiển thị, độ ổn định khi chạy lâu và khả năng boot ROM Nokia. Không suy diễn các phần đó là PASS.

**Baseline hiện tại:** Lite v2, 121.09 MiB IPA unsigned, SHA256 `cc3ea51698d9e6c19b997114796c6a4969c75db46887ce80320c885d64fff5a2`. Bản đầy đủ vẫn được giữ làm đối chứng.

## Hướng thử

1. Tải artifact ZIP v2, giải nén IPA, ký lại bằng ESign.
2. Cài đè, trước khi thử nên sao lưu các máy ảo cấu hình hiện có. Bundle ID giữ nguyên `com.phai.nokias60.UTM-SE`.
3. Bước mở ứng dụng đã PASS; **bước kế tiếp là tạo một VM ARM nhỏ và nhấn Start**, ghi lại hiện tượng nếu có lỗi.
4. Sau khi VM PASS mới tiếp tục nghiên cứu giảm CPU engines **tại bước link/build của QEMUKit**, không xóa nhị phân sau build.
