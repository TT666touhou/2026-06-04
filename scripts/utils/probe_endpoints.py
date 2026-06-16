"""
探測 PixelLab 端點：哪個同時支援「圖片輸入」+ 「自訂小尺寸」(16/32/48)
"""
import sys, io, urllib.request, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
API_HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}

# Step 1: Get OpenAPI spec
req = urllib.request.Request('https://api.pixellab.ai/v2/openapi.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=15) as r:
    spec = json.loads(r.read())

# Print all paths
print("=== All API Endpoints ===")
for path in sorted(spec.get('paths', {}).keys()):
    methods = list(spec['paths'][path].keys())
    print(f"  {path}: {methods}")

print()

# For each interesting endpoint, check if it has image input and size params
interesting = ['/pixflux', '/pixen', '/animate-character', '/image-to-image', '/bitforge']
for ep_path in interesting:
    if ep_path not in spec.get('paths', {}):
        print(f"{ep_path}: NOT FOUND")
        continue
    ep = spec['paths'][ep_path]
    method_data = ep.get('post', ep.get('get', {}))
    body = method_data.get('requestBody', {})
    for ct, val in body.get('content', {}).items():
        s = val.get('schema', {})
        ref = s.get('$ref', '')
        if ref:
            schema_name = ref.split('/')[-1]
            comp = spec.get('components', {}).get('schemas', {}).get(schema_name, {})
            props = comp.get('properties', {})
            print(f"\n{ep_path} ({schema_name}):")
            for pk in sorted(props.keys()):
                pv = props[pk]
                print(f"  {pk}: type={pv.get('type','?')} ref={pv.get('$ref','')} anyOf={[x.get('$ref','?') for x in pv.get('anyOf',[])[:2]]}")
