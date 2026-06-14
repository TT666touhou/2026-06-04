# PixelLab API 全功能參考表

> **維護者**：Designer ROLE
> **Last Updated: 2026-06-14**
> **操作規則**：所有 API 呼叫由用戶明確指示後才執行。AI 不主動生成。
> **參考**：workflow.md §O | GDD § 3.2 角色組成架構

---

## 帳戶狀態

| 項目 | 狀態 |
|---|---|
| 帳戶類型 | Trial |
| 剩餘次數 | ~12.9 次（2026-06-14 統計） |
| Pro 功能 | 需升級方案才可使用 |

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
- **尺寸支援**：32x32 ~ 512x512（需整除4）
- **新增參數**：
  - `outline_style`：`none` / `solid` / `glow`
  - `detail_style`：`none` / `low` / `medium` / `high`
  - `view`：`side` / `low top-down` / `high top-down`
  - `direction`：`south` / `north` / `east` / `west`

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

幾乎所有 endpoint 都支援，格式：
```json
["#FF8C42", "#2B2D42", "#8D99AE", "#EF233C"]
```

API 會強制只使用指定顏色，確保風格一致性。
可搭配 GDD MRMOTEXT VfxMix 34色調色盤直接指定。

### 本專案調色盤（GDD § 2.2）

| 用途 | Hex |
|---|---|
| 玩家 P1 | `#FF8C42`（暖橙）|
| 玩家 P2 | `#4CC9F0`（冷藍）|
| 玩家 P3 | `#5DA16E`（綠）|
| 玩家 P4 | `#9D5789`（紫）|
| 普通敵人 | `#FFFFFF`（原色白）|
| 不死系敵人 | `#5DA16E` / `#B1D368` |
| 魔法系敵人 | `#6F81B3` / `#9D5789` |
| 背景暗色 | `#363232` / `#453C3C` |

---

## Trial 配額消耗

| 動作 | 消耗 |
|---|---|
| 生成單張圖 | 1 次 |
| 動畫（任何幀數）| 1 次 |
| 旋轉 / Resize / 去背 / 骨架偵測 | 各 1 次 |
| Pro 系列 | ⚠️ 需升級 Pro 方案 |

**剩餘次數（2026-06-14）**：~12.9 次

---

## 生成記錄（每次 PixelLab 工作後由 Designer 更新）

| 日期 | 端點 | 描述 | 結果 | 消耗次數 |
|---|---|---|---|---|
| 2026-06-14 | create-image-pixflux | 初次測試生成 | ⏳ 未確認 | -1 |

---

> **維護規則（§O-REF）**：
> 1. 每次發現 API 新功能/限制 → 立即更新此文件
> 2. 每次 PixelLab 生成工作完成後 → 在「生成記錄」加一行
> 3. 每次更新 → 修改頂部 `Last Updated: YYYY-MM-DD`
> 4. sensor-scan.ps1 Check 15/15 驗證此文件存在且有 Last Updated 戳記
