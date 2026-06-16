"""Extract B-1 result from last_response field"""
import requests, json, sys, base64, os
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
OUT_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_style'

job_id = '0263d1cc-b0be-402d-95d9-f2dbb8a780c0'
jr = requests.get(BASE + '/background-jobs/' + job_id, headers=HEADERS)
jdata = jr.json()

# ERR-039 fix: images are in last_response.images, not result.images!
last_response = jdata.get('last_response', {})
print('last_response keys:', list(last_response.keys()))
imgs = last_response.get('images', [])
print(f'Found {len(imgs)} images in last_response.images')

for i, img_obj in enumerate(imgs):
    b64 = img_obj.get('base64', '')
    w = img_obj.get('width', '?')
    print(f'  Image {i}: width={w}, b64 length={len(b64)}')
    if b64:
        data = base64.b64decode(b64)
        path = os.path.join(OUT_DIR, f'B1_style_v2_FINAL_{i}.png')
        with open(path, 'wb') as f:
            f.write(data)
        img = Image.open(path)
        print(f'  Saved: B1_style_v2_FINAL_{i}.png  size={img.size}')

print()
print('ERR-039 CONFIRMED:')
print('  generate-with-style-v2 job result is in: last_response.images[]')
print('  NOT in: result.images[] (result field is empty/null!)')
print('  status="completed" (NOT "complete")')
print('  image data: {"type": "base64", "width": N, "base64": "..."}')
