#!/usr/bin/env python3
"""
generate_palette_pngs.py
從 MRMOTEXT_EX.png 生成染色版本：
1. 34 種前景顏色，背景設為【透明】（檔名：color_T_XX_名稱.png）
2. 城堡場景所需的特定【前景+背景】雙色組合（檔名：color_C_FGxx_BGyy_名稱.png）

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
    "shenzonghui", "shenzong", "meiguizong", "anan",
    "ganlanlv", "tailv", "ouhui", "hupozong",
    "yanzhihong", "meiguifen", "fanqiehong", "chenghong",
    "bohelv", "jincheng", "fuse", "xincheng",
    "laimeng", "huang", "ganlanlv2", "zihong",
    "shiya", "tiankong", "zhonghui", "lanhui",
    "taofen", "danjin", "xunyi", "fen",
    "bohe", "yinhui", "luhui", "naiyu",
    "xunyi2", "jingbai",
]

# 定義要產生的雙色 (前景, 背景) 組合
# 背景如果是 None，則為透明
COMBINATIONS = []

# 1. 產生 34 個「前景為調色盤顏色，背景為透明」的圖源（適合星星、雲朵、旗幟或一般疊加圖層）
for idx in range(34):
    COMBINATIONS.append((idx, None))

# 2. 產生城堡場景所需的特定 (前景, 背景) 配色組合
CUSTOM_COMBOS = [
    # 城堡牆面磚塊
    (29, 0),   # 銀灰 FG + 深棕灰 BG (普通磚牆)
    (6, 2),    # 藕灰 FG + 玫瑰棕 BG (陰影磚牆)
    (22, 1),   # 中灰 FG + 深棕 BG (暗色磚牆)
    (22, 2),   # 中灰 FG + 玫瑰棕 BG
    (29, 23),  # 銀灰 FG + 藍灰 BG (藍調磚牆)
    (29, 6),   # 銀灰 FG + 藕灰 BG
    (22, 6),   # 中灰 FG + 藕灰 BG
    (29, 22),  # 銀灰 FG + 中灰 BG

    # 土地、草地與植被
    (4, 1),    # 橄欖綠 FG + 深棕 BG (草地與泥土)
    (4, 2),    # 橄欖綠 FG + 玫瑰棕 BG
    (5, 2),    # 苔綠 FG + 玫瑰棕 BG
    (12, 1),   # 薄荷綠 FG + 深棕 BG (亮色草地)
    (13, 2),   # 金橙 FG + 玫瑰棕 BG (橙色觸手/植物)
    (11, 7),   # 橙紅 FG + 琥珀棕 BG
    (8, 7),    # 胭脂紅 FG + 琥珀棕 BG
]

# 3. 所有的 palette 顏色 on 最黑的那個顏色 (index 0)，排除重複與同色
for fg_idx in range(34):
    if fg_idx == 0:
        continue  # 排除同色 (0, 0)
    if any(c == (fg_idx, 0) for c in CUSTOM_COMBOS):
        continue  # 排除重複
    CUSTOM_COMBOS.append((fg_idx, 0))

for combo in CUSTOM_COMBOS:
    COMBINATIONS.append(combo)


def main():
    orig_path = Path("assets/tilesets/mrmotext/MRMOTEXT_EX.png")
    out_dir   = Path("assets/tilesets/mrmotext/colored")

    if not orig_path.exists():
        print(f"Not found: {orig_path}")
        sys.exit(1)

    # 清空並重建輸出目錄，確保沒有殘留的舊單色 PNG
    if out_dir.exists():
        for f in out_dir.glob("*.png"):
            f.unlink()
    else:
        out_dir.mkdir(parents=True, exist_ok=True)

    orig    = Image.open(orig_path).convert("RGBA")
    orig_np = np.array(orig, dtype=np.float32) / 255.0
    alpha   = orig_np[:, :, 3:4]
    rgb     = orig_np[:, :, :3]

    # 計算原始圖片亮度以進行插值 (1-bit 中，白 = 1.0, 黑 = 0.0)
    brightness = (rgb[:,:,0:1]*0.299 + rgb[:,:,1:2]*0.587 + rgb[:,:,2:3]*0.114)
    # 在原圖中，如果亮度小於 0.1，視為黑色背景像素；否則為白色前景像素
    is_foreground = brightness > 0.1

    print(f"Start generating PNGs for {len(COMBINATIONS)} color combinations...")
    t = time.time()
    
    for i, (fg_idx, bg_idx) in enumerate(COMBINATIONS):
        fg_color = np.array(PALETTE[fg_idx], dtype=np.float32) / 255.0
        fg_hw = fg_color[np.newaxis, np.newaxis, :]
        
        result_rgb = np.zeros_like(rgb)
        result_alpha = np.zeros_like(alpha)
        
        if bg_idx is None:
            # 透明背景模式：
            # 前景像素填充 fg_color，且 alpha 為 1.0
            # 背景像素填充透明 (alpha = 0.0)
            result_rgb = fg_hw * brightness
            result_alpha = np.where(is_foreground, 1.0, 0.0)
            fname = f"color_T_{fg_idx:02d}_{NAMES[fg_idx]}.png"
        else:
            # 雙色實心背景模式：
            # 前景為 fg_color，背景為 bg_color，alpha 均為 1.0
            bg_color = np.array(PALETTE[bg_idx], dtype=np.float32) / 255.0
            bg_hw = bg_color[np.newaxis, np.newaxis, :]
            
            result_rgb = bg_hw + (fg_hw - bg_hw) * brightness
            result_alpha = np.ones_like(alpha)
            fname = f"color_C_fg{fg_idx:02d}_bg{bg_idx:02d}_{NAMES[fg_idx]}_{NAMES[bg_idx]}.png"
            
        result = np.zeros_like(orig_np)
        result[:,:,:3] = np.clip(result_rgb, 0, 1)
        result[:,:,3:4] = result_alpha
        
        Image.fromarray((result*255).astype("uint8"), "RGBA").save(out_dir/fname)

    print(f"\n[DONE] Successfully generated {len(COMBINATIONS)} PNG files! Time taken: {time.time()-t:.2f}s")
    print("Next step: Please Rescan in Godot FileSystem panel, then run build_palette_sources.gd")

if __name__ == "__main__":
    main()
