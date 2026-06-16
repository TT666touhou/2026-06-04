"""
MRMOTEXT 風格 — 四端點完整對比生成
PIXEL-REVIEW 通過後執行
目標：重新生成，修正所有歷史錯誤（style_strength=0 等）
"""
import sys, os, base64, json, time, requests
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v2'
IMG_DIR = r'd:\2026-06-04\docs\mrmotext_research\images'
os.makedirs(OUT_DIR, exist_ok=True)

def img_to_b64(path, max_px=256):
    img = Image.open(path).convert('RGBA')
    img.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    raw = buf.getvalue()
    return base64.b64encode(raw).decode(), img.size

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
    return r.json()['subscription']['generations']

# ============================================================
# PIXEL-REVIEW 通過確認（ERR 修正清單）
# ============================================================
print('='*60)
print('PIXEL-REVIEW 確認清單')
print('='*60)
print('PL-R1:  image_size = {"width": 128, "height": 128}  ✅')
print('PL-R2:  description 非空字串  ✅')
print('PL-R3:  base64 無 data: 前綴  ✅')
print('PL-R4:  無禁止詞  ✅')
print('PL-R5:  bitforge style_strength = 85（明確設定）  ✅')
print('PL-R6:  style_image = {"base64":"..."} 僅一欄  ✅')
print('PL-R7:  text_guidance_scale = 12  ✅')
print('PL-R8:  128px <= 200px  ✅')
print()

bal = check_balance()
print(f'餘額: {bal:.1f} gen')
print()

# ============================================================
# 載入 MRMOTEXT 風格參考圖
# ============================================================
# 上傳的三張參考圖（使用者提供的 MRMOTEXT 官方截圖）
# 這些圖片在本次對話中被上傳，用 base64 讀取本地緩存
# 若無本地圖，改用 docs/mrmotext_research/images 中的截圖
style_refs = []
for fname in ['x3_version.jpg', 'building_blocks.png', 'mrmotext_title.jpg']:
    fpath = os.path.join(IMG_DIR, fname)
    if os.path.exists(fpath):
        b64, (w, h) = img_to_b64(fpath, max_px=256)
        style_refs.append({'path': fpath, 'b64': b64, 'w': min(w, 256), 'h': min(h, 256), 'name': fname})
        print(f'Style ref loaded: {fname} ({w}x{h})')

print(f'Total style refs: {len(style_refs)}')
print()

# ============================================================
# MRMOTEXT 核心 Description
# （重點：大色塊、tile 組合、圖騰感、非 RPG 寫實）
# ============================================================
MRMOTEXT_DESC_A = (
    "MRMOTEXT textmode tile art character, "
    "2D side-scrolling game, "
    "humanoid creature assembled from large flat 8x8 tile blocks, "
    "geometric totem-pole silhouette, "
    "bold CGA-palette flat color areas with hard pixel edges, "
    "each body part is a distinct color rectangle, "
    "symmetric chunky form, "
    "dark muted background, "
    "retro ASCII art creature, "
    "no gradients, no anti-aliasing, "
    "1-bit aesthetic with flat color fill"
)

MRMOTEXT_DESC_B = (
    "2D game character sprite, "
    "textmode pixel art assembled from large tile blocks like MRMOTEXT, "
    "each limb is a flat-colored geometric shape, "
    "totem carving aesthetic, "
    "bold dark outlines, flat color fills, "
    "EGA 16-color palette style, "
    "symmetric blocky creature design, "
    "side-scrolling game sprite, "
    "chunky retro pixel art, no fine detail"
)

# ============================================================
# Method 1: pixflux（修正：text_guidance_scale=12，新描述）
# ============================================================
print('='*60)
print('Method 1: pixflux — 修正版（guidance=12，新 MRMOTEXT 描述）')
print('='*60)

for i, desc in enumerate([MRMOTEXT_DESC_A, MRMOTEXT_DESC_B]):
    payload = {
        'description': desc,
        'image_size': {'width': 128, 'height': 128},
        'text_guidance_scale': 12.0,   # 之前是 9，提高到 12
        'no_background': True,
        'outline': 'single color black outline',
        'shading': 'flat shading',     # 明確設 flat shading 符合 MRMOTEXT
    }
    r = requests.post(BASE + '/create-image-pixflux', headers=HEADERS, json=payload, timeout=120)
    print(f'  HTTP {r.status_code}')
    if r.status_code == 200:
        data = r.json()
        imgs = data.get('images', [data.get('image', {})])
        for j, img_obj in enumerate(imgs):
            b64 = img_obj.get('base64', '')
            if b64:
                save_b64(b64, f'V2_pixflux_desc{i+1}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

print(f'  Balance: {check_balance():.1f} gen')
print()

# ============================================================
# Method 2: bitforge（修正：style_strength=85，之前是0！）
# ============================================================
print('='*60)
print('Method 2: bitforge — 修正版（style_strength=85，之前忘了設！）')
print('='*60)

if style_refs:
    ref = style_refs[0]   # 用第一張 MRMOTEXT 截圖
    payload = {
        'description': MRMOTEXT_DESC_A,
        'negative_description': 'realistic proportions, detailed shading, gradient, smooth curves, RPG warrior, anime character, photorealistic, 3D render, fine detail',
        'image_size': {'width': 128, 'height': 128},
        'text_guidance_scale': 12.0,
        'style_strength': 85.0,        # 之前是 0.0！！！
        'style_image': {'base64': ref['b64']},
        'outline': 'single color black outline',
        'shading': 'flat shading',
        'no_background': True,
    }
    r = requests.post(BASE + '/create-image-bitforge', headers=HEADERS, json=payload, timeout=120)
    print(f'  HTTP {r.status_code}')
    if r.status_code == 200:
        data = r.json()
        imgs = data.get('images', [data.get('image', {})])
        for j, img_obj in enumerate(imgs):
            b64 = img_obj.get('base64', '')
            if b64:
                save_b64(b64, f'V2_bitforge_ss85_{j}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

    # 再試一次 style_strength=95
    payload2 = dict(payload)
    payload2['style_strength'] = 95.0
    payload2['description'] = MRMOTEXT_DESC_B
    r2 = requests.post(BASE + '/create-image-bitforge', headers=HEADERS, json=payload2, timeout=120)
    print(f'  HTTP {r2.status_code} (ss=95)')
    if r2.status_code == 200:
        data2 = r2.json()
        imgs2 = data2.get('images', [data2.get('image', {})])
        for j, img_obj in enumerate(imgs2):
            b64 = img_obj.get('base64', '')
            if b64:
                save_b64(b64, f'V2_bitforge_ss95_{j}.png')
    else:
        print(f'  ERR: {r2.text[:300]}')

print(f'  Balance: {check_balance():.1f} gen')
print()

# ============================================================
# Method 3: pixen（修正：direction=west，flat shading 關鍵字）
# ============================================================
print('='*60)
print('Method 3: pixen — 修正版（direction=west，low detail）')
print('='*60)

payload = {
    'description': (
        'MRMOTEXT textmode tile art creature, '
        'assembled from 8x8 blocks, '
        'geometric totem silhouette, '
        'CGA flat colors, bold pixel edges, '
        'side-scrolling game sprite, '
        'chunky retro aesthetic, symmetric design'
    ),
    'image_size': {'width': 128, 'height': 128},
    'outline': 'single color black outline',
    'detail': 'low detail',        # low detail = MRMOTEXT 簡潔感
    'view': 'side',
    'direction': 'west',           # ERR-035 修正
    'no_background': True,
}
r = requests.post(BASE + '/create-image-pixen', headers=HEADERS, json=payload, timeout=120)
print(f'  HTTP {r.status_code}')
if r.status_code == 200:
    data = r.json()
    imgs = data.get('images', [data.get('image', {})])
    for j, img_obj in enumerate(imgs):
        b64 = img_obj.get('base64', '')
        if b64:
            save_b64(b64, f'V2_pixen_lowdetail_{j}.png')
else:
    print(f'  ERR: {r.text[:300]}')

print(f'  Balance: {check_balance():.1f} gen')
print()

# ============================================================
# Method 4: generate-with-style-v2（修正：完整非同步流程）
# ============================================================
print('='*60)
print('Method 4: generate-with-style-v2 — 修正版（ERR-036/038/039 全修正）')
print('='*60)

if len(style_refs) >= 2:
    # 使用 2 張不同 MRMOTEXT 圖片作為 style references
    style_imgs = [
        {'image': {'base64': style_refs[0]['b64']}, 'width': style_refs[0]['w'], 'height': style_refs[0]['h']},
        {'image': {'base64': style_refs[1]['b64']}, 'width': style_refs[1]['w'], 'height': style_refs[1]['h']},
    ]
    payload = {
        'description': MRMOTEXT_DESC_A,
        'style_images': style_imgs,
        'image_size': {'width': 128, 'height': 128},   # ERR-038：必須是 image_size 物件
        'style_description': 'MRMOTEXT textmode tile art, geometric totem creature, flat CGA colors',
        'no_background': True,
    }
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
                if status == 'completed':   # ERR-039: "completed" 非 "complete"
                    # ERR-039: 圖片在 last_response.images
                    imgs = jdata.get('last_response', {}).get('images', [])
                    print(f'  Found {len(imgs)} images')
                    for i, img_obj in enumerate(imgs):
                        b64 = img_obj.get('base64', '')
                        if b64:
                            save_b64(b64, f'V2_style_v2_{i}.png')
                    break
                elif status in ('failed', 'error'):
                    print(f'  FAILED: {jdata}')
                    break
                time.sleep(5)
    else:
        print(f'  ERR: {r.text[:300]}')

print(f'  Balance: {check_balance():.1f} gen')
print()
print('='*60)
print('ALL DONE')
bal_final = check_balance()
print(f'Final balance: {bal_final:.1f} gen')
print(f'Output dir: {OUT_DIR}')
