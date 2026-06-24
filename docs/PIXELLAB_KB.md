# PIXELLAB_KB.md — PixelLab 完整知識庫

> 版本：v2（2026-06-21 全面更新，加入網頁版完整工具目錄）
> 維護者：Pixel Consultant 角色（`roles/pixel-consultant.md`）
> 用途：本專案以 **PixelLab（Aseprite 擴充 + 網頁版）** 製作像素美術時的權威參考。

---

## 0. 本專案美術規格（生成時務必對齊）

| 物件 | 尺寸（px） | 備註 |
|------|-----------|------|
| Player（玩家） | **32 × 64** | 直立人形；側視 2D 橫向卷軸 |
| 鋼針 needle | **12 × 2** | 極細長；攻擊針 + 帶線針 |
| 訓練木人 | **32 × 64** | 與 Player 同尺寸 |
| 平台/地形 | 視場景 | 16px 邊界牆、ColorRect 平台 |
| 視窗/場景 | 1280 × 720 | `viewport` stretch |
| 視角 | **側視（side-scroller）** | Camera view: sidescroller (eye level) |

- 風格方向：GDD §7 [DRAFT]。生成前先定**調色板 + 輪廓粗細 + 陰影方向**，全專案統一。
- 角色原型：已生成（軍裝女角色，白髮/紅眼/黑色軍帽/黑色大衣/紅色內襯/白色過膝襪）

---

## 1. PixelLab 取用方式

| 方式 | 說明 | 本專案建議 |
|------|------|-----------|
| **Aseprite 擴充** | 直接在 Aseprite 內生成，與畫布整合最深 | ★ 主要（修改/動畫） |
| **網頁 Creator** | `pixellab.ai/create` — 工具最齊全，包含 Pro 工具 | ★ 生成新資產首選 |
| Pixelorama（瀏覽器）| 開源編輯器，內建 PixelLab | 備用 |
| API / Python SDK | 程式化批量生成 | 後期管線化 |
| MCP「Vibe Coding」 | 接 Claude Code / Cursor + Godot | 未來可評估 |

- **模型**：`PixFlux`（中～特大）、`BitForge`（小～中，角色/動畫主力）
- **訂閱層級**：Tier 0（免費）/ Tier 1 / Tier 2+（Pro 工具需 Tier 1+）

---

## 2. Aseprite 擴充安裝

1. **Aseprite v1.3.7+**（試用版不支援擴充；需正式購買版）
2. 帳號頁下載擴充 → 雙擊或 `Edit > Preferences > Extensions > Add Extension`
3. 重啟，授予：`package.json` / websockets / Full Trust
4. 開啟：`Edit > PixelLab > Open plugin` 或 **Ctrl + Space + P**

---

## 3. GENERATORS（生成器）

### 3A. 圖像生成

#### Create S-M image（BitForge / style ref）
- **用途**：文字 + 風格參考圖 → 新圖像（角色/物件/UI）
- **參數**：
  - Description（主描述）/ Negative description
  - Camera view / Direction
  - Outline / Shading / Details（風格強度）
  - Isometric / Oblique projection
  - Guidance weight / Style guidance weight
  - Target Palette（鎖調色板）
  - Init image / Init image strength
  - Remove background / Seed
- **尺寸限制**：Tier 1 ≤ 80×80；Tier 2+ ≤ 140×140
- **本專案用途**：以角色原型作 style ref，生成配件/道具保持風格一致

#### Create M-XL image（new）
- **用途**：生成中～超大尺寸圖像
- **參數**：同 S-M，尺寸上限更大
- **本專案用途**：場景背景、大型 UI 元素

#### Pose to image
- **用途**：先擺好骨架 pose → 生成對應角色圖
- **必要條件**：需先設定 skeleton pose
- **參數**：Description / Camera view / Direction / Canvas coverage / Pose guidance weight / Target palette / Init image / Output method
- **尺寸限制**：small～medium 尺寸（文件未標明確數值）
- **本專案用途**：生成特定動作的靜止關鍵幀

#### Image to pixel art
- **用途**：把真實照片或非像素圖轉為像素風格
- **參數**：Guidance weight / Target palette / Remove background / Output method / Seed
- **尺寸限制**：最大輸出 Tier 1: 200×200；Tier 2+: 320×320（超過自動縮圖 ÷4）
- **本專案用途**：快速把概念草圖轉像素稿

---

### 3B. 動畫生成

#### Animate with text（new）★ 推薦
- **用途**：單圖 + 文字動作描述 → 動畫幀
- **參數**：Character description / Action description / Negative description / Camera view / Direction / Guidance weight / Seed
- **幀數**：固定 **4 幀**
- **畫布要求**：**必須 64×64**
- **本專案備注**：32×64 角色不符合，需跑兩次合并得 8 幀；或改用 Pro 版

#### Animate with text（Pro）★★ 本專案主力動畫工具
- **用途**：參考圖 + 動作描述 → 多幀動畫
- **參數**：Reference image / Action description / Camera view / Direction / No Background / Seed
- **幀數（依畫布尺寸）**：

| 參考圖尺寸 | 幀數 | Grid | 消耗 generations |
|-----------|------|------|----------------|
| 32×32 或 64×64 | **16 幀** | 4×4 | 20 |
| 65–128 px | **4 幀** | 2×2 | 20 |
| 129–170 px | **4 幀** | 2×2 | 25 |
| 171–256 px | **4 幀** | 2×2 | 40 |

- **最大尺寸**：256×256
- **本專案備注**：角色 32×64 → 65-128px 範圍 → 一次 4 幀；需跑兩次拼 8 幀

#### Create animated object/character（Pro）
- **用途**：從單一靜圖一次生成**完整動畫組**（idle/walk/run/attack 等）
- **需求**：Tier 1+
- **本專案用途**：最快得到完整角色動畫集的路線

#### Animation to animation
- **用途**：把一條動畫的動作風格轉移到另一角色或生成新動畫
- **參數**：Number of frames（滑桿，最少 2）/ Character description / Action description / Camera view / Direction / Outline/Shading/Details / AI Freedom / Guidance weight / Seed
- **畫布限制**：只接受 **16×16 / 32×32 / 64×64 / 128×128**（正方形）
- **訂閱需求**：**Tier 2+**

#### Animate with skeleton
- **用途**：骨架姿勢驅動動畫，對個別部位有精確控制
- **最適用於**：細微動作（subtle movement）、特定肢體運動
- **前置**：需先用 Insert / Edit Skeleton 設定骨架

#### Create animations（automatic）
- **用途**：全自動生成動畫，選擇預設動畫類型
- **預設動畫類型**：Walk / Thrust / Running / Cast spell（僅這4種）
- **本專案備注**：不含 idle/jump 等，需求不完整時改用 Animate with text

#### Create walking character（experimental）
- **用途**：實驗性：一次生成可行走的角色
- **狀態**：實驗中，穩定性較低

---

### 3C. 地圖 / 地形 / UI 生成

#### Create tiles（Pro）★ Tile 生成最完整
- **用途**：生成各種形狀的遊戲 tile
- **Tile 類型**：Square / Hex / Hex pointy / Isometric / Octagon
- **尺寸（正方形）**：16 / 32 / 48 / 64 / 96 / 128 px
- **尺寸（矩形）**：16×32 / 32×64 / 48×96 / 64×128
- **視角**：Low top-down / High top-down / Side
- **可附加**：Style reference tiles（鎖風格）
- **消耗**：20–25 generations；有 style ref 時 20–40
- **本專案用途**：平台地磚、牆面、背景 tile

#### Extend map（v2）
- **用途**：在現有地圖基礎上擴展/填充區域
- **參數**：Description / Negative description / Camera view / Guidance weight / Target palette / Init image / Seed / Paint in selection
- **尺寸限制**：Tier 1 ≤ 140×140；Tier 2+ ≤ 200×200
- **技巧**：極粗略的 init image 反而效果最好

#### Create texture / Create tileset / Create isometric tile
- **用途**：自由文字生成各種紋理/素材/等角 tile
- **本專案用途**：地形紋理、背景材質

#### Create UI elements（Pro）
- **用途**：生成遊戲 UI 組件：按鈕 / 血條 / 選單 / 圖示
- **可指定風格一致性**：使用 reference 圖鎖定 UI 視覺語彙

---

## 4. MODIFIERS（修改器）

### 4A. 圖像修改

#### Inpaint / Inpaint v3 / Inpaint M-L（PixPatch v2）★★★
- **用途**：選取畫面特定區域重繪（改衣服/加配件/移除元素）
- **參數**：Description / Negative description / Camera view / Direction / Outline/Shading/Details / Guidance weight / Init image / Target palette / Output method（New layer 推薦）/ Paint in selection / Seed
- **尺寸限制**：

| 版本 | 最小 | Tier 1 最大 | Tier 2+ 最大 |
|------|------|------------|-------------|
| Inpaint（基礎）| 32×32 | 100×100 | 160×160 |
| Inpaint M-L | 更大尺寸 | — | 更大 |

- **操作流程**：勾選「Use selection tool」→ 用 Aseprite 選取工具框出要改的區域 → Generate
- **輸出**：建議用 New Layer，方便對比 / 選擇性合并

#### Edit image / Edit image（Pro）
- **用途**：全圖修改，不限定選取區域
- **本專案用途**：整體風格調整

#### Remove background
- **用途**：自動去背，輸出透明 PNG
- **本專案必用**：所有角色/物件生成後都要跑一次

#### Reduce colors★
- **用途**：色彩量化（color quantization），減少調色板顏色數量
- **參數**：Quantization method / Palette（自訂調色板）/ Color count / Dithering（選填）
- **尺寸限制**：最大 **512×512**
- **本專案用途**：Inpaint 後強制對齊現有調色板；確保全專案色數一致

#### Resize（Aseprite 限定）
- **用途**：智慧重繪改尺寸（非一般縮放，會重繪細節）
- **參數**：目標尺寸選項（200×200 / 128×128 / 64×64 / 48×48 / 自訂）/ Description（輔助）/ Seed
- **注意**：**僅 Aseprite 擴充可用，網頁版無此工具**
- **技巧**：大幅度縮放建議分步漸進（如 128→64→32）

#### Unzoom pixel art
- **用途**：把小像素圖擴大到更高解析度（反方向的 resize）

#### Reshape
- **用途**：改變角色/物件的外形輪廓

#### Try on（experimental）
- **用途**：把服裝/道具套用到角色上（實驗性）
- **本專案潛力用途**：快速試穿不同裝備版本

#### Multi image（experimental）
- **用途**：同時輸入多張圖進行組合生成

---

### 4B. 動畫修改

#### Edit animation（Pro）★★
- **用途**：跨所有幀一致修改動畫（加武器/換衣服/加配件）
- **參數**：Instruction（文字指令，如 "add a sword"）/ No background / Seed
- **最少需要**：2 幀
- **幀數上限（依尺寸）**：

| 像素尺寸 | 最大幀數 | Grid | 消耗 |
|---------|---------|------|------|
| 32–64 px | 16 幀 | 4×4 | 20 |
| 65–80 px | 9 幀 | 3×3 | 20 |
| 81–128 px | 4 幀 | 2×2 | 20 |
| 129–170 px | 4 幀 | 2×2 | 25 |
| 171–256 px | 4 幀 | 2×2 | 40 |

- **平台**：Aseprite + Pixelorama（不含網頁版）

#### Transfer outfit（Pro）
- **用途**：把一套服裝套用到整條動畫的所有幀
- **本專案用途**：角色換裝後更新動畫

#### Re-pose（skeleton）
- **用途**：改變有骨架的角色的姿勢，不重繪外觀細節
- **本專案用途**：調整動畫關鍵幀的姿勢

#### Interpolate（new / old）
- **用途**：在兩張關鍵幀之間自動補間（tweening）
- **本專案用途**：4 幀動畫 → 8 幀；或修補幀間跳幀問題

---

### 4C. 骨架工具

#### Insert / Edit Skeleton
- **用途**：在角色靜圖上標記骨架節點（頭/肩/肘/腕/腰/膝/踝），供骨架動畫工具使用
- **前置於**：Animate with skeleton / Re-pose / Pose to image

#### Rotate / Create 8-directional sprite（Pro）
- **用途**：從一個方向生成 4 或 8 個方向的 sprite
- **畫布限制**：只接受 **16×16 / 32×32 / 64×64 / 128×128**
- **視角轉換**：可在 low top-down / high top-down / side-scroller 之間切換
- **技巧**：從 south（正面/俯瞰朝下）方向的圖開始，效果最佳

---

## 5. 尺寸限制速查表

| 工具 | Tier 1 最大 | Tier 2+ 最大 | 備注 |
|------|------------|-------------|------|
| Create S-M（style ref）| 80×80 | 140×140 | |
| Inpaint | 100×100 | 160×160 | 最小 32×32 |
| Extend map | 140×140 | 200×200 | |
| Image to pixel art | 200×200 | 320×320 | 超過自動縮圖 |
| Animate with text（Pro）| 256×256（最大輸入）| 同 | 幀數依尺寸 |
| Edit animation（Pro）| 256×256（最大輸入）| 同 | 幀數依尺寸 |
| Animation to animation | 128×128（最大，正方形）| 同 | Tier 2+ 才能用 |
| Rotate | 128×128（最大，正方形）| 同 | 只支援正方形 |
| Reduce colors | 512×512 | 512×512 | |
| Resize（Aseprite only）| 自訂 | 自訂 | 僅 Aseprite |

---

## 6. 提示詞（Prompt）原則

### 6.1 一般圖片（物件 / tile / UI / 場景）
- **要**加像素語彙：`pixel art` / `8-bit pixel` / `16-bit pixelated`
- 例：`needle, thin metal spike, 16-bit pixelated, side view, isolated on transparent background`

### 6.2 角色描述 — 反直覺
- **避免** `"pixel art"`（角色生成器效果差）
- 改用：`Pixel Perfect` / `pixelated full body` / `character icon concept art`
- 例：`Pixel Perfect, anime military girl, short white hair, red eyes`

### 6.3 Animate with text — Action description
- 描述**動作**，不需重述外觀（模型看圖）
- 格式：`[幀數]-frame seamless loop, [動作], [姿態], [布料效果]`
- 例：`8-frame seamless loop, sprint run, aggressive forward lean, cape billowing behind`

### 6.4 Inpaint Description
- 描述**要生成什麼**，不描述問題（無負面詞）
- 不用顏色名稱描述現有顏色 → 用**著色結構**：`3-tone pixel shading: dark shadow, mid base, bright highlight`
- 加：`same colors as existing sprite` / `consistent palette`
- 自然語言也有效：`coat taken off, white long-sleeve shirt revealed underneath`

### 6.5 Style Transfer / Reference image
- 用角色原型圖做 reference → 後續所有資產 style 一致
- Style guidance weight 建議 0.6–0.75

---

## 7. 本專案工作流程（Godot 銜接）

```
PixelLab 生成 → Remove background → Reduce colors（對齊調色板）
→ Resize（對齊遊戲尺寸）→ 匯出 PNG（透明背景）
→ 放入 assets/ → Godot Sprite2D/AnimatedSprite2D
→ Import 設定 Nearest filter（像素完美，已在 project.godot 設定）
```

- **角色動畫 sprite sheet**：Aseprite export → Godot 切幀，對齊 GDD 行為
- **Inpaint 後強制調色板**：`Sprite > Color Mode > Indexed` → Use current palette

---

## 8. 常見坑

| 坑 | 原因 | 解法 |
|----|------|------|
| 角色 prompt 寫 "pixel art" 效果差 | 角色生成器對此詞反應不佳 | 改用 `Pixel Perfect` |
| Inpaint 生成後顏色跑偏 | 模型引入新色值 | 生成後 Indexed Color Mode 鎖調色板 |
| Animate with text 只出 4 幀 | 畫布不是 32×32 或 64×64 | 跑兩次合并；或縮圖後用 Pro |
| Resize 找不到 | 網頁版沒有 | 只在 Aseprite 擴充使用 |
| Animation to animation 沒有此工具 | 需要 Tier 2+ | 升訂閱或改用 Animate with text |
| Rotate 結果不符合預期 | 輸入圖不是正南（frontal）方向 | 先畫/生成正面朝下的圖再 rotate |
| 風格漂移 | 每次生成沒有 reference | 一律帶入角色原型圖做 style ref |

---

## 9. 研究來源（2026-06-21 更新）

- PixelLab 官網：https://www.pixellab.ai/
- 工具文檔索引：https://www.pixellab.ai/docs/tools
- Animate with text（Pro）：https://www.pixellab.ai/docs/tools/animate-with-text-pro
- Animation with text：https://www.pixellab.ai/docs/tools/animation
- Animation options：https://www.pixellab.ai/docs/options/animation
- Edit animation（Pro）：https://www.pixellab.ai/docs/tools/edit-animation-pro
- Style ref（BitForge）：https://www.pixellab.ai/docs/tools/style
- Inpaint：https://www.pixellab.ai/docs/tools/inpaint
- Rotate：https://www.pixellab.ai/docs/tools/rotate
- Create tiles（Pro）：https://www.pixellab.ai/docs/tools/create-tiles-pro
- Extend map：https://www.pixellab.ai/docs/tools/extend-map
- Image to pixel art：https://www.pixellab.ai/docs/tools/image-to-pixel-art
- Resize：https://www.pixellab.ai/docs/tools/resize
- Reduce colors：https://www.pixellab.ai/docs/tools/reduce-colors
- Pose to image：https://www.pixellab.ai/docs/tools/pose-to-image
- Animation to animation：https://www.pixellab.ai/docs/tools/animation-to-animation
