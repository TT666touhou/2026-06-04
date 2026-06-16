"""Extract all parameters for 4 key endpoints"""
import json, sys
sys.stdout.reconfigure(encoding='utf-8')

with open(r'C:\Users\88698\.gemini\antigravity-ide\brain\5c7c2789-1b53-4748-8d20-5fb4966c1360\.system_generated\steps\458\content.md', encoding='utf-8') as f:
    content = f.read()

# The content is actually the raw JSON saved as markdown
# Let's just parse the spec directly
import requests
r = requests.get('https://api.pixellab.ai/v2/openapi.json', timeout=30)
spec = r.json()

def resolve_ref(spec, ref):
    parts = ref.lstrip('#/').split('/')
    node = spec
    for p in parts:
        node = node[p]
    return node

def get_schema_props(spec, schema):
    if '$ref' in schema:
        schema = resolve_ref(spec, schema['$ref'])
    props = schema.get('properties', {})
    required = schema.get('required', [])
    return props, required

targets = {
    'generate-with-style-v2': 'POST',
    'create-image-bitforge': 'POST',
    'create-image-pixflux': 'POST',
    'create-character-v3': 'POST',
    'create-image-pixen': 'POST',
}

for path, methods in spec.get('paths', {}).items():
    for tname in targets:
        if tname in path:
            for method, details in methods.items():
                if method == 'post':
                    print(f'\n{"="*60}')
                    print(f'POST {path}')
                    print('='*60)
                    body = details.get('requestBody', {})
                    schema_raw = body.get('content', {}).get('application/json', {}).get('schema', {})
                    props, required = get_schema_props(spec, schema_raw)
                    
                    print(f'Required: {required}')
                    print(f'\nParameters:')
                    for pname, pdef in props.items():
                        is_req = '★' if pname in required else ' '
                        # Resolve ref
                        if '$ref' in pdef:
                            pdef_resolved = resolve_ref(spec, pdef['$ref'])
                        elif 'anyOf' in pdef:
                            types = [x.get('$ref', x.get('type', '?')).split('/')[-1] for x in pdef['anyOf'] if x.get('type') != 'null']
                            pdef_resolved = {'type': ' | '.join(types)}
                        else:
                            pdef_resolved = pdef
                        
                        ptype = pdef_resolved.get('type', pdef_resolved.get('$ref', '?').split('/')[-1])
                        pdesc = pdef.get('description', pdef_resolved.get('description', ''))
                        pdefault = pdef.get('default', pdef_resolved.get('default', '(no default)'))
                        pmin = pdef_resolved.get('minimum', '')
                        pmax = pdef_resolved.get('maximum', '')
                        
                        range_str = f' [{pmin}~{pmax}]' if pmin or pmax else ''
                        print(f'  {is_req} {pname}: {ptype}{range_str}')
                        if pdesc:
                            print(f'      → {pdesc}')
                        if pdefault != '(no default)':
                            print(f'      default: {pdefault}')
                        
                        # If it's an object, show sub-props
                        sub_props = pdef_resolved.get('properties', {})
                        if sub_props:
                            for spname, spdef in sub_props.items():
                                sptype = spdef.get('type', '?')
                                spmin = spdef.get('minimum', '')
                                spmax = spdef.get('maximum', '')
                                srange = f' [{spmin}~{spmax}]' if spmin or spmax else ''
                                print(f'        - {spname}: {sptype}{srange}')
