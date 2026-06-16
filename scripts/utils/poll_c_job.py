"""
poll_c_job.py - Poll the img2px-pro background job and save result
"""
import sys, os, base64, io, time, json, requests
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')

API_TOKEN = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {API_TOKEN}"}
JOB_ID = "c1b9831b-a7a3-45d6-b91f-54832845ceb2"
OUT_DIR = r"d:\2026-06-04\assets\characters\generated\vampire_v1\skin_conversion"

def b64_to_img(b64str):
    return Image.open(io.BytesIO(base64.b64decode(b64str)))

def resize_to_skin(img):
    rgba = img.convert("RGBA")
    t = rgba.resize((40, 52), Image.NEAREST)
    bg = Image.new("RGB", (40, 52), (0, 0, 0))
    bg.paste(t, mask=t.split()[3])
    return bg

print(f"Polling job {JOB_ID[:16]}...")

for i in range(60):
    time.sleep(5)
    r = requests.get(f"{BASE_URL}/background-jobs/{JOB_ID}", headers=HEADERS)
    data = r.json()
    status = data.get("status", "?")
    print(f"[{(i+1)*5}s] status={status}")

    if status == "completed":
        lr = data.get("last_response", {})
        print(f"last_response keys: {list(lr.keys())}")

        img = None

        # 嘗試 images list (gen-with-style-v2 格式, GAP-018 修復)
        imgs = lr.get("images", [])
        if imgs:
            print(f"Found {len(imgs)} images in list")
            b64 = imgs[0]["base64"]  # ★ 頂層直接取 (GAP-018)
            img = b64_to_img(b64)

        # 嘗試單個 image (img2px-pro 可能格式)
        if img is None:
            single = lr.get("image", {})
            if single and single.get("base64"):
                print("Found single image")
                img = b64_to_img(single["base64"])

        if img is None:
            print("ERROR: Could not find image in response!")
            print(f"Full last_response: {json.dumps(lr)[:800]}")
            break

        print(f"Raw size: {img.size}")

        # Save raw
        img.save(os.path.join(OUT_DIR, "C1_img2pxpro_raw.png"))
        prev = img.resize((img.width * 8, img.height * 8), Image.NEAREST)
        prev.save(os.path.join(OUT_DIR, "C1_img2pxpro_raw_8x_preview.png"))
        print("Saved C1 raw + 8x preview")

        # Resize to 40x52 DS skin spec
        result = resize_to_skin(img)
        result.save(os.path.join(OUT_DIR, "C2_img2pxpro_resized_40x52.png"))
        r8x = result.resize((40 * 8, 52 * 8), Image.NEAREST)
        r8x.save(os.path.join(OUT_DIR, "C2_img2pxpro_resized_40x52_8x_preview.png"))
        print("Saved C2 40x52 + 8x preview")
        print("ALL DONE!")
        break

    elif status in ("failed", "cancelled"):
        print(f"Job failed! {json.dumps(data)[:400]}")
        break
else:
    print("Timeout after 5 minutes")
