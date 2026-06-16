"""
V13 - DS Skin 畫風直接導入實驗
目標：餵多張 DS 官方 skin 小人圖，讓 PixelLab 直接學習畫風
策略：
  V13-A: generate-with-style-v2 + 5 skins，無 prompt / 最少 prompt
  V13-B: generate-image-v2 + 多 skin 作 reference_images，精確 40×52
  V13-C: image-to-pixelart-pro（直接轉，給最少 prompt）
  V13-D: pixen + skin 配色 + 曖昧語句

GATE-1: llms.txt 已確認讀取（Designer 本輪）
GATE-2: pixellab_cookbook.md v2.4 已讀取
GATE-3: 餘額 1442.75 次 ✅
GATE-4: Pre-Flight 8問已完成
GATE-5: Generation Plan 已確認

token 限制：≤ 30 次
輸出上限：5 張核心圖
"""
import sys, io, urllib.request, urllib.error, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json",
           "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\v13_skin_style")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ─── Reference skins（精選 5 張不同角色的 skin）─────────
SKIN_LADY      = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
SKIN_DOPPEL    = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Doppelganger.png")
SKIN_PHANTOM   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Phantom_of_the_White_Night.png")
SKIN_VAMPIRE   = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Vampire.png")
SKIN_ASSASSIN  = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Assassin.png")
SKIN_MAGE      = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Mage\skins\R_R_Mage.png")
SKIN_SUMMONER  = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Summoner\skins\R_R_Summoner.png")
SKIN_SHAMAN    = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Shaman\skins\Shaman.png")

def img_b64(path: Path, exact_wh=None) -> str:
    """精確尺寸 base64（不強制縮放——skin 本身就是小圖，保持原始尺寸）"""
    img = Image.open(path).convert("RGBA")
    if exact_wh:
        img = img.resize(exact_wh, Image.NEAREST)  # 像素藝術用 NEAREST
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")

def get_wh(path: Path, exact_wh=None):
    if exact_wh:
        return exact_wh
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
    print("  ⚠️ Timeout")
    return None

def save_png(b64, filename, scale=8) -> Path | None:
    """保存 + 自動產生 Nx 放大版（用 NEAREST 保持像素感）"""
    if not b64: return None
    if b64.startswith("data:"): b64 = b64.split(",", 1)[1]
    try: raw = base64.b64decode(b64)
    except: return None
    if raw[:4] != b'\x89PNG':
        print(f"  ❌ Not PNG: {raw[:8].hex()}")
        return None
    out = OUT_DIR / filename
    out.write_bytes(raw)
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    # 放大版（用 NEAREST 保持像素風）
    big = img.resize((w*scale, h*scale), Image.NEAREST)
    big.save(OUT_DIR / filename.replace(".png", f"_{scale}x.png"))
    print(f"  ✅ {filename} ({w}×{h}) → {scale}x 放大")
    return out

def save_best(result, prefix, scale=8) -> int:
    """從異步結果提取所有圖片，只保存前 3 張"""
    if not result: return 0
    saved = 0
    imgs = []
    if "image" in result and isinstance(result["image"], dict):
        imgs = [result["image"]]
    elif "images" in result:
        imgs = result["images"][:3]  # 最多 3 張
    for i, d in enumerate(imgs):
        if save_png(d.get("base64",""), f"{prefix}_{i:02d}.png", scale):
            saved += 1
    return saved

# =============================================================
print("=" * 70)
print("V13 DS SKIN STYLE LEARNING EXPERIMENT")
print("llms.txt: CONFIRMED (this turn)")
print("Cookbook: v2.4 CONFIRMED")
print("=" * 70)

bal = api_get("balance")
print(f"Balance: {bal['subscription']['generations']:.1f} gens")
print()

# ─── 預先編碼所有 skins（保持原始尺寸）──────────────────────
print("[PREP] Encoding skin references at ORIGINAL size...")
lady_b64   = img_b64(SKIN_LADY);    lady_w, lady_h   = get_wh(SKIN_LADY)
doppel_b64 = img_b64(SKIN_DOPPEL);  doppel_w, doppel_h = get_wh(SKIN_DOPPEL)
phantom_b64= img_b64(SKIN_PHANTOM); phantom_w, phantom_h= get_wh(SKIN_PHANTOM)
vamp_b64   = img_b64(SKIN_VAMPIRE); vamp_w, vamp_h   = get_wh(SKIN_VAMPIRE)
assn_b64   = img_b64(SKIN_ASSASSIN);assn_w, assn_h   = get_wh(SKIN_ASSASSIN)
mage_b64   = img_b64(SKIN_MAGE);    mage_w, mage_h   = get_wh(SKIN_MAGE)
summ_b64   = img_b64(SKIN_SUMMONER);summ_w, summ_h   = get_wh(SKIN_SUMMONER)
shan_b64   = img_b64(SKIN_SHAMAN);  shan_w, shan_h   = get_wh(SKIN_SHAMAN)

print(f"  Lady:    {lady_w}×{lady_h}")
print(f"  Doppel:  {doppel_w}×{doppel_h}")
print(f"  Phantom: {phantom_w}×{phantom_h}")
print(f"  Vampire: {vamp_w}×{vamp_h}")
print(f"  Assassin:{assn_w}×{assn_h}")
print(f"  Mage:    {mage_w}×{mage_h}")
print(f"  Summoner:{summ_w}×{summ_h}")
print(f"  Shaman:  {shan_w}×{shan_h}")

# 目標尺寸：與 Lady 相同 40×52（正方形改用 48×48）
TARGET_W, TARGET_H = lady_w, lady_h  # 40×52

async_jobs = {}

# ════════════════════════════════════════════════════════════════
# V13-A: generate-with-style-v2（5 skins 學畫風）
# ★ 正方形限制：必須用 48×48
# ★ 兩個版本：完全無 prompt vs 曖昧語句
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("V13-A: generate-with-style-v2 (5 skins → style learning)")
print("NOTE: MUST use square image_size!")
print("═"*60)

# A1: 無 prompt（讓模型完全依賴 style 學習）
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_b64),    "size": {"width": lady_w,    "height": lady_h}},
        {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
        {"image": b64_obj(phantom_b64), "size": {"width": phantom_w,  "height": phantom_h}},
        {"image": b64_obj(vamp_b64),    "size": {"width": vamp_w,    "height": vamp_h}},
        {"image": b64_obj(assn_b64),    "size": {"width": assn_w,    "height": assn_h}},
    ],
    "style_description": "2D side-scrolling pixel art game character sprite with black outline, clear pixel structure, DS game style",
    "description": "",  # ★ 完全無 prompt！
    "image_size": {"width": 48, "height": 48},  # 正方形
    "no_background": True,
})
if err: print(f"  A1 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A1 job: {jid[:12]}... (5 skins, NO PROMPT, 48×48 square)")
        async_jobs["A1_style5skins_noprompt_48x48"] = jid
    else:
        # 可能同步回傳
        save_best(r, "v13_A1_style5skins_noprompt")
time.sleep(2)

# A2: 曖昧語句 prompt
r, err = api_post("generate-with-style-v2", {
    "style_images": [
        {"image": b64_obj(lady_b64),    "size": {"width": lady_w,    "height": lady_h}},
        {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
        {"image": b64_obj(phantom_b64), "size": {"width": phantom_w,  "height": phantom_h}},
        {"image": b64_obj(vamp_b64),    "size": {"width": vamp_w,    "height": vamp_h}},
        {"image": b64_obj(assn_b64),    "size": {"width": assn_w,    "height": assn_h}},
        {"image": b64_obj(mage_b64),    "size": {"width": mage_w,    "height": mage_h}},
        {"image": b64_obj(summ_b64),    "size": {"width": summ_w,    "height": summ_h}},
        {"image": b64_obj(shan_b64),    "size": {"width": shan_w,    "height": shan_h}},
    ],
    "style_description": "DS game pixel sprite, standing character, black outline, clean flat colors",
    "description": "white haired vampire loli girl anime style",  # ★ 曖昧語句
    "image_size": {"width": 48, "height": 48},
    "no_background": True,
})
if err: print(f"  A2 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  A2 job: {jid[:12]}... (8 skins, '白髮吸血鬼蘿莉', 48×48)")
        async_jobs["A2_style8skins_vampire_48x48"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# V13-B: generate-image-v2 + 多 skin 作 style_image + reference
# ★ 可以用非正方形 40×52！style_image + reference_images
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("V13-B: generate-image-v2 + skin as style_image (40×52)")
print("═"*60)

# B1: Lady skin 作 style_image（複製所有風格），其他 skin 作 reference
r, err = api_post("generate-image-v2", {
    "description": "",  # ★ 無 prompt，全靠 skin 學習
    "image_size": {"width": TARGET_W, "height": TARGET_H},  # 40×52
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_b64),
        "size": {"width": lady_w, "height": lady_h},
    },
    "style_options": {
        "color_palette": True,
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {"image": b64_obj(doppel_b64),  "size": {"width": doppel_w,  "height": doppel_h}},
        {"image": b64_obj(phantom_b64), "size": {"width": phantom_w,  "height": phantom_h}},
        {"image": b64_obj(vamp_b64),    "size": {"width": vamp_w,    "height": vamp_h}},
    ],
})
if err: print(f"  B1 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  B1 job: {jid[:12]}... (Lady style + 3 skin refs, NO PROMPT, 40×52)")
        async_jobs["B1_genv2_lady_style_noprompt_40x52"] = jid
time.sleep(2)

# B2: 曖昧語句 + 更多 skin refs
r, err = api_post("generate-image-v2", {
    "description": "white haired vampire loli",
    "image_size": {"width": TARGET_W, "height": TARGET_H},
    "no_background": True,
    "style_image": {
        "image": b64_obj(phantom_b64),  # Phantom_of_White_Night 作為主風格
        "size": {"width": phantom_w, "height": phantom_h},
    },
    "style_options": {
        "color_palette": False,   # 不複製 Phantom 的配色（白紫色），只複製風格
        "outline": True,
        "detail": True,
        "shading": True,
    },
    "reference_images": [
        {"image": b64_obj(lady_b64),   "size": {"width": lady_w,   "height": lady_h}},
        {"image": b64_obj(assn_b64),   "size": {"width": assn_w,   "height": assn_h}},
        {"image": b64_obj(mage_b64),   "size": {"width": mage_w,   "height": mage_h}},
    ],
})
if err: print(f"  B2 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  B2 job: {jid[:12]}... (Phantom style, white vamp, 40×52)")
        async_jobs["B2_genv2_phantom_style_vamp_40x52"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# V13-C: image-to-pixelart-pro + Lady Skin
# 直接把 Lady skin 轉成更小 / 不同尺寸的版本（測試能否學習 skin 風格）
# ════════════════════════════════════════════════════════════════
print("\n" + "═"*60)
print("V13-C: image-to-pixelart-pro (skin as direct input)")
print("═"*60)

# C1: 直接把 Lady skin 餵給 img2px-pro（無 prompt）
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(lady_b64),
    "description": "",  # ★ 無 prompt
})
if err: print(f"  C1 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  C1 job: {jid[:12]}... (Lady skin → pixelart-pro, NO PROMPT)")
        async_jobs["C1_img2pxpro_ladyskin_noprompt"] = jid
    else:
        # 可能同步回傳
        b64 = r.get("image", {}).get("base64", "")
        if b64:
            save_png(b64, "v13_C1_img2pxpro_ladyskin_sync.png")
time.sleep(2)

# C2: Phantom skin → pixelart-pro（看它能否保持或改變角色設計）
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(phantom_b64),
    "description": "white haired girl pixel sprite",  # 輕量 prompt
})
if err: print(f"  C2 ERR: {err[:250]}")
else:
    jid = r.get("background_job_id", "")
    if jid:
        print(f"  C2 job: {jid[:12]}... (Phantom skin → pixelart-pro)")
        async_jobs["C2_img2pxpro_phantomskin"] = jid
time.sleep(2)

# ════════════════════════════════════════════════════════════════
# POLL ALL ASYNC JOBS
# ════════════════════════════════════════════════════════════════
print(f"\n{'═'*60}")
print(f"POLLING {len(async_jobs)} jobs (≤ 30 token budget)...")
print(f"{'═'*60}")

total_saved = 0
for prefix, job_id in async_jobs.items():
    print(f"\n[POLL] {prefix}")
    result = poll_job(job_id, max_wait=300)
    if result:
        n = save_best(result, f"v13_{prefix}", scale=8)
        total_saved += n
        if n == 0:
            print(f"  ⚠️ Result keys: {list(result.keys())[:5]}")
    time.sleep(1)

print("\n" + "=" * 70)
bal2 = api_get("balance")
used = bal['subscription']['generations'] - bal2['subscription']['generations']
print(f"V13 COMPLETE")
print(f"Balance: {bal2['subscription']['generations']:.1f} gens ({used:.1f} used)")
print(f"Total images saved: {total_saved}")

all_files = sorted([f.name for f in OUT_DIR.glob("v13_*.png") if "_8x" not in f.name])
print(f"Core images: {len(all_files)}")
for f in all_files:
    print(f"  {f}")
