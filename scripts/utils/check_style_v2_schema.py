"""Get ImageSize schema for generate-with-style-v2"""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8')

r = requests.get('https://api.pixellab.ai/v2/openapi.json', timeout=30)
spec = r.json()

# Find the ImageSize schema for generate-with-style-v2
schemas = spec.get('components', {}).get('schemas', {})
for k, v in schemas.items():
    if 'generate_with_style_v2' in k and 'ImageSize' in k:
        print(f'=== {k} ===')
        print(json.dumps(v, indent=2, ensure_ascii=False))
        print()
    elif k == 'StyleImage':
        print(f'=== StyleImage ===')
        print(json.dumps(v, indent=2, ensure_ascii=False))
        print()
