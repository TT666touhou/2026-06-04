"""
V12 多策略實驗腳本 - 使用新發現的 API 方法
新發現：
- medium shading（從未測試的平衡點）
- single color outline（非純黑）
- negative_description 在 bitforge 才生效（pixflux 已廢棄）
- generate-image-v2 (Pro) + style_options 複製風格
- generate-with-style-v2 (Pro) 多風格 Sprite 參考
- image-to-pixelart-pro (Pro) 自動判斷像素密度

llms.txt 確認讀取：2026-06-16（前一輪）
cookbook 確認讀取：2026-06-16

目標：~20 張不同尺寸/策略組合
"""
import sys, io, urllib.request, urllib.error, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# ─── API 設定 ─────────────────────────────────────────────────
BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": "https://pixellab.ai",
}
CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": "https://pixellab.ai",
}

# ─── 路徑 ────────────────────────────────────────────────────
OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v12_new_methods")
OUT_DIR.mkdir(parents=True, exist_ok=True)

LADY_ILLUST   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
AMELIA_ILLUST = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Amelia_Rainwales.png")
LADY_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
SOUL_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Soul_Eater\skins\sprite.png")
VAMPIRESS     = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Phantasm_Petal.png")
MAGE_ILLUST   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Mage\illustrations\Lady_Scarlet_Mage.png")

# ─── 工具函式 ────────────────────────────────────────────────
def img_b64(path: Path, max_size: int = 256, resize_wh=None) -> str:
    """PIL open + resize + base64（不含 data URI 前綴）"""
    img = Image.open(path).convert("RGBA")
    if resize_wh:
        img = img.resize(resize_wh, Image.LANCZOS)
    elif max_size:
        w, h = img.size
        if max(w, h) > max_size:
            scale = max_size / max(w, h)
            img = img.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")

def b64_obj(b64_str: str) -> dict:
    """帶 data URI prefix 的物件（某些端點需要）"""
    return {"type": "base64", "base64": b64_str}

def b64_obj_prefix(path: Path, max_size: int = 256) -> dict:
    """帶完整 data URI 前綴"""
    b = img_b64(path, max_size)
    return {"type": "base64", "base64": f"data:image/png;base64,{b}"}

def get_img_size(path: Path) -> tuple:
    img = Image.open(path)
    return img.size

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
    """輪詢 background job，每5秒一次，直到完成"""
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
            print(f"  ❌ Job failed: {data.get('last_response', {}).get('detail', 'unknown')}")
            return None
        if i % 6 == 0:
            print(f"  ⏳ {job_id[:8]}... status={status} ({(i+1)*5}s)")
    print(f"  ⚠️ Timeout after {max_wait}s")
    return None

def save_b64_png(b64: str, filename: str, with_4x=True) -> Path | None:
    """保存 base64 PNG，並自動產生 4x 版本"""
    if not b64:
        return None
    if b64.startswith("data:"):
        b64 = b64.split(",", 1)[1]
    try:
        raw = base64.b64decode(b64)
    except Exception as ex:
        print(f"  ❌ decode error: {ex}")
        return None
    if raw[:4] != b'\x89PNG':
        print(f"  ❌ Not PNG! First bytes: {raw[:8].hex()}")
        return None
    out = OUT_DIR / filename
    out.write_bytes(raw)
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    if with_4x and max(w, h) <= 128:
        big = img.resize((w*4, h*4), Image.NEAREST)
        big.save(OUT_DIR / filename.replace(".png", "_4x.png"))
    print(f"  ✅ {filename} ({w}×{h})")
    return out

def save_sync_result(result: dict | None, filename: str) -> Path | None:
    """返回 Path 物件（給 pil_post_process 使用）或 None"""
    if not result:
        return None
    img_data = result.get("image", {})
    if isinstance(img_data, dict):
        b64 = img_data.get("base64", "")
        return save_b64_png(b64, filename)
    return None

def save_async_results(result: dict | None, prefix: str, max_imgs: int = 6) -> int:
    """保存異步結果（可能是 .image 或 .images[]）"""
    if not result:
        return 0
    saved = 0
    # 單張
    if "image" in result and isinstance(result["image"], dict):
        b64 = result["image"].get("base64", "")
        if save_b64_png(b64, f"{prefix}_00.png"):
            saved += 1
    # 多張
    elif "images" in result:
        for i, img_data in enumerate(result["images"][:max_imgs]):
            b64 = img_data.get("base64", "")
            if save_b64_png(b64, f"{prefix}_{i:02d}.png"):
                saved += 1
    return saved

def enhance_pixen_prompt(desc: str, w: int, h: int, outline: str = "single color black outline") -> str:
    """§O-10-1 強制前置：enhance-pixen-prompt"""
    result, err = api_post("enhance-pixen-prompt", {
        "description": desc,
        "image_size": {"width": w, "height": h},
        "outline": outline,
    })
    if err:
        print(f"  ⚠️ enhance failed: {err[:100]}")
        return desc
    enhanced = result.get("enhanced_prompt", desc)
    print(f"  🔧 Enhanced ({len(enhanced)} chars): {enhanced[:120]}...")
    return enhanced

def remove_isolated_pixels(img: Image.Image) -> Image.Image:
    """去除孤立噪點像素（≤1個不透明鄰居 → 刪除）"""
    img = img.convert("RGBA")
    data = list(img.getdata())
    w, h = img.size
    new_data = list(data)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            idx = y * w + x
            if data[idx][3] < 10:
                continue
            opaque = sum(1 for dy in [-1,0,1] for dx in [-1,0,1]
                         if not (dx==0 and dy==0) and data[(y+dy)*w+(x+dx)][3] > 10)
            if opaque <= 1:
                new_data[idx] = (0, 0, 0, 0)
    result = img.copy()
    result.putdata(new_data)
    return result

def pil_post_process(img_path: Path) -> Path | None:
    """PIL 後處理：去噪 + 量化 → 保存 _q8.png"""
    if not img_path or not img_path.exists():
        return None
    img = Image.open(img_path).convert("RGBA")
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b))
    quantized = rgb.quantize(colors=8, method=Image.Quantize.MEDIANCUT).convert("RGB")
    result = Image.merge("RGBA", (*quantized.split(), a))
    result = remove_isolated_pixels(result)
    out = OUT_DIR / img_path.name.replace(".png", "_q8.png")
    result.save(out)
    print(f"  🎨 Post-processed: {out.name}")
    return out

# ═══════════════════════════════════════════════════════════════
print("=" * 70)
print("V12 MULTI-STRATEGY GENERATION  (20+ images)")
print("llms.txt: CONFIRMED read previous turn")
print("=" * 70)

# PRE-FLIGHT
bal_data = api_get("balance")
bal = bal_data.get("usd_balance", bal_data.get("balance", "?"))
print(f"[PRE-FLIGHT] Balance: {bal}")

# 基礎描述
BASE_DESC = (
    "pale lavender-white long straight hair with large black ribbon bow on head, "
    "dark purple-charcoal gothic lolita dress, deep burgundy dark red ruffle hem frills, "
    "dark gray-black pantyhose, warm peach skin tone, slender proportions, "
    "facing right side view, 2D sidescroller pixel art character sprite, "
    "transparent background"
)

# ─── 預先生成所有 base64 ──────────────────────────────────────
print("\n[PREP] Encoding reference images...")
lady_sprite_b64   = img_b64(LADY_SPRITE, 60)
soul_sprite_b64   = img_b64(SOUL_SPRITE, 60)
vampiress_b64     = img_b64(VAMPIRESS, 80)
lady_illust_b64   = img_b64(LADY_ILLUST, 256)
amelia_illust_b64 = img_b64(AMELIA_ILLUST, 256)
mage_illust_b64   = img_b64(MAGE_ILLUST, 256)

# Lady sprite 尺寸
lady_sprite_w, lady_sprite_h = get_img_size(LADY_SPRITE)
soul_w, soul_h = get_img_size(SOUL_SPRITE)
vampiress_w, vampiress_h = get_img_size(VAMPIRESS)
print(f"  Lady Sprite: {lady_sprite_w}×{lady_sprite_h}")
print(f"  Soul Sprite: {soul_w}×{soul_h}")
print(f"  Vampiress: {vampiress_w}×{vampiress_h}")

# ─── Enhance prompts ─────────────────────────────────────────
print("\n[PREP] Running enhance-pixen-prompt...")
enhanced_48x60 = enhance_pixen_prompt(BASE_DESC, 48, 60, "single color black outline")
time.sleep(1)
enhanced_64x80 = enhance_pixen_prompt(BASE_DESC, 64, 80, "single color outline")
time.sleep(1)
enhanced_32x40 = enhance_pixen_prompt(BASE_DESC, 32, 40, "single color black outline")
time.sleep(1)
enhanced_lineless_48 = enhance_pixen_prompt(BASE_DESC, 48, 60, "lineless")
time.sleep(1)

# ════════════════════════════════════════════════════════════════
# STRATEGY A: pixflux + medium shading（★ 新！從未測試）
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("A: pixflux + medium shading (NEW)")
print("═"*60)

# A1: 已完成（上次運行成功），跳過
print("  A1 SKIP (already saved)")
time.sleep(1)

# A2: 64×80, medium shading + single color outline (非純黑) ★
r, err = api_post("create-image-pixflux", {
    "description": enhanced_64x80,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color outline",   # ★ 非純黑！
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64),
    "text_guidance_scale": 9.0,
})
if err: print(f"  A2 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_A2_medium_single_outline_64x80.png")
    if p: pil_post_process(p)
time.sleep(2)

# A3: 32×40, medium shading, text_guidance 10.0 (最高)
r, err = api_post("create-image-pixflux", {
    "description": enhanced_32x40,
    "image_size": {"width": 32, "height": 40},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "medium detail",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64),
    "text_guidance_scale": 10.0,       # ★ 最高！
})
if err: print(f"  A3 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_A3_medium_shading_32x40.png")
    if p: pil_post_process(p)
time.sleep(2)

# A4: lineless + medium shading, 48×60 (對比：V11 是 lineless+flat)
r, err = api_post("create-image-pixflux", {
    "description": enhanced_lineless_48,
    "image_size": {"width": 48, "height": 60},
    "outline": "lineless",
    "shading": "medium shading",       # 不用 flat，試 medium
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64),
    "text_guidance_scale": 9.0,
})
if err: print(f"  A4 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_A4_lineless_medium_48x60.png")
    if p: pil_post_process(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# STRATEGY B: pixflux + init_image = illustration (插畫啟動)
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("B: pixflux + init_image from illustrations")
print("═"*60)

# B1: init = Lady Illust (full illustration), 48×60, medium shading
r, err = api_post("create-image-pixflux", {
    "description": enhanced_48x60,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "init_image": b64_obj(lady_illust_b64),
    "init_image_strength": 200,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B1 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_B1_init_ladyillust_48x60.png")
    if p: pil_post_process(p)
time.sleep(2)

# B2: init = Amelia Illust (不同角色形態 → 測試角度/姿勢多樣性), 48×60
r, err = api_post("create-image-pixflux", {
    "description": enhanced_48x60,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64),
    "init_image": b64_obj(amelia_illust_b64),
    "init_image_strength": 150,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B2 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_B2_init_amelia_48x60.png")
    if p: pil_post_process(p)
time.sleep(2)

# B3: init = Lady Illust + Vampiress color_image 風格, 64×80
r, err = api_post("create-image-pixflux", {
    "description": enhanced_64x80,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "color_image": b64_obj(vampiress_b64),    # 使用 Vampiress 配色
    "init_image": b64_obj(lady_illust_b64),
    "init_image_strength": 180,
    "text_guidance_scale": 9.0,
})
if err: print(f"  B3 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_B3_init_lady_vampiress_color_64x80.png")
    if p: pil_post_process(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# STRATEGY C: bitforge + negative_description（真正生效！）
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("C: bitforge + negative_description (真正生效)")
print("═"*60)

NEGATIVE = "cat ears, bunny ears, gradient, anti-aliasing, smooth shading, blurry, noisy pixels, dithering, soft edges, undefined shapes, isolated dots"

# C1: bitforge + Lady Sprite style + negative_desc, 64×80
r, err = api_post("create-image-bitforge", {
    "description": enhanced_64x80,
    "negative_description": NEGATIVE,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "style_image": b64_obj(lady_sprite_b64),
    "style_strength": 60.0,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C1 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_C1_bitforge_style_lady_64x80.png")
    if p: pil_post_process(p)
time.sleep(2)

# C2: bitforge + Vampiress style + negative_desc, 48×60
r, err = api_post("create-image-bitforge", {
    "description": enhanced_48x60,
    "negative_description": NEGATIVE,
    "image_size": {"width": 48, "height": 60},
    "outline": "single color black outline",
    "shading": "medium shading",
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "style_image": b64_obj(vampiress_b64),
    "style_strength": 55.0,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C2 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_C2_bitforge_style_vampiress_48x60.png")
    if p: pil_post_process(p)
time.sleep(2)

# C3: bitforge + init_image=Lady Illust + negative_desc, 64×80
r, err = api_post("create-image-bitforge", {
    "description": BASE_DESC,
    "negative_description": NEGATIVE,
    "image_size": {"width": 64, "height": 80},
    "outline": "single color black outline",
    "shading": "basic shading",          # bitforge 用 basic 更穩定
    "detail": "highly detailed",
    "view": "side", "direction": "east",
    "no_background": True,
    "init_image": b64_obj(lady_illust_b64),
    "init_image_strength": 180,
    "text_guidance_scale": 9.0,
})
if err: print(f"  C3 ERR: {err[:200]}")
else:
    p = save_sync_result(r, "v12_C3_bitforge_init_ladyillust_64x80.png")
    if p: pil_post_process(p)
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# STRATEGY D: generate-image-v2 (Pro) + style_options
# 異步，最後 poll
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("D: generate-image-v2 (Pro) + style_options [ASYNC]")
print("═"*60)

async_jobs = {}

# D1: Lady Sprite 的全部視覺風格 → 複製到新生成
# style_image = Lady Sprite, reference = Lady Illust
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 60},
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_sprite_b64),
        "width": lady_sprite_w, "height": lady_sprite_h,
    },
    "style_options": {
        "color_palette": True,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {"image": b64_obj(lady_illust_b64), "width": 256, "height": 256}
    ],
})
if err:
    print(f"  D1 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D1 job: {jid[:12]}... (Lady Sprite style + Lady Illust ref)")
        async_jobs["D1_gen_v2_ladysprite_style_48x60"] = jid
time.sleep(2)

# D2: Lady+Vampiress style, Lady Illust ref, 64×80
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 64, "height": 80},
    "no_background": True,
    "style_image": {
        "image": b64_obj(vampiress_b64),
        "width": vampiress_w, "height": vampiress_h,
    },
    "style_options": {
        "color_palette": False,     # 不複製 Vampiress 顏色！只複製筆觸風格
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {"image": b64_obj(lady_illust_b64), "width": 256, "height": 256},
        {"image": b64_obj(amelia_illust_b64), "width": 256, "height": 256},
    ],
})
if err:
    print(f"  D2 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D2 job: {jid[:12]}... (Vampiress style + Lady+Amelia refs, 64x80)")
        async_jobs["D2_gen_v2_vampiress_style_64x80"] = jid
time.sleep(2)

# D3: Soul Eater style, Lady+Amelia refs, 32×40（最小尺寸測試）
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 32, "height": 40},
    "no_background": True,
    "style_image": {
        "image": b64_obj(soul_sprite_b64),
        "width": soul_w, "height": soul_h,
    },
    "style_options": {
        "color_palette": False,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {"image": b64_obj(lady_illust_b64), "width": 256, "height": 256},
    ],
})
if err:
    print(f"  D3 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D3 job: {jid[:12]}... (Soul style + Lady ref, 32x40)")
        async_jobs["D3_gen_v2_soul_style_32x40"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# STRATEGY E: generate-with-style-v2 (Pro) 多風格
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("E: generate-with-style-v2 (Pro) [ASYNC]")
print("═"*60)

# E1: 3個 Sprite 作為 style_images, Lady Illust 作為描述基礎, 48×60
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_sprite_b64), "width": lady_sprite_w, "height": lady_sprite_h},
        {"image": b64_obj(vampiress_b64), "width": vampiress_w, "height": vampiress_h},
        {"image": b64_obj(soul_sprite_b64), "width": soul_w, "height": soul_h},
    ],
    "style_description": "2D side-scrolling pixel art game character sprite, clean pixel structure, dark gothic colors, clear outlines",
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 60},
    "no_background": True,
})
if err:
    print(f"  E1 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  E1 job: {jid[:12]}... (Lady+Vampiress+Soul styles, 48x60)")
        async_jobs["E1_gen_with_style_3sprites_48x60"] = jid
time.sleep(2)

# E2: Lady+Vampiress style, 64×80（更大尺寸）
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_sprite_b64), "width": lady_sprite_w, "height": lady_sprite_h},
        {"image": b64_obj(vampiress_b64), "width": vampiress_w, "height": vampiress_h},
    ],
    "style_description": "pixel art game sprite, gothic girl character, dark charcoal dress, precise pixel boundaries",
    "description": BASE_DESC,
    "image_size": {"width": 64, "height": 80},
    "no_background": True,
})
if err:
    print(f"  E2 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  E2 job: {jid[:12]}... (Lady+Vampiress styles, 64x80)")
        async_jobs["E2_gen_with_style_2sprites_64x80"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# STRATEGY F: image-to-pixelart-pro (Pro) 自動像素化
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("F: image-to-pixelart-pro (Auto pixel density) [ASYNC]")
print("═"*60)

# F1: Lady Illust → 自動像素化
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(lady_illust_b64),
    "description": "clean pixel art game character, no dithering, flat colors, gothic style",
})
if err:
    print(f"  F1 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  F1 job: {jid[:12]}... (Lady Illust → auto pixel)")
        async_jobs["F1_img2pxpro_lady_illust"] = jid
time.sleep(2)

# F2: Amelia Illust → 自動像素化
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(amelia_illust_b64),
    "description": "2D side-scrolling game pixel art character sprite, clean pixels",
})
if err:
    print(f"  F2 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  F2 job: {jid[:12]}... (Amelia Illust → auto pixel)")
        async_jobs["F2_img2pxpro_amelia_illust"] = jid
time.sleep(2)

# F3: Lady Scarlet Mage (非常乾淨的洛麗塔插畫) → 自動像素化
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(mage_illust_b64),
    "description": "retro pixel game character sprite, clean colors, no noise",
})
if err:
    print(f"  F3 ERR: {err[:200]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  F3 job: {jid[:12]}... (LadyScarletMage → auto pixel)")
        async_jobs["F3_img2pxpro_mage_illust"] = jid
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
        n = save_async_results(result, f"v12_{prefix}")
        if n == 0:
            print(f"  ⚠️ No images extracted from result: {list(result.keys())[:5]}")
        # PIL 後處理
        for img_path in OUT_DIR.glob(f"v12_{prefix}_??.png"):
            pil_post_process(img_path)
    time.sleep(1)

# ════════════════════════════════════════════════════════════════
# FINAL
# ════════════════════════════════════════════════════════════════
print("\n" + "=" * 70)
print("V12 COMPLETE")
bal2 = api_get("balance")
bal2_v = bal2.get("usd_balance", bal2.get("balance", "?"))
print(f"Balance: ${bal} → ${bal2_v}")

all_outputs = list(OUT_DIR.glob("v12_*.png"))
core_outputs = [f for f in all_outputs if "_4x" not in f.name and "_q8" not in f.name]
print(f"Generated {len(core_outputs)} core images ({len(all_outputs)} total with 4x/q8 versions)")
print(f"Output: {OUT_DIR}")
