"""
V10 完整生成腳本
目標：基於 v9b_pixflux_48x48（用戶喜歡的基礎）做改進
修正：蝴蝶結(非貓耳)、更長的腿、乾淨像素

策略：
A) create-image-pixflux + color_image=Lady Sprite (版本1：Sprite調色盤)
B) create-image-pixflux + color_image=VfxMix 34色 palette.png (版本2：34色)
C) create-image-bitforge + style_image=Lady Sprite + color_image=palette (多參數組合)
D) /resize 端點：把 Lady Sprite 作為 reference_image 做不同尺寸（直接繼承比例！）
E) /edit-image：用 v9b 做改進
F) inpaint：修特定部位

30張預算分配：
  A: 8張 (4尺寸 × 2種描述)
  B: 8張 (4尺寸 × 2種描述)  
  C: 8張 (bitforge 多參數)
  D: 4張 (resize 不同尺寸)
  E: 2張 (edit-image 修v9b)
  總計: 30張
"""
import sys, io, urllib.request, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}

# Source images
V9B_48 = Path(r"D:\2026-06-04\assets\characters\generated\v9_proper_sprites\v9b_pixflux_48x48.png")
LADY_SPRITE = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
PALETTE_PNG = Path(r"D:\2026-06-04\assets\vfxmix\palette.png")
ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v10_refined")

RESULTS = []
TOTAL_COST = 0.0


def img_b64(path: Path, max_size: int = None) -> tuple:
    img = Image.open(path).convert("RGBA")
    if max_size:
        img.thumbnail((max_size, max_size), Image.LANCZOS)
    size = img.size
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return b64, size


def b64_obj(b64: str, fmt="png") -> dict:
    return {"type": "base64", "base64": b64, "format": fmt}


def api_post(ep, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{ep}", data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return None, f"HTTP {e.code}: {body[:500]}"


def api_get(path):
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def save_result(result, name: str) -> bool:
    global TOTAL_COST
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    save_path = OUT_DIR / name
    img_data = result.get("image", {})
    usage = result.get("usage", {}).get("generations", 0)
    TOTAL_COST += float(usage)
    if isinstance(img_data, dict):
        b64 = img_data.get("base64", "")
        if b64:
            if ',' in b64:
                b64 = b64.split(',', 1)[1]
            save_path.write_bytes(base64.b64decode(b64))
            print(f"  -> Saved: {name} (usage={usage})")
            return True
    print(f"  -> WARN: no image in result for {name}")
    return False


def gen(ep, payload, name, tag=""):
    global RESULTS
    print(f"\n[{tag}] {name}")
    t0 = time.time()
    result, err = api_post(ep, payload)
    elapsed = time.time() - t0
    if err:
        print(f"  ERROR ({elapsed:.1f}s): {err[:200]}")
        RESULTS.append({"name": name, "tag": tag, "status": "error", "error": err[:100]})
        return False
    print(f"  OK ({elapsed:.1f}s)")
    ok = save_result(result, name)
    RESULTS.append({"name": name, "tag": tag, "status": "ok" if ok else "save_failed"})
    return ok


def main():
    global TOTAL_COST

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Check balance
    bal = api_get("balance")
    gens_start = float(bal.get("subscription", {}).get("generations", 0))
    print(f"Starting balance: {gens_start}")

    # Encode all images
    sprite_b64, sprite_sz = img_b64(LADY_SPRITE)
    pal_b64, pal_sz = img_b64(PALETTE_PNG)
    illus_b64, illus_sz = img_b64(ILLUS_PATH, max_size=128)
    v9b_b64, v9b_sz = img_b64(V9B_48)
    print(f"Lady Sprite: {sprite_sz}, Palette: {pal_sz}, Illus: {illus_sz}")

    # ============================================================
    # 修正後的精準角色描述（蝴蝶結！不是貓耳！腿更長！）
    # ============================================================
    DESC_PRECISE = (
        "2D side-scrolling pixel art game character, young girl facing right side view, "
        "long silver-white straight hair, large BLACK RIBBON BOW on top-right of head (not cat ears), "
        "crimson red eyes, bare shoulders, dark purple-gray gothic lolita dress with deep red ruffled frills at hem, "
        "dark brown-black opaque tights, long slender legs (longer leg proportion), "
        "black cat tail curving upward, transparent background, clean pixel art, "
        "every pixel has clear structure, no blurry details, no undefined color blobs"
    )

    DESC_SIMPLE = (
        "2D side-scrolling pixel art character girl facing right, "
        "white hair large black BOW (hair decoration not ears), red eyes, "
        "dark gothic dress red frills, dark tights, long legs, cat tail, "
        "clean minimal pixel art, clear silhouette"
    )

    NEGATIVE = (
        "cat ears on head, blurry, noisy pixels, undefined shapes, "
        "gradients, smooth shading, cat ears, bunny ears, antenna"
    )

    # ============================================================
    # STRATEGY A: create-image-pixflux + color_image=Lady Sprite
    # 版本1：使用 Lady Sprite 原版配色
    # ============================================================
    print("\n" + "="*60)
    print("STRATEGY A: pixflux + Lady Sprite color reference")
    print("="*60)

    sizes_a = [(48, 48), (40, 52), (32, 32), (64, 80)]
    for w, h in sizes_a:
        payload = {
            "description": DESC_PRECISE,
            "negative_description": NEGATIVE,
            "color_image": b64_obj(sprite_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed" if h >= 48 else "medium detail",
            "no_background": True,
            "shading": "basic shading",
        }
        gen("create-image-pixflux", payload, f"v10a_sprite_col_{w}x{h}.png", f"A")

    # Second run same sizes with simple desc + different seed
    for w, h in [(48, 48), (40, 52)]:
        payload = {
            "description": DESC_SIMPLE,
            "negative_description": NEGATIVE,
            "color_image": b64_obj(sprite_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed",
            "no_background": True,
            "shading": "basic shading",
            "seed": 2025,
        }
        gen("create-image-pixflux", payload, f"v10a2_sprite_col_{w}x{h}_s2025.png", f"A2")

    # ============================================================
    # STRATEGY B: create-image-pixflux + color_image=VfxMix 34色
    # 版本2：使用遊戲專屬 VfxMix 34色調色盤
    # ============================================================
    print("\n" + "="*60)
    print("STRATEGY B: pixflux + VfxMix 34-color palette")
    print("="*60)

    for w, h in sizes_a:
        payload = {
            "description": DESC_PRECISE,
            "negative_description": NEGATIVE,
            "color_image": b64_obj(pal_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed" if h >= 48 else "medium detail",
            "no_background": True,
            "shading": "basic shading",
        }
        gen("create-image-pixflux", payload, f"v10b_vfxmix_{w}x{h}.png", f"B")

    for w, h in [(48, 48), (40, 52)]:
        payload = {
            "description": DESC_SIMPLE,
            "negative_description": NEGATIVE,
            "color_image": b64_obj(pal_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed",
            "no_background": True,
            "shading": "basic shading",
            "seed": 777,
        }
        gen("create-image-pixflux", payload, f"v10b2_vfxmix_{w}x{h}_s777.png", f"B2")

    # ============================================================
    # STRATEGY C: create-image-bitforge (style_image + color_image)
    # 最強：style_image + color_image + init_image 三重引導
    # ============================================================
    print("\n" + "="*60)
    print("STRATEGY C: bitforge (style + color + multiple params)")
    print("="*60)

    # C1: style=Lady Sprite, color=Lady Sprite
    for w, h in [(48, 48), (40, 52), (32, 32)]:
        payload = {
            "description": DESC_PRECISE,
            "negative_description": NEGATIVE,
            "style_image": b64_obj(sprite_b64),
            "color_image": b64_obj(sprite_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed" if h >= 48 else "medium detail",
            "no_background": True,
            "shading": "basic shading",
            "style_strength": 0.7,
            "text_guidance_scale": 7.0,
            "extra_guidance_scale": 3.0,
        }
        gen("create-image-bitforge", payload, f"v10c_bitforge_sprite_{w}x{h}.png", "C1")

    # C2: style=Lady Sprite, color=VfxMix
    for w, h in [(48, 48), (40, 52)]:
        payload = {
            "description": DESC_PRECISE,
            "negative_description": NEGATIVE,
            "style_image": b64_obj(sprite_b64),
            "color_image": b64_obj(pal_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed",
            "no_background": True,
            "shading": "basic shading",
            "style_strength": 0.6,
            "text_guidance_scale": 8.0,
            "extra_guidance_scale": 3.0,
        }
        gen("create-image-bitforge", payload, f"v10c_bitforge_vfxmix_{w}x{h}.png", "C2")

    # C3: init_image=v9b with higher style_strength
    for w, h in [(48, 48), (40, 52)]:
        payload = {
            "description": DESC_PRECISE,
            "negative_description": NEGATIVE,
            "init_image": b64_obj(v9b_b64),
            "init_image_strength": 30,
            "color_image": b64_obj(sprite_b64),
            "image_size": {"width": w, "height": h},
            "view": "side", "direction": "east",
            "outline": "selective outline",
            "detail": "highly detailed",
            "no_background": True,
            "shading": "basic shading",
        }
        gen("create-image-bitforge", payload, f"v10c_bitforge_init_v9b_{w}x{h}.png", "C3")

    # ============================================================
    # STRATEGY D: /resize 端點
    # 把 Lady Sprite 作為 reference_image，重新生成不同尺寸
    # ============================================================
    print("\n" + "="*60)
    print("STRATEGY D: /resize with Lady Sprite as reference")
    print("="*60)

    for w, h in [(48, 48), (64, 80), (32, 40), (40, 52)]:
        payload = {
            "description": DESC_PRECISE,
            "reference_image": b64_obj(sprite_b64),
            "reference_image_size": {"width": sprite_sz[0], "height": sprite_sz[1]},
            "target_size": {"width": w, "height": h},
            "color_image": b64_obj(sprite_b64),
            "view": "side",
            "no_background": True,
        }
        gen("resize", payload, f"v10d_resize_from_sprite_{w}x{h}.png", "D")

    # ============================================================
    # Final count
    # ============================================================
    bal2 = api_get("balance")
    gens_end = float(bal2.get("subscription", {}).get("generations", 0))
    actual_cost = gens_start - gens_end

    print("\n" + "="*60)
    print("ALL DONE!")
    print(f"Balance: {gens_start} -> {gens_end} (actual cost: {actual_cost:.2f})")
    print(f"Accumulated tracked cost: {TOTAL_COST:.2f}")
    print(f"\nResults ({len(RESULTS)} attempts):")
    ok_count = sum(1 for r in RESULTS if r["status"] == "ok")
    err_count = sum(1 for r in RESULTS if r["status"] == "error")
    print(f"  OK: {ok_count}, ERROR: {err_count}")
    for r in RESULTS:
        icon = "OK" if r["status"] == "ok" else "ERR"
        print(f"  [{icon}][{r['tag']}] {r['name']}")


if __name__ == "__main__":
    main()
