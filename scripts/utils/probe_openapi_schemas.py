"""
從 OpenAPI JSON 提取 pixflux/pixen/bitforge 的完整 schema 參數
"""
import json, re
from pathlib import Path

CONTENT_PATH = Path(r"C:\Users\88698\.gemini\antigravity-ide\brain\386f167b-d148-4652-bd4e-bbc85be962ff\.system_generated\steps\1098\content.md")

content = CONTENT_PATH.read_text(encoding="utf-8", errors="replace")
# 提取 JSON 部分（去掉 markdown header）
json_start = content.index("{")
raw_json = content[json_start:]
# 截斷到正確的 JSON（可能有截斷）
try:
    obj = json.loads(raw_json)
except:
    # 找最後一個完整的字符
    obj = None
    for i in range(len(raw_json), 0, -1000):
        try:
            obj = json.loads(raw_json[:i])
            break
        except:
            pass

schemas = obj["components"]["schemas"]
targets = [
    "CreateImagePixfluxRequest",
    "CreateImagePixenRequest",
    "CreateImageBitforgeRequest",
    "GenerateImageV2Request",
    "InpaintV3Request",
    "ResizeRequest",
    "EditImageRequest",
    "ImageToPixelartProRequest",
]

for t in targets:
    if t in schemas:
        s = schemas[t]
        props = s.get("properties", {})
        print(f"\n{'='*60}")
        print(f"Schema: {t}")
        print(f"{'='*60}")
        req = s.get("required", [])
        print(f"Required: {req}")
        print(f"\nAll properties:")
        for k, v in props.items():
            typ = v.get("type", v.get("$ref", "?"))
            enum_vals = v.get("enum", v.get("allOf", [{}])[0].get("enum", None) if "allOf" in v else None)
            desc = v.get("description", "")[:150]
            default = v.get("default", "N/A")
            if enum_vals:
                print(f"  [{k}] type={typ}, default={default}")
                print(f"       enum={enum_vals}")
            else:
                print(f"  [{k}] type={typ}, default={default}, desc={desc[:80]}")
    else:
        print(f"\n[NOT FOUND] {t}")
