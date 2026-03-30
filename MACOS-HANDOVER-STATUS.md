# CloudXR Handover Status (Linux -> macOS)

Muc tieu: file nay giup may macOS clone repo ve la nam duoc ngay trang thai hien tai, cac thay doi vua push, cach build lai client iOS, va cach connect den Linux server.

## 1) Commit da push gan nhat

- Branch: `main`
- Commit: `e9efda2`
- Message: `fix: improve record feedback and add Lua recording tests`

Thay doi chinh:

- `cloudxr-apple-generic-viewer/CloudXRViewer/Common/ServerActionsView.swift`
  - Nut Record luon tra feedback ngay khi nhan.
  - Hien thi loi ro rang khi channel chua san sang / khong gui duoc lenh.
  - Parse loi tu server theo dang `status:recording_error:<detail>`.
- `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/cloudxr_manager.lua`
  - Server tra loi recording co detail (`status:recording_error:<detail>`).
- Them test Lua:
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/tests/recorder_gpu_capture_test.lua`
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/tests/cloudxr_manager_record_feedback_test.lua`
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/tests/run_lua_tests.sh`

## 2) Tinh trang server Linux hien tai

- Da khoi dong lai CloudXR LOVR server tu:
  - `cloudxr-lovr-sample/run.sh`
- Server dang listen:
  - TCP `0.0.0.0:48010`
- LAN IP da dung de test:
  - `10.24.240.130`

Luu y: IP co the thay doi theo moi lan vao mang. Luon kiem tra lai IP tren Linux bang:

```bash
hostname -I
ip route get 1.1.1.1
ss -lntup | grep 48010
```

## 3) Cac test record da verify

### 3.1 Lua tests (logic)

Da chay pass:

```bash
bash cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/tests/run_lua_tests.sh
```

Ket qua:

- `PASS recorder_gpu_capture_test.lua`
- `PASS cloudxr_manager_record_feedback_test.lua`
- `All Lua tests passed.`

### 3.2 Record that webcam thuc te

Da test luu video thuc te bang GStreamer:

```bash
./ubuntu-webcam-example.sh record "/home/anhnx10/work/cloudxr-vs-ipad/recordings/webcam-18s-test.webm" 18s
```

File ket qua:

- `/home/anhnx10/work/cloudxr-vs-ipad/recordings/webcam-18s-test.webm`
- Duration thuc te: ~`17.83s`
- Resolution: `640x480`, `30 FPS`, codec `VP8`, container `WebM`

## 4) Huong dan nhanh tren macOS sau khi clone

### 4.1 Clone va dong bo

```bash
git clone git@github.com:anhnx000/cloudxr-vs-ipad.git
cd cloudxr-vs-ipad
git checkout main
git pull --ff-only
git log --oneline -n 5
```

Xac nhan co commit `e9efda2`.

### 4.2 Build client iOS tren macOS

Doc chi tiet tai:

- `HUONG-DAN-BUILD-IPAD-CLOUDXR.md`
- `cloudxr-apple-generic-viewer/README.md`

Lenh mau:

```bash
xcodebuild \
  -project cloudxr-apple-generic-viewer/CloudXRViewer.xcodeproj \
  -scheme CloudXRViewer-iOS \
  -destination 'platform=iOS,id=<YOUR_DEVICE_ID>' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  clean build
```

### 4.3 Connect tu iPad/visionOS app

- Trong app, chon `Manual IP address`.
- Nhap IP Linux server (vi du hien tai: `10.24.240.130`).
- Connect den CloudXR server (port mac dinh: `48010`).

Neu khong connect duoc:

1. Kiem tra Linux server dang chay (`run.sh`) va port `48010` dang listen.
2. Ping/port check tu mac:

```bash
ping -c 4 <SERVER_IP>
nc -vz <SERVER_IP> 48010
nc -vzu <SERVER_IP> 48010
```

3. Dam bao iPad va Linux cung subnet va khong bi client isolation.

## 5) Ghi chu van hanh

- Neu `runtime_started` bi ket sau lan crash:

```bash
rm -f /run/user/1000/runtime_started
```

- Sau do chay lai:

```bash
cd cloudxr-lovr-sample
./run.sh
```

