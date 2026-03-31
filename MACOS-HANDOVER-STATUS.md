# CloudXR Handover Status (Linux -> macOS)

Muc tieu: tai lieu nay giup may macOS clone repo ve la hieu ngay:
- Kien truc hien tai cua luong iPad -> Linux server.
- Cac commit chinh da push tren `main`.
- Cach build client iOS va test ket noi.
- Cach doc logs de phan tich loi khi test that tren iPad.

## 1) Snapshot commit gan day tren main

Recent commits (new -> old):

- `fba130f` - feat: add iPad camera ingest pipeline and CloudXR output recording
- `6c64f03` - fix: separate iPad/Ubuntu recordings and harden record stop flow
- `fcedde8` - feat: add iPad fallback record control without headset dependency
- `da70f8b` - docs: add macOS handover status for rebuild and reconnect
- `e9efda2` - fix: improve record feedback and add Lua recording tests

Neu clone tren macOS, hay xac nhan da co commit `fba130f` tro len.

## 2) Kien truc hien tai (quan trong)

### 2.1 CloudXR output recording (muc tieu chinh)

- Record output sau khi qua render pipeline cua LOVR/CloudXR (khong phai quay truc tiep camera iPad).
- Path chinh:
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/main.lua`
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/cloudxr_manager.lua`
  - `cloudxr-lovr-sample/plugins/nvidia/examples/cloudxr/recorder.lua`
- Recorder capture frame tu off-screen pass, encode MP4 bang GStreamer.

### 2.2 Fallback control API cho iPad

- API chay tren Linux: `cloudxr-lovr-sample/tools/record_control_api.py`
- Port: `49080`
- Endpoints:
  - `GET /health`
  - `GET /record/status`
  - `POST /record/start`
  - `POST /record/stop`
  - `GET /camera/status`
  - `POST /camera/start`
  - `POST /camera/frame`
  - `POST /camera/stop`
- Control record qua file IPC:
  - `/tmp/cloudxr_lovr_record_cmd.txt`
  - `/tmp/cloudxr_lovr_record_status.txt`

### 2.3 Headset-independent mode

- Mac dinh khong bat buoc headset (`CXR_REQUIRE_HEADSET != 1`).
- Muc tieu: dam bao iPad flow van chay du khong co OpenXR headset vat ly.

## 3) Logging va phan tich server (da nang cap)

### 3.1 Thu muc logs theo session

`run.sh` tao log theo tung session:

- `cloudxr-lovr-sample/logs/server/<YYYYmmdd_HHMMSS>/run.log`
- `cloudxr-lovr-sample/logs/server/<YYYYmmdd_HHMMSS>/lovr.log`
- `cloudxr-lovr-sample/logs/server/<YYYYmmdd_HHMMSS>/record_api.log`
- Shortcut session moi nhat:
  - `cloudxr-lovr-sample/logs/server/latest`

### 3.2 Script check nhanh logs

Da co script:

- `cloudxr-lovr-sample/tools/check_server_logs.sh`

Dung:

```bash
cd cloudxr-lovr-sample
./tools/check_server_logs.sh
```

Script se in:
- tail `lovr.log`
- tail `record_api.log`
- noi dung `/tmp/cloudxr_lovr_record_status.txt`

### 3.3 Pattern logs quan trong de phan tich

Trong `record_api.log`, uu tien tim:

- `record.start request_id=...`
- `record.start ok request_id=...`
- `record.stop request_id=...`
- `record.stop ok request_id=...`
- `record.start failed ...` / `record.stop failed ...`

Neu can truy vet mot case, gom log theo `request_id`.

## 4) Huong dan nhanh tren macOS sau khi clone

### 4.1 Clone va dong bo

```bash
git clone git@github.com:anhnx000/cloudxr-vs-ipad.git
cd cloudxr-vs-ipad
git checkout main
git pull --ff-only
git log --oneline -n 8
```

### 4.2 Build client iOS tren macOS

Tai lieu:

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

### 4.3 Connect tu iPad app

- Trong app: chon `Manual IP address`.
- Nhap IP Linux server.
- Connect CloudXR port `48010`.
- API fallback record dung port `49080` (HTTP).

## 5) Runbook Linux server cho nguoi van hanh

### 5.1 Start server

```bash
cd cloudxr-lovr-sample
rm -f /run/user/1000/runtime_started
./run.sh
```

### 5.2 Check nhanh runtime/network

```bash
hostname -I
ip route get 1.1.1.1
ss -lntup | grep -E '48010|49080'
curl -sS http://127.0.0.1:49080/health
```

### 5.3 Khi test iPad xong, thu thap thong tin de phan tich

```bash
cd cloudxr-lovr-sample
./tools/check_server_logs.sh
```

Va gui kem:
- thu muc `cloudxr-lovr-sample/logs/server/latest/`
- file `/tmp/cloudxr_lovr_record_status.txt`
- timestamp thao tac tren iPad (nhan record/start/stop, thong bao loi tren UI)

## 6) Ghi chu cho nguoi tiep theo

- Luong record uu tien output sau CloudXR render (khong phai stream camera iPad raw).
- Camera ingest endpoints van ton tai de test pipeline du phong.
- Neu co loi recording pending hoac mismatch status, check `record_api.log` theo `request_id` truoc, sau do doi chieu voi `lovr.log`.

