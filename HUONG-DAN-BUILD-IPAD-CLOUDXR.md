# Hướng dẫn build CloudXR trên iPad và xử lý lỗi mismatch

Tài liệu này ghi lại quy trình đã chạy thành công trong repo `cloudxr-vs-ipad`.

## 1) Chuẩn bị

- Xcode đã cài iOS Platform.
- iPad đã bật **Developer Mode**, đã **Trust** máy Mac.
- Apple ID đã đăng nhập ở `Xcode > Settings > Accounts`.
- Có Team signing hợp lệ trong target iOS.

## 2) Build và cài app lên iPad

Từ thư mục repo:

```bash
cd ~/Documents/work/github_repo/cloudxr-vs-ipad

xcodebuild \
  -project cloudxr-apple-generic-viewer/CloudXRViewer.xcodeproj \
  -scheme CloudXRViewer-iOS \
  -destination 'platform=iOS,id=00008130-000E648C0CE1001C' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  clean build
```

Cài app:

```bash
xcrun devicectl device install app --device 00008130-000E648C0CE1001C \
  "/Users/$USER/Library/Developer/Xcode/DerivedData/CloudXRViewer-fpcohakyjomltsfoevprpaxgdmyy/Build/Products/Debug-iphoneos/CloudXRViewer.app"
```

Lưu ý: cảnh báo `No provider was found` từ `devicectl` có thể xuất hiện nhưng không chặn cài đặt nếu vẫn có dòng `App installed`.

## 3) Cấu hình app trên iPad

Trong app `CloudXRViewer`:

1. Chọn `Manual IP address`.
2. Nhập IP server: `192.168.0.17`.
3. Để `Resolution Preset` ở `Standard`.
4. Bấm `Connect`.

## 4) Kiểm tra mạng nhanh từ Mac

```bash
ping -c 4 192.168.0.17
nc -vz 192.168.0.17 48010
nc -vzu 192.168.0.17 48010
```

Nếu cả TCP/UDP đều `succeeded` thì đường mạng cơ bản đã thông.

## 5) Lỗi `device config mismatch`

Nguyên nhân thường gặp: server đang ép `device-profile` không đúng với thiết bị client.

Trong repo này đã chỉnh ở file:

`cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/cloudxr_manager.lua`

Thay vì hardcode `apple-vision-pro`, server sẽ:

- Không ép profile mặc định.
- Chỉ ép profile khi có biến môi trường `CXR_DEVICE_PROFILE`.

Khuyến nghị chạy mặc định (không set `CXR_DEVICE_PROFILE`) khi kết nối iPad.

## 6) Thay đổi client để giảm sai cấu hình

Đã cập nhật client iOS:

- Tự chuyển về `Manual IP address` khi mở form cấu hình.
- Giảm nguy cơ nhầm sang flow cloud zone gây mismatch.

## 7) Nếu vẫn lỗi

1. Gỡ app trên iPad, cài lại.
2. Restart CloudXR Runtime + app server (lovr).
3. Kết nối lại với IP local.
4. Thu log server tại thời điểm bấm `Connect` để đối chiếu profile/runtime.

## 8) Lỗi thực tế đã gặp: `0x80b1004`

Triệu chứng trên iPad:

- Popup: `Connection attempt unsuccessful`
- Error description: `The operation couldn't be completed. 0x80b1004`

Phân tích:

- Đây là nhánh `failedConnectionAttempt` trong `CloudXRViewer`.
- Đã đối chiếu với test mạng thực tế:
  - `ping 10.24.240.130` -> OK
  - `nc -vzu -w 3 10.24.240.130 48010` -> UDP OK
  - `nc -vz -w 3 10.24.240.130 48010` -> `Connection refused` (TCP fail)

Kết luận:

- Lỗi không nằm ở bước build app iPad.
- Root cause là server chưa mở TCP listener ở cổng `48010` (hoặc process CloudXR/lovr chưa chạy đúng), nên client chuyển từ `Connecting` sang `Disconnected` ngay.

Lệnh xác minh nhanh trên server Linux:

```bash
ss -lntup | grep 48010
ps -ef | grep -E "lovr|cloudxr" | grep -v grep
```

Nếu chưa listen TCP `48010`:

```bash
cd ~/work/cloudxr-vs-ipad/cloudxr-lovr-sample
pkill -f lovr || true
sleep 1
./run.sh
```

