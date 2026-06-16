import sys, io, urllib.request, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

req = urllib.request.Request('https://api.pixellab.ai/v2/openapi.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=15) as r:
    spec = json.loads(r.read())

schemas = spec.get('components', {}).get('schemas', {})

targets = [
    'OutputSize',
    'app__endpoints__external__v2__image_to_pixelart__ImageSize',
    'app__endpoints__external__v2__create_image_pixen__ImageSize',
    'CameraView',
    'Direction',
    'Outline',
    'Detail',
    'Shading',
]

for k in targets:
    s = schemas.get(k, {})
    if not s:
        print(f"{k}: NOT FOUND")
        continue
    print(f"{k}:")
    print(f"  type={s.get('type')}")
    print(f"  enum={s.get('enum')}")
    props = s.get('properties', {})
    if props:
        for pk, pv in props.items():
            print(f"  prop[{pk}]: type={pv.get('type')} enum={pv.get('enum')} anyOf={[x.get('type','?') for x in pv.get('anyOf',[])]}")
    print()
