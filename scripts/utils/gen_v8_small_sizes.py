"""
V8 生成腳本 - image-to-pixelart
直接將插畫 Lady_of_the_Bloodline.png 餵入 /image-to-pixelart 端點
生成三種尺寸：16x16, 32x32, 48x48

重點：
- 頭身比：16x16 自由，32x32 約4頭身，48x48 接近 40x52 參考比例
- 此端點為同步（無 background_job），直接回傳
"""
import sys, io, urllib.request, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
API_HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}

ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v8_small_sizes")


def image_to_base64(img_path: Path, max_size: int = 256) -> tuple:
    """Load, resize, return (base64_str, (w,h))"""
    img = Image.open(img_path).convert("RGBA")
    orig_size = img.size
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    resized_size = img.size
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    print(f"  Input image: {orig_size} -> resized to {resized_size}, b64={len(b64)} chars")
    return b64, resized_size


def api_post(endpoint: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/{endpoint}", data=data, headers=API_HEADERS, method="POST"
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read())


def api_get(path: str) -> dict:
    req = urllib.request.Request(
        f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
}


def download_url(url: str, save_path: Path) -> bool:
    req = urllib.request.Request(url, headers=CDN_HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    if data[:4] != b'\x89PNG' and not data[:3] == b'\xff\xd8\xff':
        # Try to save anyway and see
        print(f"  WARN: not PNG/JPEG header: {data[:8].hex()}")
    save_path.write_bytes(data)
    return True


def save_base64_image(b64data: str, save_path: Path):
    """Save base64 image data to file"""
    # Remove data URI prefix if present
    if ',' in b64data:
        b64data = b64data.split(',', 1)[1]
    raw = base64.b64decode(b64data)
    save_path.write_bytes(raw)


def generate_small_sprite(output_w: int, output_h: int, input_b64: str, input_size: tuple, label: str):
    """Generate one small sprite via image-to-pixelart"""
    save_dir = OUT_DIR
    save_dir.mkdir(parents=True, exist_ok=True)
    save_path = save_dir / f"v8_{label}_{output_w}x{output_h}.png"

    print(f"\n{'='*55}")
    print(f"Generating {output_w}x{output_h} ({label})")
    print(f"{'='*55}")

    payload = {
        "image": {
            "type": "base64",
            "base64": input_b64,
            "format": "png",
        },
        "image_size": {
            "width": input_size[0],
            "height": input_size[1],
        },
        "output_size": {
            "width": output_w,
            "height": output_h,
        },
    }

    t0 = time.time()
    try:
        result = api_post("image-to-pixelart", payload)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  HTTP ERROR {e.code}: {body[:500]}")
        return None

    elapsed = time.time() - t0
    print(f"  Response in {elapsed:.1f}s")
    print(f"  Keys: {list(result.keys())}")

    # Check for usage info
    usage = result.get("usage", {})
    print(f"  Usage: {usage}")

    # Check for image data (could be url or base64)
    img_data = result.get("image", {})
    img_url = result.get("url", "")
    img_b64 = result.get("base64", "")

    # Try image object
    if isinstance(img_data, dict):
        url = img_data.get("url", "")
        b64 = img_data.get("base64", "")
        if url:
            print(f"  Image URL: {url[:80]}...")
            download_url(url, save_path)
            print(f"  Saved: {save_path.name}")
            return save_path
        elif b64:
            print(f"  Image base64 length: {len(b64)}")
            save_base64_image(b64, save_path)
            print(f"  Saved: {save_path.name}")
            return save_path

    # Fallback: direct URL in result
    if img_url:
        print(f"  Direct URL: {img_url[:80]}...")
        download_url(img_url, save_path)
        print(f"  Saved: {save_path.name}")
        return save_path

    # Fallback: direct base64
    if img_b64:
        save_base64_image(img_b64, save_path)
        print(f"  Saved from base64: {save_path.name}")
        return save_path

    print(f"  WARN: could not find image in response!")
    print(f"  Full result: {json.dumps(result)[:500]}")
    return None


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Check balance
    bal = api_get("balance")
    gens = bal.get("subscription", {}).get("generations", "?")
    print(f"Balance: {gens} generations")

    # Encode illustration (resize to max 256 for API input)
    print(f"\nEncoding illustration: {ILLUS_PATH.name}")
    input_b64, input_size = image_to_base64(ILLUS_PATH, max_size=256)

    # ============================================================
    # 16x16: Free style (chibi proportion OK)
    # ============================================================
    result_16 = generate_small_sprite(16, 16, input_b64, input_size, "chibi_free")

    # ============================================================
    # 32x32: ~4 head ratio (head ~9px, body ~23px)
    # ============================================================
    result_32 = generate_small_sprite(32, 32, input_b64, input_size, "medium")

    # ============================================================
    # 48x48: Close to 40x52 Sprite ratio (head ~17px = 35%)
    # Note: 48x48 is square, original 40x52 is portrait
    # We could also try 40x52 directly to match exactly
    # ============================================================
    result_48 = generate_small_sprite(48, 48, input_b64, input_size, "sprite_size")

    # Bonus: try 40x52 to match exact reference proportions
    result_ref = generate_small_sprite(40, 52, input_b64, input_size, "exact_ref")

    # Final balance check
    bal2 = api_get("balance")
    gens2 = bal2.get("subscription", {}).get("generations", "?")
    print(f"\n{'='*55}")
    print(f"ALL DONE!")
    print(f"Balance before: {gens} -> after: {gens2}")
    print(f"Cost: {float(gens) - float(gens2):.2f} generations")
    print(f"Output dir: {OUT_DIR}")
    print(f"{'='*55}")


if __name__ == "__main__":
    main()
