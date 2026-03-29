# Ví dụ webcam trên Ubuntu (đã chạy thành công)

Script mẫu: `~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh`

## 1) Test nhanh camera

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh test
```

Mục đích: đọc camera `/dev/video0` và đẩy vào `fakesink` để xác nhận pipeline hoạt động.

## 2) Mở preview local

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh preview
```

Mục đích: hiển thị cửa sổ video từ webcam ngay trên Ubuntu.

## 3) Stream webcam qua UDP (RTP/JPEG)

Terminal A (máy gửi):

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh stream 192.168.0.17 5000
```

Terminal B (máy nhận):

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh receive 5000
```

Bạn có thể đổi IP/port theo mạng thực tế.

## 4) Lưu video thật ra file (WebM)

### 4.1 Ghi webcam ra file

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh record ~/work/cloudxr-vs-ipad/recordings/webcam-test.webm 10s
```

- Nếu bỏ `10s`, script sẽ ghi liên tục cho tới khi bạn nhấn `Ctrl+C`.
- Script dùng `vp8enc + webmmux`, không cần `ffmpeg`.

### 4.2 Ghi màn hình Ubuntu ra file

```bash
~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh record-screen ~/work/cloudxr-vs-ipad/recordings/screen-test.webm 10s
```

- Dùng `ximagesrc` để quay desktop hiện tại (`DISPLAY` đang chạy).
- Hữu ích để lưu lại cửa sổ LÖVR/CloudXR khi demo.

### 4.3 Kiểm tra file đã tạo

```bash
ls -lh ~/work/cloudxr-vs-ipad/recordings/*.webm
```

Kết quả đã test trên máy này:
- `~/work/cloudxr-vs-ipad/recordings/webcam-test.webm`
- `~/work/cloudxr-vs-ipad/recordings/screen-test.webm`

## Biến môi trường tùy chọn

```bash
DEVICE=/dev/video1 WIDTH=1280 HEIGHT=720 FPS=30 ~/work/cloudxr-vs-ipad/ubuntu-webcam-example.sh preview
```

## Lưu ý với CloudXR

Ví dụ này là pipeline webcam độc lập để kiểm tra capture/stream trên Ubuntu.  
Để đưa webcam vào luồng CloudXR, cần tích hợp thêm vào ứng dụng OpenXR server (không có sample “cắm thẳng webcam vào CloudXR runtime” sẵn trong bộ sample hiện tại).

## Hook point prototype đã tích hợp vào `cloudxr-lovr-sample`

Mình đã thêm module `camera_hook.lua` vào sample để test luồng dữ liệu camera-metadata qua CloudXR opaque channel:

- File mới: `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/camera_hook.lua`
- App sẽ hiển thị thêm trạng thái `Camera hook: ...` trong scene.
- Khi bật hook, app sẽ gửi metadata định kỳ theo dạng:
  - `camera_hook:device=/dev/video0;ts=<epoch>;seq=<n>`

### Cách bật hook

```bash
cd ~/work/cloudxr-vs-ipad/cloudxr-lovr-sample
export CLOUDXR_CAMERA_HOOK=1
export CLOUDXR_CAMERA_DEVICE=/dev/video0
export CLOUDXR_CAMERA_INTERVAL_SEC=1
./run.sh
```

Mục tiêu của bước này là xác nhận đường ống app -> CloudXR opaque channel -> client hoạt động, trước khi tích hợp capture frame thực tế vào rendering path.
