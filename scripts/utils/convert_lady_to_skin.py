"""
convert_lady_to_skin.py
Lady_of_the_Bloodline 插畫 → DS Skin 規格 (40×52px) 轉換
三種方案對比：
  A. PIL 直接 NEAREST 縮放（免費）
  B. pixflux API + PIL（0.5gen）
  C. image-to-pixelart-pro API + PIL（~40gen，高費用）

§Q2 流程：Designer → Architect → Developer → Sensor → Reviewer → QA
"""
import sys
import os
import base64
import json
import time
import struct
import zlib
import io
import requests
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')

# === CONFIG ===
API_TOKEN = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Content-Type": "application/json",
}
CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "Referer": "https://editor.pixellab.ai/",
    # ⚠️ 禁止加 Accept-Encoding (CDN Brotli 解碼錯誤 § GAP-014)
}

SOURCE_IMAGE = r"d:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png"
TARGET_SKIN = r"d:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png"
OUT_DIR = r"d:\2026-06-04\assets\characters\generated\vampire_v1\skin_conversion"
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_W, TARGET_H = 40, 52
PREVIEW_SCALE = 8  # 8x preview for visibility


def img_to_b64(img: Image.Image, fmt="PNG") -> str:
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return base64.b64encode(buf.getvalue()).decode()


def b64_to_img(b64: str) -> Image.Image:
    return Image.open(io.BytesIO(base64.b64decode(b64)))


def save_with_preview(img: Image.Image, name: str, scale: int = PREVIEW_SCALE):
    """Save image and 8x preview"""
    out_path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(out_path)
    prev = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    prev_path = os.path.join(OUT_DIR, f"{name}_{scale}x_preview.png")
    prev.save(prev_path)
    print(f"  ✅ 已儲存: {name}.png ({img.size}) + {scale}x preview")
    return out_path


def resize_to_skin_spec(img: Image.Image) -> Image.Image:
    """Resize to 40×52 with black background (DS skin spec §O12)"""
    img_rgba = img.convert("RGBA")
    target = img_rgba.resize((TARGET_W, TARGET_H), Image.NEAREST)
    bg = Image.new("RGB", (TARGET_W, TARGET_H), (0, 0, 0))
    bg.paste(target, mask=target.split()[3])
    return bg


def poll_job(job_id: str, max_wait=300) -> dict:
    """Poll background job (§O11-6, §O8 異步規則)"""
    print(f"  📡 等待異步 job {job_id[:12]}...")
    for i in range(max_wait // 5):
        time.sleep(5)
        r = requests.get(f"{BASE_URL}/background-jobs/{job_id}", headers=HEADERS)
        if r.status_code != 200:
            print(f"  ⚠️ Poll error: {r.status_code}")
            continue
        job = r.json()
        status = job.get("status", "unknown")
        print(f"  [{i*5}s] status={status}")
        if status == "completed":
            return job
        elif status in ("failed", "cancelled"):
            raise RuntimeError(f"Job failed: {job}")
    raise TimeoutError(f"Job {job_id} did not complete in {max_wait}s")


# ==========================================
# 方案 A：PIL 直接 NEAREST 縮放（免費）
# ==========================================
def method_a_pil_only():
    print("\n🅐 方案 A: PIL 直接 NEAREST 縮放（免費）")
    src = Image.open(SOURCE_IMAGE).convert("RGBA")
    print(f"  來源尺寸: {src.size}")

    # 直接縮放到 40×52
    result = resize_to_skin_spec(src)
    save_with_preview(result, "A1_pil_nearest_40x52")

    # 也試試先縮到 160×208 再縮（減少色彩損失）
    mid = src.resize((160, 208), Image.LANCZOS)
    result2 = resize_to_skin_spec(mid)
    save_with_preview(result2, "A2_pil_lanczos_then_nearest_40x52")
    print("  ✅ 方案 A 完成（0 gen 消耗）")


# ==========================================
# 方案 B：pixflux API + PIL（0.5gen）
# ==========================================
def method_b_pixflux():
    print("\n🅑 方案 B: pixflux API + PIL（0.5gen）")
    # 讀取插畫，縮至 128px 作為 color_image
    src = Image.open(SOURCE_IMAGE).convert("RGBA")
    src_small = src.copy()
    src_small.thumbnail((128, 128), Image.LANCZOS)
    color_b64 = img_to_b64(src_small)

    # 配色從 Lady skin 提取（§O9-2b）
    payload = {
        "description": "girl character sprite, pale white silver hair, deep red eyes, dark charcoal gothic dress with deep burgundy dark red ruffle hem, dark tights, no background, pixel art, side view, facing right",
        "image_size": {"width": 80, "height": 104},  # 生成 80×104，再縮小（§O8 陷阱）
        "no_background": True,
        "outline": "selective outline",
        "shading": "medium shading",
        "detail": "highly detailed",
        "text_guidance_scale": 9.5,
        "color_image": {
            "type": "base64",
            "base64": color_b64,
            "format": "png",
        },
    }

    print("  📡 呼叫 create-image-pixflux...")
    r = requests.post(f"{BASE_URL}/create-image-pixflux", headers=HEADERS, json=payload)
    print(f"  Status: {r.status_code}")

    if r.status_code == 200:
        data = r.json()
        img_b64 = data.get("image", {}).get("base64", "")
        if img_b64:
            img80 = b64_to_img(img_b64)
            save_with_preview(img80, "B1_pixflux_80x104_raw")
            # PIL resize to 40×52
            result = resize_to_skin_spec(img80)
            save_with_preview(result, "B2_pixflux_resized_40x52")
            print("  ✅ 方案 B 完成（消耗約 0.5gen）")
        else:
            print(f"  ❌ No image in response: {json.dumps(data)[:200]}")
    else:
        print(f"  ❌ Error: {r.text[:300]}")


# ==========================================
# 方案 C：image-to-pixelart-pro + PIL（~40gen）
# ==========================================
def method_c_img2px_pro():
    print("\n🅒 方案 C: image-to-pixelart-pro（~40gen）+ PIL resize")
    print("  ⚠️ GAP-023：高費用端點，已由用戶二次確認（'123都用一遍'）")

    # 縮小插畫到 ≤256px
    src = Image.open(SOURCE_IMAGE).convert("RGBA")
    src_copy = src.copy()
    src_copy.thumbnail((256, 256), Image.LANCZOS)
    print(f"  縮小插畫: {src.size} → {src_copy.size}")
    src_b64 = img_to_b64(src_copy)

    payload = {
        "image": {
            "type": "base64",
            "base64": src_b64,
            "format": "png",
        },
        "description": "girl character sprite, pixel art style, dark gothic dress",
    }

    print("  📡 呼叫 image-to-pixelart-pro（異步）...")
    r = requests.post(f"{BASE_URL}/image-to-pixelart-pro", headers=HEADERS, json=payload)
    print(f"  Status: {r.status_code}")

    if r.status_code in (200, 202):
        data = r.json()
        print(f"  Response keys: {list(data.keys())}")

        # 可能同步或異步
        if "image" in data and data["image"].get("base64"):
            # 同步回傳
            img = b64_to_img(data["image"]["base64"])
            save_with_preview(img, "C1_img2pxpro_raw")
        elif "id" in data:
            # 異步（background_job_id）
            job_id = data["id"]
            print(f"  ⏳ 異步 job_id: {job_id}")
            job = poll_job(job_id)
            # 從 last_response 提取圖片 (§O11-6 GAP-018 修復格式)
            lr = job.get("last_response", {})
            imgs = lr.get("images", [])
            if imgs:
                img_b64 = imgs[0]["base64"]  # ★ 頂層直接取，非 ["image"]["base64"]
                img = b64_to_img(img_b64)
                save_with_preview(img, "C1_img2pxpro_raw")
                print(f"  生成尺寸: {img.size}")
            else:
                # 也可能直接在 last_response["image"] 頂層
                single_img = lr.get("image", {})
                if single_img.get("base64"):
                    img = b64_to_img(single_img["base64"])
                    save_with_preview(img, "C1_img2pxpro_raw")
                else:
                    print(f"  ❌ 無法取出圖片，last_response keys: {list(lr.keys())}")
                    print(f"  Full job: {json.dumps(job)[:500]}")
                    return
        else:
            print(f"  ❓ Unknown response: {json.dumps(data)[:300]}")
            return

        # PIL resize to 40×52
        img = Image.open(os.path.join(OUT_DIR, "C1_img2pxpro_raw.png"))
        result = resize_to_skin_spec(img)
        save_with_preview(result, "C2_img2pxpro_resized_40x52")
        print("  ✅ 方案 C 完成（消耗約 40gen）")
    else:
        print(f"  ❌ Error {r.status_code}: {r.text[:300]}")


# ==========================================
# 與參考 Skin 對比
# ==========================================
def compare_with_target_skin():
    print("\n📊 與目標 skin 規格對比")
    ref_skin = Image.open(TARGET_SKIN)
    print(f"  目標 skin 尺寸: {ref_skin.size}")
    save_with_preview(ref_skin, "REF_Lady_skin_reference")


# ==========================================
# Main
# ==========================================
print("=" * 60)
print("Lady_of_the_Bloodline 插畫 → DS Skin 規格 轉換")
print(f"輸出目錄: {OUT_DIR}")
print("=" * 60)

# 顯示參考 skin
compare_with_target_skin()

# 執行三種方案
method_a_pil_only()
method_b_pixflux()
method_c_img2px_pro()

print("\n🎉 所有方案完成！")
print(f"結果目錄: {OUT_DIR}")
print("請比較 A1/A2/B2/C2 輸出以選擇最佳方案")
