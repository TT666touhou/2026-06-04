"""
§R-6: MRMOTEXT 34色色盤採樣腳本
用途：從 MRMOTEXT tileset 的 colored/ 目錄採樣每種前景色，輸出 34 個 HEX 色值
"""
import sys, os
from PIL import Image
import numpy as np

sys.stdout.reconfigure(encoding='utf-8')

COLORED_DIR = r'd:\2026-06-04\assets\tilesets\mrmotext\colored'


def sample_fg_color(tileset_path):
    """從 tileset 圖中採樣前景色（最亮的非黑色像素）"""
    img = Image.open(tileset_path).convert('RGB')
    arr = np.array(img)

    # 計算每個像素的亮度
    brightness = arr[:,:,0].astype(int) + arr[:,:,1] + arr[:,:,2]

    # 取最亮像素（排除純黑 < 30）
    mask = brightness > 90
    if not mask.any():
        return None, None

    bright_pixels = arr[mask]
    # 取中位數顏色（避免噪點）
    r = int(np.median(bright_pixels[:,0]))
    g = int(np.median(bright_pixels[:,1]))
    b = int(np.median(bright_pixels[:,2]))

    hex_color = f'#{r:02X}{g:02X}{b:02X}'
    return hex_color, (r, g, b)


if __name__ == '__main__':
    print('='*60)
    print('§R-6: MRMOTEXT 34色色盤採樣')
    print('='*60)
    print()

    # 只抓 color_T_ 系列（單色 tileset，最代表各色前景色）
    color_files = sorted([
        f for f in os.listdir(COLORED_DIR)
        if f.startswith('color_T_') and f.endswith('.png')
    ])

    print(f'找到 {len(color_files)} 個色彩版本')
    print()

    palette = []
    print('| 編號 | 文件名 | HEX 色值 | RGB |')
    print('|------|--------|---------|-----|')

    for fname in color_files:
        fpath = os.path.join(COLORED_DIR, fname)
        hex_color, rgb = sample_fg_color(fpath)
        if hex_color:
            # 從文件名提取色名
            parts = fname.replace('color_T_', '').replace('.png', '').split('_')
            idx = parts[0]
            name = '_'.join(parts[1:]) if len(parts) > 1 else 'unknown'
            palette.append({'index': idx, 'name': name, 'hex': hex_color, 'rgb': rgb})
            print(f'| {idx} | {name} | {hex_color} | {rgb} |')

    print()
    print(f'共採樣 {len(palette)} 種顏色')

    # 輸出 Python 格式的色盤清單
    print()
    print('# Python 格式（可直接用於 color_image 生成）:')
    print('MRMOTEXT_PALETTE = [')
    for c in palette:
        print(f'    ("{c["hex"]}", "{c["name"]}"),  # fg{c["index"]}')
    print(']')

    # 輸出到文件
    output_path = r'd:\2026-06-04\docs\mrmotext_research\mrmotext_palette.md'
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('# MRMOTEXT 34色色盤\n\n')
        f.write('> 採樣來源：d:\\2026-06-04\\assets\\tilesets\\mrmotext\\colored\\color_T_*.png\n\n')
        f.write('| 編號 | 色名 | HEX | RGB |\n')
        f.write('|------|------|-----|-----|\n')
        for c in palette:
            f.write(f'| fg{c["index"]} | {c["name"]} | `{c["hex"]}` | {c["rgb"]} |\n')
        f.write('\n')
        f.write('```python\n')
        f.write('MRMOTEXT_PALETTE = [\n')
        for c in palette:
            f.write(f'    ("{c["hex"]}", "{c["name"]}"),  # fg{c["index"]}\n')
        f.write(']\n')
        f.write('```\n')

    print()
    print(f'[SAVED] {output_path}')
