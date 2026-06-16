"""
V11：讓像素結構清晰的雙管齊下策略

Part 1 - Post-processing v9b with PIL（免費，立即）：
  - 顏色量化：減少色彩數（8/12/16色）
  - 噪點移除：消除孤立像素（Despeckle）
  - 硬化邊緣：用 NEAREST 放大再縮回

Part 2 - 重生成（flat shading + single color outline）：
  - outline: "single color black outline" → 硬邊，最清楚
  - shading: "flat shading" → 每區域純色，無漸層
  - text_guidance_scale: 9.0 → 強力遵守 Prompt
  - negative: "gradient, anti-aliasing, dithering, blurry"

Part 3 - enhance-pixen-prompt（0.05次）：
  - 先讓 PixelLab AI 優化我們的描述
  - 再用優化後的 Prompt 生成

workflow §O-10-1 規定：使用 enhance-pixen-prompt 前置！
"""
import sys, io, urllib.request, json, base64, time
from pathlib import Path
from PIL import Image, ImageFilter
import colorsys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}

V9B_PATH = Path(r"D:\2026-06-04\assets\characters\generated\v9_proper_sprites\v9b_pixflux_48x48.png")
LADY_SPRITE = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
PALETTE_PNG = Path(r"D:\2026-06-04\assets\vfxmix\palette.png")
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v11_clean_structure")

def img_b64(path: Path, max_size: int = None, resize_to: tuple = None) -> tuple:
    img = Image.open(path).convert("RGBA")
    if resize_to:
        img = img.resize(resize_to, Image.NEAREST)
    elif max_size:
        img.thumbnail((max_size, max_size), Image.LANCZOS)
    size = img.size
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return b64, size

def b64_obj(b64, fmt="png"):
    return {"type": "base64", "base64": b64, "format": fmt}

def api_post(ep, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{ep}", data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return None, f"HTTP {e.code}: {body[:400]}"

def api_get(path):
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

def save_img(img: Image.Image, name: str):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / name
    img.save(path)
    print(f"  Saved: {name} ({img.size})")
    return path

def save_result_from_api(result, name: str) -> bool:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img_data = result.get("image", {})
    usage = result.get("usage", {}).get("generations", 0)
    if isinstance(img_data, dict):
        b64 = img_data.get("base64", "")
        if b64:
            if ',' in b64:
                b64 = b64.split(',', 1)[1]
            path = OUT_DIR / name
            path.write_bytes(base64.b64decode(b64))
            print(f"  Saved: {name} (cost={usage})")
            return True
    return False

# =============================================================
# PART 1: PIL Post-processing（免費，不消耗 API 次數）
# =============================================================

def remove_isolated_pixels(img: Image.Image, bg_threshold: int = 30) -> Image.Image:
    """
    移除孤立的噪點像素：
    若一個像素的 8 個鄰居中有 ≥6 個是透明的，就把它設為透明
    """
    img = img.convert("RGBA")
    data = list(img.getdata())
    w, h = img.size
    new_data = list(data)
    
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            idx = y * w + x
            r, g, b, a = data[idx]
            if a < 10:  # 本身透明
                continue
            # 計算鄰居的不透明數量
            opaque_neighbors = 0
            for dy in [-1, 0, 1]:
                for dx in [-1, 0, 1]:
                    if dx == 0 and dy == 0:
                        continue
                    ni = (y + dy) * w + (x + dx)
                    if data[ni][3] > 10:
                        opaque_neighbors += 1
            # 孤立像素（≤1個不透明鄰居）→ 刪除
            if opaque_neighbors <= 1:
                new_data[idx] = (0, 0, 0, 0)
    
    result = img.copy()
    result.putdata(new_data)
    return result

def quantize_keeping_transparency(img: Image.Image, num_colors: int) -> Image.Image:
    """
    顏色量化，保留透明度。
    """
    # 分離 alpha
    img = img.convert("RGBA")
    r, g, b, a = img.split()
    rgb_img = Image.merge("RGB", (r, g, b))
    
    # 只量化不透明部分
    mask = a.point(lambda p: 255 if p > 10 else 0)
    
    # 量化
    quantized = rgb_img.quantize(colors=num_colors, method=Image.Quantize.MEDIANCUT)
    quantized = quantized.convert("RGB")
    
    # 合回 alpha
    result = Image.merge("RGBA", (*quantized.split(), a))
    return result

def pixel_art_upscale_downscale(img: Image.Image, scale: int = 4) -> Image.Image:
    """
    放大（NEAREST）再縮小（NEAREST）= 硬化邊緣
    同時也能看出放大後的效果
    """
    w, h = img.size
    big = img.resize((w * scale, h * scale), Image.NEAREST)
    return big

print("=" * 60)
print("PART 1: PIL Post-Processing（免費）")
print("=" * 60)

v9b = Image.open(V9B_PATH).convert("RGBA")
print(f"V9B source: {v9b.size}")

# 1a. 移除孤立像素噪點
cleaned = remove_isolated_pixels(v9b)
save_img(cleaned, "v11_p1a_despeckle.png")

# 1b. 顏色量化版本（各種色數）
for n_colors in [6, 8, 12, 16]:
    q = quantize_keeping_transparency(cleaned, n_colors)
    save_img(q, f"v11_p1b_quant_{n_colors}colors.png")

# 1c. 量化後再去噪
q8_clean = remove_isolated_pixels(quantize_keeping_transparency(v9b, 8))
save_img(q8_clean, "v11_p1c_quant8_clean.png")

# 1d. 4x 放大版（更清楚看結構）
big = pixel_art_upscale_downscale(cleaned, scale=4)
save_img(big, "v11_p1d_4x_zoom.png")

# 量化+4x
big_q = pixel_art_upscale_downscale(q8_clean, scale=4)
save_img(big_q, "v11_p1e_quant8_4x.png")

# =============================================================
# PART 2: 重新生成（flat shading + hard outline）
# =============================================================

print("\n" + "=" * 60)
print("PART 2: 重新生成（flat shading + single color black outline）")
print("=" * 60)

# Check balance
bal = api_get("balance")
gens = float(bal.get("subscription", {}).get("generations", 0))
print(f"Balance: {gens}")

# §O-10-1 mandatory: enhance-pixen-prompt FIRST（0.05次）
print("\n[enhance-pixen-prompt] Running... (0.05 cost)")
raw_desc = (
    "2D side-scrolling pixel art game character, young female character facing right, "
    "long silver-white straight hair, large black ribbon bow hair decoration on head (NOT cat ears), "
    "crimson dark red eyes, bare shoulders, "
    "dark charcoal gray gothic dress, deep crimson ruffle hem at skirt bottom, "
    "dark gray tights, long slender legs, "
    "black cat tail curving upward, "
    "transparent background, clean flat pixel art, "
    "every pixel has clear definite color, no gradients, no anti-aliasing"
)

ep_result, ep_err = api_post("enhance-pixen-prompt", {
    "description": raw_desc,
    "image_size": {"width": 48, "height": 48},
    "outline": "single color black outline",
})
if ep_err:
    print(f"  enhance ERROR: {ep_err}")
    enhanced_desc = raw_desc
else:
    enhanced_desc = ep_result.get("enhanced_prompt", raw_desc)
    print(f"  Enhanced Prompt:\n  {enhanced_desc[:300]}")

# Encode Lady Sprite
sprite_b64, sprite_sz = img_b64(LADY_SPRITE)
pal_b64, _ = img_b64(PALETTE_PNG)

NEGATIVE = (
    "cat ears, bunny ears, gradient, anti-aliasing, smooth shading, "
    "blurry, noisy pixels, dithering, soft edges, undefined shapes, "
    "complex background, 3D rendering"
)

results_p2 = []

def gen_api(ep, payload, name, tag=""):
    print(f"\n[{tag}] {name}")
    t0 = time.time()
    r, err = api_post(ep, payload)
    elapsed = time.time() - t0
    if err:
        print(f"  ERROR ({elapsed:.1f}s): {err[:200]}")
        return False
    print(f"  OK ({elapsed:.1f}s), usage={r.get('usage', {})}")
    ok = save_result_from_api(r, name)
    results_p2.append({"name": name, "tag": tag, "ok": ok})
    return ok

sizes = [(48, 48), (40, 52), (64, 80), (32, 32)]

# Strategy 2A: pixflux + Lady Sprite + flat shading + hard outline
print("\n--- 2A: pixflux + flat shading + single color outline + Lady Sprite ---")
for w, h in sizes:
    payload = {
        "description": enhanced_desc,
        "negative_description": NEGATIVE,
        "color_image": b64_obj(sprite_b64),
        "image_size": {"width": w, "height": h},
        "view": "side",
        "direction": "east",
        "outline": "single color black outline",
        "shading": "flat shading",
        "detail": "medium detail" if h <= 32 else "highly detailed",
        "no_background": True,
    }
    gen_api("create-image-pixflux", payload, f"v11_2a_flat_{w}x{h}.png", "2A")

# Strategy 2B: pixflux + flat shading + VfxMix 34色
print("\n--- 2B: pixflux + flat shading + VfxMix 34色 ---")
for w, h in [(48, 48), (40, 52)]:
    payload = {
        "description": enhanced_desc,
        "negative_description": NEGATIVE,
        "color_image": b64_obj(pal_b64),
        "image_size": {"width": w, "height": h},
        "view": "side",
        "direction": "east",
        "outline": "single color black outline",
        "shading": "flat shading",
        "detail": "highly detailed",
        "no_background": True,
    }
    gen_api("create-image-pixflux", payload, f"v11_2b_flat_vfxmix_{w}x{h}.png", "2B")

# Strategy 2C: pixflux + lineless（最乾淨的選擇）
print("\n--- 2C: pixflux + lineless（全面積色塊，極簡乾淨）---")
for w, h in [(48, 48), (40, 52)]:
    payload = {
        "description": enhanced_desc,
        "negative_description": NEGATIVE,
        "color_image": b64_obj(sprite_b64),
        "image_size": {"width": w, "height": h},
        "view": "side",
        "direction": "east",
        "outline": "lineless",
        "shading": "flat shading",
        "detail": "highly detailed",
        "no_background": True,
    }
    gen_api("create-image-pixflux", payload, f"v11_2c_lineless_{w}x{h}.png", "2C")

# Strategy 2D: bitforge + init=v9b（在v9b基礎上重生成，保留比例）
print("\n--- 2D: bitforge + init_image=v9b（保留v9b比例，重清化顏色）---")
v9b_b64, v9b_sz = img_b64(V9B_PATH)
payload = {
    "description": enhanced_desc,
    "negative_description": NEGATIVE,
    "init_image": b64_obj(v9b_b64),
    "init_image_strength": 40,  # 低強度=更自由
    "color_image": b64_obj(sprite_b64),
    "image_size": {"width": 48, "height": 48},
    "view": "side",
    "direction": "east",
    "outline": "single color black outline",
    "shading": "flat shading",
    "detail": "highly detailed",
    "no_background": True,
}
gen_api("create-image-bitforge", payload, "v11_2d_bitforge_init_v9b_48x48.png", "2D")

# Strategy 2E: pixen（不支援shading，但提供最乾淨輪廓）
print("\n--- 2E: pixen + single color outline（pixen 特有的乾淨像素）---")
for w, h in [(48, 48), (40, 52)]:
    payload = {
        "description": enhanced_desc,
        "image_size": {"width": w, "height": h},
        "view": "side",
        "direction": "east",
        "outline": "single color black outline",
        "detail": "medium detail",
        "no_background": True,
        "enhance_prompt": False,
    }
    gen_api("create-image-pixen", payload, f"v11_2e_pixen_outline_{w}x{h}.png", "2E")

# =============================================================
# PART 3: PIL post-process ALL generated results
# =============================================================
print("\n" + "=" * 60)
print("PART 3: PIL post-process 生成的結果（量化+去噪）")
print("=" * 60)

gen_files = list(OUT_DIR.glob("v11_2*.png"))
for gen_path in gen_files:
    try:
        img = Image.open(gen_path).convert("RGBA")
        # 去噪 + 8色量化
        q = remove_isolated_pixels(quantize_keeping_transparency(img, 8))
        q_name = gen_path.stem + "_q8.png"
        save_img(q, q_name)
    except Exception as e:
        print(f"  SKIP {gen_path.name}: {e}")

# Final balance
bal2 = api_get("balance")
gens2 = float(bal2.get("subscription", {}).get("generations", 0))
print(f"\nBalance: {gens} -> {gens2} (cost: {gens - gens2:.2f})")

ok_count = sum(1 for r in results_p2 if r["ok"])
print(f"API results: {ok_count}/{len(results_p2)} OK")
print(f"Output: {OUT_DIR}")
