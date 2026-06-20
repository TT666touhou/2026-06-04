# PIXELLAB_KB.md — PixelLab（Aseprite）像素美術知識庫

> 版本：v1（2026-06-20 建立，研究來源見文末）
> 維護者：Pixel Consultant 角色（`roles/pixel-consultant.md`）
> 用途：本專案以 **PixelLab（Aseprite 擴充）** 製作像素美術時的權威參考。
> 使用情境：用戶在 Aseprite 中用 PixelLab；Consultant 角色依此 KB 給「正確作法 + 推薦關鍵字」。

---

## 0. 本專案美術規格（生成時務必對齊）

> 來源：`docs/GAME_DESIGN.md`。目前場景用 ColorRect 佔位，將以 PixelLab 產出實際像素圖替換。

| 物件 | 尺寸（px） | 備註 |
|------|-----------|------|
| Player（玩家） | **32 × 64** | 直立人形；側視 2D 橫向卷軸 |
| 鋼針 needle | **12 × 2** | 極細長；攻擊針 + 帶線針 |
| 平台/地形 | 視場景 | 16px 邊界牆、ColorRect 平台 |
| 視窗/場景 | 1280 × 720 | `viewport` stretch |
| 視角 | **側視（side-scroller）** | 非 top-down/isometric |

- **風格方向**：GDD §7「視覺風格」尚 [DRAFT]（像素藝術，可參考既有 MRMOTEXT/DungeonMode tilesets）。生成時先定**調色板 + 像素密度 + 輪廓/陰影語彙**，後續所有資產一致。

---

## 1. PixelLab 是什麼 / 取用方式

PixelLab = AI 像素美術生成工具（角色、動畫、sprite sheet、tileset、場景）。取用方式：

| 方式 | 說明 | 本專案建議 |
|------|------|-----------|
| **Aseprite 擴充** | 直接在 Aseprite 內生成/編輯到當前檔案，更新最頻繁、功能最新 | **★ 主要**（用戶選用）|
| Web Creator | 瀏覽器快速生成（PixFlux / BitForge 模型）| 快速試風格 |
| Pixelorama（瀏覽器編輯器）| 內建 AI 工具的開源編輯器 | 備用 |
| **MCP「Vibe Coding」** | MCP 接 Claude Code / Cursor + **Godot 工具** | 後期可評估（與本 Claude Code 流程整合）|
| API / Python SDK | 程式化批量 | 後期管線化 |

- **模型**：`PixFlux`（中～特大尺寸）、`BitForge`（小～中尺寸）。
- **訂閱層級**：Pixel Apprentice / Pixel Artisan / Pixel Architect（功能與額度不同）。

---

## 2. Aseprite 擴充安裝（一次性）

1. **Aseprite v1.3.7+**（**試用版不支援擴充**；需正式版）。
2. 訂閱/試用後，從 **帳號頁** 下載 PixelLab 擴充檔。
3. 安裝：雙擊安裝；失敗則 `Edit > Preferences > Extensions > Add Extension` 選下載檔。
4. **重啟 Aseprite**，授予：`package.json` 檔案存取、websockets 網路存取、**Full Trust**（自動更新需要）。
5. 開啟：`Edit > PixelLab > Open plugin`，或快捷鍵 **`Ctrl + Space + P`**。

---

## 3. 工具一覽（功能 → 用途）

| 工具 | 用途 | 本專案典型用法 |
|------|------|---------------|
| **Text-to-Image 生成** | 文字 → 角色/物件/UI/場景 | 生成玩家、鋼針、道具、UI 圖示 |
| **Character（角色）** | 角色 sprite + **4/8 方向** + 動畫 | 玩家多向（側視主要用左右）；export sprite sheet 或單幀 |
| **Rotation（旋轉）** | 一鍵生成 4/8 方向視圖 | top-down/isometric 用；側視較少 |
| **Skeleton Animation** | 骨架控制動作（walk/run/attack）| 玩家跑/跳/盪繩/投針動畫 |
| **Text Animation** | 文字描述驅動動畫 | 快速試動作 |
| **Inpainting** | 在既有圖上加/改（衣服、物件、髮型）| 微調玩家裝備、修細節 |
| **Background Removal** | 去背 | 角色/物件透明化 |
| **Tileset / Texture** | top-down/側視 tile 擴充與生成 | 平台、地形、背景 tile |
| **Style Transfer / Reference 參考圖** | 用參考圖鎖風格 | **維持全專案風格一致的關鍵** |
| **Resize / Reshape / Color Reduction** | 改尺寸、減色 | 對齊本專案尺寸與調色板 |

---

## 4. 提示詞（Prompt / 關鍵字）原則 ★最重要

> 用戶要的「推薦關鍵字」核心規則：**描述要具體、英文、含風格與尺寸語彙；但角色描述要避開 "pixel art" 字樣**。

### 4.1 一般圖片（物件 / tile / UI / 場景）
- **要**加像素語彙讓模型理解意圖：`pixel art`、`8-bit pixel`、`16-bit pixelated`。
- 例：`needle, thin metal spike, 16-bit pixelated, side view, isolated on transparent background`。

### 4.2 角色（Character）描述 — 反直覺
- **避免** prompt 直接寫 `"pixel art"`（角色生成器對此關鍵字效果差）。
- 改用：`pixelated full body`、`character icon concept art`、`Pixel Perfect`，並**具體描述外觀**。
- 例：`pixelated full body, a nimble parkour ninja, dark blue outfit, holding thin needles, side view, Pixel Perfect`。

### 4.3 描述應包含的要素（checklist）
1. **主體**（具體：誰/什麼、顏色、配件、姿勢）。
2. **視角**：`side view`（本專案側視）/ `top-down` / `isometric`。
3. **風格**：`retro 8-bit` / `modern 16px anime` / 指定調色板。
4. **尺寸/畫布**：對齊本專案（玩家 32×64、針 12×2…）。
5. **動畫**：幀數、動作（walk/run/attack）。
6. **輸出**：sprite sheet / 單幀 / 透明背景。

### 4.4 一致性（全專案風格不漂移）
- 第一個角色定案後，**用其當 reference image / style transfer 的來源**生成後續資產。
- 固定：**調色板、像素密度（每單位幾 px）、輪廓粗細、陰影方向**。

---

## 5. 與本專案的銜接（Godot）

- PixelLab 在 Aseprite 出圖 → 匯出 PNG（透明背景、對齊尺寸）→ 放入 `assets/`（或專屬子夾）→ Godot 以 Sprite2D/AnimatedSprite2D 取代現有 ColorRect 佔位。
- **像素完美**：Godot 端 `textures/canvas_textures/default_texture_filter=0`（本專案已設 Nearest），匯入 PNG 用 Nearest，避免模糊。
- sprite sheet → Aseprite/Godot 切幀；逐幀動畫對齊 GDD 行為（跑/跳/盪繩/投針）。

---

## 6. 常見坑

- 試用版 Aseprite 無法裝擴充 → 需正式版 v1.3.7+。
- 角色 prompt 寫 "pixel art" 反而差（見 §4.2）。
- 生成尺寸與遊戲尺寸不符 → 用 Resize/Color Reduction 對齊；或一開始就設正確畫布。
- 風格漂移 → 一律用 reference/style transfer 鎖風格。

---

## 7. 研究來源（2026-06-20）

- PixelLab 官網：https://www.pixellab.ai/
- Ways to use PixelLab：https://www.pixellab.ai/docs/ways-to-use-pixellab
- Aseprite 擴充安裝：https://www.pixellab.ai/docs/installation
- 80.lv 介紹（Aseprite + sketch）：https://80.lv/articles/easily-create-pixel-art-based-on-sketch-with-this-ai-tool-for-aseprite
- 評測（JonathanYu）：https://www.jonathanyu.xyz/2025/12/31/pixellab-review-the-best-ai-tool-for-2d-pixel-art-games/
- 提示詞參考（pixel art prompts）：https://bydira.medium.com/mastering-pixel-art-prompts-a3abf7f08219
