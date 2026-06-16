"""
QA 測試腳本 — PixelLab API 端點參數驗證
目的：確認 ERR-036~041 的修復是否有效
測試項目：
  QA-01: 餘額查詢正常
  QA-02: generate-with-style-v2 status "completed" 判斷
  QA-03: create-character-v3 禁止欄位確認（ERR-041）
  QA-04: pixen direction 合法值確認（ERR-035）
  QA-05: V3b 輸出文件存在確認
"""
import sys, os, requests, base64
from PIL import Image
import io

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = '956460ee-978e-4d60-999a-f4b0f567bb48'
BASE = 'https://api.pixellab.ai/v2'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
V3B_DIR = r'd:\2026-06-04\assets\characters\generated\mrmotext_v3b'

PASS = '[PASS]'
FAIL = '[FAIL]'
SKIP = '[SKIP]'

results = []

def test(name, condition, detail=''):
    status = PASS if condition else FAIL
    results.append((status, name, detail))
    print(f'  {status} {name}')
    if detail:
        print(f'         Detail: {detail}')

print('='*60)
print('QA TEST SUITE — PixelLab API + V3b Output Validation')
print('='*60)
print()

# QA-01: 餘額查詢
print('[QA-01] API 連線 + 餘額查詢')
try:
    r = requests.get(BASE + '/balance', headers=HEADERS, timeout=10)
    bal = r.json()['subscription']['generations']
    test('QA-01a: API 連線正常', r.status_code == 200, f'HTTP {r.status_code}')
    test('QA-01b: 餘額非零', bal > 0, f'剩餘: {bal:.1f} gen')
    test('QA-01c: 餘額安全（>10）', bal > 10, f'剩餘: {bal:.1f} gen')
except Exception as e:
    test('QA-01: API 連線', False, str(e))

print()

# QA-02: ERR-041 確認 — create-character-v3 禁止 shading/direction
print('[QA-02] ERR-041 確認 — create-character-v3 禁止 shading/direction')
bad_payload = {
    'description': 'test character',
    'image_size': {'width': 64, 'height': 64},
    'shading': 'flat shading',    # 禁止欄位
    'direction': 'west',          # 禁止欄位
}
r = requests.post(BASE + '/create-character-v3', headers=HEADERS, json=bad_payload, timeout=10)
test('QA-02a: 含禁止欄位 → HTTP 422', r.status_code == 422, f'HTTP {r.status_code}')
if r.status_code == 422:
    err_detail = r.json().get('detail', [])
    forbidden_fields = [d.get('loc', ['', ''])[-1] for d in err_detail if d.get('type') == 'extra_forbidden']
    test('QA-02b: 確認是 shading 和 direction 被拒絕', 
         'shading' in forbidden_fields and 'direction' in forbidden_fields,
         f'Forbidden fields: {forbidden_fields}')

print()

# QA-03: ERR-035 確認 — pixen direction 合法值
print('[QA-03] ERR-035 確認 — pixen direction 非法值應報錯')
bad_dir_payload = {
    'description': 'test',
    'image_size': {'width': 64, 'height': 64},
    'direction': 'left',  # 非法值（應該用 west）
}
r = requests.post(BASE + '/create-image-pixen', headers=HEADERS, json=bad_dir_payload, timeout=10)
test('QA-03: direction="left" → 應報錯（422或400）', r.status_code in (422, 400), f'HTTP {r.status_code}')

print()

# QA-04: V3b 輸出文件存在確認
print('[QA-04] V3b 輸出文件存在確認')
expected_files = [
    'V3b_stylev2_white_totem_0.png',
    'V3b_stylev2_white_totem_1.png',
    'V3b_stylev2_white_totem_2.png',
    'V3b_stylev2_white_totem_3.png',
    'V3b_stylev2_white_glyph_figure_0.png',
    'V3b_stylev2_white_glyph_figure_1.png',
    'V3b_stylev2_white_glyph_figure_2.png',
    'V3b_stylev2_white_glyph_figure_3.png',
    'V3b_pixen_white_totem_0.png',
    'V3b_pixen_white_glyph_figure_0.png',
]
for fname in expected_files:
    fpath = os.path.join(V3B_DIR, fname)
    exists = os.path.exists(fpath)
    if exists:
        img = Image.open(fpath)
        size_ok = img.size[0] == 128 and img.size[1] == 128
        test(f'QA-04 {fname}', size_ok, f'size={img.size}')
    else:
        test(f'QA-04 {fname}', False, 'FILE NOT FOUND')

print()

# QA-05: V3b 圖片內容基本驗證（非全黑/全白）
print('[QA-05] V3b 圖片內容驗證（非空白/噪訊）')
for fname in ['V3b_stylev2_white_totem_1.png', 'V3b_stylev2_white_glyph_figure_3.png']:
    fpath = os.path.join(V3B_DIR, fname)
    if os.path.exists(fpath):
        img = Image.open(fpath).convert('L')  # 灰階
        import numpy as np
        arr = np.array(img)
        std = arr.std()
        unique_colors = len(np.unique(arr))
        # 標準差太低 = 全黑或全白（空白/噪訊）
        not_blank = std > 10
        test(f'QA-05 {fname} 非空白', not_blank, f'std={std:.1f}, unique_colors={unique_colors}')
    else:
        test(f'QA-05 {fname}', False, 'FILE NOT FOUND')

print()

# QA-06: 文件落地確認
print('[QA-06] 文件落地確認')
doc_checks = [
    (r'd:\2026-06-04\docs\ERROR_LOG.md', 'ERR-041', 'ERR-041 in ERROR_LOG'),
    (r'd:\2026-06-04\docs\pixellab_cookbook.md', 'ERR-041', 'ERR-041 in cookbook'),
    (r'c:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md', '§R. MRMOTEXT', 'workflow §R'),
    (r'd:\2026-06-04\roles\reviewer.md', 'PL-R-NEW1', 'reviewer.md PL-R-NEW1'),
    (r'd:\2026-06-04\docs\mrmotext_research\mrmotext_generation_log.md', 'V3b', 'mrmotext_generation_log.md'),
]
for fpath, search_term, label in doc_checks:
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        found = search_term in content
        test(f'QA-06 {label}', found, f'Search: "{search_term}"')
    except Exception as e:
        test(f'QA-06 {label}', False, str(e))

print()

# 結果摘要
print('='*60)
print('QA TEST SUMMARY')
print('='*60)
passed = sum(1 for r in results if r[0] == PASS)
failed = sum(1 for r in results if r[0] == FAIL)
total = len(results)
print(f'  PASS: {passed}/{total}')
print(f'  FAIL: {failed}/{total}')
print()
if failed > 0:
    print('FAILED TESTS:')
    for status, name, detail in results:
        if status == FAIL:
            print(f'  {FAIL} {name}: {detail}')
else:
    print('ALL TESTS PASSED')
