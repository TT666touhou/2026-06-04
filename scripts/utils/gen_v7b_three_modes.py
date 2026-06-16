"""
V7B 生成腳本 - 三種模式
Mode 1: 文字 Prompt -> enhance-character-v3-prompt -> create-character-v3
Mode 2A: 大插畫(487x707) resize -> reference_image + enhance_prompt:true -> create-character-v3
Mode 2B: 小Sprite(40x52) resize -> reference_image + enhance_prompt:true -> create-character-v3

關鍵修正(V7A -> V7B):
- view: "south" (非 side) - 2D橫向遊戲標準視角，可見臉部
- 髮色: "silver-white hair" (非 pale warm-white)
- enhance-character-v3-prompt 不支援圖片，改用 create-character-v3 內建 enhance_prompt:true
"""
import sys, io, urllib.request, json, time, base64
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v7b")

# Reference image paths
ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
SPRITE_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")

CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    # NO Accept-Encoding - Brotli trap!
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
}

API_HEADERS = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
}

# V7B text prompt (corrected from V7A - SHORT version for enhance endpoint)
BASE_PROMPT = (
    "2D side-scrolling game character, young girl, "
    "4-to-5 head body ratio, slight 3/4 angle toward viewer, "
    "silver-white hair, black bow, crimson red eyes, "
    "dark purple-gray off-shoulder gothic dress, black waist belt with back bow, "
    "deep burgundy red frills at hem and sleeves, dark tights, "
    "black cat tail, no weapons, facing right"
)


def image_to_base64(img_path: Path, max_size: int = 256) -> str:
    """Load image, resize to max_size, return raw base64 (no data URI prefix)"""
    img = Image.open(img_path).convert("RGBA")
    # Resize so max dimension = max_size
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    import io as _io
    buf = _io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


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


def poll_job(job_id: str, timeout_s: int = 600) -> dict:
    deadline = time.time() + timeout_s
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        result = api_get(f"background-jobs/{job_id}")
        status = result.get("status", "unknown")
        print(f"  [{attempt}] status={status}", flush=True)
        if status == "completed":
            return result
        elif status == "failed":
            raise RuntimeError(f"Job failed: {result.get('last_response', {})}")
        time.sleep(5)
    raise TimeoutError(f"Job timed out")


def run_generation(mode_name: str, payload: dict, save_subdir: str):
    """Generic runner: POST -> poll -> download"""
    save_dir = OUT_DIR / save_subdir
    save_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"MODE: {mode_name}")
    print(f"{'='*60}")

    # POST
    result = api_post("create-character-v3", payload)
    job_id = result.get("background_job_id")
    char_id = result.get("character_id")
    print(f"job_id: {job_id}")
    print(f"char_id: {char_id}")

    if not job_id:
        raise RuntimeError(f"No job_id! response={result}")

    # Poll
    print("Polling...")
    job_done = poll_job(job_id)
    usage = job_done.get("usage", {}).get("generations", "?")
    print(f"Completed! usage={usage} generations")

    # Get character
    char_data = api_get(f"characters/{char_id}")
    rotation_urls = char_data.get("rotation_urls", {})
    print(f"Available directions: {list(rotation_urls.keys())}")

    # Download
    success = 0
    for direction, url in rotation_urls.items():
        if url:
            fname = save_dir / f"{save_subdir}_{direction}.png"
            try:
                download_image(url, fname)
                print(f"  OK {direction}: {fname.name}")
                success += 1
            except Exception as e:
                print(f"  ERR {direction}: {e}")

    # Save log
    log = {
        "mode": mode_name,
        "payload_desc": payload.get("description", "")[:100],
        "char_id": char_id,
        "job_id": job_id,
        "usage_generations": usage,
        "saved_to": str(save_dir),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    (save_dir / "log.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Done: {success} files -> {save_dir}")
    return char_id


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Check balance
    bal = api_get("balance")
    gens = bal.get("subscription", {}).get("generations", "?")
    print(f"Balance: {gens} generations")
    if isinstance(gens, float) and gens < 30:
        raise RuntimeError(f"Balance too low ({gens})! Need >= 30 for 3 modes.")

    # ================================================================
    # MODE 1: Text Prompt -> enhance -> create-character-v3
    # ================================================================
    print("\n--- MODE 1: Text Prompt + enhance-character-v3-prompt ---")
    enhance_result = api_post("enhance-character-v3-prompt", {
        "description": BASE_PROMPT,
        "image_size": {"width": 256, "height": 256},
        # Note: view param NOT supported by enhance endpoint (causes 422)
    })
    enhanced = enhance_result.get("enhanced_prompt", BASE_PROMPT)
    print(f"Enhanced prompt:\n  {enhanced[:200]}...")

    mode1_payload = {
        "description": enhanced,
        "image_size": {"width": 256, "height": 256},
        "view": "side",  # VALID: 'side' | 'low top-down' | 'high top-down'
        "outline": "selective outline",
        "detail": "medium detail",
    }
    run_generation("Mode1_TextPrompt_Enhanced", mode1_payload, "mode1_text")

    # ================================================================
    # MODE 2A: Large illustration reference_image + enhance_prompt:true
    # ================================================================
    print("\n--- MODE 2A: Large Illustration (487x707 -> resize 256) ---")
    illus_b64 = image_to_base64(ILLUS_PATH, max_size=256)
    print(f"Illustration base64 length: {len(illus_b64)} chars")

    mode2a_payload = {
        "description": (
            "2D side-scrolling game character, 4-to-5 head body ratio, "
            "face visible toward viewer, "
            "silver-white long straight hair, deep crimson red eyes, "
            "dark purple-gray off-shoulder gothic dress, "
            "deep burgundy dark red frills, dark tights, black cat tail, "
            "no weapons, facing right"
        ),
        "reference_image": {
            "type": "base64",
            "base64": illus_b64,
            "format": "png",
        },
        "image_size": {"width": 256, "height": 256},
        "view": "side",  # VALID for 2D side-scrolling
        "enhance_prompt": True,
    }
    run_generation("Mode2A_IllustrationRef", mode2a_payload, "mode2a_illus")

    # ================================================================
    # MODE 2B: Small sprite reference_image + enhance_prompt:true
    # ================================================================
    print("\n--- MODE 2B: Small Sprite (40x52) as reference ---")
    sprite_b64 = image_to_base64(SPRITE_PATH, max_size=256)  # already small, just encode
    print(f"Sprite base64 length: {len(sprite_b64)} chars")

    mode2b_payload = {
        "description": (
            "2D side-scrolling game character, 4-to-5 head body ratio, "
            "face visible toward viewer, "
            "silver-white long straight hair, deep crimson red eyes, "
            "dark purple-gray off-shoulder gothic dress, "
            "deep burgundy dark red frills, dark tights, black cat tail, "
            "no weapons, facing right"
        ),
        "reference_image": {
            "type": "base64",
            "base64": sprite_b64,
            "format": "png",
        },
        "image_size": {"width": 256, "height": 256},
        "view": "side",  # VALID for 2D side-scrolling
        "enhance_prompt": True,
    }
    run_generation("Mode2B_SpriteRef", mode2b_payload, "mode2b_sprite")

    print("\n=== ALL 3 MODES COMPLETE ===")


if __name__ == "__main__":
    main()
