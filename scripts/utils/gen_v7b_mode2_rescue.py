"""
V7B Mode 2A + 2B 補救腳本
- Mode 2A: 大插畫 reference_image（已有 job_id: 1057ccaf-a263-431a-9503-7dc7f4413de2）
- Mode 2B: 小 Sprite reference_image（新送出）

修正: enhance_prompt: true 不是有效參數 (422)
     改為只用 reference_image，不帶 enhance_prompt
"""
import sys, io, urllib.request, json, time, base64
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v7b")

ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
SPRITE_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")

CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    # NO Accept-Encoding
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
}

API_HEADERS = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
}


def image_to_base64(img_path: Path, max_size: int = 256) -> tuple[str, tuple]:
    img = Image.open(img_path).convert("RGBA")
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return b64, img.size


def api_post(endpoint: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{endpoint}", data=data, headers=API_HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


def api_get(path: str) -> dict:
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def download_image(url: str, save_path: Path) -> bool:
    req = urllib.request.Request(url, headers=CDN_HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    if data[:4] != b'\x89PNG':
        raise ValueError(f"Not PNG! bytes={data[:4].hex()}")
    save_path.write_bytes(data)
    return True


def poll_and_download(job_id: str, char_id: str, save_dir: Path, prefix: str, timeout_s: int = 600):
    """Poll job then download all rotations"""
    save_dir.mkdir(parents=True, exist_ok=True)
    deadline = time.time() + timeout_s
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        result = api_get(f"background-jobs/{job_id}")
        status = result.get("status", "unknown")
        print(f"  [{attempt}] status={status}", flush=True)
        if status == "completed":
            usage = result.get("usage", {}).get("generations", "?")
            print(f"  Completed! usage={usage}")
            break
        elif status == "failed":
            raise RuntimeError(f"Job failed: {result}")
        time.sleep(5)
    else:
        raise TimeoutError("Job timed out")

    # Get character data
    char_data = api_get(f"characters/{char_id}")
    rotation_urls = char_data.get("rotation_urls", {})
    print(f"  Directions: {list(rotation_urls.keys())}")

    success = 0
    for direction, url in rotation_urls.items():
        if url:
            fname = save_dir / f"{prefix}_{direction}.png"
            try:
                download_image(url, fname)
                print(f"  OK {direction}: {fname.name}")
                success += 1
            except Exception as e:
                print(f"  ERR {direction}: {e}")
    print(f"  Done: {success} files -> {save_dir}")
    return success


def main():
    print("=== V7B Mode2A + Mode2B rescue ===")
    print(f"Note: enhance_prompt is NOT a valid param for create-character-v3")

    # ========================================================
    # Mode 2A: Already submitted, just poll + download
    # job_id: 1057ccaf-a263-431a-9503-7dc7f4413de2
    # char_id: unknown, need to get from job result
    # ========================================================
    print("\n--- MODE 2A: Polling already-submitted job ---")
    job_id_2a = "1057ccaf-a263-431a-9503-7dc7f4413de2"

    # Poll to get char_id from result
    deadline = time.time() + 600
    attempt = 0
    char_id_2a = None
    while time.time() < deadline:
        attempt += 1
        result = api_get(f"background-jobs/{job_id_2a}")
        status = result.get("status", "unknown")
        print(f"  [{attempt}] status={status}", flush=True)
        if status == "completed":
            usage = result.get("usage", {}).get("generations", "?")
            char_id_2a = result.get("last_response", {}).get("character_id", "")
            print(f"  Completed! usage={usage}, char_id={char_id_2a}")
            break
        elif status == "failed":
            print(f"  Failed: {result}")
            break
        time.sleep(5)

    if char_id_2a:
        poll_and_download(job_id_2a, char_id_2a, OUT_DIR / "mode2a_illus", "mode2a", timeout_s=10)

    # ========================================================
    # Mode 2B: Small sprite reference_image (NEW submission)
    # ========================================================
    print("\n--- MODE 2B: Small Sprite reference_image ---")
    sprite_b64, sprite_size = image_to_base64(SPRITE_PATH, max_size=256)
    print(f"  Sprite size after thumbnail: {sprite_size}, b64 len: {len(sprite_b64)}")

    desc_2b = (
        "young girl, 4-to-5 head body ratio, "
        "silver-white long straight hair, black bow, deep crimson red eyes, "
        "dark purple-gray off-shoulder gothic dress, black waist belt, "
        "deep burgundy red frills at hem and sleeves, dark tights, "
        "black cat tail, no weapons, facing right"
    )

    payload_2b = {
        "description": desc_2b,
        "reference_image": {
            "type": "base64",
            "base64": sprite_b64,
            "format": "png",
        },
        "image_size": {"width": 256, "height": 256},
        "view": "side",
    }

    print("  Submitting Mode 2B...")
    result_2b = api_post("create-character-v3", payload_2b)
    job_id_2b = result_2b.get("background_job_id")
    char_id_2b = result_2b.get("character_id")
    print(f"  job_id: {job_id_2b}")
    print(f"  char_id: {char_id_2b}")

    if job_id_2b:
        poll_and_download(job_id_2b, char_id_2b, OUT_DIR / "mode2b_sprite", "mode2b")

    print("\n=== ALL MODES COMPLETE ===")


if __name__ == "__main__":
    main()
