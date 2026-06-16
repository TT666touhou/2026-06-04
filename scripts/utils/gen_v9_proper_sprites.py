"""
V9 正式生成腳本：
- 使用插畫只作為 配色/風格 參考（不直接丟進去）
- 生成真正的 2D 橫向遊戲角色 Sprite
- 尺寸：16x16, 32x32, 48x48（+加碼 40x52）
- 端點：create-image-pixen（主力）+ create-image-pixflux+color_image（對照）

插畫角色分析（CHAR-006, Lady of the Bloodline）：
  - 銀白長直髮 + 右側大黑蝴蝶結 #F1ECF7
  - 深紅眼 #E03030
  - 深紫灰色露肩哥德洋裝 #3D3448
  - 黑色腰帶
  - 深酒紅荷葉邊 #6B1C24
  - 深棕黑色不透明絲襪 #2B1F1A
  - 修長黑色貓尾巴
"""
import sys, io, urllib.request, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
API_HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}
ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v9_proper_sprites")

CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
    # NO Accept-Encoding
    "Referer": "https://pixellab.ai/",
}


def image_to_base64(img_path: Path, max_size: int = 128) -> tuple:
    img = Image.open(img_path).convert("RGBA")
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return b64, img.size


def api_post(endpoint, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{endpoint}", data=data, headers=API_HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return None, f"HTTP {e.code}: {body[:600]}"


def api_get(path):
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def poll_job(job_id, timeout_s=300):
    deadline = time.time() + timeout_s
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        result = api_get(f"background-jobs/{job_id}")
        status = result.get("status", "unknown")
        print(f"  [{attempt}] {status}", flush=True)
        if status == "completed":
            return result
        elif status == "failed":
            raise RuntimeError(f"Job failed: {result}")
        time.sleep(5)
    raise TimeoutError("Job timed out")


def save_image_from_result(result, save_path: Path) -> bool:
    """Extract and save image from API result (handles both sync and async)"""
    save_path.parent.mkdir(parents=True, exist_ok=True)

    # Case 1: Has background_job_id (async)
    job_id = result.get("background_job_id")
    if job_id:
        print(f"  Async job: {job_id}, polling...")
        job_result = poll_job(job_id)
        # Try to get image from job result's last_response
        nested = job_result.get("last_response", {})
        result = nested if nested else result

    # Case 2: Direct image in result
    img_data = result.get("image", {})
    if isinstance(img_data, dict):
        b64 = img_data.get("base64", "")
        url = img_data.get("url", "")
        if b64:
            if ',' in b64:
                b64 = b64.split(',', 1)[1]
            save_path.write_bytes(base64.b64decode(b64))
            return True
        elif url:
            req = urllib.request.Request(url, headers=CDN_HEADERS)
            with urllib.request.urlopen(req, timeout=30) as resp:
                save_path.write_bytes(resp.read())
            return True

    print(f"  WARN: no image found in result. Keys={list(result.keys())}")
    return False


# ============================================================
# Character description (short, precise, based on CK-3 colors)
# ============================================================
CHAR_DESC_SHORT = (
    "2D side-scrolling pixel art game character, young girl facing right, "
    "silver-white hair large black bow, crimson red eyes, "
    "dark purple-gray gothic dress deep red frilled hem, "
    "black cat tail, dark tights, no weapons"
)

CHAR_DESC_WITH_COLORS = (
    "2D side-scrolling pixel art game character, young girl facing right, "
    "silver-white hair (#F1ECF7) with large black bow, crimson red eyes (#E03030), "
    "dark purple-gray gothic dress (#3D3448) with deep burgundy ruffled frills (#6B1C24), "
    "dark brown-black tights (#2B1F1A), black cat tail, no background, no weapons"
)

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Check balance
    bal = api_get("balance")
    gens = bal.get("subscription", {}).get("generations", "?")
    print(f"Balance: {gens} generations\n")

    # Encode illustration for color_image reference
    illus_b64, illus_size = image_to_base64(ILLUS_PATH, max_size=128)
    print(f"Illustration encoded: {illus_size}, b64={len(illus_b64)} chars\n")

    sizes = [
        (16, 16, "16x16", "low detail"),
        (32, 32, "32x32", "medium detail"),
        (48, 48, "48x48", "medium detail"),
        (40, 52, "40x52", "medium detail"),
    ]

    results = []

    # ============================================================
    # STRATEGY A: create-image-pixen (text description only)
    # Best for: clean pixel art at any size
    # ============================================================
    print("=" * 60)
    print("STRATEGY A: create-image-pixen (text description)")
    print("=" * 60)

    for w, h, label, detail in sizes:
        print(f"\n[A] Generating {label} ({detail})...")
        payload = {
            "description": CHAR_DESC_WITH_COLORS,
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "selective outline",
            "detail": detail,
            "no_background": True,
            "enhance_prompt": False,
        }
        t0 = time.time()
        result, err = api_post("create-image-pixen", payload)
        elapsed = time.time() - t0

        if err:
            print(f"  ERROR: {err}")
            results.append({"size": label, "strategy": "A", "status": "error", "error": err})
            continue

        print(f"  Response in {elapsed:.1f}s, usage={result.get('usage', {})}")
        save_path = OUT_DIR / f"v9a_pixen_{label}.png"
        ok = save_image_from_result(result, save_path)
        if ok:
            print(f"  Saved: {save_path.name}")
            results.append({"size": label, "strategy": "A", "status": "ok", "file": save_path.name,
                           "usage": result.get("usage", {}).get("generations", "?")})
        else:
            results.append({"size": label, "strategy": "A", "status": "save_failed"})

    # ============================================================
    # STRATEGY B: create-image-pixflux + color_image (illustration as color palette)
    # Skip 16x16 (too small for pixflux)
    # ============================================================
    print("\n" + "=" * 60)
    print("STRATEGY B: create-image-pixflux + color_image reference")
    print("=" * 60)

    for w, h, label, detail in sizes:
        if w < 24:
            print(f"\n[B] Skipping {label} (too small for pixflux)")
            continue
        print(f"\n[B] Generating {label}...")
        payload = {
            "description": CHAR_DESC_SHORT,
            "color_image": {
                "type": "base64",
                "base64": illus_b64,
                "format": "png",
            },
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "selective outline",
            "detail": detail,
            "no_background": True,
        }
        t0 = time.time()
        result, err = api_post("create-image-pixflux", payload)
        elapsed = time.time() - t0

        if err:
            print(f"  ERROR: {err}")
            results.append({"size": label, "strategy": "B", "status": "error", "error": err})
            continue

        print(f"  Response in {elapsed:.1f}s, usage={result.get('usage', {})}")
        save_path = OUT_DIR / f"v9b_pixflux_{label}.png"
        ok = save_image_from_result(result, save_path)
        if ok:
            print(f"  Saved: {save_path.name}")
            results.append({"size": label, "strategy": "B", "status": "ok", "file": save_path.name,
                           "usage": result.get("usage", {}).get("generations", "?")})
        else:
            results.append({"size": label, "strategy": "B", "status": "save_failed"})

    # Final balance check
    bal2 = api_get("balance")
    gens2 = bal2.get("subscription", {}).get("generations", "?")
    cost = float(gens) - float(gens2)

    print("\n" + "=" * 60)
    print("ALL DONE!")
    print(f"Balance: {gens} -> {gens2} (cost: {cost:.2f})")
    print("\nResults summary:")
    for r in results:
        status_icon = "OK" if r["status"] == "ok" else "ERR"
        print(f"  [{status_icon}] {r['strategy']}-{r['size']}: {r.get('file', r.get('error', '?'))}")
    print(f"\nOutput: {OUT_DIR}")

if __name__ == "__main__":
    main()
