"""
bitforge 修正版 — ERR-040: style_image 必須 resize 到與 image_size 相同尺寸
"""
import sys, os, base64, requests
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v2'
IMG_DIR = r'd:\2026-06-04\docs\mrmotext_research\images'

TARGET_W, TARGET_H = 128, 128  # 輸出尺寸

def img_to_b64_exact(path, w, h):
    """ERR-040 修正：style_image 必須 resize 到與 output 完全相同的尺寸"""
    img = Image.open(path).convert('RGBA')
    img = img.resize((w, h), Image.LANCZOS)  # 強制 resize 到 exact 尺寸
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()

def save_b64(b64_str, filename):
    data = base64.b64decode(b64_str)
    out = os.path.join(OUT_DIR, filename)
    with open(out, 'wb') as f:
        f.write(data)
    img = Image.open(out)
    print(f'  [SAVED] {filename}  size={img.size}')
    return out

print('ERR-040 fix: style_image must be EXACTLY same size as image_size')
print(f'Resizing style ref to {TARGET_W}x{TARGET_H}')

style_ref_path = os.path.join(IMG_DIR, 'x3_version.jpg')
style_b64 = img_to_b64_exact(style_ref_path, TARGET_W, TARGET_H)
print(f'  Style image resized to {TARGET_W}x{TARGET_H}')

MRMOTEXT_DESC = (
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

NEG_DESC = (
    "realistic proportions, detailed shading, gradient, smooth curves, "
    "RPG warrior, anime character, photorealistic, 3D render, "
    "fine detail, complex texture, gradient shading"
)

for ss, idx in [(75, 'A'), (85, 'B'), (95, 'C')]:
    print(f'\n  style_strength={ss}')
    payload = {
        'description': MRMOTEXT_DESC,
        'negative_description': NEG_DESC,
        'image_size': {'width': TARGET_W, 'height': TARGET_H},
        'text_guidance_scale': 12.0,
        'style_strength': float(ss),
        'style_image': {'base64': style_b64},   # exact same size as image_size
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
                save_b64(b64, f'V2_bitforge_ss{ss}_{j}.png')
    else:
        print(f'  ERR: {r.text[:300]}')

rb = requests.get(BASE + '/balance', headers=HEADERS)
print(f'\nBalance: {rb.json()["subscription"]["generations"]:.1f} gen')
print('\nERR-040 confirmed: bitforge style_image MUST be exact same size as image_size!')
