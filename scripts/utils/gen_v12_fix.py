"""
V12-fix: 修正所有上次失敗的生成
錯誤修正：
  B: init_image 必須 resize 到精確輸出尺寸
  C: style_image 必須 resize 到精確輸出尺寸（bitforge 要求）
  D: reference_images 需要 size 子欄位 {"size": {"width": w, "height": h}}
  E: generate-with-style-v2 只接受正方形 image_size，改用 48x48 / 64x64

已成功（跳過）：A1-A4, F1-F3
"""
import sys, io, urllib.request, urllib.error, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v12_new_methods")
OUT_DIR.mkdir(parents=True, exist_ok=True)

LADY_ILLUST   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
AMELIA_ILLUST = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Amelia_Rainwales.png")
LADY_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
SOUL_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Soul_Eater\skins\sprite.png")
VAMPIRESS     = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Phantasm_Petal.png")
MAGE_ILLUST   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Mage\illustrations\Lady_Scarlet_Mage.png")

def img_b64(path: Path, max_size: int = 256, exact_wh=None) -> str:
    """exact_wh=(w,h) → 強制 resize 到精確尺寸"""
    img = Image.open(path).convert("RGBA")
    if exact_wh:
        img = img.resize(exact_wh, Image.LANCZOS)
    elif max_size:
        w, h = img.size
        if max(w, h) > max_size:
            scale = max_size / max(w, h)
            img = img.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")

def img_actual_wh(path: Path, max_size: int = 256, exact_wh=None):
    """返回 resize 後的實際 (w, h)"""
    img = Image.open(path)
    if exact_wh:
        return exact_wh
    w, h = img.size
    if max_size and max(w, h) > max_size:
        scale = max_size / max(w, h)
        return (int(w*scale), int(h*scale))
    return (w, h)

def b64_obj(b64_str: str) -> dict:
    return {"type": "base64", "base64": b64_str}

def api_post(endpoint: str, payload: dict):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{endpoint}", data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return None, f"HTTP {e.code}: {body[:500]}"

def api_get(path: str):
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

def poll_job(job_id: str, max_wait: int = 300) -> dict | None:
    for i in range(max_wait // 5):
        time.sleep(5)
        try:
            data = api_get(f"background-jobs/{job_id}")
        except Exception as ex:
            print(f"  ⚠️ Poll error: {ex}")
            continue
        status = data.get("status", "unknown")
        if status == "completed":
            return data.get("last_response", {})
        if status == "failed":
            print(f"  ❌ Job failed: {data.get('last_response', {})}")
            return None
        if i % 6 == 0:
            print(f"  ⏳ {job_id[:8]}... status={status} ({(i+1)*5}s)")
    print(f"  ⚠️ Timeout {max_wait}s")
    return None

def save_b64_png(b64: str, filename: str) -> Path | None:
    if not b64:
        return None
    if b64.startswith("data:"):
        b64 = b64.split(",", 1)[1]
    try:
        raw = base64.b64decode(b64)
    except Exception as ex:
        print(f"  ❌ decode: {ex}")
        return None
    if raw[:4] != b'\x89PNG':
        print(f"  ❌ Not PNG: {raw[:8].hex()}")
        return None
    out = OUT_DIR / filename
    out.write_bytes(raw)
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    if max(w, h) <= 256:
        big = img.resize((w*4, h*4), Image.NEAREST)
        big.save(OUT_DIR / filename.replace(".png", "_4x.png"))
    print(f"  ✅ {filename} ({w}×{h})")
    return out

def save_sync(result, filename) -> Path | None:
    if not result:
        return None
    img_data = result.get("image", {})
    if isinstance(img_data, dict):
        return save_b64_png(img_data.get("base64", ""), filename)
    return None

def save_async(result, prefix, max_imgs=4) -> int:
    if not result:
        return 0
    saved = 0
    if "image" in result and isinstance(result["image"], dict):
        if save_b64_png(result["image"].get("base64", ""), f"{prefix}_00.png"):
            saved += 1
    elif "images" in result:
        for i, d in enumerate(result["images"][:max_imgs]):
            if save_b64_png(d.get("base64", ""), f"{prefix}_{i:02d}.png"):
                saved += 1
    return saved

def pil_quantize(img_path: Path) -> None:
    if not img_path or not img_path.exists():
        return
    img = Image.open(img_path).convert("RGBA")
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b))
    q = rgb.quantize(colors=8, method=Image.Quantize.MEDIANCUT).convert("RGB")
    result = Image.merge("RGBA", (*q.split(), a))
    out = OUT_DIR / img_path.name.replace(".png", "_q8.png")
    result.save(out)
    print(f"  🎨 {out.name}")

# =============================================================
print("=" * 70)
print("V12-FIX: Correcting all format errors")
print("=" * 70)

bal_data = api_get("balance")
bal = bal_data.get("usd_balance", bal_data.get("subscription", {}).get("generations", "?"))
print(f"[PRE-FLIGHT] {bal_data}")

# 預先 enhance（use cached from V9/V11 era, or fallback to BASE_DESC）
BASE_DESC = (
    "pale lavender-white long straight hair with large black ribbon bow on head, "
    "dark purple-charcoal gothic lolita dress, deep burgundy dark red ruffle hem frills, "
    "dark gray-black pantyhose, warm peach skin tone, slender proportions, "
    "facing right side view, 2D sidescroller pixel art character sprite, "
    "transparent background"
)

def try_enhance(desc, w, h, outline="single color black outline"):
    r, err = api_post("enhance-pixen-prompt", {
        "description": desc,
        "image_size": {"width": w, "height": h},
        "outline": outline,
    })
    if err:
        print(f"  ⚠️ enhance fail ({w}x{h}): {err[:80]}")
        return desc
    e = r.get("enhanced_prompt", desc)
    print(f"  🔧 enhanced ({len(e)}ch): {e[:100]}...")
    return e

e48x60 = try_enhance(BASE_DESC, 48, 60)
time.sleep(1)
e64x80 = try_enhance(BASE_DESC, 64, 80, "single color outline")
time.sleep(1)
e48x48 = try_enhance(BASE_DESC, 48, 48)   # 正方形版
time.sleep(1)
e64x64 = try_enhance(BASE_DESC, 64, 64)   # 正方形版
time.sleep(1)

# ─── 預生成所有 base64（Sprite尺寸&Sprite精確輸出尺寸）────────
lady_sprite_b64_60 = img_b64(LADY_SPRITE, max_size=60)
lady_sprite_w, lady_sprite_h = Image.open(LADY_SPRITE).size   # 40×52
soul_b64 = img_b64(SOUL_SPRITE, max_size=60)
soul_w, soul_h = Image.open(SOUL_SPRITE).size
vamp_b64 = img_b64(VAMPIRESS, max_size=80)
vamp_w, vamp_h = Image.open(VAMPIRESS).size

# 插畫縮放到精確輸出尺寸（修正 B 系列）
lady_illust_48x60 = img_b64(LADY_ILLUST, exact_wh=(48, 60))
lady_illust_64x80 = img_b64(LADY_ILLUST, exact_wh=(64, 80))
amelia_48x60      = img_b64(AMELIA_ILLUST, exact_wh=(48, 60))
# Sprite 縮放到精確輸出尺寸（修正 C 系列）
lady_spr_64x80    = img_b64(LADY_SPRITE, exact_wh=(64, 80))
lady_spr_48x60    = img_b64(LADY_SPRITE, exact_wh=(48, 60))
vamp_64x80        = img_b64(VAMPIRESS, exact_wh=(64, 80))
vamp_48x60        = img_b64(VAMPIRESS, exact_wh=(48, 60))
# 正方形版（修正 E 系列）
lady_spr_48x48    = img_b64(LADY_SPRITE, exact_wh=(48, 48))
lady_spr_64x64    = img_b64(LADY_SPRITE, exact_wh=(64, 64))
vamp_48x48        = img_b64(VAMPIRESS, exact_wh=(48, 48))
soul_48x48        = img_b64(SOUL_SPRITE, exact_wh=(48, 48))
# 插畫（256 max，用於 reference_images）
lady_illust_ref   = img_b64(LADY_ILLUST, max_size=256)
amelia_ref        = img_b64(AMELIA_ILLUST, max_size=256)
lady_illust_256w, lady_illust_256h = img_actual_wh(LADY_ILLUST, max_size=256)
amelia_256w, amelia_256h = img_actual_wh(AMELIA_ILLUST, max_size=256)

print(f"  lady_illust_ref actual wh: {lady_illust_256w}×{lady_illust_256h}")
print(f"  amelia_ref actual wh: {amelia_256w}×{amelia_256h}")

NEGATIVE = "cat ears, bunny ears, gradient, anti-aliasing, smooth shading, blurry, noisy pixels, dithering, soft edges, isolated dots"

# ════════════════════════════════════════════════════════════════
# FIX B: pixflux + init_image (精確尺寸 resize 修正)
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("FIX-B: pixflux + init_image (correct exact resize)")
print("═"*60)

# B1: init = Lady Illust (48×60 exact), medium shading
r, err = api_post("create-image-pixflux", {
    "description": e48x60,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "init_image": b64_obj(lady_illust_48x60),   # ★ 精確 48×60
    "init_image_strength": 200,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B1 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_B1fix_init_ladyillust_48x60.png")
    if p: pil_quantize(p)
time.sleep(2)

# B2: init = Amelia Illust (48×60 exact), medium shading
r, err = api_post("create-image-pixflux", {
    "description": e48x60,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64_60),
    "init_image": b64_obj(amelia_48x60),         # ★ 精確 48×60
    "init_image_strength": 150,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B2 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_B2fix_init_amelia_48x60.png")
    if p: pil_quantize(p)
time.sleep(2)

# B3: init = Lady Illust (64×80 exact) + Vampiress color
r, err = api_post("create-image-pixflux", {
    "description": e64x80,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(vamp_b64),
    "init_image": b64_obj(lady_illust_64x80),    # ★ 精確 64×80
    "init_image_strength": 180,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B3 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_B3fix_init_lady_vampcol_64x80.png")
    if p: pil_quantize(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# FIX C: bitforge + style_image (精確尺寸 resize 修正)
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("FIX-C: bitforge + exact-size style_image/init_image")
print("═"*60)

# C1: bitforge + Lady Sprite (64×80 exact) as style
r, err = api_post("create-image-bitforge", {
    "description": e64x80,
    "negative_description": NEGATIVE,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "style_image": b64_obj(lady_spr_64x80),      # ★ 精確 64×80
    "style_strength": 60.0,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C1 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_C1fix_bitforge_ladystyle_64x80.png")
    if p: pil_quantize(p)
time.sleep(2)

# C2: bitforge + Vampiress (48×60 exact) as style
r, err = api_post("create-image-bitforge", {
    "description": e48x60,
    "negative_description": NEGATIVE,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "style_image": b64_obj(vamp_48x60),          # ★ 精確 48×60
    "style_strength": 55.0,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C2 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_C2fix_bitforge_vampstyle_48x60.png")
    if p: pil_quantize(p)
time.sleep(2)

# C3: bitforge + Lady Sprite style + Lady Illust init (both exact 64×80)
r, err = api_post("create-image-bitforge", {
    "description": BASE_DESC,
    "negative_description": NEGATIVE,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "basic shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "style_image": b64_obj(lady_spr_64x80),      # ★ 精確 64×80
    "style_strength": 50.0,
    "init_image": b64_obj(lady_illust_64x80),    # ★ 精確 64×80
    "init_image_strength": 150,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C3 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_C3fix_bitforge_both_64x80.png")
    if p: pil_quantize(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# FIX D: generate-image-v2 + reference_images 使用 size 子欄位
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("FIX-D: generate-image-v2 + size={} format [ASYNC]")
print("═"*60)

async_jobs = {}

# D1: Lady Sprite style + Lady Illust reference (size 子欄位修正)
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 60},
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_sprite_b64_60),
        "width": lady_sprite_w, "height": lady_sprite_h,
    },
    "style_options": {
        "color_palette": True,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_ref),
            "size": {"width": lady_illust_256w, "height": lady_illust_256h}  # ★ 修正格式
        }
    ],
})
if err: print(f"  D1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D1 job: {jid[:12]}... (Lady Sprite style + Lady ref, 48x60)")
        async_jobs["D1_gen_v2_ladysprite_48x60"] = jid
    else:
        print(f"  D1 no job_id: {list(r.keys())}")
time.sleep(2)

# D2: Vampiress style + Lady+Amelia refs (no palette copy), 64×80
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 64, "height": 80},
    "no_background": True,
    "style_image": {
        "image": b64_obj(vamp_b64),
        "width": vamp_w, "height": vamp_h,
    },
    "style_options": {
        "color_palette": False,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_ref),
            "size": {"width": lady_illust_256w, "height": lady_illust_256h}  # ★ 修正
        },
        {
            "image": b64_obj(amelia_ref),
            "size": {"width": amelia_256w, "height": amelia_256h}            # ★ 修正
        },
    ],
})
if err: print(f"  D2 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D2 job: {jid[:12]}... (Vampiress style + Lady+Amelia refs, 64x80)")
        async_jobs["D2_gen_v2_vamp_style_64x80"] = jid
time.sleep(2)

# D3: Soul style + Lady ref, 32×40
soul_wh = img_actual_wh(SOUL_SPRITE, max_size=60)
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 32, "height": 40},
    "no_background": True,
    "style_image": {
        "image": b64_obj(soul_b64),
        "width": soul_wh[0], "height": soul_wh[1],
    },
    "style_options": {
        "color_palette": False,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_ref),
            "size": {"width": lady_illust_256w, "height": lady_illust_256h}
        },
    ],
})
if err: print(f"  D3 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D3 job: {jid[:12]}... (Soul style + Lady ref, 32x40)")
        async_jobs["D3_gen_v2_soul_style_32x40"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# FIX E: generate-with-style-v2 → 使用正方形 image_size
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("FIX-E: generate-with-style-v2 SQUARE sizes (48x48, 64x64)")
print("═"*60)

# E1: 3 Sprite style → 48×48 (正方形！)
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_spr_48x48), "width": 48, "height": 48},
        {"image": b64_obj(vamp_48x48), "width": 48, "height": 48},
        {"image": b64_obj(soul_48x48), "width": 48, "height": 48},
    ],
    "style_description": "2D pixel art side-scrolling game sprite, dark gothic colors, clean black outline, clear pixel structure",
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 48},    # ★ 正方形
    "no_background": True,
})
if err: print(f"  E1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  E1 job: {jid[:12]}... (3 Sprite styles, 48x48 SQUARE)")
        async_jobs["E1_gen_with_style_3sprites_48x48"] = jid
time.sleep(2)

# E2: Lady+Vampiress → 64×64 (正方形！)
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_spr_64x64), "width": 64, "height": 64},
        {"image": b64_obj(vamp_64x80), "width": 64, "height": 80},  # 允許 style_images 非正方形？
    ],
    "style_description": "gothic pixel art game character sprite, clean precise pixel boundaries, dark charcoal dress",
    "description": BASE_DESC,
    "image_size": {"width": 64, "height": 64},    # ★ 正方形
    "no_background": True,
})
if err: print(f"  E2 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  E2 job: {jid[:12]}... (Lady+Vampiress styles, 64x64 SQUARE)")
        async_jobs["E2_gen_with_style_2sprites_64x64"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# BONUS G: pixen + medium shading (pixen 支援 medium? 上次跳過)
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("BONUS-G: pixen endpoint exploration")
print("═"*60)

# G1: pixen 48×60 (pixen 是否也接受 medium detail?)
r, err = api_post("create-image-pixen", {
    "description": e48x60,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "detail": "highly detailed",
    "view": "side",
    "direction": "east",
    "no_background": True,
})
if err: print(f"  G1 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_G1_pixen_48x60.png")
    if p: pil_quantize(p)
time.sleep(2)

# G2: pixen 64×80
r, err = api_post("create-image-pixen", {
    "description": e64x80,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color outline",
    "detail": "highly detailed",
    "view": "side",
    "direction": "east",
    "no_background": True,
})
if err: print(f"  G2 ERR: {err[:200]}")
else:
    p = save_sync(r, "v12_G2_pixen_64x80.png")
    if p: pil_quantize(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# POLL ALL ASYNC JOBS
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print(f"POLLING {len(async_jobs)} ASYNC JOBS...")
print("═"*60)

for prefix, job_id in async_jobs.items():
    print(f"\n[POLL] {prefix}")
    result = poll_job(job_id, max_wait=300)
    if result:
        n = save_async(result, f"v12_{prefix}")
        if n == 0:
            print(f"  ⚠️ No images in result: {list(result.keys())[:5]}")
        for img_path in OUT_DIR.glob(f"v12_{prefix}_??.png"):
            pil_quantize(img_path)
    time.sleep(1)

# FINAL
print("\n" + "=" * 70)
print("V12-FIX COMPLETE")
bal2 = api_get("balance")
bal2_v = bal2.get("usd_balance", bal2.get("balance", "?"))
print(f"Balance: {bal2}")

all_outputs = list(OUT_DIR.glob("v12_*.png"))
core = [f for f in all_outputs if "_4x" not in f.name and "_q8" not in f.name]
print(f"Total core images: {len(core)} ({len(all_outputs)} with 4x/q8)")
for f in sorted(core):
    print(f"  {f.name}")
