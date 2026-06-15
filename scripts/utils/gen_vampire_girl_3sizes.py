"""
CHAR-007: White-Hair Anime Vampire Girl - 3 Sizes Generation Script
Sizes: 16x16, 32x32, 48x48
Endpoint: create-image-pixen (synchronous, supports custom small sizes)
Colors: ONLY 3 colors from VfxMix 34-color palette:
  - Pure Black:   #363232 (Index 1 in palette)
  - Pure White:   #F2F9F8 (Index 34 in palette - closest to pure white)
  - Crimson Red:  #E55C5C (Index 12 in palette - closest to crimson/red)

Workflow: workflow.md §O GATE-1~5 compliant
Designer: GATE-4 Pre-Flight confirmed
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import urllib.request
import urllib.error
import json
import base64
import os
import time
from pathlib import Path

# --- CONFIG ---
BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
OUT_DIR = Path("d:/2026-06-04/assets/characters/vampire_girl_char007")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# 34-color palette analysis:
# Index 1:  R=54,  G=50,  B=50   -> #363232  (deep black)
# Index 12: R=229, G=92,  B=92   -> #E55C5C  (crimson red)
# Index 34: R=242, G=249, B=248  -> #F2F9F8  (near-pure white)

# 3-color Prompt: strictly black/white/crimson
# Rule: black body/dress/outline, white hair/skin highlight, crimson eyes/bow
PROMPT_TEMPLATE = """2D side-scrolling pixel art game character, young girl vampire facing right,
pure white (#F2F9F8) silver-white hair with large crimson red (#E55C5C) bow ornament,
glowing crimson red eyes, pure black (#363232) gothic dress and cape, black body silhouette,
strictly 3-color palette only: jet black and pure white and crimson red,
monochrome black-and-white body with red accent on eyes and hair bow,
pixel art, pixel perfect, clean black outline, no background, no weapons,
2D platformer sprite style, side view facing right"""

SIZES = [
    (16, 16, "16x16"),
    (32, 32, "32x32"),
    (48, 48, "48x48"),
]

def api_call(endpoint: str, payload: dict) -> tuple:
    """Call PixelLab API v2, return (result_dict, error_str)"""
    url = f"{BASE_URL}/{endpoint}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data,
        headers={
            "Authorization": f"Bearer {BEARER}",
            "Content-Type": "application/json",
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return None, f"HTTP {e.code}: {body[:300]}"
    except Exception as e:
        return None, str(e)

def save_base64_png(b64_str: str, path: Path) -> bool:
    """Decode base64 and save as PNG, verify PNG signature"""
    data = base64.b64decode(b64_str)
    if data[:4] != b'\x89PNG':
        print(f"[ERROR] Not a valid PNG! First 4 bytes: {data[:4].hex()}")
        return False
    path.write_bytes(data)
    print(f"[OK] Saved {path.name} ({len(data)} bytes)")
    return True

def upscale_nearest(src_path: Path, scale: int = 10) -> Path:
    """Upscale image for preview using PIL NEAREST"""
    from PIL import Image
    img = Image.open(src_path)
    w, h = img.size
    big = img.resize((w * scale, h * scale), Image.NEAREST)
    out = src_path.parent / f"{src_path.stem}_{scale}x_preview.png"
    big.save(out)
    return out

def quantize_to_3_colors(src_path: Path) -> Path:
    """Quantize image to 3 target colors (black/white/crimson) and save"""
    from PIL import Image
    import numpy as np

    TARGET_COLORS = [
        (54, 50, 50),    # #363232 black
        (242, 249, 248), # #F2F9F8 white
        (229, 92, 92),   # #E55C5C crimson
    ]

    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)

    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]

    # For each pixel, find the nearest target color
    result = np.zeros_like(rgb)
    for i, tc in enumerate(TARGET_COLORS):
        tc_arr = np.array(tc, dtype=np.float32)
        dist = np.sqrt(np.sum((rgb - tc_arr) ** 2, axis=2))
        if i == 0:
            min_dist = dist.copy()
            nearest_idx = np.zeros(dist.shape, dtype=np.int32)
        else:
            better = dist < min_dist
            min_dist = np.where(better, dist, min_dist)
            nearest_idx = np.where(better, i, nearest_idx)

    for i, tc in enumerate(TARGET_COLORS):
        mask = nearest_idx == i
        result[mask] = np.array(tc, dtype=np.float32)

    # Restore alpha
    out_arr = np.concatenate([result, alpha[:, :, np.newaxis]], axis=2).astype(np.uint8)
    out_img = Image.fromarray(out_arr, "RGBA")

    out_path = src_path.parent / f"{src_path.stem}_3color.png"
    out_img.save(out_path)
    print(f"[OK] Quantized to 3 colors: {out_path.name}")
    return out_path

def main():
    print("=" * 60)
    print("CHAR-007: Vampire Girl - 3 Sizes Generation")
    print(f"Output dir: {OUT_DIR}")
    print(f"Endpoint: create-image-pixen (synchronous)")
    print(f"3-Color Palette: Black #363232 | White #F2F9F8 | Crimson #E55C5C")
    print("=" * 60)

    results = []

    for (w, h, label) in SIZES:
        print(f"\n[GEN] {label} ...")

        # Optional: use enhance-pixen-prompt first (0.05 cost)
        # (Skipping for speed, using direct prompt)

        payload = {
            "description": PROMPT_TEMPLATE.strip(),
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "detail": "medium detail",
            "no_background": True,
            "enhance_prompt": False,
        }

        t0 = time.time()
        result, err = api_call("create-image-pixen", payload)
        elapsed = time.time() - t0

        if err:
            print(f"[ERROR] {label}: {err}")
            results.append((label, None, None, err))
            continue

        # Extract base64 from result
        img_data = result.get("image")
        if not img_data:
            print(f"[ERROR] {label}: No image in response. Keys: {list(result.keys())}")
            results.append((label, None, None, "No image in response"))
            continue

        b64 = img_data.get("base64") if isinstance(img_data, dict) else img_data
        if not b64:
            print(f"[ERROR] {label}: No base64 in image. img_data type: {type(img_data)}")
            results.append((label, None, None, "No base64"))
            continue

        # Save original
        out_path = OUT_DIR / f"vampire_girl_{label}.png"
        if save_base64_png(b64, out_path):
            print(f"[TIMING] {label} generated in {elapsed:.1f}s")

            # Save 3-color quantized version
            try:
                q_path = quantize_to_3_colors(out_path)
                # Upscale for preview (10x)
                preview = upscale_nearest(out_path, scale=10)
                q_preview = upscale_nearest(q_path, scale=10)
                print(f"[PREVIEW] {preview.name}, {q_preview.name}")
                results.append((label, out_path, q_path, None))
            except ImportError:
                print("[WARN] PIL not available for post-processing, skipping quantize")
                results.append((label, out_path, None, "PIL not available"))
            except Exception as ex:
                print(f"[WARN] Post-processing failed: {ex}")
                results.append((label, out_path, None, str(ex)))
        else:
            results.append((label, None, None, "Invalid PNG"))

        # Brief pause between API calls
        if label != SIZES[-1][2]:
            time.sleep(3)

    # Summary
    print("\n" + "=" * 60)
    print("GENERATION SUMMARY")
    print("=" * 60)
    success = 0
    for (label, orig, quant, err) in results:
        if orig:
            print(f"[OK] {label}: {orig.name}")
            if quant:
                print(f"     3-color: {quant.name}")
            success += 1
        else:
            print(f"[FAIL] {label}: {err}")

    print(f"\nTotal: {success}/{len(SIZES)} successful")
    print(f"Output directory: {OUT_DIR}")

if __name__ == "__main__":
    main()
