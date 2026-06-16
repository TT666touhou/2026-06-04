"""
V12-fix-D: 修正 generate-image-v2 的 style_image 格式
錯誤：style_image 需要 {"image": ..., "size": {"width": w, "height": h}}
而不是 {"image": ..., "width": w, "height": h}（頂層 key）
"""
import sys, io, urllib.request, urllib.error, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json",
           "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v12_new_methods")
LADY_ILLUST   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
AMELIA_ILLUST = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Amelia_Rainwales.png")
LADY_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
SOUL_SPRITE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Soul_Eater\skins\sprite.png")
VAMPIRESS     = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Phantasm_Petal.png")

def img_b64(path, max_size=256, exact_wh=None):
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

def actual_wh(path, max_size=256, exact_wh=None):
    if exact_wh:
        return exact_wh
    img = Image.open(path)
    w, h = img.size
    if max_size and max(w, h) > max_size:
        scale = max_size / max(w, h)
        return (int(w*scale), int(h*scale))
    return (w, h)

def b64_obj(b): return {"type": "base64", "base64": b}

def api_post(ep, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{BASE_URL}/{ep}", data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.loads(r.read()), None
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode(errors='replace')[:400]}"

def api_get(path):
    req = urllib.request.Request(f"{BASE_URL}/{path}", headers={"Authorization": f"Bearer {BEARER}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def poll_job(job_id, max_wait=300):
    for i in range(max_wait // 5):
        time.sleep(5)
        try:
            data = api_get(f"background-jobs/{job_id}")
        except: continue
        status = data.get("status", "")
        if status == "completed": return data.get("last_response", {})
        if status == "failed":
            print(f"  ❌ Failed: {data.get('last_response', {})}")
            return None
        if i % 6 == 0: print(f"  ⏳ {job_id[:8]}... {status} ({(i+1)*5}s)")
    print("  ⚠️ Timeout")
    return None

def save_png(b64, filename):
    if not b64: return None
    if b64.startswith("data:"): b64 = b64.split(",", 1)[1]
    try: raw = base64.b64decode(b64)
    except: return None
    if raw[:4] != b'\x89PNG': return None
    out = OUT_DIR / filename
    out.write_bytes(raw)
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    if max(w, h) <= 200:
        img.resize((w*4, h*4), Image.NEAREST).save(OUT_DIR / filename.replace(".png", "_4x.png"))
    print(f"  ✅ {filename} ({w}×{h})")
    return out

def save_async(result, prefix):
    saved = 0
    if result and "image" in result and isinstance(result["image"], dict):
        if save_png(result["image"].get("base64",""), f"{prefix}_00.png"): saved += 1
    elif result and "images" in result:
        for i, d in enumerate(result["images"][:6]):
            if save_png(d.get("base64",""), f"{prefix}_{i:02d}.png"): saved += 1
    return saved

print("=" * 60)
print("V12-FIX-D: generate-image-v2 correct style_image format")
print("=" * 60)

bal = api_get("balance")
print(f"Balance: {bal.get('subscription', {}).get('generations', '?')} gens")

BASE_DESC = (
    "pale lavender-white long straight hair with large black ribbon bow on head, "
    "dark purple-charcoal gothic lolita dress, deep burgundy dark red ruffle hem frills, "
    "dark gray-black pantyhose, warm peach skin tone, slender proportions, "
    "facing right side view, 2D sidescroller pixel art character sprite, transparent background"
)

# 預備圖片
lady_sprite_b64 = img_b64(LADY_SPRITE, 60)
lady_sprite_w, lady_sprite_h = Image.open(LADY_SPRITE).size       # 40×52
soul_b64 = img_b64(SOUL_SPRITE, 60)
soul_w, soul_h = actual_wh(SOUL_SPRITE, 60)
vamp_b64 = img_b64(VAMPIRESS, 80)
vamp_w, vamp_h = Image.open(VAMPIRESS).size                        # 23×48
lady_illust_b64 = img_b64(LADY_ILLUST, 256)
lady_illust_w, lady_illust_h = actual_wh(LADY_ILLUST, 256)         # 176×256
amelia_b64 = img_b64(AMELIA_ILLUST, 256)
amelia_w, amelia_h = actual_wh(AMELIA_ILLUST, 256)                  # 219×256

print(f"Lady Sprite: {lady_sprite_w}×{lady_sprite_h}")
print(f"Vampiress: {vamp_w}×{vamp_h}")
print(f"Lady Illust (scaled): {lady_illust_w}×{lady_illust_h}")
print(f"Amelia (scaled): {amelia_w}×{amelia_h}")

async_jobs = {}

print("\n" + "─"*60)
print("D: generate-image-v2 + style_image (CORRECT size format)")
print("─"*60)

# D1: Lady Sprite style → ★ 正確格式：size 子欄位
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 60},
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_sprite_b64),
        "size": {"width": lady_sprite_w, "height": lady_sprite_h},  # ★ 修正！
    },
    "style_options": {
        "color_palette": True,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_b64),
            "size": {"width": lady_illust_w, "height": lady_illust_h}
        }
    ],
})
if err: print(f"  D1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D1 job: {jid[:12]}... (Lady Sprite style + Lady Illust ref, 48x60)")
        async_jobs["D1_gen_v2_ladystyle_48x60"] = jid
    else:
        print(f"  D1 response keys: {list(r.keys())}")
time.sleep(2)

# D2: Vampiress style (no palette) + Lady+Amelia refs, 64×80
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 64, "height": 80},
    "no_background": True,
    "style_image": {
        "image": b64_obj(vamp_b64),
        "size": {"width": vamp_w, "height": vamp_h},              # ★ 修正！
    },
    "style_options": {
        "color_palette": False,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_b64),
            "size": {"width": lady_illust_w, "height": lady_illust_h}
        },
        {
            "image": b64_obj(amelia_b64),
            "size": {"width": amelia_w, "height": amelia_h}
        },
    ],
})
if err: print(f"  D2 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D2 job: {jid[:12]}... (Vampiress style + Lady+Amelia refs, 64x80)")
        async_jobs["D2_gen_v2_vampstyle_64x80"] = jid
time.sleep(2)

# D3: Soul style + Lady ref, 32×40
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 32, "height": 40},
    "no_background": True,
    "style_image": {
        "image": b64_obj(soul_b64),
        "size": {"width": soul_w, "height": soul_h},              # ★ 修正！
    },
    "style_options": {
        "color_palette": False,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_b64),
            "size": {"width": lady_illust_w, "height": lady_illust_h}
        },
    ],
})
if err: print(f"  D3 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D3 job: {jid[:12]}... (Soul style + Lady ref, 32x40)")
        async_jobs["D3_gen_v2_soulstyle_32x40"] = jid
time.sleep(2)

# D4 BONUS: Lady Sprite style + ALL Sprite styles (4 references = Lady+Amelia illust), 48x60
r, err = api_post("generate-image-v2", {
    "description": BASE_DESC,
    "image_size": {"width": 48, "height": 60},
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_sprite_b64),
        "size": {"width": lady_sprite_w, "height": lady_sprite_h},
    },
    "style_options": {
        "color_palette": True,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {
            "image": b64_obj(lady_illust_b64),
            "size": {"width": lady_illust_w, "height": lady_illust_h}
        },
        {
            "image": b64_obj(amelia_b64),
            "size": {"width": amelia_w, "height": amelia_h}
        },
    ],
})
if err: print(f"  D4 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  D4 job: {jid[:12]}... (Lady Sprite style + Lady+Amelia refs, 48x60 BONUS)")
        async_jobs["D4_gen_v2_lady_lady_amelia_48x60"] = jid
time.sleep(2)

print(f"\nPolling {len(async_jobs)} D-series jobs...")

for prefix, job_id in async_jobs.items():
    print(f"\n[POLL] {prefix}")
    result = poll_job(job_id, max_wait=300)
    if result:
        n = save_async(result, f"v12_{prefix}")
        if n == 0:
            print(f"  ⚠️ Empty result: {list(result.keys())}")
    time.sleep(1)

print("\n" + "=" * 60)
bal2 = api_get("balance")
print(f"Balance: {bal2.get('subscription', {}).get('generations', '?')} gens remaining")
all_files = sorted([f.name for f in OUT_DIR.glob("v12_*.png") if "_4x" not in f.name and "_q8" not in f.name])
print(f"Total core images: {len(all_files)}")
for f in all_files:
    print(f"  {f}")
