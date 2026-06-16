"""
深入提取所有 enum 值（特別是 outline/shading/detail 的完整選項）
以及 GenerateImageV2 的 StyleOptions
"""
import json
from pathlib import Path

CONTENT_PATH = Path(r"C:\Users\88698\.gemini\antigravity-ide\brain\386f167b-d148-4652-bd4e-bbc85be962ff\.system_generated\steps\1098\content.md")

content = CONTENT_PATH.read_text(encoding="utf-8", errors="replace")
json_start = content.index("{")
raw_json = content[json_start:]
obj = json.loads(raw_json)
schemas = obj["components"]["schemas"]

# 找所有與 outline/shading/detail/view/direction 相關的 enum schema
print("=" * 60)
print("ALL ENUM SCHEMAS RELATED TO VISUAL QUALITY")
print("=" * 60)

keywords = ["outline", "shading", "detail", "view", "direction", "coverage"]
for name, schema in schemas.items():
    nm_lower = name.lower()
    if any(kw in nm_lower for kw in keywords):
        if "enum" in schema:
            print(f"\n[{name}]")
            print(f"  type: {schema.get('type', '?')}")
            print(f"  enum: {schema['enum']}")

print("\n\n" + "=" * 60)
print("StyleOptions (for GenerateImageV2)")
print("=" * 60)
if "StyleOptions" in schemas:
    s = schemas["StyleOptions"]
    print(json.dumps(s, indent=2, ensure_ascii=False)[:2000])

print("\n\n" + "=" * 60)
print("GenerateImageV2Request FULL (looking for new params)")
print("=" * 60)
if "GenerateImageV2Request" in schemas:
    s = schemas["GenerateImageV2Request"]
    props = s.get("properties", {})
    for k, v in props.items():
        ref = v.get("$ref", "")
        anyOf = v.get("anyOf", [])
        allOf = v.get("allOf", [])
        desc = v.get("description", "")
        default = v.get("default", "N/A")
        print(f"\n  [{k}]")
        print(f"    desc: {desc[:200]}")
        print(f"    default: {default}")
        if ref:
            print(f"    $ref: {ref}")
            ref_name = ref.split("/")[-1]
            if ref_name in schemas:
                rs = schemas[ref_name]
                if "enum" in rs:
                    print(f"    enum values: {rs['enum']}")
                elif "properties" in rs:
                    print(f"    sub-properties: {list(rs['properties'].keys())}")

print("\n\n" + "=" * 60)
print("InpaintV3Request FULL DETAIL")
print("=" * 60)
if "InpaintV3Request" in schemas:
    s = schemas["InpaintV3Request"]
    print(json.dumps(s, indent=2, ensure_ascii=False)[:3000])

print("\n\n" + "=" * 60)
print("CreateImagePixfluxRequest FULL DETAIL (all $refs resolved)")
print("=" * 60)
if "CreateImagePixfluxRequest" in schemas:
    s = schemas["CreateImagePixfluxRequest"]
    props = s.get("properties", {})
    for k, v in props.items():
        anyOf = v.get("anyOf", [])
        allOf = v.get("allOf", [])
        ref = v.get("$ref", "")
        desc = v.get("description", "")
        default = v.get("default", "N/A")
        enum_source = None
        if ref:
            ref_name = ref.split("/")[-1]
            if ref_name in schemas:
                enum_source = schemas[ref_name]
        for a in anyOf + allOf:
            if "$ref" in a:
                ref_name = a["$ref"].split("/")[-1]
                if ref_name in schemas and "enum" in schemas[ref_name]:
                    enum_source = schemas[ref_name]
        print(f"\n  [{k}]")
        print(f"    desc: {desc[:200]}")
        print(f"    default: {default}")
        if enum_source and "enum" in enum_source:
            print(f"    ★ ENUM values: {enum_source['enum']}")
        elif enum_source and "properties" in enum_source:
            print(f"    sub-props: {list(enum_source['properties'].keys())}")
