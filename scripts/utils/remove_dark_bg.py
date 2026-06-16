"""
§R-5: generate-with-style-v2 黑背景後處理腳本
用途：把 V3b style-v2 生成的黑背景圖轉為透明背景
"""
import sys, os
from PIL import Image
import numpy as np

sys.stdout.reconfigure(encoding='utf-8')

V3B_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v3b'


def remove_dark_bg(input_path, output_path, threshold=30):
    """把暗色背景轉為透明"""
    img = Image.open(input_path).convert('RGBA')
    data = np.array(img)
    r, g, b, a = data[:,:,0], data[:,:,1], data[:,:,2], data[:,:,3]
    dark_mask = (r < threshold) & (g < threshold) & (b < threshold)
    data[:,:,3] = np.where(dark_mask, 0, 255)
    result = Image.fromarray(data)
    result.save(output_path)
    # 統計透明像素
    transparent = int(dark_mask.sum())
    total = data.shape[0] * data.shape[1]
    print(f'  [BG REMOVED] {os.path.basename(output_path)} '
          f'(transparent: {transparent}/{total} = {transparent/total*100:.1f}%)')
    return output_path


if __name__ == '__main__':
    print('='*60)
    print('§R-5 黑背景去除 — V3b style-v2 圖片後處理')
    print('='*60)

    # 找出所有 style-v2 生成的圖（可能有黑背景）
    target_files = [
        f for f in os.listdir(V3B_DIR)
        if f.startswith('V3b_stylev2_') and f.endswith('.png')
    ]

    if not target_files:
        print('  [SKIP] 沒有找到 V3b_stylev2_*.png 文件')
        sys.exit(0)

    # 輸出目錄（加 _nobg 後綴）
    nobg_dir = os.path.join(V3B_DIR, 'nobg')
    os.makedirs(nobg_dir, exist_ok=True)

    for fname in sorted(target_files):
        src = os.path.join(V3B_DIR, fname)
        dst_name = fname.replace('.png', '_nobg.png')
        dst = os.path.join(nobg_dir, dst_name)
        remove_dark_bg(src, dst, threshold=30)

    print()
    print(f'Output dir: {nobg_dir}')
    print(f'Processed: {len(target_files)} files')
