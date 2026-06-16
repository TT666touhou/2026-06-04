"""
Download-only script using already-generated character_id
char_id: 56f7d3b5-6352-444e-a1f4-5f59008b4f1f (Strategy A)
"""
import sys
import io
import urllib.request
import json
from pathlib import Path

# Fix encoding for Windows console
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"

CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    # NO Accept-Encoding - Brotli trap
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
}

# Direct URLs from completed job
ROTATION_URLS = {
    "east":       "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/east.png",
    "west":       "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/west.png",
    "north":      "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/north.png",
    "south":      "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/south.png",
    "north-east": "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/north-east.png",
    "north-west": "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/north-west.png",
    "south-east": "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/south-east.png",
    "south-west": "https://backblaze.pixellab.ai/file/pixellab-characters/e70172c4-54fa-40b4-80ea-37198918957e/56f7d3b5-6352-444e-a1f4-5f59008b4f1f/rotations/south-west.png",
}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\strategy_a_text_prompt")
OUT_DIR.mkdir(parents=True, exist_ok=True)

print("=== Downloading Strategy A (text prompt) - 8 rotations ===")
success = 0
for direction, url in ROTATION_URLS.items():
    fname = OUT_DIR / f"lady_v7a_{direction}.png"
    try:
        req = urllib.request.Request(url, headers=CDN_HEADERS)
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        if data[:4] != b'\x89PNG':
            print(f"FAIL {direction}: not PNG, got {data[:4].hex()}")
            continue
        fname.write_bytes(data)
        print(f"OK {direction}: {len(data)} bytes -> {fname.name}")
        success += 1
    except Exception as e:
        print(f"ERR {direction}: {e}")

print(f"\nDone: {success}/8 downloaded to {OUT_DIR}")
