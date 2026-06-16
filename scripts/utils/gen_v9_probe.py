"""
V9 正確做法：
- 插畫只做配色/風格參考，不直接丟進去
- 使用 create-image-pixen 生成真正的2D橫向遊戲角色
- 使用 create-image-pixflux + color_image 讓插畫指導配色

測試：先發一個小尺寸 pixen 看是同步還是非同步
"""
import sys, io, urllib.request, json, base64, time
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
API_HEADERS = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}
ILLUS_PATH = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")

def image_to_base64(img_path: Path, max_size: int = 256) -> tuple:
    img = Image.open(img_path).convert("RGBA")
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return b64, img.size

def api_post(endpoint, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/{endpoint}", data=data, headers=API_HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return None, f"HTTP {e.code}: {body[:600]}"

# ============================================================
# Test 1: pixen at 32x32
# CK-3 colors: hair=#F1ECF7, dress=#3D3448, frills=#6B1C24, tights=#2B1F1A
# ============================================================
print("=== Test 1: create-image-pixen 32x32 ===")
payload1 = {
    "description": (
        "2D side-scrolling pixel art game character, young girl, facing right, "
        "silver-white hair with black bow at right side, crimson red eyes, "
        "dark purple-gray off-shoulder gothic dress, deep red ruffled frills at hem, "
        "dark tights, black cat tail, no weapons, "
        "color palette: hair #F1ECF7, dress #3D3448, frills #6B1C24"
    ),
    "image_size": {"width": 32, "height": 32},
    "view": "side",
    "direction": "east",
    "outline": "selective outline",
    "detail": "medium detail",
    "no_background": True,
    "enhance_prompt": False,
}
t0 = time.time()
result1, err1 = api_post("create-image-pixen", payload1)
elapsed = time.time() - t0

if err1:
    print(f"  ERROR: {err1}")
else:
    print(f"  Response in {elapsed:.1f}s")
    print(f"  Keys: {list(result1.keys())}")
    print(f"  Has background_job_id: {'background_job_id' in result1}")
    print(f"  Has image: {'image' in result1}")
    print(f"  Usage: {result1.get('usage', {})}")
    print(f"  Full response (trimmed): {str(result1)[:300]}")

# ============================================================
# Test 2: pixflux with color_image at 32x32
# ============================================================
print("\n=== Test 2: create-image-pixflux + color_image 32x32 ===")
illus_b64, illus_size = image_to_base64(ILLUS_PATH, max_size=128)
print(f"  Illustration b64: {len(illus_b64)} chars, size: {illus_size}")

payload2 = {
    "description": (
        "2D side-scrolling pixel art game character, young girl, facing right, "
        "silver-white hair with black bow, crimson red eyes, "
        "gothic dress with red frills, dark tights, black cat tail, no weapons"
    ),
    "color_image": {
        "type": "base64",
        "base64": illus_b64,
        "format": "png",
    },
    "image_size": {"width": 32, "height": 32},
    "view": "side",
    "direction": "east",
    "outline": "selective outline",
    "detail": "medium detail",
    "no_background": True,
}
t0 = time.time()
result2, err2 = api_post("create-image-pixflux", payload2)
elapsed2 = time.time() - t0

if err2:
    print(f"  ERROR: {err2}")
else:
    print(f"  Response in {elapsed2:.1f}s")
    print(f"  Keys: {list(result2.keys())}")
    print(f"  Has background_job_id: {'background_job_id' in result2}")
    print(f"  Has image: {'image' in result2}")
    print(f"  Usage: {result2.get('usage', {})}")
    print(f"  Full response (trimmed): {str(result2)[:300]}")
