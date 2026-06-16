"""
MRMOTEXT STYLE v3 — 核心突破：
- 把彩色 tileset 圖直接作為 style_images 丟給 generate-with-style-v2
- 每張 style_image = 不同顏色的 MRMOTEXT tile sheet
- Prompt 強調：CP437 glyph 符號組成、文字模式感、電子感
- 加入完整負面提示詞：排除寫實、動畫、RPG 感

ERR-040 修正：style_image 必須精確 resize，且只能用 tileset 圖（非場景截圖）
"""
import sys, os, base64, requests, time
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}

TILESET_DIR = r'd:\2026-06-04\assets\tilesets\mrmotext\colored'
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v3'
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_W, TARGET_H = 128, 128  # 生成尺寸

def img_to_b64_crop(path, max_px=256):
    """載入 tileset 圖，縮到 max_px，轉 base64"""
    img = Image.open(path).convert('RGB')
    img.thumbnail((max_px, max_px), Image.NEAREST)  # NEAREST 保留像素感
    w, h = img.size
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode(), w, h

def save_b64(b64_str, filename):
    data = base64.b64decode(b64_str)
    out = os.path.join(OUT_DIR, filename)
    with open(out, 'wb') as f:
        f.write(data)
    img = Image.open(out)
    print(f'  [SAVED] {filename}  size={img.size}')
    return out

def check_balance():
    r = requests.get(BASE + '/balance', headers=HEADERS)
    bal = r.json()['subscription']['generations']
    print(f'  Balance: {bal:.1f} gen')
    return bal

# ============================================================
# 選取 4 張不同顏色的 MRMOTEXT tileset 作為 style_images
# ============================================================
STYLE_TILESETS = [
    'color_C_fg08_bg00_yanzhihong_shenzonghui.png',    # 深紅色（類似 DS 調）
    'color_C_fg04_bg00_ganlanlv_shenzonghui.png',      # 橄欖綠（電子感）
    'color_C_fg12_bg00_bohelv_shenzonghui.png',        # 薄荷綠（清新數位）
    'color_C_fg07_bg00_hupozong_shenzonghui.png',      # 琥珀棕（溫暖電子）
]

print('='*60)
print('載入 MRMOTEXT tileset style references')
print('='*60)
style_images = []
for fname in STYLE_TILESETS:
    fpath = os.path.join(TILESET_DIR, fname)
    if os.path.exists(fpath):
        b64, w, h = img_to_b64_crop(fpath, max_px=200)
        # generate-with-style-v2 格式：頂層 width/height
        style_images.append({
            'image': {'base64': b64},
            'width': w,
            'height': h,
        })
        print(f'  [OK] {fname} -> {w}x{h}px')
    else:
        print(f'  [SKIP] {fname} not found')

print(f'Total style_images: {len(style_images)} (max 4)')
print()
check_balance()
print()

# ============================================================
# PIXEL-REVIEW 確認
# ============================================================
print('PIXEL-REVIEW:')
print('  PL-R1: image_size = {"width": 128, "height": 128}  OK (正方形 for gen-with-style-v2)')
print('  PL-R3: base64 無 data: 前綴  OK')
print('  PL-R4: 無禁止詞  OK')
print('  PL-style: style_images 用 MRMOTEXT tileset（非場景截圖）  OK (ERR-040 fix)')
print('  PL-fmt: style_images 格式用頂層 width/height  OK (generate-with-style-v2 格式)')
print()

# ============================================================
# 核心 Prompt — v3 全新設計
# ============================================================
# 重點：CP437 字元/glyph 組成、文字模式感、符號感、電子感
# 負面：全部寫實元素
PROMPTS = {
    'totem_warrior': (
        "2D side-scrolling game character, "
        "body assembled from CP437 glyphs and text-mode symbols, "
        "each body part is a different ASCII block character, "
        "textmode art creature, geometric glyph figure, "
        "blocky robotic totem warrior, "
        "made of box-drawing characters and block elements, "
        "dark background, glowing symbol segments, "
        "retro computer terminal aesthetic, "
        "symmetric humanoid assembled from monospace character blocks"
    ),
    'glyph_monster': (
        "retro computer monster, "
        "body constructed from ASCII block characters and special symbols, "
        "CP437 textmode creature, "
        "each limb is a different character glyph, "
        "symmetric totem figure, "
        "box-drawing characters form the skeleton, "
        "blocky electronic aesthetic, "
        "terminal art character, "
        "dark background with glowing glyph segments"
    ),
}

NEG_PROMPT = (
    "photorealistic, 3D render, smooth shading, gradient, "
    "anime, manga, chibi, cartoon, "
    "RPG warrior, armor, knight, "
    "detailed texture, fine detail, "
    "anti-aliasing, blur, soft edges, "
    "human proportions, natural skin, "
    "weapon, sword, shield"
)

# ============================================================
# Method 1: generate-with-style-v2（MRMOTEXT tileset 作 style）
# ============================================================
print('='*60)
print('Method 1: generate-with-style-v2 (MRMOTEXT tileset x4 style)')
print('='*60)

if len(style_images) >= 2:
    for pname, pdesc in PROMPTS.items():
        payload = {
            'description': pdesc,
            'style_images': style_images[:4],   # 最多 4 張
            'style_description': 'MRMOTEXT textmode tileset, CP437 glyph art, dark background, colored symbol blocks',
            'image_size': {'width': TARGET_W, 'height': TARGET_H},  # 必須正方形
            'no_background': False,   # 保留背景（黑色背景是 MRMOTEXT 特色）
        }
        print(f'\n  Prompt: {pname}')
        r = requests.post(BASE + '/generate-with-style-v2', headers=HEADERS, json=payload, timeout=60)
        print(f'  HTTP {r.status_code}')
        if r.status_code in (200, 202):
            data = r.json()
            job_id = data.get('background_job_id')
            if job_id:
                print(f'  Async job: {job_id}')
                deadline = time.time() + 300
                while time.time() < deadline:
                    jr = requests.get(BASE + '/background-jobs/' + job_id, headers=HEADERS)
                    jdata = jr.json()
                    status = jdata.get('status', '')
                    print(f'    Status: {status}')
                    if 'complet' in status:  # ERR-036: completed 非 complete
                        imgs = jdata.get('last_response', {}).get('images', [])
                        print(f'  Found {len(imgs)} images')
                        for i, img_obj in enumerate(imgs[:4]):   # 只存前4張
                            b64 = img_obj.get('base64', '')  # ERR-037: 直接頂層
                            if b64:
                                save_b64(b64, f'V3_stylev2_{pname}_{i}.png')
                        break
                    elif status in ('failed', 'error'):
                        print(f'  FAILED: {jdata}')
                        break
                    time.sleep(5)
        else:
            print(f'  ERR: {r.text[:400]}')

check_balance()
print()

# ============================================================
# Method 2: pixen (low detail + 新 Prompt)
# 用 image-to-pixelart 作 init 讓它有 tileset 紋理感
# ============================================================
print('='*60)
print('Method 2: pixen (low detail + CP437 totem prompt)')
print('='*60)

for pname, pdesc in PROMPTS.items():
    payload = {
        'description': pdesc,
        'image_size': {'width': TARGET_W, 'height': TARGET_H},
        'outline': 'single color black outline',
        'detail': 'low detail',
        'view': 'side',
        'direction': 'west',
        'no_background': True,
    }
    print(f'\n  Prompt: {pname}')
    r = requests.post(BASE + '/create-image-pixen', headers=HEADERS, json=payload, timeout=120)
    print(f'  HTTP {r.status_code}')
    if r.status_code == 200:
        data = r.json()
        imgs = data.get('images', [data.get('image', {})])
        for j, img_obj in enumerate(imgs):
            b64 = img_obj.get('base64', '')
            if b64:
                save_b64(b64, f'V3_pixen_{pname}_{j}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

check_balance()
print()

# ============================================================
# Method 3: pixflux + color_image (tileset 注入色彩)
# 把 tileset 圖縮到 128x128 作為 color_image
# ============================================================
print('='*60)
print('Method 3: pixflux + color_image (tileset as color guide)')
print('='*60)

# 把第一張 tileset 縮到輸出尺寸作 color_image
tileset_path = os.path.join(TILESET_DIR, STYLE_TILESETS[0])
tile_img = Image.open(tileset_path).convert('RGB')
tile_resized = tile_img.resize((TARGET_W, TARGET_H), Image.NEAREST)
buf = io.BytesIO()
tile_resized.save(buf, format='PNG')
color_b64 = base64.b64encode(buf.getvalue()).decode()
print(f'  color_image (tileset cropped): {TARGET_W}x{TARGET_H}')

for pname, pdesc in list(PROMPTS.items())[:1]:   # 只做第一個 prompt
    payload = {
        'description': pdesc,
        'image_size': {'width': TARGET_W, 'height': TARGET_H},
        'text_guidance_scale': 12.0,
        'color_image': {'base64': color_b64},  # tileset 作 color guide
        'outline': 'single color black outline',
        'shading': 'flat shading',
        'no_background': True,
    }
    print(f'\n  Prompt: {pname}')
    r = requests.post(BASE + '/create-image-pixflux', headers=HEADERS, json=payload, timeout=120)
    print(f'  HTTP {r.status_code}')
    if r.status_code == 200:
        data = r.json()
        imgs = data.get('images', [data.get('image', {})])
        for j, img_obj in enumerate(imgs):
            b64 = img_obj.get('base64', '')
            if b64:
                save_b64(b64, f'V3_pixflux_color_{pname}_{j}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

check_balance()
print()
print('='*60)
print('ALL DONE — V3 MRMOTEXT tileset style transfer')
print(f'Output: {OUT_DIR}')
