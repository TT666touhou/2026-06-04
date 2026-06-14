#!/usr/bin/env python3
"""
generate_convex_physics_script.py
====================================================
讀取 MRMOTEXT_EX.png，對 32×32 格的每個 8×8 tile 計算凸包絡，
生成 GDScript EditorScript (auto_gen_convex_physics_T_sources.gd)。
在 Godot Editor 中執行生成的 GDScript，即可自動更新
mrmotext_world_tileset.tres 內所有 [T] Source 的 physics layer 0。

使用方法（在專案根目錄執行）：
    python scripts/tools/generate_convex_physics_script.py

依賴：
    pip install Pillow numpy  (numpy 已被 generate_dungeon_palette_pngs.py 使用)
"""

import sys
import re
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
except ImportError as e:
    print(f"[ERROR] 缺少依賴：{e}")
    print("請執行：pip install Pillow numpy")
    sys.exit(1)

# ── 路徑設定 ────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent.parent  # d:/2026-06-04/
SOURCE_PNG    = ROOT / "assets" / "tilesets" / "mrmotext" / "MRMOTEXT_EX.png"
TILESET_TRES  = ROOT / "assets" / "tilesets" / "mrmotext" / "mrmotext_world_tileset.tres"
OUTPUT_GD     = ROOT / "scripts" / "utils" / "auto_gen_convex_physics_T_sources.gd"

# ── 常數 ─────────────────────────────────────────────────────────────────────
TILE_W = 8                 # px
TILE_H = 8                 # px
GRID_COLS = 32             # MRMOTEXT_EX.png 橫向格數
GRID_ROWS = 32             # MRMOTEXT_EX.png 縱向格數
BRIGHTNESS_THRESHOLD = 0.1 # 亮度閾值，大於此值視為前景像素
# Godot 座標範圍：tile 中心 = (0,0)，8px tile → -4.0 to 4.0


# ══════════════════════════════════════════════════════════════════════════════
# 凸包絡算法（Andrew's Monotone Chain）
# ══════════════════════════════════════════════════════════════════════════════

def _cross2d(O, A, B):
    """向量 OA × OB 的 z 分量（二維叉積）"""
    return (A[0] - O[0]) * (B[1] - O[1]) - (A[1] - O[1]) * (B[0] - O[0])


def convex_hull(points):
    """
    Andrew's Monotone Chain 凸包絡算法。
    輸入：(x, y) tuple 的列表（可包含重複點）
    輸出：凸包頂點列表，CCW 順序（Y-down 坐標中視覺上為 CW）
    最少 1 個點可輸入，少於 3 點的退化情況會返回所有去重點。
    """
    pts = sorted(set(map(lambda p: (float(p[0]), float(p[1])), points)))
    n = len(pts)
    if n <= 2:
        return pts  # 退化：直接返回

    # 建立下包（lower hull）
    lower = []
    for p in pts:
        while len(lower) >= 2 and _cross2d(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)

    # 建立上包（upper hull）
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and _cross2d(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)

    # 去除首尾重複點（lower[-1] == upper[0]，upper[-1] == lower[0]）
    return lower[:-1] + upper[:-1]


# ══════════════════════════════════════════════════════════════════════════════
# 計算單個 Tile 的凸包絡（Godot 座標）
# ══════════════════════════════════════════════════════════════════════════════

def compute_tile_hull(img_np, col, row):
    """
    計算 tile (col, row) 的凸包絡頂點。
    img_np : H×W×3 float32 array，值域 0.0~1.0（來自 MRMOTEXT_EX.png）
    col/row: tile 在 32×32 格中的位置（0-indexed）

    返回：
        None            → 沒有前景像素，不需要碰撞（如空格字符）
        list of (x, y)  → Godot 座標系下的凸包頂點，中心為 (0,0)
    """
    # 截取 8×8 tile 像素（img_np 為 [row, col] 即 [y, x] 索引）
    y0, x0 = row * TILE_H, col * TILE_W
    tile = img_np[y0: y0 + TILE_H, x0: x0 + TILE_W]  # shape (8,8,3)

    # 計算亮度（Rec.601 係數）
    brightness = (
        tile[:, :, 0] * 0.299 +
        tile[:, :, 1] * 0.587 +
        tile[:, :, 2] * 0.114
    )  # shape (8,8)

    # 收集前景像素的 4 個角點（Godot 座標：tile 中心 = 0,0；範圍 -4~4）
    corners = []
    for py in range(TILE_H):
        for px in range(TILE_W):
            if brightness[py, px] > BRIGHTNESS_THRESHOLD:
                # 像素 (px, py) 在 Godot 座標中的 4 個角點
                # 左上角偏移 = px - 4, py - 4（像素 (0,0) 的左上角 = (-4,-4)）
                gx0 = float(px) - 4.0
                gy0 = float(py) - 4.0
                gx1 = gx0 + 1.0
                gy1 = gy0 + 1.0
                corners.extend([
                    (gx0, gy0), (gx1, gy0),
                    (gx0, gy1), (gx1, gy1),
                ])

    if not corners:
        return None  # 全黑 tile，無碰撞

    hull = convex_hull(corners)

    if len(hull) < 3:
        # 退化（所有點共線等）→ 使用前景範圍的包圍矩形
        xs = [p[0] for p in corners]
        ys = [p[1] for p in corners]
        xmn, xmx = min(xs), max(xs)
        ymn, ymx = min(ys), max(ys)
        return [(xmn, ymn), (xmx, ymn), (xmx, ymx), (xmn, ymx)]

    return hull


# ══════════════════════════════════════════════════════════════════════════════
# 解析 .tres 取得 Source 0 的 tile 座標集合
# ══════════════════════════════════════════════════════════════════════════════

def parse_source0_tile_coords(tres_path):
    """
    從 mrmotext_world_tileset.tres 解析 Source 0（第一個 sub_resource）的 tile 座標。
    格式：X:Y/0 = 0 或 X:Y/next_alternative_id = N
    返回 set of (col, row) tuples。
    """
    content = tres_path.read_text(encoding="utf-8")
    coords = set()
    in_source0 = False
    source_idx = 0

    coord_re = re.compile(r'^(\d+):(\d+)/(?:0|next_alternative_id)\s*=')

    for line in content.splitlines():
        if line.startswith('[sub_resource'):
            source_idx += 1
            in_source0 = (source_idx == 1)
        elif source_idx > 1 and in_source0:
            break  # Source 0 結束，後面是 Source 1+

        if in_source0:
            m = coord_re.match(line)
            if m:
                coords.add((int(m.group(1)), int(m.group(2))))

    print(f"  [Parser] Source 0 tile 座標數：{len(coords)}")
    return coords


# ══════════════════════════════════════════════════════════════════════════════
# 生成 GDScript EditorScript
# ══════════════════════════════════════════════════════════════════════════════

def format_hull(hull_pts):
    """將凸包頂點列表轉換為 GDScript PackedVector2Array 字面量"""
    flat = []
    for x, y in hull_pts:
        # 格式化：去掉不必要小數點，保留精度
        flat.append(f"{x:g}")
        flat.append(f"{y:g}")
    return f"PackedVector2Array({', '.join(flat)})"


def generate_gdscript(hull_map, output_path):
    """
    hull_map: dict { (col, row): hull_pts_or_None }
    只輸出有效 hull（非 None）到字典中。
    無 hull 的 tile（空格等）在 GDScript 執行時會清除碰撞。
    """
    lines = []

    # ── 文件頭 ────────────────────────────────────────────────────────────────
    lines += [
        "@tool",
        "extends EditorScript",
        "## auto_gen_convex_physics_T_sources.gd",
        "## [自動生成文件 - 請勿手動修改]",
        "## 由 scripts/tools/generate_convex_physics_script.py 產生",
        "##",
        "## 執行方法：",
        "##   Godot Editor → Script Editor → 開啟此文件",
        "##   → File → Run（或 Ctrl+Shift+X）",
        "##",
        "## 功能：",
        "##   掃描 mrmotext_world_tileset.tres 中所有 [T] Source，",
        "##   為每個 tile 設定基於 MRMOTEXT_EX.png 像素輪廓的凸包絡碰撞多邊形。",
        "",
        'const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"',
        "",
    ]

    # ── 凸包絡數據字典 ─────────────────────────────────────────────────────────
    non_null = {k: v for k, v in hull_map.items() if v is not None}
    null_count = sum(1 for v in hull_map.values() if v is None)
    print(f"  [GDScript] 有效凸包 tile 數（有前景）：{len(non_null)}")
    print(f"  [GDScript] 無前景 tile 數（空格類，將清除碰撞）：{null_count}")

    lines.append("# 凸包絡數據：\"col:row\" -> PackedVector2Array")
    lines.append("# 不在此字典中的 tile 代表無前景像素（碰撞將被清除）")
    lines.append("var _hulls: Dictionary")
    lines.append("")
    lines.append("func _build_hulls() -> Dictionary:")
    lines.append("\treturn {")

    # 按座標排序輸出，方便人工審查
    for (col, row), hull in sorted(non_null.items()):
        key = f"{col}:{row}"
        vec_str = format_hull(hull)
        lines.append(f'\t\t"{key}": {vec_str},')

    lines.append("\t}")
    lines.append("")

    # ── _run() 主函數 ─────────────────────────────────────────────────────────
    lines += [
        "func _run() -> void:",
        "\t_hulls = _build_hulls()",
        "\tvar tileset := load(TILESET_PATH) as TileSet",
        "\tif not tileset:",
        '\t\tpush_error("[auto_gen] 無法載入 TileSet：" + TILESET_PATH)',
        "\t\treturn",
        "",
        "\tvar physics_layer_count := tileset.get_physics_layers_count()",
        "\tif physics_layer_count == 0:",
        '\t\tpush_error("[auto_gen] TileSet 沒有 physics layer，請先在 TileSet 設定頁面新增。")',
        "\t\treturn",
        "",
        "\tvar t_source_count := 0",
        "\tvar total_tile_count := 0",
        "",
        "\tfor si in range(tileset.get_source_count()):",
        "\t\tvar src := tileset.get_source(si) as TileSetAtlasSource",
        "\t\tif src == null:",
        "\t\t\tcontinue",
        "",
        "\t\t# 只處理 [T] 開頭的 Source（透明背景版）",
        '\t\tif not src.resource_name.begins_with("[T]"):',
        "\t\t\tcontinue",
        "",
        "\t\tt_source_count += 1",
        '\t\tprint("[auto_gen] 處理 Source #", si, " : ", src.resource_name)',
        "",
        "\t\tvar tile_count := src.get_tiles_count()",
        "\t\tfor ti in range(tile_count):",
        "\t\t\tvar coords := src.get_tile_id(ti)",
        '\t\t\tvar key := str(coords.x) + ":" + str(coords.y)',
        "\t\t\tvar tdata := src.get_tile_data(coords, 0)",
        "\t\t\tif tdata == null:",
        "\t\t\t\tcontinue",
        "",
        "\t\t\tif key in _hulls:",
        "\t\t\t\t# 設定凸包絡碰撞多邊形",
        "\t\t\t\ttdata.set_collision_polygons_count(0, 1)",
        "\t\t\t\ttdata.set_collision_polygon_points(0, 0, _hulls[key])",
        "\t\t\telse:",
        "\t\t\t\t# 無前景像素：清除碰撞（空格、全黑 tile）",
        "\t\t\t\ttdata.set_collision_polygons_count(0, 0)",
        "\t\t\ttotal_tile_count += 1",
        "",
        "\tvar save_result := ResourceSaver.save(tileset, TILESET_PATH)",
        "\tif save_result != OK:",
        '\t\tpush_error("[auto_gen] 儲存失敗，錯誤碼：" + str(save_result))',
        "\t\treturn",
        "",
        '\tprint("[auto_gen] ✅ 完成！共處理 ", t_source_count, " 個 [T] Source，",',
        '\t\t\ttotal_tile_count, " 個 tile。")',
        '\tprint("[auto_gen] 請在 TileSet Editor 驗證碰撞形狀。")',
    ]

    content = "\n".join(lines) + "\n"
    output_path.write_text(content, encoding="utf-8")
    print(f"  [Output] 已寫入：{output_path}")
    print(f"  [Output] 文件大小：{output_path.stat().st_size:,} bytes")


# ══════════════════════════════════════════════════════════════════════════════
# 主流程
# ══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 60)
    print("Convex Hull Physics Generator for MRMOTEXT_EX.png")
    print("=" * 60)

    # 1. 讀取 PNG
    print(f"\n[Step 1] 讀取 {SOURCE_PNG.name} ...")
    if not SOURCE_PNG.exists():
        print(f"[ERROR] 找不到文件：{SOURCE_PNG}")
        sys.exit(1)

    img = Image.open(SOURCE_PNG).convert("RGB")
    w, h = img.size
    print(f"  圖片尺寸：{w}×{h}px，預期 32×32 格 @ 8×8px")
    assert w == GRID_COLS * TILE_W and h == GRID_ROWS * TILE_H, \
        f"圖片尺寸不符：{w}×{h}（期望 {GRID_COLS*TILE_W}×{GRID_ROWS*TILE_H}）"

    img_np = np.array(img, dtype=np.float32) / 255.0  # H×W×3, 0.0~1.0

    # 2. 解析 Source 0 的 tile 座標（用於過濾：只計算實際使用的 tile）
    print(f"\n[Step 2] 解析 {TILESET_TRES.name} 的 tile 座標 ...")
    if not TILESET_TRES.exists():
        print(f"[ERROR] 找不到文件：{TILESET_TRES}")
        sys.exit(1)

    source0_coords = parse_source0_tile_coords(TILESET_TRES)

    # 3. 計算每個 tile 的凸包絡
    print(f"\n[Step 3] 計算 {len(source0_coords)} 個 tile 的凸包絡 ...")
    hull_map = {}  # (col, row) -> hull_pts | None
    full_tile_count = 0
    empty_tile_count = 0

    for col, row in sorted(source0_coords):
        if col >= GRID_COLS or row >= GRID_ROWS:
            print(f"  [WARN] tile ({col},{row}) 超出圖片範圍，跳過")
            continue
        hull = compute_tile_hull(img_np, col, row)
        hull_map[(col, row)] = hull

        if hull is None:
            empty_tile_count += 1
        elif (len(hull) == 4 and
              hull[0] == (-4.0, -4.0) and hull[1] == (4.0, -4.0) and
              hull[2] == (4.0, 4.0) and hull[3] == (-4.0, 4.0)):
            full_tile_count += 1

    print(f"  全格 tile（所有像素亮）：{full_tile_count}")
    print(f"  空格 tile（無前景像素）：{empty_tile_count}")
    print(f"  其他凸包絡 tile：{len(hull_map) - full_tile_count - empty_tile_count}")

    # 4. 樣本驗證輸出（幫助 review）
    print("\n[Step 4] 樣本凸包絡預覽（抽查幾個有代表性的 tile）：")
    sample_tiles = [
        (0, 0, "tile 0:0 (首字符)"),
        (9, 2, "tile 9:2 ('+' 符號區域)"),
        (0, 2, "tile 0:2 (空格區域)"),
        (5, 11, "tile 5:11 (特殊 tile)"),
    ]
    for col, row, label in sample_tiles:
        if (col, row) in hull_map:
            h = hull_map[(col, row)]
            if h is None:
                print(f"  {label}: [無前景 - 不碰撞]")
            else:
                pts_str = ", ".join(f"({x:g},{y:g})" for x, y in h)
                print(f"  {label}: {len(h)} 頂點 → {pts_str}")
        else:
            print(f"  {label}: [不在 Source 0 中]")

    # 5. 生成 GDScript
    print(f"\n[Step 5] 生成 GDScript → {OUTPUT_GD.name} ...")
    OUTPUT_GD.parent.mkdir(parents=True, exist_ok=True)
    generate_gdscript(hull_map, OUTPUT_GD)

    print("\n" + "=" * 60)
    print("✅ 完成！下一步驟：")
    print("1. 在 Godot Editor 中開啟：")
    print(f"   {OUTPUT_GD.relative_to(ROOT)}")
    print("2. Script Editor → File → Run（Ctrl+Shift+X）")
    print("3. 等待輸出面板顯示 [auto_gen] ✅ 完成")
    print("4. 在 TileSet Editor 驗證碰撞形狀")
    print("=" * 60)


if __name__ == "__main__":
    main()
