"""
Gen Vampire v1 - All Modes
白髮吸血鬼少女 Sprite 生成腳本
5種模式：pixen / pixflux+color_image / bitforge / img2px-pro / gen-with-style-v2

IMPORTANT:
- "loli" is banned (content policy) → use "petite young girl" / "small young girl"
- style_images in generate-with-style-v2 use TOP-LEVEL width/height (not size subfield!)
- generate-image-v2 reference_images use size SUBFIELD
- enhance-pixen-prompt key is "enhanced_prompt"
- No Accept-Encoding header when downloading CDN images!
"""
import sys, io, json, base64, time, urllib.request, urllib.error
from pathlib import Path
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# ──────────────────────────────────────────
# Config
# ──────────────────────────────────────────
BEARER   = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS  = {
    "Authorization": f"Bearer {BEARER}",
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
}
CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "image/avif,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
    # NO Accept-Encoding! (prevents Brotli garbage)
}

OUT_DIR = Path(r"D:\2026-06-04\assets\characters\generated\vampire_v1")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Reference images
LADY_ILLUST = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\illustrations\Lady_of_the_Bloodline.png")
LADY_SPRITE = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Assassin\skins\Lady_of_the_Bloodline.png")
DOPPEL_SKIN = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Doppelganger.png")
PHANTOM_SKIN = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Doppelganger\skins\Phantom_of_the_White_Night.png")
VAMPIRE_SKIN = Path(r"D:\2026-06-04\assets\characters\ds_reference\by_character\Vampire\skins\Vampire.png")

# ──────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────
def b64_obj(path: Path, max_px: int = 256, exact_wh: tuple = None) -> dict:
    """Load image, optionally resize, return Base64Image object."""
    img = Image.open(path).convert("RGBA")
    if exact_wh:
        img = img.resize(exact_wh, Image.LANCZOS)
    else:
        img.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    raw = base64.b64encode(buf.getvalue()).decode()
    w, h = img.size
    return {"type": "base64", "base64": raw, "format": "png"}, w, h

def b64_obj_simple(path: Path, max_px: int = 256, exact_wh: tuple = None) -> dict:
    """Return only the Base64Image dict (without w/h)."""
    obj, _, _ = b64_obj(path, max_px, exact_wh)
    return obj

def api_post(endpoint: str, payload: dict, timeout: int = 120):
    """POST to PixelLab API, return (result_dict, error_str)."""
    url = f"{BASE_URL}/{endpoint}"
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read()), None
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        return None, f"HTTP {e.code}: {body[:300]}"
    except Exception as ex:
        return None, str(ex)

def save_b64_image(b64str: str, path: Path, scale: int = 8):
    """Decode base64 PNG, save original + upscaled preview."""
    data = base64.b64decode(b64str)
    if data[:4] != b'\x89PNG':
        raise ValueError(f"Not a PNG! First 4 bytes: {data[:4].hex()}")
    with open(path, 'wb') as f:
        f.write(data)
    # Upscale for preview
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    preview = img.resize((w*scale, h*scale), Image.NEAREST)
    preview_path = path.with_stem(path.stem + f"_{scale}x")
    preview.save(preview_path)
    return w, h

def check_balance():
    req = urllib.request.Request(f"{BASE_URL}/balance", headers=HEADERS)
    data = json.loads(urllib.request.urlopen(req, timeout=15).read())
    return data.get("subscription", {}).get("generations", 0)

# ──────────────────────────────────────────
# Lady color palette (extracted from illustration)
# Colors present in Lady_of_the_Bloodline.png only!
# ──────────────────────────────────────────
# White hair: #F8F0F0 (brightest), #E0C0D0 (shadow), #C098A8 (deep shadow)
# Dark purple-gray outfit: #504050 / #483848 / #302030 / #181020
# Deep burgundy frills: #880838 / #780830 / #680828
# Skin: #F8F0F0 / #F8D0D8 / #E0C0C8
# Near-black: #181020 / #100010
LADY_COLORS_HEX = [
    "#F8F0F0",  # silver-white hair / skin highlight
    "#E0C0D0",  # hair shadow / light gray-pink
    "#C098A8",  # hair mid-shadow
    "#F8D0D8",  # warm skin
    "#604858",  # dark purple-gray outfit (most common)
    "#504050",  # outfit shadow
    "#483848",  # outfit deep shadow
    "#302030",  # near black
    "#181020",  # outline/darkest
    "#880838",  # deep burgundy red frills
    "#780830",  # frills shadow
    "#680828",  # frills darkest
]

# Core Prompt (Lady-palette only, no banned words)
# "loli" BANNED → "petite young girl"
# "assassin/ninja/chibi" BANNED
CORE_DESC = (
    "2D side-scrolling pixel art game sprite, petite young girl standing upright, "
    "silver-white long straight hair with large black hair bow, "
    "crimson-red glowing eyes (#880838), "
    "dark purple-charcoal gothic off-shoulder dress with wide black waist belt, "
    "deep burgundy dark-red layered ruffled frills at hem and cuffs (#780830), "
    "dark opaque tights, "
    "pale warm-ivory skin (#F8F0F0), "
    "strict color palette: white (#F8F0F0), gray-pink (#E0C0D0), "
    "dark purple (#504050), deep red (#880838), near-black (#181020), "
    "sharp pixel edges, no gradients, no anti-aliasing, no blur, "
    "cel-shaded 2-tone style, facing right, no weapons, no accessories"
)

# ──────────────────────────────────────────
# === MODE A: pixen — 3 sizes ===
# ──────────────────────────────────────────
def run_mode_A():
    print("\n" + "="*60)
    print("MODE A: create-image-pixen (3 sizes: 16x16, 32x32, 48x48)")
    print("="*60)

    # Step A0: enhance prompt first (§O-10-1 mandatory)
    print("\n[A0] Enhancing prompt via enhance-pixen-prompt...")
    enh_r, enh_err = api_post("enhance-pixen-prompt", {
        "description": CORE_DESC,
        "image_size": {"width": 32, "height": 32},
        "outline": "single color black outline",
    })
    if enh_err:
        print(f"  WARN enhance failed: {enh_err}")
        enhanced_prompt = CORE_DESC
    else:
        enhanced_prompt = enh_r.get("enhanced_prompt", CORE_DESC)
        print(f"  Enhanced ({len(enhanced_prompt)} chars)")

    sizes = [
        (16, 16, "A1"),
        (32, 32, "A2"),
        (48, 48, "A3"),
    ]
    for w, h, tag in sizes:
        print(f"\n[{tag}] pixen {w}x{h}...")
        payload = {
            "description": enhanced_prompt,
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "detail": "medium detail",
            "no_background": True,
            "seed": 42,
        }
        r, err = api_post("create-image-pixen", payload, timeout=120)
        if err:
            print(f"  ERR: {err}")
            continue
        b64 = r.get("image", {}).get("base64", "")
        if not b64:
            print(f"  ERR: no image in response: {list(r.keys())}")
            continue
        out_path = OUT_DIR / f"{tag}_pixen_{w}x{h}.png"
        ow, oh = save_b64_image(b64, out_path, scale=8)
        print(f"  Saved {out_path.name} ({ow}x{oh}) -> 8x preview")

# ──────────────────────────────────────────
# === MODE B: pixflux + color_image ===
# ──────────────────────────────────────────
def run_mode_B():
    print("\n" + "="*60)
    print("MODE B: create-image-pixflux + color_image (2 sizes: 32x32, 48x48)")
    print("="*60)

    # Use illustration as color_image guide (resize to <= 128px)
    color_img = b64_obj_simple(LADY_ILLUST, max_px=128)
    print(f"  color_image: Lady illustration (max 128px)")

    desc = (
        "2D side-scrolling pixel art sprite, petite young girl, "
        "silver-white straight hair with black bow, glowing red eyes, "
        "dark gray-purple gothic dress with deep red ruffled frills at hem, "
        "dark tights, pale skin, facing right, no weapons, "
        "limited color palette, pixel perfect, crisp sharp pixels"
    )

    sizes = [
        (32, 32, "B1"),
        (48, 48, "B2"),
    ]
    for w, h, tag in sizes:
        print(f"\n[{tag}] pixflux {w}x{h} + color_image...")
        payload = {
            "description": desc,
            "color_image": color_img,
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail",
            "no_background": True,
            "text_guidance_scale": 9.5,
        }
        r, err = api_post("create-image-pixflux", payload, timeout=90)
        if err:
            print(f"  ERR: {err}")
            continue
        b64 = r.get("image", {}).get("base64", "")
        if not b64:
            print(f"  ERR: no image. keys={list(r.keys())}")
            continue
        out_path = OUT_DIR / f"{tag}_pixflux_{w}x{h}.png"
        ow, oh = save_b64_image(b64, out_path, scale=8)
        print(f"  Saved {out_path.name} ({ow}x{oh}) -> 8x preview")

# ──────────────────────────────────────────
# === MODE C: bitforge + style+color+init ===
# ──────────────────────────────────────────
def run_mode_C():
    print("\n" + "="*60)
    print("MODE C: create-image-bitforge (style+color+init triple guide)")
    print("="*60)

    # bitforge: style_image AND init_image must EXACTLY match output size!
    sizes = [
        (32, 32, "C1"),
        (48, 48, "C2"),  # 48x48 is fine for bitforge
    ]
    color_img = b64_obj_simple(LADY_ILLUST, max_px=128)

    for w, h, tag in sizes:
        print(f"\n[{tag}] bitforge {w}x{h} style+color...")
        # style_image must be exact output size
        style_obj = b64_obj_simple(LADY_SPRITE, exact_wh=(w, h))

        payload = {
            "description": (
                "pixel art game sprite, small young girl, silver-white hair with black bow, "
                "red eyes, dark gothic dress with deep red frills, dark tights, facing right, no weapons"
            ),
            "style_image": style_obj,
            "color_image": color_img,
            "image_size": {"width": w, "height": h},
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail",
            "no_background": True,
        }
        r, err = api_post("create-image-bitforge", payload, timeout=90)
        if err:
            print(f"  ERR: {err}")
            continue
        b64 = r.get("image", {}).get("base64", "")
        if not b64:
            print(f"  ERR: no image. keys={list(r.keys())}")
            continue
        out_path = OUT_DIR / f"{tag}_bitforge_{w}x{h}.png"
        ow, oh = save_b64_image(b64, out_path, scale=8)
        print(f"  Saved {out_path.name} ({ow}x{oh}) -> 8x preview")

# ──────────────────────────────────────────
# === MODE D: image-to-pixelart-pro ===
# ──────────────────────────────────────────
def poll_job(job_id: str, timeout_s: int = 360) -> dict:
    """Poll a background job until completed or failed."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        req = urllib.request.Request(
            f"{BASE_URL}/background-jobs/{job_id}",
            headers=HEADERS,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read())
        except Exception as ex:
            print(f"  poll error: {ex}")
            time.sleep(5)
            continue
        status = result.get("status")
        print(f"  ... status={status}")
        if status == "completed":
            return result
        elif status == "failed":
            raise RuntimeError(f"Job failed: {result.get('last_response', {}).get('detail', 'unknown')}")
        time.sleep(8)
    raise TimeoutError(f"Job {job_id} timed out after {timeout_s}s")

def run_mode_D():
    print("\n" + "="*60)
    print("MODE D: image-to-pixelart-pro (illustration direct conversion)")
    print("="*60)
    print("NOTE: This endpoint is ASYNC — polling background_job_id")

    sources = [
        (LADY_ILLUST, "D1", "illustration"),
        (LADY_SPRITE, "D2", "sprite_skin"),
    ]

    for src_path, tag, src_name in sources:
        print(f"\n[{tag}] img2pxpro <- {src_name}...")
        src_obj = b64_obj_simple(src_path, max_px=256)
        payload = {
            "image": src_obj,
            "description": "pixel art game character sprite, clean crisp pixels",
        }
        r, err = api_post("image-to-pixelart-pro", payload, timeout=60)
        if err:
            print(f"  ERR post: {err}")
            continue

        # Check for immediate image (sync fallback)
        b64 = r.get("image", {}).get("base64", "") if isinstance(r, dict) else ""
        if b64:
            out_path = OUT_DIR / f"{tag}_img2pxpro_{src_name}.png"
            ow, oh = save_b64_image(b64, out_path, scale=4)
            print(f"  Saved (sync) {out_path.name} ({ow}x{oh})")
            continue

        # Async: poll background job
        job_id = r.get("background_job_id", "")
        if not job_id:
            print(f"  ERR: no image and no background_job_id. keys={list(r.keys())}")
            continue
        print(f"  Async job: {job_id}")
        try:
            job_result = poll_job(job_id, timeout_s=300)
        except Exception as ex:
            print(f"  ERR poll: {ex}")
            continue

        # Extract image from completed job
        last_resp = job_result.get("last_response", {})
        b64 = last_resp.get("image", {}).get("base64", "")
        if not b64:
            # Try images array
            images = last_resp.get("images", [])
            if images:
                b64 = images[0].get("image", {}).get("base64", "")
        if not b64:
            print(f"  ERR: completed but no image. last_resp keys={list(last_resp.keys())}")
            print(f"  Full job keys={list(job_result.keys())}")
            continue
        out_path = OUT_DIR / f"{tag}_img2pxpro_{src_name}.png"
        ow, oh = save_b64_image(b64, out_path, scale=4)
        print(f"  Saved {out_path.name} ({ow}x{oh}) -> 4x preview")

# ──────────────────────────────────────────
# === MODE E: generate-with-style-v2 + 4 skins ===
# ──────────────────────────────────────────
def run_mode_E():
    print("\n" + "="*60)
    print("MODE E: generate-with-style-v2 + 4 DS skins (48x48 square)")
    print("="*60)
    print("CRITICAL: style_images use TOP-LEVEL width/height (not size subfield!)")

    # Load 4 skins with their actual sizes
    def skin_entry(path: Path) -> dict:
        img = Image.open(path).convert("RGBA")
        w, h = img.size
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode()
        return {
            "image": {"type": "base64", "base64": b64, "format": "png"},
            "width": w,   # TOP-LEVEL! Not nested in "size"
            "height": h,
        }

    four_skins = []
    for sp in [LADY_SPRITE, DOPPEL_SKIN, PHANTOM_SKIN, VAMPIRE_SKIN]:
        if sp.exists():
            four_skins.append(skin_entry(sp))
            print(f"  Loaded skin: {sp.name} ({four_skins[-1]['width']}x{four_skins[-1]['height']})")
        else:
            print(f"  SKIP (not found): {sp.name}")

    if len(four_skins) > 4:
        four_skins = four_skins[:4]  # max 4!

    variants = [
        ("E1", "petite young girl with silver-white hair and black bow, dark gothic dress, deep red frills"),
        ("E2", "small girl with white hair, black hair ribbon, dark purple dress with red ruffled hem, dark tights"),
    ]

    for tag, desc in variants:
        print(f"\n[{tag}] gen-with-style-v2 48x48 - {desc[:50]}...")
        payload = {
            "style_images": four_skins,
            "style_description": "DS 2D side-scrolling pixel art game character sprite, black outline, flat pixel colors",
            "description": desc,  # NOT empty string!
            "image_size": {"width": 48, "height": 48},  # MUST be square!
            "no_background": True,
        }
        r, err = api_post("generate-with-style-v2", payload, timeout=60)
        if err:
            print(f"  ERR: {err}")
            continue

        # Check sync response first
        images = r.get("images", []) if isinstance(r, dict) else []
        if not images:
            b64 = r.get("image", {}).get("base64", "") if isinstance(r, dict) else ""
            if b64:
                images = [{"image": {"base64": b64}}]

        if not images:
            # Async path
            job_id = r.get("background_job_id", "") if isinstance(r, dict) else ""
            if not job_id:
                print(f"  ERR: no images and no background_job_id. keys={list(r.keys())}")
                continue
            print(f"  Async job: {job_id}")
            try:
                job_result = poll_job(job_id, timeout_s=300)
            except Exception as ex:
                print(f"  ERR poll: {ex}")
                continue
            last_resp = job_result.get("last_response", {})
            images = last_resp.get("images", [])
            if not images:
                b64 = last_resp.get("image", {}).get("base64", "")
                if b64:
                    images = [{"image": {"base64": b64}}]
            if not images:
                print(f"  ERR: completed but no images. last_resp keys={list(last_resp.keys())}")
                continue

        for i, img_data in enumerate(images[:4]):
            b64 = img_data.get("image", {}).get("base64", "")
            if not b64:
                continue
            out_path = OUT_DIR / f"{tag}_genwstyle_{i:02d}.png"
            ow, oh = save_b64_image(b64, out_path, scale=8)
            print(f"  Saved {out_path.name} ({ow}x{oh}) -> 8x preview")

# ──────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────
if __name__ == "__main__":
    print("="*60)
    print("VAMPIRE V1 - All Modes Generation")
    print("Target: White-hair vampire sprite (Lady palette only)")
    print("="*60)

    # Pre-check balance
    bal = check_balance()
    print(f"\nBalance: {bal:.1f} gens")
    if bal < 10:
        print("ERROR: Balance too low! Need >= 10")
        sys.exit(1)

    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    print(f"Mode: {mode}")
    print(f"Output dir: {OUT_DIR}")

    t0 = time.time()
    if mode in ("A", "all"): run_mode_A()
    if mode in ("B", "all"): run_mode_B()
    if mode in ("C", "all"): run_mode_C()
    if mode in ("D", "all"): run_mode_D()
    if mode in ("E", "all"): run_mode_E()

    bal2 = check_balance()
    used = bal - bal2
    print(f"\n{'='*60}")
    print(f"DONE! Time: {time.time()-t0:.0f}s | Used: {used:.1f} gens | Remaining: {bal2:.1f}")
    print(f"Output: {OUT_DIR}")
