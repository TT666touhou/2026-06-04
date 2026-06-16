"""
V13c - generate-with-style-v2 正確格式
重大發現：style_images 的格式與 generate-image-v2 的 reference_images 不同！

generate-with-style-v2 style_images：頂層 width/height（不是 size 子欄位！）
  ✅ {"image": b64_obj, "width": w, "height": h}
  ❌ {"image": b64_obj, "size": {"width": w, "height": h}}

generate-image-v2 reference_images/style_image：size 子欄位
  ✅ {"image": b64_obj, "size": {"width": w, "height": h}}
  ❌ {"image": b64_obj, "width": w, "height": h}

這是 API 的不一致設計！必須記錄到 workflow.md！
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
print("V13c - CORRECT FORMAT: generate-with-style-v2 top-level width/height")
print("KEY DISCOVERY:")
print("  style_images uses TOP-LEVEL width/height (not size sub-object!)")
print("  {\"image\": ..., \"width\": w, \"height\": h}  ← CORRECT")
print("  {\"image\": ..., \"size\": {\"width\": w}}     ← WRONG (for style_images)")
print("=" * 70)

bal = api_get("balance")
print(f"Balance: {bal['subscription']['generations']:.1f} gens\n")

# 準備 skins（精確尺寸）
lady_b64   = img_b64(SKIN_LADY);    lady_w,   lady_h   = get_wh(SKIN_LADY)
doppel_b64 = img_b64(SKIN_DOPPEL);  doppel_w, doppel_h = get_wh(SKIN_DOPPEL)
phantom_b64= img_b64(SKIN_PHANTOM); phantom_w,phantom_h= get_wh(SKIN_PHANTOM)
vamp_b64   = img_b64(SKIN_VAMPIRE); vamp_w,   vamp_h   = get_wh(SKIN_VAMPIRE)
assn_b64   = img_b64(SKIN_ASSASSIN);assn_w,   assn_h   = get_wh(SKIN_ASSASSIN)
mage_b64   = img_b64(SKIN_MAGE);    mage_w,   mage_h   = get_wh(SKIN_MAGE)

print(f"Lady:    {lady_w}×{lady_h}")
print(f"Doppel:  {doppel_w}×{doppel_h}")
print(f"Phantom: {phantom_w}×{phantom_h}")
print(f"Vampire: {vamp_w}×{vamp_h}")
print()

# ★ 正確的 style_images 格式：頂層 width/height（不是 size！）
FOUR_SKINS_CORRECT = [
    {"image": b64_obj(lady_b64),    "width": lady_w,    "height": lady_h},
    {"image": b64_obj(doppel_b64),  "width": doppel_w,  "height": doppel_h},
    {"image": b64_obj(phantom_b64), "width": phantom_w, "height": phantom_h},
    {"image": b64_obj(vamp_b64),    "width": vamp_w,    "height": vamp_h},
]

ALT_FOUR_CORRECT = [
    {"image": b64_obj(assn_b64),    "width": assn_w,    "height": assn_h},
    {"image": b64_obj(lady_b64),    "width": lady_w,    "height": lady_h},
    {"image": b64_obj(doppel_b64),  "width": doppel_w,  "height": doppel_h},
    {"image": b64_obj(mage_b64),    "width": mage_w,    "height": mage_h},
]

async_jobs = {}

# ════ A1: 4 skins, 最少 description ════
print("─"*60)
print("A1: gen-with-style-v2 (CORRECT FORMAT, 4 skins, minimal, 48×48)")
r, err = api_post("generate-with-style-v2", {
    "style_images": FOUR_SKINS_CORRECT,
    "style_description": "2D side-scrolling pixel art game sprite, black outline, flat color",
    "description": "girl character",
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A1 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A1 job: {jid[:12]}... (4 skins, 'girl character', 48×48)")
        async_jobs["A1_correct_4skins_minimal"] = jid
time.sleep(2)

# ════ A2: 4 skins, 白髮吸血鬼角色描述（無禁止詞）════
print("─"*60)
print("A2: gen-with-style-v2 (4 skins, 白髮吸血鬼, 48×48)")
r, err = api_post("generate-with-style-v2", {
    "style_images": FOUR_SKINS_CORRECT,
    "style_description": "DS pixel art game character sprite with black outline",
    "description": "white haired vampire girl gothic dark dress bow ribbon",
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A2 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A2 job: {jid[:12]}... (4 skins, white vampire girl, 48×48)")
        async_jobs["A2_correct_vampire_girl"] = jid
time.sleep(2)

# ════ A3: 備用 4 skins 組合, 蝴蝶結描述 ════
print("─"*60)
print("A3: gen-with-style-v2 (alt 4 skins, cute bow girl, 48×48)")
r, err = api_post("generate-with-style-v2", {
    "style_images": ALT_FOUR_CORRECT,
    "style_description": "pixel art game character standing sprite",
    "description": "cute girl with big black bow ribbon in hair dark gothic dress",
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A3 ERR: {err[:300]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A3 job: {jid[:12]}... (alt 4 skins, big bow girl, 48×48)")
        async_jobs["A3_correct_bow_girl"] = jid
time.sleep(2)

# ════ POLL ════
print(f"\n{'═'*60}")
print(f"POLLING {len(async_jobs)} jobs...")
print(f"{'═'*60}")

for prefix, job_id in async_jobs.items():
    print(f"\n[POLL] {prefix}")
    result = poll_job(job_id, max_wait=300)
    if result:
        n = save_all(result, f"v13c_{prefix}")
        if n == 0: print(f"  ⚠️ 0 saved. Keys: {list(result.keys())[:5]}")
    time.sleep(1)

print("\n" + "=" * 70)
bal2 = api_get("balance")
used = bal['subscription']['generations'] - bal2['subscription']['generations']
print(f"Balance: {bal2['subscription']['generations']:.1f} ({used:.1f} used)")
all_files = sorted([f.name for f in OUT_DIR.glob("v13c_*.png") if "_8x" not in f.name])
print(f"Core images: {len(all_files)}")
for f in all_files: print(f"  {f}")
