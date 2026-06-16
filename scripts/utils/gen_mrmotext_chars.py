"""
MRMOTEXT 風格角色生成腳本
Method A: 純文字提示詞（pixflux + pixen）
Method B: MRMOTEXT 範例圖作為 style reference（generate-with-style-v2 + bitforge）
"""
import sys, os, base64, json, time, requests
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_style'
os.makedirs(OUT_DIR, exist_ok=True)

def img_to_b64(path, max_px=256):
    img = Image.open(path).convert('RGBA')
    img.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode(), img.size

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
        print(f'  ERROR: {r.text[:500]}')
        return None
    return r.json()

def check_balance():
    r = requests.get(f'{BASE}/balance', headers=HEADERS)
    data = r.json()
    gen = data['subscription']['generations']
    print(f'  Balance: {gen:.1f} gen')
    return gen

# ─────────────────────────────────────────────────────────
# MRMOTEXT 風格核心提示詞（Designer 定義）
# 核心特徵：
#   - 1-bit textmode 風格，8×8 tile 積木拼接
#   - 幾何方塊感，圖騰/古典像素風格
#   - 純兩色 (dark background + accent foreground)
#   - 2D 橫向捲軸 side view
# ─────────────────────────────────────────────────────────

PROMPT_A1 = (
    "1-bit textmode pixel art character, assembled from 8x8 tile grid blocks, "
    "totem-pole aesthetic, geometric blocky form, ASCII art style humanoid creature, "
    "side view for 2D side-scrolling game, dark charcoal background (#363232), "
    "bright accent foreground color, no anti-aliasing, hard pixel edges, "
    "roguelike creature design, retro BBS terminal art, "
    "bold geometric silhouette, modular tile construction visible"
)

PROMPT_A2 = (
    "textmode 1-bit ASCII art game character sprite, side-scrolling 2D view, "
    "constructed from square pixel tile blocks like MRMOTEXT tileset, "
    "totem figure style with stacked geometric sections, "
    "dark background with high-contrast foreground tiles, "
    "retro DOS/IBM PC BIOS aesthetic, roguelike pixel creature, "
    "bold blocky proportions, 8-pixel grid snapping visible, no gradients"
)

PROMPT_B1 = (
    "2D side-scrolling game character in MRMOTEXT textmode tileset style, "
    "assembled from 8x8 pixel tiles like ASCII art building blocks, "
    "totem-like geometric figure, dark dungeon background, "
    "bold two-color pixel art: dark charcoal ground with bright foreground tiles, "
    "retro terminal textmode creature, 1-bit roguelike sprite, "
    "side view orientation, hard pixel edges, no sub-pixel blending"
)

print('='*60)
print('MRMOTEXT Character Generation')
print('='*60)
print()
check_balance()
print()

# ─────────────────────────────────────────────────────────
# METHOD A-1: create-image-pixflux（純提示詞，0.5gen）
# ─────────────────────────────────────────────────────────
print('[A-1] pixflux - pure text prompt (0.5 gen)')
payload_a1 = {
    "description": PROMPT_A1,
    "image_size": {"width": 128, "height": 128},
    "no_background": True,
    "text_guidance_scale": 8.0
}
r1 = post('create-image-pixflux', payload_a1)
if r1:
    try:
        b64 = r1['image']['base64']
        save_b64(b64, 'A1_pixflux_pure_prompt.png')
    except Exception as e:
        print(f'  Parse error: {e}, keys: {list(r1.keys())}')
        print(f'  Full response: {json.dumps(r1)[:300]}')
print()

# ─────────────────────────────────────────────────────────
# METHOD A-2: create-image-pixflux variant（不同提示詞，0.5gen）
# ─────────────────────────────────────────────────────────
print('[A-2] pixflux - totem warrior (0.5 gen)')
payload_a2 = {
    "description": PROMPT_A2,
    "image_size": {"width": 128, "height": 128},
    "no_background": True,
    "text_guidance_scale": 9.0
}
r2 = post('create-image-pixflux', payload_a2)
if r2:
    try:
        b64 = r2['image']['base64']
        save_b64(b64, 'A2_pixflux_totem_warrior.png')
    except Exception as e:
        print(f'  Parse error: {e}')
        print(f'  Keys: {list(r2.keys())}')
        print(f'  Response: {json.dumps(r2)[:400]}')
print()

# ─────────────────────────────────────────────────────────
# METHOD A-3: create-image-pixen（精細控制，1gen）
# ─────────────────────────────────────────────────────────
print('[A-3] pixen - precise control (1.0 gen)')
payload_a3 = {
    "description": PROMPT_B1,
    "image_size": {"width": 128, "height": 128},
    "outline": "selective outline",
    "detail": "low detail",
    "view": "side",
    "direction": "left",
    "no_background": True
}
r3 = post('create-image-pixen', payload_a3)
if r3:
    try:
        b64 = r3['image']['base64']
        save_b64(b64, 'A3_pixen_side_view.png')
    except Exception as e:
        print(f'  Parse error: {e}')
        print(f'  Keys: {list(r3.keys())}')
        print(f'  Response: {json.dumps(r3)[:400]}')
print()

print('[A done] Method A (text-only) complete')
check_balance()
print()
print('Proceeding to Method B (image reference)...')
