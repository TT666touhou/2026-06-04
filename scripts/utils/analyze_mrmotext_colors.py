"""分析 MRMOTEXT colored 資料夾中的配色體系"""
import sys, os, re
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8')

colored_dir = r'd:\2026-06-04\assets\tilesets\mrmotext\colored'

T_data = {}
for f in sorted(os.listdir(colored_dir)):
    if f.startswith('color_T_') and f.endswith('.png') and '.import' not in f:
        m = re.search(r'color_T_(\d+)_(.+)\.png', f)
        if m:
            num = int(m.group(1))
            name = m.group(2)
            img = Image.open(os.path.join(colored_dir, f)).convert('RGBA')
            pixels = list(set(img.getdata()))
            solid = [p for p in pixels if p[3] > 128]
            T_data[num] = {'name': name, 'colors': solid}

print('=== DS 遊戲 MRMOTEXT 配色體系（T_ background palette）===')
for num in sorted(T_data.keys()):
    info = T_data[num]
    if info['colors']:
        r, g, b = info['colors'][0][:3]
        hex_str = '#{:02X}{:02X}{:02X}'.format(r, g, b)
        print('  bg{:02d}  {:<22s}  RGB({:3d},{:3d},{:3d})  {}'.format(num, info['name'], r, g, b, hex_str))
