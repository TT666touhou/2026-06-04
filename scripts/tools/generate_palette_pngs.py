#!/usr/bin/env python3
"""
generate_palette_pngs.py
從 MRMOTEXT_EX.png 生成 34 張染色版本（每種填充色一張）
輪廓固定為 palette[0] = 深棕灰 #363232
輸出：assets/tilesets/mrmotext/colored/color_XX_名稱.png

執行：cd d:/2026-06-04 && python scripts/tools/generate_palette_pngs.py
"""
import sys, time
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("pip install Pillow numpy")
    sys.exit(1)

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
    "00_shenzonghui","01_shenzong","02_meiguizong","03_anan",
    "04_ganlanlv","05_tailv","06_ouhui","07_hupozong",
    "08_yanzhihong","09_meiguifen","10_fanqiehong","11_chenghong",
    "12_bohelv","13_jincheng","14_fuse","15_xincheng",
    "16_laimeng","17_huang","18_ganlanlv2","19_zihong",
    "20_shiya","21_tiankong","22_zhonghui","23_lanhui",
    "24_taofen","25_danjin","26_xunyi","27_fen",
    "28_bohe","29_yinhui","30_luhui","31_naiyu",
    "32_xunyi2","33_jingbai",
]

def main():
    orig_path = Path("assets/tilesets/mrmotext/MRMOTEXT_EX.png")
    out_dir   = Path("assets/tilesets/mrmotext/colored")

    if not orig_path.exists():
        print(f"Not found: {orig_path}")
        sys.exit(1)

    out_dir.mkdir(parents=True, exist_ok=True)

    orig    = Image.open(orig_path).convert("RGBA")
    orig_np = np.array(orig, dtype=np.float32) / 255.0
    alpha   = orig_np[:, :, 3:4]
    rgb     = orig_np[:, :, :3]

    brightness = (rgb[:,:,0:1]*0.299 + rgb[:,:,1:2]*0.587 + rgb[:,:,2:3]*0.114)
    transparent = alpha[:,:,0] < 0.01

    # 固定輪廓色 = palette[0] 深棕灰
    outline = np.array(PALETTE[0], dtype=np.float32) / 255.0
    outline_hw = outline[np.newaxis, np.newaxis, :]

    t = time.time()
    for i in range(34):
        fill    = np.array(PALETTE[i], dtype=np.float32) / 255.0
        fill_hw = fill[np.newaxis, np.newaxis, :]

        new_rgb = outline_hw + (fill_hw - outline_hw) * brightness
        result  = np.zeros_like(orig_np)
        result[:,:,:3] = np.clip(new_rgb, 0, 1)
        result[:,:,3:4] = alpha
        result[transparent] = 0.0

        fname = f"color_{NAMES[i]}.png"
        Image.fromarray((result*255).astype("uint8"), "RGBA").save(out_dir/fname)
        print(f"  [{i+1:2d}/34] {fname}")

    print(f"\n[DONE] 34 PNGs -> {out_dir}/  ({time.time()-t:.1f}s)")
    print("Next: Godot FileSystem Rescan -> run build_palette_sources.gd")

if __name__ == "__main__":
    main()
