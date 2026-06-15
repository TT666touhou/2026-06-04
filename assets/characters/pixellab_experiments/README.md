# PixelLab Experiment Characters v3
> Generated: 2026-06-15 v3 | Designer Role | §O-REF Maintained

## 生成說明

基底服裝/外型提示詞：
> "pixel art, retro anime game sprite, a cute girl with **bright vivid scarlet red hair** in twin tails (NOT dark red), wearing a white ruffled blouse with a black ribbon tie, a high-waisted black gothic pleated skirt with silver buckles, Japanese RPG style, pixel perfect, flat shading, contrast lighting, crisp edges"

**v3 變更**：
- 取消配色限制（不再強制使用 VfxMix 34色）
- 頭髮指定為亮紅色（scarlet red，非暗色）
- 橫向卷軸視角（`view: "side"`, `direction: "south"`）
- 每次生成設置 120-150 秒 timeout 保護，防止卡住

## 生成結果

| 檔案 | 尺寸 | 輪廓 | 細節 | 耗時 |
|------|------|------|------|------|
| `v3_16x16.png` | 16×16 | lineless | medium | 36s |
| `v3_32x32.png` | 32×32 | lineless | highly detailed | 45s |
| `v3_32x64_DS.png` | 32×64 | selective outline | highly detailed | 40s |

## Dungeon Slasher 風格（v3 分析）
- 參考：用戶提供的 dungeonslasher.wiki 截圖
- 比例：5-6 頭身動漫比例（直立全身，非 chibi）
- 尺寸：32×64 px（寬高比 1:2，兩格 tile 高度）
- 描邊：`selective outline`（適度保留描邊）
- 細節：highly detailed，多層陰影

## 共同設定
- API：`POST https://api.pixellab.ai/v2/create-image-pixen`
- `view: "side"`, `direction: "south"`, `no_background: true`
- 無配色限制

## 帳戶狀態（本批次後）
- Plan: Tier 1: Pixel Apprentice
- 本批次消耗：3 次
- 估算剩餘：~1986