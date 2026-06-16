# MRMOTEXT 生成實驗日誌

> 建立時間：2026-06-16  
> 目的：記錄所有 MRMOTEXT 風格角色生成的實驗過程、提示詞演化、結果評分

---

## V1（2026-06-15 首次嘗試）

**策略**：直接用文字描述，沒有 style_image  
**端點**：pixflux、create-character-v3  
**結果**：❌ 完全不像 MRMOTEXT，太多 RPG 風格、彩色寫實  
**問題**：
- 沒有提供 MRMOTEXT tileset 作為 style reference
- 描述詞太通用，無法傳達「tile 拼接」的感覺

---

## V2（2026-06-16 第一次系統化嘗試）

**策略**：用 MRMOTEXT 場景截圖作為 style_image  
**端點**：pixflux、pixen、bitforge、generate-with-style-v2  
**style_image**：場景截圖（x3_version.jpg、building_blocks.png）

**結果**：
| 文件名 | 端點 | 評分 | 備注 |
|--------|------|------|------|
| V2_pixflux_desc1.png | pixflux | ⭐⭐ | 科幻機器人感，非圖騰 |
| V2_pixflux_desc2.png | pixflux | ⭐⭐ | 頭盔戰士，太寫實 |
| V2_pixen_lowdetail_0.png | pixen low | ⭐⭐⭐⭐ | **最佳！** 圖騰臉、大色塊 |
| V2_style_v2_0~3.png | style-v2 | ⭐⭐⭐ | 接近方塊人，有 MRMOTEXT 感 |
| V2_bitforge_ss75/85/95.png | bitforge | ❌ | 全噪訊（ERR-040：場景截圖作 style） |

**發現的問題（ERR-036~040）**：
- ERR-036：輪詢用 `complete` 非 `completed`
- ERR-037：圖片路徑 `images[i]["image"]["base64"]` 錯誤
- ERR-038：bitforge `style_strength` 預設 0.0
- ERR-039：`image_size` 格式問題
- ERR-040：bitforge style_image 必須與輸出相同尺寸，且不能是場景截圖

---

## V3b（2026-06-16 用戶 /grill-me 後修正版）

**策略**：MRMOTEXT tileset 本身作為 style_images（突破！）  
**用戶確認需求**：白色單色、透明背景、形狀優先、8×8 tile 拼接感、CP437 電子感

**新 Prompt（確認版）**：
```
white monochrome 2D game character sprite,
assembled from 8x8 pixel tile blocks like MRMOTEXT textmode art,
each body segment is a different glyph tile,
CP437 character block figure,
bold silhouette shape, totem pole proportions,
flat white filled blocks on transparent background,
crisp pixel edges, grid-aligned block construction,
symmetric tile-assembled creature,
text-mode computer art style,
1-bit white silhouette assembled from symbol tiles
```

**負面提示詞（v3b 首次加入）**：
```
photorealistic, 3D render, smooth shading, gradient,
anime, manga, chibi, cartoon,
RPG warrior, armor, knight,
detailed texture, fine detail,
anti-aliasing, blur, soft edges,
human proportions, natural skin,
weapon, sword, shield
```

**style_images**：
1. MRMOTEXT_EX_x3.png（黑白高清 tileset）
2. MRMOTEXT_EX.png（黑白原始 tileset）
3. color_C_fg33（晶白色，最接近白色輸出）
4. color_C_fg22（中灰色）

**端點**：
- generate-with-style-v2（主力，用 4 張 tileset 作 style）
- create-image-pixen（low detail，白色透明）
- create-image-pixflux（color_image 注入 tileset）

**執行時間**：2026-06-16 08:42 UTC  
**狀態**：🔄 進行中（task-598）

### V3b 結果（2026-06-16 08:45 UTC 完成）

| 文件名 | 端點 | 評分 | 備注 |
|--------|------|------|------|
| V3b_stylev2_white_totem_0.png | style-v2 | ⭐⭐⭐⭐ | 黑白方塊機器人，tile 拼接感明顯！接近 MRMOTEXT 電子感 |
| V3b_stylev2_white_totem_1.png | style-v2 | ⭐⭐⭐⭐⭐ | **最佳！** 白色機械人+翅膀符號，每格都是不同符號 tile，完整 CP437 感 |
| V3b_stylev2_white_totem_2.png | style-v2 | ⭐⭐⭐ | 有帽子人形，符號感稍弱但仍有 tile 構成 |
| V3b_stylev2_white_totem_3.png | style-v2 | ⭐⭐⭐⭐ | 棋盤紋理怪物，圖騰感強，tile 拼接明顯 |
| V3b_stylev2_white_glyph_figure_0.png | style-v2 | ⭐⭐⭐⭐ | 機器人正面，大量符號 tile 組成身體，清晰 |
| V3b_stylev2_white_glyph_figure_1.png | style-v2 | ⭐⭐⭐⭐ | 白色機器人，輪廓清晰，圓形符號為關節 |
| V3b_stylev2_white_glyph_figure_2.png | style-v2 | ⭐⭐⭐⭐ | 複雜符號人形，密集 tile 排列，電子感最強 |
| V3b_stylev2_white_glyph_figure_3.png | style-v2 | ⭐⭐⭐⭐⭐ | **最佳！** 純白方塊人，乾淨的 MRMOTEXT tile 輪廓，最接近原版風格 |
| V3b_pixen_white_totem_0.png | pixen | ⭐⭐⭐ | 白色機械武士，太有 RPG 感，缺 tile 拼接感 |
| V3b_pixen_white_glyph_figure_0.png | pixen | ⭐⭐⭐ | 可愛白色機器人，比 V2 pixen 好但 tile 感不夠 |
| V3b_charv3_*.png | create-char-v3 | ❌ | HTTP 422 — `shading`/`direction` 不支援（ERR-041）|

**結論**：
- `generate-with-style-v2 + MRMOTEXT tileset 作 style` = ✅ **成功突破！** 達到電子感/tile拼接感
- `pixen` = 較弱（缺 style_image 引導，只靠描述詞）
- `create-character-v3` = API 參數錯誤需修正

**消耗配額**：~42gen（style-v2 ×2 任務 ~40gen + pixen ×2 ~2gen）  
**剩餘配額**：985.6 gen

---

## 提示詞演化總結

| 版本 | 核心改進 | 主要問題 |
|------|---------|---------|
| V1 | 初次嘗試 | 沒有 style reference，純文字 |
| V2 | 加入場景截圖 style | 場景截圖色彩混亂→bitforge 噪訊 |
| V3b | **tileset 本身作 style** + 白色單色 + 完整負面詞 | 待評估 |

---

## 下一步方向（V4 計劃）

若 V3b style-v2 不夠接近 MRMOTEXT，考慮：
1. **手工組合 tile** — 用 PIL 從 tileset 裁切具體的字元 tile，手工拼出一個模板角色，再用 img2px 縮小
2. **image-to-pixelart 後處理** — 把 V3b 結果縮到 32×32，再用 PIL NEAREST 到 16×16
3. **create-character-v3 + init_image** — 用 V3b pixen 結果作為 init_image 輸入 create-character-v3

---

*mrmotext_generation_log.md v1 建立於 2026-06-16*
