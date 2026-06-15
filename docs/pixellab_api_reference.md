# PixelLab API 全功能參考表

> **維護者**：Designer ROLE
> **Last Updated: 2026-06-15** (v2 pixen schema 確認)
> **操作規則**：所有 API 呼叫由用戶明確指示後才執行。AI 不主動生成。
> **禁止瀏覽器（§O-NOBROWSER）**：所有 API 查詢（餘額、角色列表等）必須使用 PowerShell `Invoke-RestMethod`，嚴格禁止 `browser_subagent`。
> **參考**：workflow.md §O | GDD § 3.2 角色組成架構

---

## 帳戶狀態

| 項目 | 狀態 |
|---|---|
| 帳戶類型 | **Tier 1: Pixel Apprentice** |
| 方案類型 | `generations`（次數制）|
| 總額度 | **2000 次 / 月** |
| 剩餘次數 | **~1990 次**（2026-06-15 實驗後）|
| Pro 功能 | 需升級 Pro 方案才可使用 |

> ✅ 帳戶正常可用，剩餘額度充足。

---

## 一、圖片生成（Create Image）

### 1. create-image-pixflux（最快，同步返回）
- **描述**：文字 → 像素圖，最快端點
- **尺寸支援**：32x32 ~ 400x400
- **關鍵參數**：
  - `description`：角色/物件描述（英文效果最佳）
  - `image_size`：{width, height}
  - `no_background`：bool（透明背景）
  - `init_image`：base64 參考圖（可選）
  - `color_palette`：陣列格式 `["#FF8C42", "#2B2D42"]`（強制配色）

### 2. create-image-pixen（精細控制）
- **端點**：`POST https://api.pixellab.ai/v2/create-image-pixen`
- **尺寸支援**：16x16 ~ 768px（寬高均須整除 4，面積 ≤ 512×512）
- **必填參數**：`description`（string）、`image_size`（{width, height}）
- **選填參數**：
  - `outline`：`"single color black outline"` / `"single color outline"` / `"selective outline"` / `"lineless"`
  - `detail`：`"low detail"` / `"medium detail"` / `"highly detailed"`（預設 `"highly detailed"`）
  - `view`：`"side"` / `"low top-down"` / `"high top-down"`
  - `direction`：`"north"` / `"north-east"` / `"east"` / `"south-east"` / `"south"` / `"south-west"` / `"west"` / `"north-west"`
  - `no_background`：bool（透明背景）
  - `seed`：int（固定隨機種子）
  - `enhance_prompt`：bool（自動優化 Prompt，+0.05 次）

> ⚠️ **v2 pixen 不支援 `color_palette`**（v1 限定功能）。配色需在 Prompt 文字描述中指定。

### 3. create-image-bitforge（風格遷移）
- **尺寸支援**：最大 200x200
- **新增參數**：`style_image`（風格參考圖 base64）

### 4. generate-image-v2（Pro 批量）⚠️ 需 Pro
- 一次生成多張供選擇（≤42px 生成64張、<85px 生成16張...）
- 最大 512x512，支援4張參考圖

### 5. generate-with-style-v2（Pro 風格匹配）⚠️ 需 Pro
- 用 1-4 張參考圖的風格生成新圖

---

## 二、動畫生成（Animate）

### 6. animate-with-text-v3（推薦，最新異步）
- **輸入**：`first_frame`（base64）+ `action` 描述 + `frame_count`
- **frame_count 建議**：
  - 4幀：簡單循環（idle）
  - 8幀：行走、攻擊動作
  - 16幀：複雜動作
- **尺寸限制**：最大 256x256；`width × height × frames ≤ 524,288`
- **動作描述範例**：`walking forward` / `swinging sword` / `idle breathing` / `jumping` / `falling down`
- **執行方式**：**異步**，需 Poll `/background-jobs/{id}`，約 30-180 秒

### 7. animate-with-text（舊版同步）
- **支援**：只能 64x64
- **參數**：`description` + `action` + `view` + `direction` + `n_frames` + `color_palette`

### 8. animate-with-skeleton（精確骨架控制）
- 手動指定骨架關鍵點 → 精確動作控制
- 通常配合 `estimate-skeleton` 先偵測骨架

### 9. interpolation-v2（Pro，補間）⚠️ 需 Pro
- 兩個關鍵幀之間生成中間過渡幀

### 10. edit-animation-v2（Pro，動畫編輯）⚠️ 需 Pro
- 對整組動畫幀套用文字編輯
- 例：`add a red cape` / `make it glow blue` / `add armor`

### 11. transfer-outfit-v2（Pro，服裝移植）⚠️ 需 Pro
- 把參考圖的服裝套用到動畫幀

---

## 三、旋轉/方向（Rotate）

### 12. rotate（基礎，單幀轉向）
- 一張圖轉換到另一個方向
- **支援尺寸**：16x16 / 32x32 / 64x64 / 128x128
- **參數**：`from_image` + `from_direction` + `to_direction` + `color_palette`

### 13. generate-8-rotations-v2（Pro，8方向）⚠️ 需 Pro
- 一次生成8方向（南/西南/西/西北/北/東北/東/東南）
- 3種方法：`rotate_character`（已有角色）/ `create_with_style`（文字描述）/ `create_from_concept`（概念圖）

### 14. generate-8-rotations-v3（最新8方向）
- 從參考幀生成8方向，最大 256x256

---

## 四、編輯/修改（Edit）

### 15. edit-image（基礎編輯）
- 對現有像素圖做文字描述編輯

### 16. inpaint（遮罩塗改）
- `mask_image`：白=重繪，黑=保留
- 可配合 `color_palette` 保持配色一致

### 17. inpaint-v3（Pro Inpainting）⚠️ 需 Pro
- 最大 512x512，支援上下文圖

### 18. edit-images-v2（Pro，批量編輯）⚠️ 需 Pro
- 同時編輯多張圖（整套動畫添加相同裝飾）

---

## 五、圖片操作（Image Operations）

### 19. resize（AI 智能縮放）
- 建議每次不超過 2 倍
- 支援 `color_palette`

### 20. image-to-pixelart
- 把普通圖片/照片/手繪轉為像素風格

### 21. remove-background
- 移除背景 → 透明 PNG

---

## 六、地圖/場景生成（Map）

| Endpoint | 用途 |
|---|---|
| create-tileset | 俯視角 Wang Tileset |
| create-tileset-sidescroller | **側視角平台遊戲瓦片集（與本遊戲風格一致）** |
| create-isometric-tile | 等角視角瓦片 |
| map-objects | 透明背景地圖物件（樹/道具/建築）|

---

## 七、角色系統（Character Management）

| Endpoint | 用途 |
|---|---|
| create-character-v3 | 最新8方向角色，自動處理方向和背景 |
| create-character-with-4-directions | 4方向角色（儲存帳戶）|
| create-character-pro | Pro 8方向高品質角色 ⚠️ 需 Pro |
| animate-character | 對已有角色添加動畫 |
| create-character-state | 創建角色新狀態（受傷/死亡等）|
| GET /characters | 列出所有已建立角色 |
| GET /characters/{id}/zip | 匯出角色 ZIP 包 |

---

## 八、Prompt 優化工具

| Endpoint | 用途 |
|---|---|
| enhance-pixen-prompt | 把簡短描述擴充成詳細 Prompt |
| enhance-character-v3-prompt | 專為 character-v3 優化 Prompt |
| enhance-animation-v3-prompt | 專為動畫優化 Prompt |
| estimate-skeleton | 從圖片自動偵測骨架關鍵點 |

---

## 配色控制（color_palette 參數）

> ⚠️ **v2 pixen 不支援 `color_palette`**。配色只能在 prompt 文字中描述。

支援 `color_palette` 的端點：pixflux、bitforge、rotate、animate（舊版）
```json
["#FF8C42", "#2B2D42", "#8D99AE", "#EF233C"]
```

- pixen 中需在 prompt 描述：`"using restricted color palette: near-white (#F2F9F8), tomato red (#E55C5C)..."`
- VfxMix 34 色 HEX 值定義於 `scripts/utils/palette_applicator.gd`

### 本專案調色盤（GDD § 2.1）

| 用途 | Hex | 說明 |
|---|---|---|
| 背景暗色 | `#363232` / `#453C3C` | VfxMix 34色第 0/1 |
| 目前普通敵人 | `#FFFFFF`（原色白） | 待天敵人色彩為 [DRAFT] |
| 玩家顏色 | **[DRAFT 待用戶確認]** | GDD §6.1 尚未確定，將待討論後填入此處 |

> VfxMix 34 色全色表請參考 `assets/vfxmix/palette.pal`

---

## Tier 1 配額消耗

| 動作 | 消耗 |
|---|---|
| pixen / pixflux 生成單張圖 | 1 次 |
| 動畫（任何幀數）| 1 次 |
| 旋轉 / Resize / 去背 / 骨架偵測 | 各 1 次 |
| enhance-pixen-prompt（Prompt 優化）| 0.05 次 |
| Pro 系列 | ⚠️ 需升級 Pro 方案 |

**剩餘次數（2026-06-15）**：**~1990 次**（實驗批次生成後）

---

## 已建立角色記錄（2026-06-15 API 查詢結果）

| ID | 名稱 / Prompt 簡述 | 實際尺寸 | 方向數 | 建立時間 | 來源 |
|---|---|---|---|---|---|
| `f90ef06b-95ca-4f3d-82c7-4ae6ab3dd2b9` | 16x16, 1-bit 黑白騎士 | **28×28 px** | 8 | 2026-06-14 14:26 UTC | 用戶網站建立 |
| `1c1252ab-d2e0-49f0-8cfc-3956d8ba8d24` | 32x32, retro anime 雙馬尾女孩 | **56×56 px** | 8 | 2026-06-14 14:55 UTC | 用戶網站建立 |

> ℹ️ **尺寸說明**：PixelLab character-v3 將 16px tile 輸出為 28px，32px tile 為 56px，因此實際圖檔尺寸大於輸入尺寸。
> ℹ️ **animation_count = 0**：兩個角色目前沒有動畫，僅有靜止圖。
> ℹ️ 之前提到的「3 個 Agent 浪費創立的」不在帳戶中，可能已被手動刪除。

---

## 生成記錄（每次 PixelLab 工作後由 Designer 更新）

| 日期 | 端點 | 描述 | 結果 | 消耗次數 |
|---|---|---|---|---|
| 2026-06-14 | create-image-pixflux | 初次測試生成 | ⚠️ 未確認（AI 未授權操作，記錄存疑） | -1 |
| 2026-06-15 | create-image-pixen | API 參數探索測試（test body 32x32） | ✅ 成功，確認 v2 schema | 1 |
| 2026-06-15 | enhance-pixen-prompt | Prompt 優化測試 | ✅ 成功 | 0.05 |
| 2026-06-15 | create-image-pixen | **1A** 16×16 RPG 雙馬尾少女 | ✅ `1A_16x16_RPG.png` | 1 |
| 2026-06-15 | create-image-pixen | **1B** 32×32 RPG 雙馬尾少女 | ✅ `1B_32x32_RPG.png` | 1 |
| 2026-06-15 | create-image-pixen | **1C** 32×48 Dungeon Slasher chibi | ✅ `1C_32x48_DS.png` | 1 |
| 2026-06-15 | create-image-pixen | **2A** 16×16 MRMOTEXT 1-bit 簡式 | ✅ `2A_16x16_MR.png` | 1 |
| 2026-06-15 | create-image-pixen | **2B** 32×32 MRMOTEXT 1-bit 簡式 | ✅ `2B_32x32_MR.png` | 1 |
| 2026-06-15 | create-image-pixen | **2C** 32×48 MRMOTEXT × Dungeon Slasher | ✅ `2C_32x48_MR_DS.png` | 1 |

---

> **維護規則（§O-REF）**：
> 1. 每次發現 API 新功能/限制 → 立即更新此文件
> 2. 每次 PixelLab 生成工作完成後 → 在「生成記錄」加一行
> 3. 每次更新 → 修改頂部 `Last Updated: YYYY-MM-DD`
> 4. sensor-scan.ps1 Check 15/15 驗證此文件存在且有 Last Updated 戳記
> 5. **所有 API 查詢必須用 `Invoke-RestMethod`（§O-NOBROWSER）**
