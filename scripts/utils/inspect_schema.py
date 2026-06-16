import json, urllib.request, sys
sys.stdout.reconfigure(encoding='utf-8')

req = urllib.request.Request('https://api.pixellab.ai/v2/openapi.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=15) as r:
    spec = json.loads(r.read())

path = '/enhance-character-v3-prompt'
ep = spec['paths'][path]['post']
body = ep.get('requestBody', {})
content = body.get('content', {})
print('Content keys:', list(content.keys()))

for ct, val in content.items():
    s = val.get('schema', {})
    ref = s.get('$ref', '')
    print(f'Content-type: {ct}, Schema $ref: {ref}')
    if ref:
        schema_name = ref.split('/')[-1]
        comp = spec.get('components', {}).get('schemas', {}).get(schema_name, {})
        print(f'Schema {schema_name} props:')
        for pk, pv in comp.get('properties', {}).items():
            inner_ref = pv.get('$ref', '')
            anyof = pv.get('anyOf', [])
            allof = pv.get('allOf', [])
            print(f'  {pk}: type={pv.get("type","?")} ref={inner_ref} anyOf={[x.get("$ref","") for x in anyof]} allOf={[x.get("$ref","") for x in allof]}')

# Also check create-character-v3 for reference_image
print()
print('=== create-character-v3 schema ===')
path2 = '/create-character-v3'
ep2 = spec['paths'][path2]['post']
body2 = ep2.get('requestBody', {})
for ct, val in body2.get('content', {}).items():
    s = val.get('schema', {})
    ref = s.get('$ref', '')
    if ref:
        schema_name = ref.split('/')[-1]
        comp = spec.get('components', {}).get('schemas', {}).get(schema_name, {})
        for pk, pv in comp.get('properties', {}).items():
            inner_ref = pv.get('$ref', '')
            print(f'  {pk}: type={pv.get("type","?")} ref={inner_ref}')
