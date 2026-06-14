#!/usr/bin/env python3
"""
generate_dungeon_palette_pngs.py
從 dungeon-mode.png 生成染色版本：
1. 34 種前景顏色，背景設為【透明】（檔名：color_T_XX_名稱.png）
2. 城堡/地牢場景所需的特定【前景+背景】雙色組合（檔名：color_C_FGxx_BGyy_名稱.png）

策略：
  - 包含 mrmotext_world_tileset.tres 中出現過的所有組合（城堡系列）
  - 新增地牢專屬配色組合（石牆/魔法/熔岩/腐朽/神聖等主題）

執行：cd d:/2026-06-04 && python scripts/tools/generate_dungeon_palette_pngs.py
"""
import sys, time
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("pip install Pillow numpy")
    sys.exit(1)

# ── 34 色調色盤（與 mrmotext_palette_swap.gdshader / palette_applicator.gd 完全對應）
PALETTE = [
    ( 54,  50,  50), ( 69,  60,  60), ( 98,  73,  76), (127,  74,  80),   # 0-3
    ( 86, 119,  74), (101, 114,  95), (117, 101, 106), (138,  94,  64),   # 4-7
    (167,  80, 100), (171, 110, 124), (229,  92,  92), (214, 107,  72),   # 8-11
    ( 93, 161, 110), (224, 150,  86), (212, 156, 115), (231, 148, 109),   # 12-15
    (177, 211, 104), (238, 207,  90), ( 67, 103, 148), (157,  87, 137),   # 16-19
    (111, 129, 179), (119, 188, 214), (151, 140, 142), (133, 153, 176),   # 20-23
    (228, 166, 145), (233, 206, 161), (190, 142, 193), (237, 188, 204),   # 24-27
    (177, 222, 207), (194, 194, 194), (223, 232, 211), (241, 233, 212),   # 28-31
    (241, 229, 248), (242, 249, 248),                                      # 32-33
]

NAMES = [
    "shenzonghui", "shenzong", "meiguizong", "anan",          # 0  深棕灰  1  深棕  2  玫瑰棕  3  暗紅
    "ganlanlv", "tailv", "ouhui", "hupozong",                 # 4  橄欖綠  5  苔綠  6  藕灰   7  琥珀棕
    "yanzhihong", "meiguifen", "fanqiehong", "chenghong",     # 8  胭脂紅  9  玫瑰粉 10 番茄紅 11 橙紅
    "bohelv", "jincheng", "fuse", "xincheng",                 # 12 薄荷綠  13 金橙  14 膚色  15 杏橙
    "laimeng", "huang", "ganlanlv2", "zihong",                # 16 萊姆綠  17 黃色  18 鋼藍  19 紫紅
    "shiya", "tiankong", "zhonghui", "lanhui",                # 20 矢車菊藍 21 天空藍 22 中灰 23 藍灰
    "taofen", "danjin", "xunyi", "fen",                       # 24 桃粉   25 淡金  26 薰衣草 27 粉紅
    "bohe", "yinhui", "luhui", "naiyu",                       # 28 薄荷   29 銀灰  30 淡蘆薈 31 奶油
    "xunyi2", "jingbai",                                      # 32 薰衣草白 33 近白
]

# ═══════════════════════════════════════════════════════════════════
# 組合清單
# ═══════════════════════════════════════════════════════════════════
COMBINATIONS = []

# ── 1. 34 個透明背景版本 ──────────────────────────────────────────
for idx in range(34):
    COMBINATIONS.append((idx, None))

# ── 2. 自訂雙色組合（去重後合併）────────────────────────────────
CUSTOM_COMBOS = []

def add_combo(fg, bg):
    """僅在不重複時加入"""
    if (fg, bg) not in CUSTOM_COMBOS and fg != bg:
        CUSTOM_COMBOS.append((fg, bg))

# ┄┄ 2A：mrmotext_world_tileset.tres 中出現過的所有組合（城堡系列）
# （來源：generate_palette_pngs.py CUSTOM_COMBOS 第 1 批）
add_combo(29, 0)   # 銀灰 + 深棕灰（普通磚牆）
add_combo( 6, 2)   # 藕灰 + 玫瑰棕（陰影磚牆）
add_combo(22, 1)   # 中灰 + 深棕（暗色磚牆）
add_combo(22, 2)   # 中灰 + 玫瑰棕
add_combo(29,23)   # 銀灰 + 藍灰（藍調磚牆）
add_combo(29, 6)   # 銀灰 + 藕灰
add_combo(22, 6)   # 中灰 + 藕灰
add_combo(29,22)   # 銀灰 + 中灰

# 土地、草地（城堡系列第 2 批）
add_combo( 4, 1)   # 橄欖綠 + 深棕（草地與泥土）
add_combo( 4, 2)   # 橄欖綠 + 玫瑰棕
add_combo( 5, 2)   # 苔綠 + 玫瑰棕
add_combo(12, 1)   # 薄荷綠 + 深棕（亮色草地）
add_combo(13, 2)   # 金橙 + 玫瑰棕（觸手/植物）
add_combo(11, 7)   # 橙紅 + 琥珀棕
add_combo( 8, 7)   # 胭脂紅 + 琥珀棕

# ┄┄ 2B：所有前景色 on 最黑（index 0）—— 與 mrmotext_world_tileset 完全一致
for fg_idx in range(1, 34):   # 跳過 0（同色）
    add_combo(fg_idx, 0)

# ┄┄ 2C：地牢石牆系列（加深加暗，強調地下感）
add_combo(22, 0)   # 中灰 + 深棕灰
add_combo(29, 1)   # 銀灰 + 深棕
add_combo( 6, 0)   # 藕灰 + 深棕灰
add_combo( 6, 1)   # 藕灰 + 深棕
add_combo(30, 0)   # 淡蘆薈 + 深棕灰（苔蘚石牆）
add_combo(30, 1)   # 淡蘆薈 + 深棕

# ┄┄ 2D：地牢逆色系列（前景較暗，背景較亮—用於發光牆面/窗口光源）
add_combo( 0,29)   # 深棕灰 + 銀灰（逆色磚）
add_combo( 1,22)   # 深棕 + 中灰（深色夾板）
add_combo( 0,22)   # 深棕灰 + 中灰
add_combo( 2,29)   # 玫瑰棕 + 銀灰

# ┄┄ 2E：魔法/禁忌地牢（藍紫系，神秘感）
add_combo(20, 0)   # 矢車菊藍 + 深棕灰
add_combo(20, 1)   # 矢車菊藍 + 深棕
add_combo(21, 0)   # 天空藍 + 深棕灰（魔法牆面）
add_combo(21, 1)   # 天空藍 + 深棕
add_combo(18, 0)   # 鋼藍 + 深棕灰
add_combo(18, 1)   # 鋼藍 + 深棕
add_combo(19, 0)   # 紫紅 + 深棕灰（禁忌）
add_combo(19, 1)   # 紫紅 + 深棕
add_combo(23, 0)   # 藍灰 + 深棕灰
add_combo(23, 1)   # 藍灰 + 深棕
add_combo(26, 0)   # 薰衣草 + 深棕灰（神秘）
add_combo(26, 1)   # 薰衣草 + 深棕
add_combo(20,18)   # 矢車菊藍 + 鋼藍（純藍魔法）
add_combo(21,20)   # 天空藍 + 矢車菊藍
add_combo(19,18)   # 紫紅 + 鋼藍（魔法禁忌混合）

# ┄┄ 2F：熔岩/危險地牢（紅橙系，高溫感）
add_combo(10, 0)   # 番茄紅 + 深棕灰（危險警示）
add_combo(10, 1)   # 番茄紅 + 深棕
add_combo(10, 7)   # 番茄紅 + 琥珀棕（熔岩）
add_combo(11, 0)   # 橙紅 + 深棕灰
add_combo( 8, 0)   # 胭脂紅 + 深棕灰（血腥）
add_combo( 8, 1)   # 胭脂紅 + 深棕
add_combo(17, 7)   # 黃色 + 琥珀棕（燃燒感）
add_combo(13, 7)   # 金橙 + 琥珀棕（火焰磚）
add_combo(10, 3)   # 番茄紅 + 暗紅（深紅熔岩）
add_combo( 8, 3)   # 胭脂紅 + 暗紅

# ┄┄ 2G：腐朽/不死地牢（綠系，毒素/苔蘚）
add_combo( 4, 0)   # 橄欖綠 + 深棕灰（苔蘚石牆）
add_combo( 4, 2)   # 橄欖綠 + 玫瑰棕（已在城堡系列，dedup 會跳過）
add_combo( 5, 0)   # 苔綠 + 深棕灰
add_combo( 5, 1)   # 苔綠 + 深棕
add_combo(12, 0)   # 薄荷綠 + 深棕灰（藻類）
add_combo(16, 0)   # 萊姆綠 + 深棕灰（毒液）
add_combo(16, 1)   # 萊姆綠 + 深棕
add_combo( 4, 7)   # 橄欖綠 + 琥珀棕（枯木/木材）
add_combo(12, 4)   # 薄荷綠 + 橄欖綠（苔層疊加）

# ┄┄ 2H：神聖/光明地牢（金白系，聖殿感）
add_combo(33, 0)   # 近白 + 深棕灰（大理石磚）
add_combo(31, 0)   # 奶油 + 深棕灰（石灰石）
add_combo(25, 0)   # 淡金 + 深棕灰（金箔裝飾）
add_combo(25, 1)   # 淡金 + 深棕（金色牆壁）
add_combo(17, 0)   # 黃色 + 深棕灰（金磚）
add_combo(17, 1)   # 黃色 + 深棕
add_combo(33, 25)  # 近白 + 淡金（神聖大理石）
add_combo(31, 25)  # 奶油 + 淡金
add_combo(25,17)   # 淡金 + 黃色（純金牆）

# ┄┄ 2I：冰雪/寒冷地牢（藍白系，凍結感）
add_combo(33, 23)  # 近白 + 藍灰（霜雪磚）
add_combo(31, 23)  # 奶油 + 藍灰
add_combo(29, 20)  # 銀灰 + 矢車菊藍（冰牆）
add_combo(33, 20)  # 近白 + 矢車菊藍（純冰磚）
add_combo(21,23)   # 天空藍 + 藍灰（深冰）
add_combo(28, 20)  # 薄荷 + 矢車菊藍（薄荷冰磚）
add_combo(28,21)   # 薄荷 + 天空藍

# ┄┄ 2J：血肉/肉質地牢（粉紅系，恐怖感）
add_combo( 9, 3)   # 玫瑰粉 + 暗紅（血肉牆）
add_combo(24, 3)   # 桃粉 + 暗紅
add_combo(27, 3)   # 粉紅 + 暗紅
add_combo( 9, 8)   # 玫瑰粉 + 胭脂紅
add_combo(15, 8)   # 杏橙 + 胭脂紅（肉塊）
add_combo(14, 3)   # 膚色 + 暗紅

# ┄┄ 2K：機械/鐵器地牢（鐵灰系，機械感）
add_combo(29, 2)   # 銀灰 + 玫瑰棕（鐵鏽板）
add_combo(22, 7)   # 中灰 + 琥珀棕（生鏽金屬）
add_combo(29, 7)   # 銀灰 + 琥珀棕（老鐵板）
add_combo(13, 0)   # 金橙 + 深棕灰（黃銅機關）
add_combo(25, 7)   # 淡金 + 琥珀棕（銅製齒輪）
add_combo(23, 7)   # 藍灰 + 琥珀棕（藍鋼板）

# ┄┄ 2L：雙色地牢地板/天花板特效組合（fg 暗 bg 較亮，製造磚縫感）
add_combo( 0, 6)   # 深棕灰 + 藕灰（地板磚縫）
add_combo( 1, 6)   # 深棕 + 藕灰
add_combo( 0,23)   # 深棕灰 + 藍灰（石板地面）
add_combo( 1,29)   # 深棕 + 銀灰（亮色地板）
add_combo( 2, 6)   # 玫瑰棕 + 藕灰（磚道地板）
add_combo( 3, 8)   # 暗紅 + 胭脂紅（血跡地板）

# ────────────────────────────────────────────────────────────────
# 最後：把所有自訂組合加入 COMBINATIONS
for combo in CUSTOM_COMBOS:
    COMBINATIONS.append(combo)

# ════════════════════════════════════════════════════════════════════
def main():
    orig_path = Path("assets/tilesets/dungeonmode/dungeon-mode.png")
    out_dir   = Path("assets/tilesets/dungeonmode/colored")

    if not orig_path.exists():
        print(f"Not found: {orig_path}")
        print("Please copy dungeon-mode.png to assets/tilesets/dungeonmode/ first.")
        sys.exit(1)

    # 清空並重建輸出目錄
    if out_dir.exists():
        for f in out_dir.glob("*.png"):
            f.unlink()
    else:
        out_dir.mkdir(parents=True, exist_ok=True)

    orig    = Image.open(orig_path).convert("RGBA")
    orig_np = np.array(orig, dtype=np.float32) / 255.0
    alpha   = orig_np[:, :, 3:4]
    rgb     = orig_np[:, :, :3]

    # 計算亮度（1-bit 中，白 = 1.0, 黑 = 0.0）
    brightness = (rgb[:,:,0:1]*0.299 + rgb[:,:,1:2]*0.587 + rgb[:,:,2:3]*0.114)
    is_foreground = brightness > 0.1

    print(f"DungeonMode Palette Generator")
    print(f"  Source: {orig_path}  ({orig.width}x{orig.height} px)")
    print(f"  Output: {out_dir}/")
    print(f"  Total combinations: {len(COMBINATIONS)}")
    print(f"    - Transparent bg (T): 34")
    print(f"    - Solid bg (C):       {len(COMBINATIONS) - 34}")
    print()
    t = time.time()

    generated = 0
    for i, (fg_idx, bg_idx) in enumerate(COMBINATIONS):
        fg_color = np.array(PALETTE[fg_idx], dtype=np.float32) / 255.0
        fg_hw = fg_color[np.newaxis, np.newaxis, :]

        result_rgb   = np.zeros_like(rgb)
        result_alpha = np.zeros_like(alpha)

        if bg_idx is None:
            # 透明背景：前景填 fg_color，背景透明
            result_rgb   = fg_hw * brightness
            result_alpha = np.where(is_foreground, 1.0, 0.0)
            fname = f"color_T_{fg_idx:02d}_{NAMES[fg_idx]}.png"
        else:
            # 實心背景：前景 fg_color，背景 bg_color
            bg_color = np.array(PALETTE[bg_idx], dtype=np.float32) / 255.0
            bg_hw    = bg_color[np.newaxis, np.newaxis, :]
            result_rgb   = bg_hw + (fg_hw - bg_hw) * brightness
            result_alpha = np.ones_like(alpha)
            fname = f"color_C_fg{fg_idx:02d}_bg{bg_idx:02d}_{NAMES[fg_idx]}_{NAMES[bg_idx]}.png"

        result = np.zeros_like(orig_np)
        result[:,:,:3] = np.clip(result_rgb, 0, 1)
        result[:,:,3:4] = result_alpha

        Image.fromarray((result*255).astype("uint8"), "RGBA").save(out_dir / fname)
        generated += 1

        if (i + 1) % 50 == 0:
            print(f"  [{i+1}/{len(COMBINATIONS)}] ...", flush=True)

    elapsed = time.time() - t
    print()
    print(f"[DONE] Generated {generated} PNG files in {elapsed:.2f}s")
    print(f"Next steps:")
    print(f"  1. Open Godot → FileSystem panel → Rescan Project")
    print(f"  2. Run scripts/utils/build_dungeon_palette_sources.gd (Ctrl+Shift+X)")

if __name__ == "__main__":
    main()
