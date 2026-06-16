import sys, io, urllib.request, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

req = urllib.request.Request('https://api.pixellab.ai/v2/openapi.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=15) as r:
    spec = json.loads(r.read())

def show_schema(path):
    if path not in spec.get('paths', {}):
        print(f'{path}: NOT FOUND')
        return
    ep = spec['paths'][path].get('post', {})
    body = ep.get('requestBody', {})
    for ct, val in body.get('content', {}).items():
        s = val.get('schema', {})
        ref = s.get('$ref', '')
        if ref:
            sname = ref.split('/')[-1]
            comp = spec.get('components', {}).get('schemas', {}).get(sname, {})
            props = comp.get('properties', {})
            print(f'{path} [{sname}]:')
            for pk in sorted(props.keys()):
                pv = props[pk]
                ptype = pv.get('type', '?')
                pref = pv.get('$ref', '')
                anyof = [x.get('$ref', x.get('type', '?')) for x in pv.get('anyOf', [])[:3]]
                print(f'  {pk}: type={ptype} ref={pref} anyOf={anyof}')
        else:
            print(f'{path}: no $ref schema')

targets = [
    '/image-to-pixelart',
    '/image-to-pixelart-pro',
    '/create-image-pixen',
    '/create-image-pixflux',
    '/generate-8-rotations-v3',
    '/create-image-bitforge',
]

for p in targets:
    show_schema(p)
    print()
