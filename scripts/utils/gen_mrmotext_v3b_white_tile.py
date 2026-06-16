"""
MRMOTEXT STYLE v3b — 用戶確認版：
- 白色單色，透明背景
- 強調 8x8 tile 拼接感
- 形狀優先（silhouette-first）
- MRMOTEXT tileset 本身作為 style_images

generate-with-style-v2: 4 tileset style + 白色描述
pixen: low detail + 白色 + no background
"""
import sys, os, base64, requests, time
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}

TILESET_DIR = r'd:\2026-06-04\assets\tilesets\mrmotext\colored'
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v3b'
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_W, TARGET_H = 128, 128

def img_to_b64(path, max_px=200):
    img = Image.open(path).convert('RGB')
    img.thumbnail((max_px, max_px), Image.NEAREST)
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

# 黑白 tileset 作為主要 style_image（最接近形狀優先）
BW_TILESET = r'd:\2026-06-04\assets\tilesets\mrmotext\MRMOTEXT_EX.png'
BW_X3 = r'd:\2026-06-04\assets\tilesets\mrmotext\MRMOTEXT_EX_x3.png'

STYLE_TILESETS = [
    'color_C_fg33_bg00_jingbai_shenzonghui.png',   # 晶白色（最接近單色）
    'color_C_fg22_bg00_zhonghui_shenzonghui.png',  # 中灰色
    'color_C_fg29_bg00_yinhui_shenzonghui.png',    # 銀灰色
]

print('='*60)
print('V3b: 白色形狀優先 — MRMOTEXT tile 拼接感')
print('='*60)

# 載入 style_images (白色+灰色 tileset)
style_images = []
# 先用黑白原版 tileset（最代表 MRMOTEXT 形狀感）
for fpath, name in [
    (BW_TILESET, 'MRMOTEXT_EX.png'),
    (BW_X3, 'MRMOTEXT_EX_x3.png'),
]:
    if os.path.exists(fpath):
        b64, w, h = img_to_b64(fpath, max_px=200)
        style_images.append({'image': {'base64': b64}, 'width': w, 'height': h})
        print(f'  [BW] {name} -> {w}x{h}')

# 再加最淺色的 tileset
for fname in STYLE_TILESETS[:2]:
    fpath = os.path.join(TILESET_DIR, fname)
    if os.path.exists(fpath):
        b64, w, h = img_to_b64(fpath, max_px=200)
        style_images.append({'image': {'base64': b64}, 'width': w, 'height': h})
        print(f'  [LIGHT] {fname} -> {w}x{h}')

print(f'Total style_images: {len(style_images)}')
print()
check_balance()
print()

# ============================================================
# 白色形狀優先 Prompt（用戶確認版）
# ============================================================
PROMPTS = {
    'white_totem': (
        "white monochrome 2D game character sprite, "
        "assembled from 8x8 pixel tile blocks like MRMOTEXT textmode art, "
        "each body segment is a different glyph tile, "
        "CP437 character block figure, "
        "bold silhouette shape, totem pole proportions, "
        "flat white filled blocks on transparent background, "
        "crisp pixel edges, grid-aligned block construction, "
        "symmetric tile-assembled creature, "
        "text-mode computer art style, "
        "1-bit white silhouette assembled from symbol tiles"
    ),
    'white_glyph_figure': (
        "single-color white pixel sprite, "
        "character body constructed from 8x8 tile glyphs, "
        "textmode ASCII art figure, "
        "bold chunky white blocks form head body arms legs, "
        "MRMOTEXT style tile assembly, "
        "monochrome glyph creature, "
        "each limb is a distinct tile symbol shape, "
        "crisp hard pixel edges, transparent background, "
        "retro terminal character sprite, "
        "shape-first design with glyph tile composition"
    ),
}

# ============================================================
# Method 1: generate-with-style-v2 + MRMOTEXT BW tileset style
# ============================================================
print('='*60)
print('Method 1: generate-with-style-v2 (BW tileset style, white output)')
print('='*60)

if len(style_images) >= 2:
    for pname, pdesc in PROMPTS.items():
        payload = {
            'description': pdesc,
            'style_images': style_images[:4],
            'style_description': 'MRMOTEXT textmode tileset, black and white glyphs on dark background, 8x8 pixel tile characters, CP437 symbol art',
            'image_size': {'width': TARGET_W, 'height': TARGET_H},
            'no_background': False,   # style-v2 不支援 no_background，需後處理
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
                    if 'complet' in status:
                        imgs = jdata.get('last_response', {}).get('images', [])
                        print(f'  Found {len(imgs)} images')
                        for i, img_obj in enumerate(imgs[:4]):
                            b64 = img_obj.get('base64', '')  # ERR-037 fix: top-level
                            if b64:
                                fname = f'V3b_stylev2_{pname}_{i}.png'
                                save_b64(b64, fname)
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
# Method 2: pixen (low detail + 白色形狀)
# ============================================================
print('='*60)
print('Method 2: pixen (low detail + white + transparent BG)')
print('='*60)

for pname, pdesc in PROMPTS.items():
    payload = {
        'description': pdesc,
        'image_size': {'width': TARGET_W, 'height': TARGET_H},
        'outline': 'single color black outline',
        'detail': 'low detail',
        'view': 'side',
        'direction': 'west',
        'no_background': True,   # 透明背景
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
                save_b64(b64, f'V3b_pixen_{pname}_{j}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

check_balance()
print()

# ============================================================
# Method 3: create-character-v3 (structured character + white)
# 測試 v3 對「tile 組合」的理解能力
# ============================================================
print('='*60)
print('Method 3: create-character-v3 (frontal, white tile figure)')
print('='*60)

v3_payload = {
    'description': (
        "white monochrome character, "
        "body assembled from 8x8 tile blocks, "
        "MRMOTEXT textmode style, "
        "glyph creature, tile-assembled figure, "
        "bold pixel silhouette, symmetric design, "
        "flat shading, facing left"  # ERR-041: shading/direction 用文字描述！
    ),
    'image_size': {'width': TARGET_W, 'height': TARGET_H},
    'outline': 'single color black outline',
    # ERR-041 FIX: 移除 'shading' 和 'direction'（不被 create-character-v3 支援 → HTTP 422）
    # 'shading': 'flat shading',    ← FORBIDDEN
    # 'direction': 'west',          ← FORBIDDEN (只支援 view，非 direction)
    'view': 'side',                 # view 合法（非 direction）
    'no_background': True,
}
r = requests.post(BASE + '/create-character-v3', headers=HEADERS, json=v3_payload, timeout=60)
print(f'  HTTP {r.status_code}')
if r.status_code == 200:
    data = r.json()
    char_id = data.get('character_id', data.get('id', ''))
    frames = data.get('frames', [])
    print(f'  char_id: {char_id}, frames: {len(frames)}')
    if char_id:
        # Poll for completion
        deadline = time.time() + 120
        while time.time() < deadline:
            cr = requests.get(f'{BASE}/characters/{char_id}', headers=HEADERS)
            cdata = cr.json()
            status = cdata.get('status', '')
            print(f'    Status: {status}')
            if 'complet' in status or cdata.get('frames'):
                frames = cdata.get('frames', [])
                for i, frame in enumerate(frames[:2]):
                    b64 = frame.get('image', {}).get('base64', '')
                    if b64:
                        save_b64(b64, f'V3b_charv3_{i}.png')
                break
            elif status in ('failed', 'error'):
                print(f'  FAILED: {cdata}')
                break
            time.sleep(5)
    elif data.get('image'):
        b64 = data['image'].get('base64', '')
        if b64:
            save_b64(b64, 'V3b_charv3_0.png')
elif r.status_code != 200:
    print(f'  ERR: {r.text[:300]}')

check_balance()
print()
print('='*60)
print('ALL DONE — V3b White tile character')
print(f'Output: {OUT_DIR}')
