"""
V13b - 修正版：應用所有新發現的限制
修正清單：
  ✅ generate-with-style-v2: 最多 4 張 style_images（非 5-8）
  ✅ description 不能空字串：用 " " 或最短的單字
  ✅ "loli" = content policy 違規：改用 "young girl" / "petite girl"
  ✅ A 系列：重試 4 skins（max）
  ✅ B1：加最少 description
  ✅ C1：加最少 description
  ✅ 同時：找出 image-to-pixelart-pro 能否移除黑背景

新陷阱記錄（V13b）：
  - generate-with-style-v2: List should have at most 4 items
  - description: String should have at least 1 character（空字串報422）
  - "loli": Content policy violation!（禁止詞！）
"""
import sys, io, urllib.request, urllib.error, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json",
           "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v13_skin_style")
OUT_DIR.mkdir(parents=True, exist_ok=True)

SKIN_LADY      = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
SKIN_DOPPEL    = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Doppelganger.png")
SKIN_PHANTOM   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Phantom_of_the_White_Night.png")
SKIN_VAMPIRE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Vampire.png")
SKIN_ASSASSIN  = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Assassin.png")
SKIN_MAGE      = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Mage\skins\R_R_Mage.png")

def img_b64(path: Path) -> str:
    img = Image.open(path).convert("RGBA")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")

def get_wh(path: Path):
    return Image.open(path).size

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
    return None

def save_png(b64, filename, scale=8) -> bool:
    if not b64: return False
    if b64.startswith("data:"): b64 = b64.split(",", 1)[1]
    try: raw = base64.b64decode(b64)
    except: return False
    if raw[:4] != b'\x89PNG': return False
    out = OUT_DIR / filename
    out.write_bytes(raw)
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    img.resize((w*scale, h*scale), Image.NEAREST).save(OUT_DIR / filename.replace(".png", f"_{scale}x.png"))
    print(f"  ✅ {filename} ({w}×{h}) → {scale}x")
    return True

def save_all(result, prefix, scale=8) -> int:
    if not result: return 0
    saved = 0
    imgs = []
    if "image" in result and isinstance(result["image"], dict):
        imgs = [result["image"]]
    elif "images" in result:
        imgs = result["images"][:4]
    for i, d in enumerate(imgs):
        if save_png(d.get("base64",""), f"{prefix}_{i:02d}.png", scale):
            saved += 1
    return saved

print("=" * 70)
print("V13b - FIXED: all V13 API constraint corrections applied")
print("  [FIX-1] style_images max 4")
print("  [FIX-2] description min 1 char (use single space or minimal text)")
print("  [FIX-3] 'loli' → content policy! use 'young girl' / 'petite girl'")
print("=" * 70)

bal = api_get("balance")
print(f"Balance: {bal['subscription']['generations']:.1f} gens\n")

# 準備 skins（4 張最多！）
lady_b64   = img_b64(SKIN_LADY);    lady_w,   lady_h   = get_wh(SKIN_LADY)    # 40×52
doppel_b64 = img_b64(SKIN_DOPPEL);  doppel_w, doppel_h = get_wh(SKIN_DOPPEL)  # 34×51
phantom_b64= img_b64(SKIN_PHANTOM); phantom_w,phantom_h= get_wh(SKIN_PHANTOM) # 33×51
vamp_b64   = img_b64(SKIN_VAMPIRE); vamp_w,   vamp_h   = get_wh(SKIN_VAMPIRE)  # 21×49
assn_b64   = img_b64(SKIN_ASSASSIN);assn_w,   assn_h   = get_wh(SKIN_ASSASSIN) # 30×52
mage_b64   = img_b64(SKIN_MAGE);    mage_w,   mage_h   = get_wh(SKIN_MAGE)    # 22×49

# 4 張 skin 組合（最多4張）
FOUR_SKINS = [
    {"image": b64_obj(lady_b64),    "size": {"width": lady_w,    "height": lady_h}},
    {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
    {"image": b64_obj(phantom_b64), "size": {"width": phantom_w, "height": phantom_h}},
    {"image": b64_obj(vamp_b64),    "size": {"width": vamp_w,    "height": vamp_h}},
]

async_jobs = {}

# ════ A1: generate-with-style-v2, 4 skins, 最少 description ════
print("─"*60)
print("A1: gen-with-style-v2 (4 skins, minimal desc)")
r, err = api_post("generate-with-style-v2", {
    "style_images": FOUR_SKINS,
    "style_description": "2D side-scrolling pixel art game sprite, black outline, clean",
    "description": "character",  # ★ 最少文字，讓 style 主導
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A1 job: {jid[:12]}... (4 skins, 'character', 48×48)")
        async_jobs["A1_4skins_minimal"] = jid
time.sleep(2)

# ════ A2: generate-with-style-v2, 4 skins, 曖昧語句（移除禁止詞）════
print("─"*60)
print("A2: gen-with-style-v2 (4 skins, vague prompt no forbidden words)")
r, err = api_post("generate-with-style-v2", {
    "style_images": FOUR_SKINS,
    "style_description": "pixel art game sprite character with black outline, side-scrolling 2D",
    "description": "white haired vampire girl gothic dark dress",  # ★ 移除 loli！
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A2 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A2 job: {jid[:12]}... (4 skins, 'white haired vampire girl', 48×48)")
        async_jobs["A2_4skins_vampire_girl"] = jid
time.sleep(2)

# ════ A3: generate-with-style-v2, 不同 4 skins 組合 + 不同 prompt ════
print("─"*60)
print("A3: gen-with-style-v2 (alt 4 skins, cute girl)")
ALT_FOUR = [
    {"image": b64_obj(assn_b64),    "size": {"width": assn_w,    "height": assn_h}},
    {"image": b64_obj(lady_b64),    "size": {"width": lady_w,    "height": lady_h}},
    {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
    {"image": b64_obj(mage_b64),    "size": {"width": mage_w,    "height": mage_h}},
]
r, err = api_post("generate-with-style-v2", {
    "style_images": ALT_FOUR,
    "style_description": "2D game sprite pixel art standing character facing right",
    "description": "cute girl with bow ribbon in hair",  # ★ 蝴蝶結！
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A3 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A3 job: {jid[:12]}... (alt 4 skins, 'cute girl with bow', 48×48)")
        async_jobs["A3_alt4skins_bow_girl"] = jid
time.sleep(2)

# ════ B1: generate-image-v2, Lady style, 最少 desc ════
print("─"*60)
print("B1: generate-image-v2 (Lady style, minimal desc, 40×52)")
r, err = api_post("generate-image-v2", {
    "description": "girl character sprite",  # ★ 最少文字
    "image_size": {"width": 40, "height": 52},
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_b64),
        "size": {"width": lady_w, "height": lady_h},
    },
    "style_options": {"color_palette": True, "outline": True, "detail": True, "shading": True},
    "reference_images": [
        {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
        {"image": b64_obj(phantom_b64), "size": {"width": phantom_w, "height": phantom_h}},
        {"image": b64_obj(vamp_b64),    "size": {"width": vamp_w,    "height": vamp_h}},
    ],
})
if err: print(f"  B1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  B1 job: {jid[:12]}... (Lady style + 3refs, 40×52)")
        async_jobs["B1_lady_style_minimal"] = jid
time.sleep(2)

# ════ C1: image-to-pixelart-pro, Lady skin (with minimal desc) ════
print("─"*60)
print("C1: image-to-pixelart-pro (Lady skin, min desc)")
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(lady_b64),
    "description": "pixel art game character sprite",  # ★ 不能空字串
})
if err: print(f"  C1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  C1 job: {jid[:12]}... (Lady skin → pixelart-pro)")
        async_jobs["C1_lady_img2pxpro"] = jid
    else:
        b64 = r.get("image", {}).get("base64", "")
        if save_png(b64, "v13b_C1_lady_img2pxpro_sync.png"): pass
time.sleep(2)

# ════ C3: image-to-pixelart-pro, Assassin skin ════
print("─"*60)
print("C3: image-to-pixelart-pro (Assassin skin)")
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(assn_b64),
    "description": "pixel art game character",
})
if err: print(f"  C3 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  C3 job: {jid[:12]}... (Assassin skin → pixelart-pro)")
        async_jobs["C3_assn_img2pxpro"] = jid
time.sleep(2)

# ════ POLL ════
print(f"\n{'═'*60}")
print(f"POLLING {len(async_jobs)} jobs...")
print(f"{'═'*60}")

for prefix, job_id in async_jobs.items():
    print(f"\n[POLL] {prefix}")
    result = poll_job(job_id, max_wait=300)
    if result:
        n = save_all(result, f"v13b_{prefix}")
        if n == 0: print(f"  ⚠️ 0 saved. Keys: {list(result.keys())[:5]}")
    time.sleep(1)

print("\n" + "=" * 70)
bal2 = api_get("balance")
used = bal['subscription']['generations'] - bal2['subscription']['generations']
print(f"Balance: {bal2['subscription']['generations']:.1f} ({used:.1f} used)")
all_files = sorted([f.name for f in OUT_DIR.glob("v13b_*.png") if "_8x" not in f.name])
print(f"Core images: {len(all_files)}")
for f in all_files: print(f"  {f}")
