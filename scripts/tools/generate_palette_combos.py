#!/usr/bin/env python3
"""
generate_all_palette_combos.py
────────────────────────────────────────────────────────────────
從 MRMOTEXT_EX.png 生成所有色板顏色組合（fill × outline，排除同色）
34 × 33 = 1122 張 PNG → assets/tilesets/mrmotext/colored_combos/

命名規則：f{fill_idx:02d}_o{outline_idx:02d}.png
例：f10_o00.png = 填充：番茄紅, 輪廓：深棕灰

需求：pip install Pillow numpy
執行：cd d:/2026-06-04 && python scripts/tools/generate_palette_combos.py
────────────────────────────────────────────────────────────────
"""
import sys
import time
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("❌ 需要安裝：pip install Pillow numpy")
    sys.exit(1)

# ── 34 色板（來自 palette.pal，RGB 整數）─────────────────────
PALETTE = [
    ( 54,  50,  50), ( 69,  60,  60), ( 98,  73,  76), (127,  74,  80),
    ( 86, 119,  74), (101, 114,  95), (117, 101, 106), (138,  94,  64),
    (167,  80, 100), (171, 110, 124), (229,  92,  92), (214, 107,  72),
    ( 93, 161, 110), (224, 150,  86), (212, 156, 115), (231, 148, 109),
    (177, 211, 104), (238, 207,  90), ( 67, 103, 148), (157,  87, 137),
    (111, 129, 179), (119, 188, 214), (151, 140, 142), (133, 153, 176),
    (228, 166, 145), (233, 206, 161), (190, 142, 193), (237, 188, 204),
    (177, 222, 207), (194, 194, 194), (223, 232, 211), (241, 233, 212),
    (241, 229, 248), (242, 249, 248),
]

NAMES = [
    "深棕灰","深棕","玫瑰棕","暗紅","橄欖綠","苔綠","藕灰","琥珀棕",
    "胭脂紅","玫瑰粉","番茄紅","橙紅","薄荷綠","金橙","膚色","杏橙",
    "萊姆綠","黃色","鋼藍","紫紅","矢車菊藍","天空藍","中灰","藍灰",
    "桃粉","淡金","薰衣草","粉紅","薄荷","銀灰","淡蘆薈","奶油",
    "薰衣草白","近白",
]

def main():
    orig_path = Path("assets/tilesets/mrmotext/MRMOTEXT_EX.png")
    out_dir   = Path("assets/tilesets/mrmotext/colored_combos")

    if not orig_path.exists():
        print(f"❌ 找不到 {orig_path}，請從專案根目錄執行本腳本")
        sys.exit(1)

    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"[OK] Output dir: {out_dir}")

    # ── 載入原始圖 ──────────────────────────────────────────
    orig      = Image.open(orig_path).convert("RGBA")
    orig_np   = np.array(orig, dtype=np.float32) / 255.0
    alpha     = orig_np[:, :, 3:4]           # (H,W,1)
    rgb       = orig_np[:, :, :3]            # (H,W,3)

    # 感知亮度（ITU-R BT.601）
    brightness = (rgb[:, :, 0:1] * 0.299
                + rgb[:, :, 1:2] * 0.587
                + rgb[:, :, 2:3] * 0.114)   # (H,W,1)

    transparent = alpha[:, :, 0] < 0.01     # (H,W) bool mask

    total   = 34 * 33   # 1122
    done    = 0
    t_start = time.time()

    print(f"Generating {total} PNG files...")

    for fi in range(34):
        fill    = np.array(PALETTE[fi],    dtype=np.float32) / 255.0   # (3,)
        fill_hw = fill[np.newaxis, np.newaxis, :]                       # (1,1,3)

        for oi in range(34):
            if fi == oi:
                continue

            outline    = np.array(PALETTE[oi], dtype=np.float32) / 255.0
            outline_hw = outline[np.newaxis, np.newaxis, :]

            # mix(outline, fill, brightness)  →  (H,W,3)
            new_rgb = outline_hw + (fill_hw - outline_hw) * brightness

            result = np.zeros_like(orig_np)
            result[:, :, :3] = np.clip(new_rgb, 0, 1)
            result[:, :, 3:4] = alpha

            # 清除透明像素
            result[transparent] = 0.0

            img_out = Image.fromarray(
                (result * 255).astype(np.uint8), "RGBA"
            )
            img_out.save(
                out_dir / f"f{fi:02d}_o{oi:02d}.png",
                optimize=False,   # 略過優化，加快速度
            )

            done += 1
            if done % 100 == 0 or done == total:
                elapsed = time.time() - t_start
                eta     = elapsed / done * (total - done)
                print(f"  {done:4d}/{total}  {done*100//total}%  "
                      f"elapsed:{elapsed:5.1f}s  eta:{eta:5.1f}s")

    elapsed = time.time() - t_start
    print(f"\n[DONE] {done} PNG files saved to {out_dir}/")
    print(f"       Total time: {elapsed:.1f}s")
    print(f"\nNext: In Godot, click FileSystem > Rescan, wait for import,")
    print(f"      then run build_all_combo_sources.gd")

if __name__ == "__main__":
    main()
