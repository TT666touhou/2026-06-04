"""讀取 OpenAPI spec 確認 style-v2 和 bitforge 的 style_images 格式"""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8')

r = requests.get('https://api.pixellab.ai/v2/openapi.json', timeout=30)
spec = r.json()

# 找目標端點的 request body schema
targets = ['generate-with-style-v2', 'create-image-bitforge']

def resolve_ref(spec, ref):
    parts = ref.lstrip('#/').split('/')
    node = spec
    for p in parts:
        node = node[p]
    return node

for path, methods in spec.get('paths', {}).items():
    for t in targets:
        if t in path:
            for method, details in methods.items():
                if method not in ('get', 'delete'):
                    print(f'=== {method.upper()} {path} ===')
                    body = details.get('requestBody', {})
                    schema = body.get('content', {}).get('application/json', {}).get('schema', {})
                    if '$ref' in schema:
                        schema = resolve_ref(spec, schema['$ref'])
                    props = schema.get('properties', {})
                    
                    # Find style_image / style_images
                    for key in ['style_image', 'style_images']:
                        if key in props:
                            prop = props[key]
                            if '$ref' in prop:
                                prop = resolve_ref(spec, prop['$ref'])
                            elif 'items' in prop and '$ref' in prop.get('items', {}):
                                items = resolve_ref(spec, prop['items']['$ref'])
                                print(f'  {key} items schema:')
                                print(json.dumps(items, indent=2, ensure_ascii=False)[:1000])
                            else:
                                print(f'  {key}: {json.dumps(prop, indent=2, ensure_ascii=False)[:500]}')
                    print()
