"""
MRMOTEXT 風格 Method B 修正版
- ERR-036 fix: generate-with-style-v2 style_images 格式：{"image": {"base64": "..."}, "width": W, "height": H}
- ERR-037 fix: create-image-bitforge style_image 格式：{"base64": "..."} (無 width/height!)
"""
import sys, os, base64, json, time, requests
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_style'
IMG_DIR = r'd:\2026-06-04\docs\mrmotext_research\images'
os.makedirs(OUT_DIR, exist_ok=True)

def img_to_b64(path, max_px=256):
    img = Image.open(path).convert('RGBA')
    img.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode()
    return b64, img.size

def img_resize_b64(path, w, h):
    """Resize to exact w,h and encode as base64"""
    img = Image.open(path).convert('RGBA')
    img = img.resize((w, h), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()

def save_b64(b64_str, filename):
    data = base64.b64decode(b64_str)
    out = os.path.join(OUT_DIR, filename)
    with open(out, 'wb') as f:
        f.write(data)
    img = Image.open(out)
    print(f'  Saved: {filename}  size={img.size}')
    return out

def post(endpoint, payload):
    r = requests.post(f'{BASE}/{endpoint}', headers=HEADERS, json=payload, timeout=120)
    print(f'  POST /{endpoint}: HTTP {r.status_code}')
    if r.status_code not in (200, 201):
        print(f'  ERROR body: {r.text[:600]}')
        return None
    return r.json()

def check_balance():
    r = requests.get(f'{BASE}/balance', headers=HEADERS)
    gen = r.json()['subscription']['generations']
    print(f'  Balance: {gen:.1f} gen')
    return gen

print('='*60)
print('MRMOTEXT Method B - FIXED Version')
print('='*60)
check_balance()
print()

W, H = 128, 128

# ─────────────────────────────────────────────────────────
# METHOD B-1: generate-with-style-v2 (FIXED)
# 正確格式：{"image": {"base64": "..."}, "width": W, "height": H}
# ─────────────────────────────────────────────────────────
print('[B-1 FIXED] generate-with-style-v2 with correct style_images format (~5 gen)')

# 使用 x3 game scene + building_blocks 作為 style references
style_imgs = []
for img_path, name in [
    (os.path.join(IMG_DIR, 'x3_version.jpg'), 'x3_game_scene'),
    (os.path.join(IMG_DIR, 'building_blocks.png'), 'building_blocks'),
]:
    if os.path.exists(img_path):
        b64, (iw, ih) = img_to_b64(img_path, max_px=256)
        # 確保 width/height 都 <= 512
        iw = min(iw, 512)
        ih = min(ih, 512)
        style_imgs.append({
            "image": {"base64": b64},   # ✅ 正確：image 是嵌套物件
            "width": iw,
            "height": ih
        })
        print(f'  Style ref {name}: {iw}x{ih}')

if len(style_imgs) > 4:
    style_imgs = style_imgs[:4]  # max 4 style_images

payload_b1 = {
    "description": (
        "2D side-scrolling game character in MRMOTEXT textmode tile style, "
        "assembled from 8x8 pixel tile blocks, totem-like geometric humanoid figure, "
        "side view orientation, 1-bit color aesthetic, bold blocky proportions, "
        "retro ASCII art roguelike creature, dark charcoal background, high contrast"
    ),
    "style_images": style_imgs,
    "width": W,
    "height": H,
    "no_background": True
}
r_b1 = post('generate-with-style-v2', payload_b1)
if r_b1:
    print(f'  Response keys: {list(r_b1.keys())}')
    images = r_b1.get('images', [])
    if images:
        for i, img_obj in enumerate(images):
            if 'base64' in img_obj:
                save_b64(img_obj['base64'], f'B1_style_v2_{i}.png')
    elif 'image' in r_b1:
        save_b64(r_b1['image']['base64'], 'B1_style_v2_0.png')
    else:
        # Check for async job
        job_id = r_b1.get('background_job_id') or r_b1.get('job_id')
        if job_id:
            print(f'  Async job: {job_id}')
            deadline = time.time() + 300
            while time.time() < deadline:
                jr = requests.get(f'{BASE}/background-jobs/{job_id}', headers=HEADERS)
                jdata = jr.json()
                status = jdata.get('status', 'unknown')
                print(f'    Status: {status}')
                if status == 'complete':
                    imgs = (jdata.get('result') or {}).get('images', jdata.get('images', []))
                    for i, img_obj in enumerate(imgs):
                        if 'base64' in img_obj:
                            save_b64(img_obj['base64'], f'B1_style_v2_job_{i}.png')
                    break
                elif status in ('failed', 'error'):
                    print(f'  Job failed: {jdata}')
                    break
                time.sleep(5)
        else:
            print(f'  Unknown response: {json.dumps(r_b1)[:400]}')
print()
check_balance()
print()

# ─────────────────────────────────────────────────────────
# METHOD B-2: create-image-bitforge (FIXED)
# 正確格式：style_image = {"base64": "..."} (不帶 width/height!)
# ─────────────────────────────────────────────────────────
print('[B-2 FIXED] create-image-bitforge with correct style_image format (~2 gen)')

# 使用 building_blocks.png 作為 style (128x128 縮放)
bb_path = os.path.join(IMG_DIR, 'building_blocks.png')
if os.path.exists(bb_path):
    b64_bb = img_resize_b64(bb_path, W, H)
    payload_b2 = {
        "description": (
            "2D side-scrolling pixel art character in MRMOTEXT 1-bit textmode tile style, "
            "assembled from geometric 8x8 pixel blocks, totem figure side view, "
            "bold contrast, dark background, ASCII roguelike sprite, no gradients, "
            "hard pixel edges, retro terminal aesthetic"
        ),
        "style_image": {"base64": b64_bb},   # ✅ 正確：直接 Base64Image，不帶 width/height
        "image_size": {"width": W, "height": H},
        "no_background": True
    }
    r_b2 = post('create-image-bitforge', payload_b2)
    if r_b2:
        print(f'  Response keys: {list(r_b2.keys())}')
        if 'image' in r_b2:
            save_b64(r_b2['image']['base64'], 'B2_bitforge_style_FIXED.png')
        elif 'images' in r_b2:
            for i, img_obj in enumerate(r_b2['images']):
                save_b64(img_obj['base64'], f'B2_bitforge_style_{i}.png')
        else:
            print(f'  Response: {json.dumps(r_b2)[:400]}')
else:
    print(f'  MISSING: {bb_path}')
print()

# ─────────────────────────────────────────────────────────
# METHOD B-3: create-image-bitforge with MRMOTEXT_EX tileset (FIXED)
# ─────────────────────────────────────────────────────────
print('[B-3 FIXED] create-image-bitforge - MRMOTEXT_EX.png as style ref (~2 gen)')

ex_path = r'd:\2026-06-04\assets\tilesets\mrmotext\MRMOTEXT_EX.png'
if os.path.exists(ex_path):
    b64_ex = img_resize_b64(ex_path, W, H)
    payload_b3 = {
        "description": (
            "2D side-scrolling character assembled from MRMOTEXT 1-bit pixel tiles, "
            "totem aesthetic, geometric blocky humanoid figure facing left, "
            "textmode style with hard 8-pixel grid edges, dark charcoal background, "
            "bright foreground tiles, ASCII art roguelike sprite, side view"
        ),
        "style_image": {"base64": b64_ex},   # ✅ 正確格式
        "image_size": {"width": W, "height": H},
        "no_background": True
    }
    r_b3 = post('create-image-bitforge', payload_b3)
    if r_b3:
        print(f'  Response keys: {list(r_b3.keys())}')
        if 'image' in r_b3:
            save_b64(r_b3['image']['base64'], 'B3_bitforge_tileset_FIXED.png')
        elif 'images' in r_b3:
            for i, img_obj in enumerate(r_b3['images']):
                save_b64(img_obj['base64'], f'B3_bitforge_tileset_{i}.png')
        else:
            print(f'  Response: {json.dumps(r_b3)[:400]}')
else:
    print(f'  MISSING: {ex_path}')

print()
print('='*60)
print('METHOD B FIXED COMPLETE')
check_balance()
print('='*60)
