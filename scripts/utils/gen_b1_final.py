"""B-1 FINAL: generate-with-style-v2 with correct image_size"""
import sys, os, base64, json, time, requests
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_style'
IMG_DIR = r'd:\2026-06-04\docs\mrmotext_research\images'

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

print('[B-1 FINAL] generate-with-style-v2 with image_size dict (ERR-038 fix)')
W, H = 128, 128

style_imgs = []
for img_path, name in [
    (os.path.join(IMG_DIR, 'x3_version.jpg'), 'x3_scene'),
    (os.path.join(IMG_DIR, 'building_blocks.png'), 'blocks'),
]:
    if os.path.exists(img_path):
        b64, (iw, ih) = img_to_b64(img_path, max_px=256)
        style_imgs.append({
            'image': {'base64': b64},
            'width': min(iw, 512),
            'height': min(ih, 512)
        })
        print(f'  Style: {name} {iw}x{ih}')

payload = {
    'description': (
        '2D side-scrolling game character in MRMOTEXT textmode tile style, '
        'assembled from 8x8 pixel tile blocks, totem-like geometric humanoid figure, '
        'side view orientation, 1-bit color aesthetic, bold blocky proportions, '
        'retro ASCII art roguelike creature, dark charcoal background, high contrast'
    ),
    'style_images': style_imgs,
    'image_size': {'width': W, 'height': H},
    'no_background': True
}

r = requests.post(BASE + '/generate-with-style-v2', headers=HEADERS, json=payload, timeout=180)
print('  HTTP', r.status_code)

if r.status_code == 200:
    data = r.json()
    print('  Keys:', list(data.keys()))
    images = data.get('images', [])
    if images:
        for i, img_obj in enumerate(images):
            if 'base64' in img_obj:
                save_b64(img_obj['base64'], f'B1_style_v2_FINAL_{i}.png')
    elif 'image' in data:
        save_b64(data['image']['base64'], 'B1_style_v2_FINAL_0.png')
    else:
        job_id = data.get('background_job_id') or data.get('job_id')
        if job_id:
            print(f'  Async job: {job_id}')
            deadline = time.time() + 300
            while time.time() < deadline:
                jr = requests.get(BASE + '/background-jobs/' + job_id, headers=HEADERS)
                jdata = jr.json()
                status = jdata.get('status', 'unknown')
                print('    Status:', status)
                if status == 'complete':
                    result = jdata.get('result', {})
                    imgs = result.get('images', [])
                    for i, img_obj in enumerate(imgs):
                        b64 = img_obj.get('base64', '')
                        if b64:
                            save_b64(b64, f'B1_style_v2_FINAL_{i}.png')
                    break
                elif status in ('failed', 'error'):
                    print('  Job failed:', jdata)
                    break
                time.sleep(5)
        else:
            print('  Unknown response:', json.dumps(data)[:400])
else:
    print('  ERROR:', r.text[:600])

print()
rb = requests.get(BASE + '/balance', headers=HEADERS)
bal = rb.json()['subscription']['generations']
print(f'  Balance: {bal:.1f} gen')
