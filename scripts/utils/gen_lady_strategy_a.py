"""
策略A：純文字 Prompt -> enhance-character-v3-prompt -> create-character-v3
基於插畫(487x707) + Sprite(40x52) 兩圖精確像素採樣的描述
執行日期：2026-06-16
"""
import urllib.request
import json
import time
import base64
import os
from pathlib import Path

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated")

CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
    # ❌ NO Accept-Encoding — Brotli 壓縮陷阱
}

API_HEADERS = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
}

# ==========================================
# 基礎 Prompt（基於兩圖精確色值分析）
# ==========================================
BASE_PROMPT = (
    "game character sprite, young girl, "
    "pale warm-white long straight hair with soft lavender highlights, "
    "black large side-ponytail bow at upper right, deep crimson red eyes, "
    "dark purple-gray off-shoulder fitted dress with wide black waist cincher belt with back bow, "
    "deep burgundy dark red layered ruffled frills at hem and detached sleeve cuffs, "
    "dark warm-brown opaque tights, "
    "long slender black cat tail curving right, "
    "cel-shaded 3-color-layer style no gradients, "
    "pale warm peach skin, facing right, no weapons"
)


def api_post(endpoint: str, payload: dict) -> dict:
    """POST to PixelLab v2 API"""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/{endpoint}",
        data=data,
        headers=API_HEADERS,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


def api_get(path: str) -> dict:
    """GET from PixelLab v2 API"""
    req = urllib.request.Request(
        f"{BASE_URL}/{path}",
        headers={"Authorization": f"Bearer {BEARER}"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def download_image(url: str, save_path: Path) -> bool:
    """CDN download with browser headers, PNG validation"""
    req = urllib.request.Request(url, headers=CDN_HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    if data[:4] != b"\x89PNG":
        raise ValueError(f"Not PNG! First 4 bytes: {data[:4].hex()}")
    save_path.write_bytes(data)
    return True


def poll_job(job_id: str, timeout_s: int = 600) -> dict:
    """Poll background job until completed"""
    deadline = time.time() + timeout_s
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        result = api_get(f"background-jobs/{job_id}")
        status = result.get("status", "unknown")
        print(f"  [{attempt}] Job status: {status}", flush=True)
        if status == "completed":
            return result
        elif status == "failed":
            detail = result.get("last_response", {}).get("detail", "unknown error")
            raise RuntimeError(f"Job failed: {detail}")
        time.sleep(5)
    raise TimeoutError(f"Job {job_id} timed out after {timeout_s}s")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # ===== Step 1: enhance-character-v3-prompt =====
    print("=== Step 1: enhance-character-v3-prompt ===")
    print(f"Original prompt:\n  {BASE_PROMPT}\n")

    enhance_payload = {
        "description": BASE_PROMPT,
        "image_size": {"width": 256, "height": 256},
    }
    enhance_result = api_post("enhance-character-v3-prompt", enhance_payload)
    print(f"Enhance raw response: {enhance_result}")

    enhanced = enhance_result.get("enhanced_prompt", "")
    if not enhanced:
        print("WARNING: enhanced_prompt is empty, using original")
        enhanced = BASE_PROMPT
    print(f"\nEnhanced prompt:\n  {enhanced}\n")

    # ===== Step 2: create-character-v3 =====
    print("=== Step 2: create-character-v3 ===")
    gen_payload = {
        "description": enhanced,
        "image_size": {"width": 256, "height": 256},
    }
    gen_result = api_post("create-character-v3", gen_payload)
    print(f"POST response: {gen_result}")

    job_id = gen_result.get("background_job_id")
    char_id = gen_result.get("character_id")
    print(f"  job_id: {job_id}")
    print(f"  char_id: {char_id}")

    if not job_id:
        raise RuntimeError("No background_job_id in response!")

    # ===== Step 3: Poll until done =====
    print("\n=== Step 3: Polling background job ===")
    job_done = poll_job(job_id)
    print(f"Job completed! {job_done}")

    # ===== Step 4: GET character details =====
    print("\n=== Step 4: GET /characters/{id} ===")
    char_data = api_get(f"characters/{char_id}")
    rotation_urls = char_data.get("rotation_urls", {})
    print(f"Available rotations: {list(rotation_urls.keys())}")

    # ===== Step 5: Download available directions =====
    print("\n=== Step 5: Downloading images ===")
    save_dir = OUT_DIR / "strategy_a_text_prompt"
    save_dir.mkdir(parents=True, exist_ok=True)

    for direction, url in rotation_urls.items():
        if url:
            fname = save_dir / f"lady_v7a_{direction}.png"
            try:
                download_image(url, fname)
                print(f"  ✅ Downloaded: {fname.name}")
            except Exception as e:
                print(f"  ❌ Failed {direction}: {e}")

    print(f"\n=== Done! Files saved to: {save_dir} ===")

    # Save log
    log = {
        "strategy": "A - text prompt only",
        "original_prompt": BASE_PROMPT,
        "enhanced_prompt": enhanced,
        "character_id": char_id,
        "job_id": job_id,
        "saved_to": str(save_dir),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    (save_dir / "generation_log.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Log saved.")


if __name__ == "__main__":
    main()
