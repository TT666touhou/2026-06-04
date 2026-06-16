import sys, io, json, base64, urllib.request
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
H = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\vampire_v1")

# Mode E job IDs from the log
job_ids = [
    ("E1", "9e9861ac-dcb9-4fe5-b4d6-5331e62ba001"),
    ("E2", "7bf44b76-dd33-44b1-b001-125f021dd6cc"),
]

def save_b64(b64str, path, scale=8):
    data = base64.b64decode(b64str)
    assert data[:4] == b'\x89PNG', f"Not PNG: {data[:4].hex()}"
    path.write_bytes(data)
    from PIL import Image
    img = Image.open(path)
    w, h = img.size
    prev = img.resize((w*scale, h*scale), Image.NEAREST)
    prev.save(path.with_stem(path.stem + f"_{scale}x"))
    return w, h

for tag, jid in job_ids:
    print(f"\n[{tag}] job {jid}")
    req = urllib.request.Request(f"{BASE_URL}/background-jobs/{jid}", headers=H)
    r = json.loads(urllib.request.urlopen(req, timeout=30).read())
    print(f"  status={r.get('status')}")
    print(f"  top-level keys={list(r.keys())}")

    lr = r.get("last_response", {})
    print(f"  last_response keys={list(lr.keys())}")

    # Try all possible image locations
    found = False

    # Option 1: images list
    images = lr.get("images", [])
    if images:
        print(f"  Found {len(images)} images in last_response.images")
        for i, img_d in enumerate(images):
            print(f"    img[{i}] keys={list(img_d.keys())}")
            b64 = img_d.get("image", {}).get("base64", "") or img_d.get("base64", "")
            if b64:
                out = OUT_DIR / f"{tag}_genwstyle_{i:02d}.png"
                w, h = save_b64(b64, out)
                print(f"    Saved {out.name} ({w}x{h})")
                found = True

    # Option 2: direct image
    if not found and "image" in lr:
        b64 = lr["image"].get("base64", "")
        if b64:
            out = OUT_DIR / f"{tag}_genwstyle_00.png"
            w, h = save_b64(b64, out)
            print(f"  Saved direct {out.name} ({w}x{h})")
            found = True

    if not found:
        print(f"  WARN: No image found. lr dump: {str(lr)[:500]}")

print("\nDone!")
