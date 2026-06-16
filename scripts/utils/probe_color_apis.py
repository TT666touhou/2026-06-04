"""
查詢 PixelLab 所有與調色盤相關的 API 參數
重點：edit-image, inpaint, inpaint-v3, transfer-outfit, pixflux 的 color 相關參數
"""
import sys, io, urllib.request, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

req = urllib.request.Request('https://api.pixellab.ai/v2/openapi.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=15) as r:
    spec = json.loads(r.read())

schemas = spec.get('components', {}).get('schemas', {})

# Check all color-related endpoints
targets = [
    '/edit-image',
    '/edit-images-v2',
    '/inpaint',
    '/inpaint-v3',
    '/transfer-outfit-v2',
    '/resize',
    '/generate-with-style-v2',
    '/create-image-bitforge',
]

def get_schema(path, method='post'):
    ep = spec.get('paths', {}).get(path, {}).get(method, {})
    body = ep.get('requestBody', {})
    for ct, val in body.get('content', {}).items():
        s = val.get('schema', {})
        ref = s.get('$ref', '')
        if ref:
            sname = ref.split('/')[-1]
            return schemas.get(sname, {})
    return {}

for path in targets:
    s = get_schema(path)
    if not s:
        print(f"{path}: NOT FOUND or no schema")
        continue
    props = s.get('properties', {})
    print(f"\n{path}:")
    for pk in sorted(props.keys()):
        pv = props[pk]
        ptype = pv.get('type', '?')
        pref = pv.get('$ref', '').split('/')[-1]
        anyof = [x.get('$ref', x.get('type', '?')).split('/')[-1] for x in pv.get('anyOf', [])[:3]]
        print(f"  {pk}: type={ptype} ref={pref} anyOf={anyof}")

# Also check if there's a color_palette schema
print("\n\n=== Checking color_palette schema ===")
for k, v in schemas.items():
    if 'color' in k.lower() or 'palette' in k.lower():
        print(f"{k}: {list(v.get('properties', {}).keys())} enum={v.get('enum')}")
