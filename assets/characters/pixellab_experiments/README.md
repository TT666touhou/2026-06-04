# PixelLab Experiment Characters v2
> Generated: 2026-06-15 v2 | Designer Role | §O-REF Maintained

## 生成說明

以原始提示詞：
> "32x32 pixel art, retro anime game sprite, a cute girl with red hair in twin tails, wearing a white blouse with oversized puffy white sleeves and intricate ruffled cuffs, a black ribbon tie, a high-waisted black gothic pleated skirt with silver buckles, Japanese RPG style, pixel perfect, flat shading, crisp edges"

為基礎，針對三種尺寸/風格進行變化，同時套用 VfxMix 34色配色表限制（透過 Prompt 描述，因 v2 pixen 不支援 `color_palette` 參數）。

## 生成結果

| 檔案 | 尺寸 | 輪廓 | 細節 | 說明 |
|------|------|------|------|------|
| `v2_16x16.png` | 16×16 | lineless | medium | 最小尺寸，簡化但保有識別度 |
| `v2_32x32.png` | 32×32 | lineless | highly detailed | 標準尺寸，原始提示詞完整呈現 |
| `v2_32x64_DS.png` | 32×64 | selective outline | highly detailed | Dungeon Slasher 風格，5-6頭身動漫比例 |

## Dungeon Slasher 風格說明
- 基於 dungeonslasher.wiki 截圖分析
- **非 chibi**：5-6 頭身動漫比例（直立全身）
- 高細節度：多層陰影，服裝細節豐富
- 使用 `selective outline`（保留適度描邊）
- 尺寸 32×64（寬高比 1:2）

## 共同限制
- API：`POST https://api.pixellab.ai/v2/create-image-pixen`
- view: `"side"`, direction: `"south"`, no_background: `true`
- 配色：VfxMix 34色（Prompt 文字描述方式限制）
  - 紅髮：#E55C5C | 白袖：#F2F9F8 / #F1E9D4 | 黑裙：#363232
  - 肌膚：#D49C73 | 扣件：#C2C2C2 | 陰影：#AB6E7C

## 帳戶狀態（本批次後）
- 剩餘：~1987 次（已消耗 3 次）