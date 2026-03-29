# CloudXR Runtime Linux - Cài đặt thành công (RTX 5060)

Tài liệu này ghi lại quy trình đã chạy thành công trên máy hiện tại:

- OS: Ubuntu 24.04.4 LTS
- GPU: NVIDIA GeForce RTX 5060 Laptop
- Driver: 580.126.09 (`nvidia-smi` hoạt động)
- Thư mục làm việc: `~/work/cloudxr-vs-ipad`

---

## 1) Kiểm tra GPU/driver trước khi cài

```bash
nvidia-smi
uname -a
cat /etc/os-release
```

Kết quả mong đợi:
- `nvidia-smi` hiển thị đầy đủ thông tin GPU/Driver.

---

## 2) Cài NGC CLI để tải CloudXR Runtime

```bash
mkdir -p ~/.local/bin
cd ~/.local/bin
curl -fL "https://ngc.nvidia.com/downloads/ngccli_linux.zip" -o ngccli_linux.zip
python3 -m zipfile -e ngccli_linux.zip .
chmod +x ~/.local/bin/ngc-cli/ngc
~/.local/bin/ngc-cli/ngc --version
```

Kết quả đã xác nhận trên máy này: `NGC CLI 4.15.0`

---

## 3) Đăng nhập NGC (nếu chưa đăng nhập)

Nếu máy đã đăng nhập sẵn, có thể bỏ qua bước này.

```bash
~/.local/bin/ngc-cli/ngc config set
```

Bước này sẽ yêu cầu nhập API key NGC.

---

## 4) Tải CloudXR Runtime từ NGC

```bash
mkdir -p ~/work/cloudxr-vs-ipad/downloads
~/.local/bin/ngc-cli/ngc registry resource download-version \
  --dest ~/work/cloudxr-vs-ipad/downloads \
  "nvidia/cloudxr-runtime:6.0.4"
```

Các file đã tải về:

- `~/work/cloudxr-vs-ipad/downloads/cloudxr-runtime_v6.0.4/CloudXR-6.0.4-Linux-sdk.tar.gz`
- `~/work/cloudxr-vs-ipad/downloads/cloudxr-runtime_v6.0.4/CloudXR-6.0.4-Win64-sdk.zip`

---

## 5) Giải nén gói Linux SDK

```bash
mkdir -p ~/work/cloudxr-vs-ipad/runtime
tar -xzf ~/work/cloudxr-vs-ipad/downloads/cloudxr-runtime_v6.0.4/CloudXR-6.0.4-Linux-sdk.tar.gz \
  -C ~/work/cloudxr-vs-ipad/runtime
```

Kiểm tra các file quan trọng:

```bash
ls -la ~/work/cloudxr-vs-ipad/runtime
```

Cần có tối thiểu:
- `openxr_cloudxr.json`
- `libopenxr_cloudxr.so`
- `libNvStreamServer.so`

---

## 6) Cài runtime vào user path và set OpenXR runtime mặc định

```bash
mkdir -p ~/.local/share/cloudxr-runtime/6.0.4
cp -a ~/work/cloudxr-vs-ipad/runtime/. ~/.local/share/cloudxr-runtime/6.0.4/

mkdir -p ~/.config/openxr/1
ln -sfn ~/.local/share/cloudxr-runtime/6.0.4/openxr_cloudxr.json \
  ~/.config/openxr/1/active_runtime.json
```

---

## 7) Thiết lập biến môi trường `XR_RUNTIME_JSON`

Thêm vào `~/.zshrc`:

```bash
export XR_RUNTIME_JSON="$HOME/.local/share/cloudxr-runtime/6.0.4/openxr_cloudxr.json"
```

Áp dụng:

```bash
source ~/.zshrc
echo "$XR_RUNTIME_JSON"
```

Kết quả mong đợi:
- In ra đường dẫn `~/.local/share/cloudxr-runtime/6.0.4/openxr_cloudxr.json`

---

## 8) Verify cài đặt thành công

### 8.1 Verify logic runtime/manifest

```bash
python3 - <<'PY'
import json
from pathlib import Path

runtime_json = Path.home()/".local/share/cloudxr-runtime/6.0.4/openxr_cloudxr.json"
active_link = Path.home()/".config/openxr/1/active_runtime.json"

print("runtime_json_exists:", runtime_json.exists())
print("active_runtime_exists:", active_link.exists())
print("active_runtime_target_ok:", active_link.resolve()==runtime_json if active_link.exists() else False)

data = json.loads(runtime_json.read_text())
lib_abs = (runtime_json.parent / data["runtime"]["library_path"]).resolve()
print("runtime_library_exists:", lib_abs.exists())
print("runtime_library:", lib_abs)
PY
```

### 8.2 Verify phụ thuộc thư viện

```bash
ldd ~/.local/share/cloudxr-runtime/6.0.4/libopenxr_cloudxr.so
```

Kết quả mong đợi:
- Không có dòng `not found`.

Kết quả đã xác minh trên máy này:
- `runtime_json_exists: True`
- `active_runtime_exists: True`
- `active_runtime_target_ok: True`
- `runtime_library_exists: True`

---

## 9) Lưu ý để stream sang iPad

- Máy đã cài xong **CloudXR Runtime** trên Linux.
- Để stream thực tế, cần có **server app OpenXR** sử dụng runtime này (ví dụ app/server sample tương thích), không chỉ riêng framework iPad.
- iPad client vẫn cần build/deploy bằng Xcode từ:
  - `cloudxr-framework`
  - `cloudxr-apple-generic-viewer`

---

## Đường dẫn quan trọng

- Runtime install: `~/.local/share/cloudxr-runtime/6.0.4`
- OpenXR active runtime symlink: `~/.config/openxr/1/active_runtime.json`
- Biến môi trường: `XR_RUNTIME_JSON`
- Repo làm việc: `~/work/cloudxr-vs-ipad`
