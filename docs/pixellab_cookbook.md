# PixelLab Cookbook（DS 遊戲版）

> **定位（Layer 2 — 靜態）**：本文件只記錄本遊戲（Dungeon Slasher）特有規則。  
> **API 端點詳細格式請即時讀取**：`https://api.pixellab.ai/v2/llms.txt`  
> **維護者**：Designer ROLE  
> **Last Updated: 2026-06-16 v2.4**（V12 更新：medium shading 黃金配置、generate-image-v2/generate-with-style-v2/image-to-pixelart-pro Pro 端點實測、API 格式陷阱修正）

---

## §CK-1. 快速決策樹（選擇端點）

```
問：你要生成什麼？
│
├─ 遊戲角色精靈圖（有方向感、遊戲用）
│   └─→ POST /create-character-v3  ✅ 主力端點（異步，background_job_id）
│
├─ 手動命中字諸/隨機化（Style 學習）
│   └─→ POST /generate-with-style-v2  ⚠️ 非同步！回傳 HTTP 202 + background_job_id
│         ⚠️ 最多 4 張 style_images！（V13 實測）
│         ⚠️ Required: style_images + description + image_size（三個必填！）
│         ❌ ERR-036： style_images[·].image = {"base64": "..."}（嵌套 image 物件！）
│         ❌ ERR-038： 頂層必須是 "image_size": {"width": W, "height": H}！不能直接放 width/height
│         ❌ 絕對禁止: "width": W, "height": H 在頂層 → HTTP 422 （Field required: image_size）
│         ✅ 正確格式：
│           {
│             "style_images": [{"image": {"base64": "..."}, "width": W, "height": H}],
│             "description": "...",
│             "image_size": {"width": 128, "height": 128}
│           }
│         ⚠️ ERR-039 輪詢陷阱（3個！）：
│           ❌ status == "completed"（非 "complete"）
│           ❌ 圖片在 data["last_response"]["images"]（非 result.images！）
│           ❌ 圖片物件：{"type": "base64", "width": W, "base64": "..."}（非純 base64 string）
│           ✅ 正確取圖：data["last_response"]["images"][i]["base64"]
│           ✅ 回傳 4 張候選圖（皆有效）
│
├─ 快速測試/單張參考圖
│   └─→ POST /create-image-pixflux  ✅ 同步~20s，支援 color_image（調色盤引導）
│
├─ 精細像素藝術（控制輪廓/細節/視角）
│   └─→ POST /create-image-pixen  ✅ 同步~30s
│         ✓ 支援 outline / detail / view / direction / seed
│         ✗ 不支援 init_image / shading / color_image！
│
├─ 最強多參數生成（style+color+init 三重引導）
│   └─→ POST /create-image-bitforge  ✅ 同步~30s
│         ✓ style_image + color_image + init_image 同時支援
│         ⚠️ ERR-037： style_image = {"base64": "..."} 直接用 Base64Image！
│         ❌ 絕對禁止：{"base64": "...", "width": W, "height": H} → HTTP 422 extra_forbidden
│         ⚠️ style_image 不需要與輸出相同尺寸（先前文件錯誤，已更正）
│
│            (e.g. 輸出 40x52 → style_image 必須 40x52)
│
├─ 把現有 Sprite 重新生成不同尺寸
│   └─→ POST /resize  ✅ 同步~40s
│         ✓ reference_image + target_size + color_image
│         ✓ 可繼承 Sprite 的風格與比例到新尺寸
│
├─ 修改現有像素圖（局部或整體）
│   └─→ POST /edit-image  同步，image + color_image + description
│         或 POST /inpaint  有 mask_image，精準修補特定部位
│
├─ 圖片直接像素化縮小（注意：不是「生成」！）
│   └─→ POST /image-to-pixelart  同步~10s，1次/張
│         ⚠️ 結果是「模糊縮小版」，不是重新生成的角色！
│
├─ 已有角色，添加動畫
│   └─→ POST /animate-character  （需先有 character_id）
│         或 POST /animate-with-text-v3  （從靜止幀開始）
│
└─ 場景瓦片（側視角平台遊戲）
    └─→ POST /create-tileset-sidescroller
```

---

## §CK-0. 遊戲類型（Designer 必讀，每次生成前確認）

> **必讀來源**：`docs/GAME_DESIGN.md §1.1 ~ §1.3`（Designer 工作流 §A Step 4 強制項目）

```
遊戲類型：2D 橫向捲軸動作（Castlevania 惡魔城風格）
視覺風格：像素藝術 + 哥德/恐怖
PixelLab 用途：可行性實驗（非最終生產管道）
角色系統：Tile Composite（MRMOTEXT tile 拼接）— PixelLab 生成物需轉換為 tile 格式

★ 只有確認遊戲類型後，才能決定角色角度和輸出尺寸！★
```

---

## §CK-2. DS 遊戲精確規格（不得改動）

### 遊戲視角與角色朝向（★最易出錯★）

```
遊戲類型：2D 橫向捲軸（Side-Scrolling）

API 實測驗證 - view 參數有效值（僅此三種！）：
  'side'          → 橫向視角（2D 橫向捲軸的正確選擇）
  'low top-down'  → 低俯角
  'high top-down' → 高俯角
  ❌ 'south' / 'east' / 'north' / 'front' → HTTP 422！

2D 橫向捲軸遊戲正確設定：view: "side"
（在此 API 中 "side" = 橫向遊戲慣例視角，非純剪影）
```

### 頭身比
```
DS 慣例：4~5頭身（使用者確認）
參考量測：Lady_of_the_Bloodline.png Sprite (40x52px)
  頭部（rows 0-17）:  18px = 35%
  軀幹（rows 18-38）: 21px = 40%
  腿部（rows 39-51）: 13px = 25%
注：2D橫向動作遊戲常見4~5頭身，非chibi(1:3)也非寫實(1:7)
```

### 目標輸出尺寸
```
參考Sprite：40×52px（Lady_of_the_Bloodline.png，無透明邊距後的實際人物尺寸）
PixelLab 最小輸出：create-character-v3 = 256×256（固定）
比例換算策略：
  → 生成 256×256，人物本體約佔 80-90% 高度
  → 後製：PIL resize 到 40×52 或遊戲所需的實際大小
  → 或：使用 pixen endpoint 指定自訂小尺寸（支援 32x32 ~ 512x512）

★ 不要把「插畫尺寸」(487x707)與「Sprite尺寸」(40x52)混淆！★
```

### 髮色規範（★V7A 已犯錯，記錄於此★）
```
正確：silver white hair / pure white hair / snow white hair
正確hex：#F1ECF7（sprite採樣）/ #F9F1F1（插畫採樣）
❌ 錯誤：pale warm-white（→AI會理解成金色/米白色！）
❌ 錯誤：warm-white / cream white / off-white（都容易被誤解為暖色）

Prompt 固定寫法："silver-white hair" 或 "pure white hair"
```

### 輪廓與陰影
```
outline：  selective outline（非純黑，用深棕 #1A1A2E）
shading：  basic shading（每色兩層，禁止 flat / detailed / gradient）
禁止：     gradients / smooth shading / glow effects
```

### 尺寸規格
```
create-character-v3：image_size 強制 256×256
reference_image：    最大 256×256（超過 HTTP 422）
插畫轉精靈：         PIL resize max=256px 後傳入
enhance-character-v3-prompt：不支援圖片輸入！（只有 description/image_size/outline/detail）
enhance-character-v3-prompt：不支援 view 參數！（會 HTTP 422）
create-character-v3：不支援 enhance_prompt 欄位！（會 HTTP 422）

★ image-to-pixelart（V8 新發現，2026-06-16）★
  - 端點：POST /image-to-pixelart
  - 輸入：image (Base64Image) + image_size {w,h} + output_size {w,h}
  - 輸出：同步！（無 background_job，約 10 秒直接回傳）
  - 費用：1.0 次/張（無論尺寸大小）
  - 回傳格式：result["image"]["base64"] (非 URL！)
  - output_size：完全自訂，可設 16x16 / 32x32 / 40x52 / 48x48
  - 無 description/view/outline/direction 等參數（純圖片轉換）
  - 不需 PIL resize 就可傳入，但建議 resize max=256 節省傳輸
  - image_size：傳入圖片的當前 {w,h}（PIL thumbnail 後的尺寸）
```

---

## §CK-3. CHAR-006 標準色值（Lady of the Bloodline）

| 部位 | 主色 HEX | 陰影 HEX | 備注 |
|------|---------|---------|------|
| 頭髮 | `#F1ECF7` 淡薰衣草白 | `#B2A9C9` / `#7B7291` / `#2B2135` | 非純白！ |
| 服裝 | `#423749` 深紫炭灰 | `#271E30` / `#150E1E` | 非純黑，有紫調！ |
| 荷葉邊 | `#870A36` 深酒紅 | `#480F2D` | 非 crimson（#C41830）！ |
| 膚色 | `#FFE6DB` 暖桃色 | `#EAB09E` | |
| 眼睛 | `#8B0000` 深紅 | — | |

> ⚠️ V5 曾錯用 `crimson`（#C41830）—— 太亮。正確是深酒紅 `#870A36`  
> ⚠️ 服裝是**紫調**炭灰 `#423749`，不是純炭灰

### Prompt 中的色值描述方式
```
頭髮：  "pale lavender-white" (非 silver / pure white)
服裝：  "dark purple-charcoal" (非 black / dark gray)
荷葉邊："deep burgundy dark red" (非 crimson / bright red)
膚色：  "warm peach skin" (非 fair / white)
```

---

## §CK-4. 絕對禁止詞清單（Prompt 中永遠不能出現）

### 武器相關（會導致生成出帶武器角色）
```
❌ katana  ❌ sword  ❌ blade  ❌ weapon
❌ knife   ❌ dagger ❌ bow    ❌ arrow
❌ shuriken ❌ kunai ❌ staff  ❌ spear
```

### 職業/身分相關（會污染風格）
```
❌ ninja      ❌ assassin  ❌ kunoichi
❌ shinobi    ❌ warrior   ❌ fighter
❌ samurai    ❌ rogue     ❌ thief
```

### 比例相關（會破壞 DS 正確頭身比）
```
❌ chibi              ❌ chibi proportions
❌ 1:4 ratio          ❌ big head small body
❌ deformed           ❌ cute chibi style
```

### 服裝過具體（會限制 AI 創意，且部分有文化敏感性）
```
❌ gothic lolita         ❌ thigh-high stockings
❌ kimono                ❌ haori
❌ cosplay               ❌ school uniform
```

### 臉部錯誤指令（會干擾 view:side 的自動處理）
```
❌ front-facing face     ❌ looking at viewer
❌ facing forward        ❌ frontal view
（view:"side" API 參數已自動處理，不需要 Prompt 指定）
```

---

## §CK-5. 已確認 API 陷阱（Gotchas）

| 症狀 | 原因 | 解法 |
|------|------|------|
| HTTP 422 `image_size missing` | create-character-v3 或 enhance-character-v3-prompt 缺少 `image_size` | 加 `"image_size": {"width": 256, "height": 256}` |
| HTTP 422 `extra_forbidden shading` | pixen v2 不支援 `shading` | 移除，改在 Prompt 文字描述陰影 |
| HTTP 422 `extra_forbidden init_image` | pixen v2 不支援 `init_image` | 改用 pixflux 或 bitforge |
| HTTP 422 `extra_forbidden color_palette` | pixflux v2 不支援 `color_palette` | 移除，在 Prompt 描述顏色 |
| HTTP 422 `reference_image > 256px` | CDN 圖片或插畫太大 | `PIL.Image.thumbnail((256,256))` 後再 base64 |
| HTTP 500 Incorrect padding | bitforge style_image 帶 `data:image/png;base64,` 前綴 | 只傳 raw base64，不加前綴 |
| HTTP 500 must be size (H, W) | bitforge style_image 尺寸與輸出不符 | PIL resize 到**完全相同**尺寸再傳入（`img.resize((W, H))`，非 thumbnail！）|
| 生成 116×116 小圖（非 256×256）| create-character-v3 缺少 `image_size` | 同第一行解法 |
| **bitforge style_strength 全噪訊** | `style_strength` 預設是 **0.0**（等於完全無 style 引導！） | **明確設定 style_strength = 70~90**；不設就是純文字生成 |
| **bitforge + 場景截圖 style_image 全噪訊** | style_image 是複雜場景圖（ERR-040 2026-06-16 實測）| bitforge style_image **必須是角色 sprite/skin**，不能是場景截圖。複雜場景色彩混亂 → 噪訊輸出 |
| **bitforge style_image 必須精確 resize** | `thumbnail()` 不保證精確尺寸 | 用 `img.resize((OUTPUT_W, OUTPUT_H), Image.LANCZOS)`（不是 thumbnail）|
| CDN 下載 CF 1010 Forbidden | urllib 沒有瀏覽器 Headers | 使用下方標準 CDN 下載程式碼 |
| CDN 下載得到亂碼（非 PNG）| Accept-Encoding 觸發 Brotli 壓縮 | **禁止**加 `Accept-Encoding` Header |
| create-character-v3 回傳 frames=0 | 誤以為失敗 | 正常！圖在 CDN，需 GET /characters/{id} 後下載 |
| enhance-pixen-prompt 取錯 key | 取到 dict 整個字串 | 正確 key 是 `enhanced_prompt`（非 description/prompt/text）|
| enhance-character-v3-prompt 取錯 key | 同上 | 同樣是 `enhanced_prompt` |
| Prompt 含職業詞（ninja/assassin）| 生成帶武器或忍者元素 | 使用 §CK-4 禁止詞清單 |
| bitforge 小尺寸（≤64px）全噪訊 | bitforge 不適合小圖 | 改用 create-character-v3 或 pixflux + init_image |
| Python print 含 emoji（✅❌）在 Windows cp932 環境崩潰 | Windows console 預設 cp932，無法編碼 emoji | 腳本加 `sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')` 或改用純 ASCII 輸出 |
| enhance-character-v3-prompt 帶 `view` 參數 HTTP 422 | 此端點不支援 `view` 欄位 | 移除 `view`；`view` 只能在 create-character-v3 傳入 |
| create-character-v3 帶 `enhance_prompt: true` HTTP 422 | `enhance_prompt` 不是此端點的有效欄位 | 移除 `enhance_prompt`；若要增強請用 enhance-character-v3-prompt 分兩步驟 |
| **ERR-041**: create-character-v3 帶 `shading` 或 `direction` HTTP 422 | `shading`、`direction` 均不是 create-character-v3 的有效欄位（2026-06-16 確認）| 移除 `shading` 和 `direction`；create-character-v3 只支援 `view`（非 `direction`）；shading 改用文字描述 |

---

## §CK-6. CDN 下載標準程式碼（copy-paste ready）

```python
import urllib.request
import json

BEARER = "956460ee-978e-4d60-999a-f4b0f567bb48"

# ✅ 必加的 CDN Headers
CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    # ❌ 禁止加 Accept-Encoding！（觸發 Brotli，得到亂碼）
    "Sec-Fetch-Dest": "image",
    "Referer": "https://pixellab.ai/",
}

def download_cdn_image(url: str, save_path: str) -> bool:
    """下載 CDN 圖片並驗證為有效 PNG"""
    req = urllib.request.Request(url, headers=CDN_HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    # 驗證 PNG 簽名
    if data[:4] != b'\x89PNG':
        raise ValueError(f"下載的不是 PNG（前4bytes: {data[:4].hex()}），可能是 Brotli 壓縮！")
    with open(save_path, 'wb') as f:
        f.write(data)
    return True

def check_balance() -> int:
    """查詢當前餘額次數"""
    req = urllib.request.Request(
        "https://api.pixellab.ai/v2/balance",
        headers={"Authorization": f"Bearer {BEARER}"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read())
    return data.get("count", 0)

def poll_background_job(job_id: str, timeout_s: int = 360) -> dict:
    """輪詢 background job 直到完成"""
    import time
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        req = urllib.request.Request(
            f"https://api.pixellab.ai/v2/background-jobs/{job_id}",
            headers={"Authorization": f"Bearer {BEARER}"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read())
        status = result.get("status")
        if status == "completed":
            return result
        elif status == "failed":
            raise RuntimeError(f"Job failed: {result.get('last_response', {}).get('detail', 'unknown')}")
        time.sleep(5)
    raise TimeoutError(f"Job {job_id} timeout after {timeout_s}s")
```

---

## §CK-7. Pre-Generation Checklist（8 問強制通關）

> **規則**：Designer 開始任何 PixelLab 生成前，必須在回覆中逐條列出以下 8 個問題的答案。  
> 不能只說「已確認」，必須逐條回答。違反 → Sensor 🔴 Level 1 觸發（立即中斷任務）。

| # | 問題 | 正確答案 |
|---|------|---------|
| Q1 | 你要用哪個 endpoint？為什麼選它？ | create-character-v3（遊戲角色精靈圖）/ pixflux（快速單張）/ pixen（精細控制）|
| Q2 | image_size 格式？ | `{"width": 256, "height": 256}` — **必填！** 不填 → 輸出 116px 垃圾 |
| Q3 | create-character-v3 完成後圖片在哪裡？ | **不在 POST 回應！** 需輪詢 background_job → GET /characters/{id} → 從 rotation_urls CDN 下載 |
| Q4 | CDN 下載要加什麼 Headers？不能加什麼？ | 必加：User-Agent + Accept + Referer + Sec-Fetch-Dest；**禁止加 Accept-Encoding** |
| Q5 | 如何確認下載到真正的 PNG？ | 驗證 `data[:4] == b'\x89PNG'`，否則是 Brotli 壓縮垃圾 |
| Q6 | reference_image 最大多少 px？ | 256×256（超過 → HTTP 422），插畫需 PIL resize |
| Q7 | 你的 Prompt 有沒有包含禁止詞？ | 逐條對照 §CK-4 清單（ninja/assassin/katana/chibi/front-facing 等）|
| Q8 | 預估費用？目前餘額？ | create-character-v3 ≈ 5~10 次；餘額需 ≥ 10 次才允許生成 |

---

## §CK-8. 標準 Prompt 模板（已驗證 + V7A 反省後更新）

### ⚠️ V7A 錯誤記錄（2026-06-16）
```
錯誤1: view="side" + direction="east" → 純側面剪影（非2D橫向慣例）
錯誤2: "pale warm-white hair" → AI 生成金色/米白色頭髮
修正1: view="south" + direction="south-east" → 稍微斜向正面（2D橫向標準）
修正2: "silver-white hair" 或 "pure white hair"
```

### V7B：create-character-v3（2D橫向正確角度，text prompt）
```json
{
  "description": "2D side-scrolling game character, young girl, 4-to-5 head body ratio, slight 3/4 angle toward viewer with face visible, silver-white long straight hair, black large bow at upper right side, deep crimson red eyes, dark purple-gray off-shoulder gothic dress, wide black waist cincher belt with back bow, deep burgundy dark red layered ruffled frills at hem and detached sleeve cuffs, dark warm-brown opaque tights, long slender black cat tail, cel-shaded 3-color-layer style no gradients, pale warm peach skin, facing right, no weapons",
  "image_size": {"width": 256, "height": 256},
  "view": "south",
  "outline": "selective outline",
  "detail": "medium detail"
}
```

### V7B-REF：create-character-v3 + reference_image（內建 enhance）
```json
{
  "description": "2D side-scrolling game character, 4-to-5 head body ratio, slight 3/4 angle toward viewer with face visible, silver-white long straight hair, deep crimson red eyes, dark purple-gray off-shoulder gothic dress, deep burgundy dark red frills, dark tights, black cat tail, no weapons, facing right",
  "reference_image": {
    "type": "base64",
    "base64": "<插畫 base64（已 PIL resize max=256px，無 data URI 前綴）>",
    "format": "png"
  },
  "image_size": {"width": 256, "height": 256},
  "view": "south",
  "enhance_prompt": true
}
```

### enhance-character-v3-prompt（⚠️ 僅支援文字！不支援圖片）
```json
POST /enhance-character-v3-prompt
{
  "description": "<你的原始簡短描述>",
  "image_size": {"width": 256, "height": 256},
  "view": "south"
}
// 回傳 key = "enhanced_prompt"（非 description/prompt/text）
// 使用：result.get("enhanced_prompt")
// ❌ 此端點不支援 reference_image！圖片 enhance 請用 create-character-v3 的 enhance_prompt: true
```

### pixen（精細像素藝術，可指定小尺寸）
```json
{
  "description": "<描述>",
  "image_size": {"width": 40, "height": 52},
  "outline": "selective outline",
  "detail": "medium detail",
  "view": "side",
  "direction": "west",
  "no_background": true,
  "seed": 42
}
```

> ⚠️ pixen 不支援：`shading`、`init_image`、`color_palette`（都會 HTTP 422）
> ✅ pixen 支援自訂小尺寸！可直接生成 16×16 / 32×32 / 40×52px
> ✅ pixen 是**同步**端點（~25-50秒，無需輪詢），回傳 result["image"]["base64"]
> ❌ `image-to-pixelart` 不能生成角色！只會模糊縮小原圖 → 結果不可用

> ⚠️ **ERR-025（2026-06-16）direction 必須用羅盤方向！**
> - ❌ 絕對禁止：`"direction": "left"` / `"direction": "right"` → HTTP 422！
> - ✅ 唯一合法值：`'north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'`
> - 2D 橫向左朝：`"direction": "west"` | 右朝：`"direction": "east"`
> - 這個限制同樣適用於 create-image-bitforge、create-image-pixflux 等有 direction 參數的端點

### V9 最佳實踐：生成小尺寸 Sprite（2D橫向）

**策略 A（pixen + 文字描述 + 色值）← 推薦**
```json
POST /create-image-pixen
{
  "description": "2D side-scrolling pixel art game character, young girl facing right, silver-white hair (#F1ECF7) with large black bow, crimson red eyes (#E03030), dark purple-gray gothic dress (#3D3448) with deep burgundy ruffled frills (#6B1C24), dark brown-black tights (#2B1F1A), black cat tail, no background, no weapons",
  "image_size": {"width": 40, "height": 52},
  "view": "side",
  "direction": "east",
  "outline": "selective outline",
  "detail": "medium detail",
  "no_background": true,
  "enhance_prompt": false
}
// 費用：1.0 次/張  |  時間：25-50秒  |  回傳：result["image"]["base64"]
```

**策略 B（pixflux + color_image ← 插畫當調色盤）**
```json
POST /create-image-pixflux
{
  "description": "2D side-scrolling pixel art game character, young girl facing right, silver-white hair with black bow, crimson red eyes, gothic dress with red frills, dark tights, black cat tail, no weapons",
  "color_image": {
    "type": "base64",
    "base64": "<插畫 base64, PIL resize max=128px>",
    "format": "png"
  },
  "image_size": {"width": 40, "height": 52},
  "view": "side",
  "direction": "east",
  "outline": "selective outline",
  "detail": "medium detail",
  "no_background": true
}
// 費用：1.0 次/張  |  時間：12-30秒  |  不適合 ≤16px
```

**V9 各尺寸視覺評分（2026-06-16 實測）**：
| 尺寸 | A(pixen) | B(pixflux+color) | 推薦 |
|------|---------|-----------------|------|
| 16×16 | chibi辨識度可 | 不試(太小) | A |
| 32×32 | ✅ 可辨識，頭身比OK | 🟡 配色較接近但比例異 | A |
| 48×48 | 🟡 頭部偏大 | ✅ 配色最接近插畫 | 視需求 |
| 40×52 | ✅ **最接近參考Sprite** | ✅ 可愛chibi | **A**★ |

---

## §CK-9. 餘額查詢標準指令

```powershell
# PowerShell（§O-NOBROWSER：嚴格禁止用 browser_subagent）
$r = Invoke-RestMethod `
  -Uri "https://api.pixellab.ai/v2/balance" `
  -Headers @{Authorization="Bearer 956460ee-978e-4d60-999a-f4b0f567bb48"}
Write-Host "餘額：$($r.count ?? $r.generations ?? ($r | ConvertTo-Json))"
```

```python
# Python
import urllib.request, json
req = urllib.request.Request(
    "https://api.pixellab.ai/v2/balance",
    headers={"Authorization": "Bearer 956460ee-978e-4d60-999a-f4b0f567bb48"}
)
with urllib.request.urlopen(req) as r:
    print(json.loads(r.read()))
```

---

## §CK-10. v2 完整端點快速索引

> 詳細參數請即時讀取：`https://api.pixellab.ai/v2/llms.txt`

| 分類 | 端點 | 同步/異步 | 備注 |
|------|------|---------|------|
| **角色（主力）** | `create-character-v3` | 異步 | 8方向，需 poll |
| **角色** | `create-character-with-4-directions` | 異步 | 4方向 |
| **角色** | `create-character-pro` | 異步 | Pro |
| **圖像** | `create-image-pixflux` | 同步 | 最快，400x400 |
| **圖像** | `create-image-pixen` | 同步 | 精細，512x512 |
| **圖像** | `create-image-bitforge` | 同步 | style 參考，200x200 |
| **動畫** | `animate-with-text-v3` | 異步 | 推薦，256x256，4/8/16幀 |
| **動畫** | `animate-character` | 異步 | 對已有角色 |
| **旋轉** | `generate-8-rotations-v3` | 異步 | 最新 |
| **Prompt 優化** | `enhance-character-v3-prompt` | 同步 | 回傳 key: enhanced_prompt |
| **Prompt 優化** | `enhance-pixen-prompt` | 同步 | 回傳 key: enhanced_prompt |
| **後製** | `resize` | 同步 | 每次 ≤2x |
| **後製** | `remove-background` | 同步 | |
| **後製** | `image-to-pixelart-pro`（直接插畫轉像素，驚人效果） | 同步 | 回傳 key: image |

---

## §CK-13. DS Skin 畫風直接導入（V13 確立，2026-06-16）

> **核心洞察**：不需要文字描述像素風格！直接餵 DS 官方 skin 小人作為 style 就能學習畫風。

### 方案 A：generate-with-style-v2 + 4 skins

```python
# ★★★ 最重要：style_images 用頂層 width/height（不是 size 子欄位！）
FOUR_SKINS = [
    {"image": b64_obj(lady_b64),    "width": 40, "height": 52},  # 頂層
    {"image": b64_obj(doppel_b64),  "width": 34, "height": 51},
    {"image": b64_obj(phantom_b64), "width": 33, "height": 51},
    {"image": b64_obj(vamp_b64),    "width": 21, "height": 49},
]
r, err = api_post("generate-with-style-v2", {
    "style_images": FOUR_SKINS,
    "style_description": "DS pixel art game character sprite with black outline",
    "description": "girl character",  # 不能空字串！
    "image_size": {"width": 48, "height": 48},  # 必須正方形
    "no_background": True,
})
```

### 方案 B：generate-image-v2 + 1 skin style + 3 ref

```python
# generate-image-v2 用 size 子欄位（與上方相反！）
r, err = api_post("generate-image-v2", {
    "description": "girl character sprite",
    "image_size": {"width": 40, "height": 52},  # 可非正方形
    "no_background": True,
    "style_image": {
        "image": b64_obj(lady_b64),
        "size": {"width": 40, "height": 52},  # size 子欄位
    },
    "style_options": {"color_palette": True, "outline": True, "detail": True, "shading": True},
    "reference_images": [
        {"image": b64_obj(doppel_b64),  "size": {"width": 34, "height": 51}},  # size 子欄位
        {"image": b64_obj(phantom_b64), "size": {"width": 33, "height": 51}},
        {"image": b64_obj(vamp_b64),    "size": {"width": 21, "height": 49}},
    ],
})
# 輸出 40×52 正確尺寸！回傳 4 張候選圖。
```

### 方案 C：image-to-pixelart-pro + skin 直接轉

```python
# 最簡單！直接餵 skin，讓 API 完全學習畫風
r, err = api_post("image-to-pixelart-pro", {
    "image": b64_obj(lady_b64),
    "description": "pixel art game character sprite",  # 不能空字串！
})
# 輸出：自動尺寸（通常 82~172px），背景黑色
# V13 效果：Lady 白髮+深紅荷葉邊完美重現！
```

### API 格式對照表

| 端點 | style 輸入 的 size 位置 | description 限制 | 輸出尺寸 |
|------|----------|-----------|------|
| `generate-with-style-v2` | **頂層** `{"width":w,"height":h}` | 不能空 | 必須正方形 |
| `generate-image-v2` | **子欄位** `{"size":{"width":w}}` | 不能空 | 任意 |
| `image-to-pixelart-pro` | - | 不能空 | 自動 |

### 禁止詞（Content Policy）

```
❌ loli       → Generation failed content policy！
✅ young girl / petite girl / small girl  → OK
❌ empty ""   → HTTP 422 description min_length: 1
✅ "character" / "girl character"  → OK
```

---

*Cookbook Version: 2.5 | Updated: 2026-06-16 | 依據：CHAR-006 V1~V13 完整實驗*
*V7B 新增：§CK-0 遊戲類型強制確認、view 有效值修正、髮色規範、enhance_prompt 陷阱*
*V8 新增：image-to-pixelart 端點（圖片直轉像素、同步、1次/張、支援任意小尺寸）*
*V9 新增：pixen/pixflux 正式生成策略、image-to-pixelart 棄用確認*
*V10 新增：bitforge style_image 尺寸限制、resize 端點加入決策樹、VfxMix 34色盤使用*
*V11 新增：flat shading + single color outline 策略、PIL 去噪量化後處理、enhance-pixen-prompt 強制前置*
*V12 新增：medium shading 黃金配置、Pro 端點（gen-v2/gen-with-style-v2/img2px-pro）、API size 子欄位格式修正、generate-with-style-v2 正方形限制、negative_description pixflux 廢棄說明*
*V13 新增：§CK-13 DS skin 畫風直接導入法、關鍵發現：generate-with-style-v2 style_images 用頂層 width/height（與 gen-image-v2 間 API 不一致）、style_images 最多 4 張、description 不能空字串、"loli" 為 content policy 禁止詞*

---

## §CK-14. V14 全模式實驗發現（2026-06-16）

> **實驗**：白髮吸血鬼少女 Sprite，Lady of the Bloodline 配色限制，5種模式全測試

### 關鍵 API 格式新發現

#### generate-with-style-v2 回傳格式（背景任務）
```python
# ✅ 正確：images 是頂層 list，每個元素的 base64 是直接欄位
job["last_response"]["images"][i]["base64"]     # ✅ 直接取
job["last_response"]["images"][i]["image"]["base64"]  # ❌ 這層不存在！

# 每個 image 物件的結構：
{
    "type": "base64",
    "width": 48,
    "height": 48,
    "base64": "..."   # ← 直接在頂層！
}

# gen-with-style-v2 回傳 16 張候選（不是 4 張！）
# last_response 另有 quantized_images 欄位（量化版本）
```

### 費用警告（實測 2026-06-16）

| 端點 | 費用/次 | 備注 |
|------|---------|------|
| `create-image-pixen` | ~0.67 gen/張 | 3張共2gens |
| `create-image-pixflux` | ~0.5 gen/張 | 2張共1gen |
| `create-image-bitforge` | ~0.5 gen/張 | 2張共1gen |
| **`image-to-pixelart-pro`** | **~40 gen/張** | ⚠️ **極貴！2張共80gens** |
| **`generate-with-style-v2`** | **~40 gen/次** | ⚠️ **極貴！回傳16張但1次80gens** |

> **⚠️ 高費用警告**：`image-to-pixelart-pro` 和 `generate-with-style-v2` 的費用是其他端點的 **60~80 倍**！謹慎使用。

### 各模式效果排名（吸血鬼少女測試）

| 排名 | 模式 | 尺寸 | 效果 | 配色準確度 | 費用 |
|------|------|------|------|-----------|------|
| 🥇 | D1 `img2px-pro` ← 插畫 | 132×195 | 完整還原 Lady 所有細節 | ⭐⭐⭐⭐⭐ | 40gen |
| 🥈 | E1 `gen-with-style` #04 | 48×48 | 有 DS 風格，有多樣候選 | ⭐⭐⭐⭐ | 40gen |
| 🥉 | A2 `pixen` 32×32 | 32×32 | 白髮/黑蝴蝶結/深紅裙 完美 | ⭐⭐⭐⭐⭐ | 0.67gen |
| 4 | B2 `pixflux+color` 48×48 | 48×48 | 正面角色，配色準確 | ⭐⭐⭐⭐⭐ | 0.5gen |
| 5 | C1 `bitforge` 32×32 | 32×32 | 最有氣質，白髮飄動感 | ⭐⭐⭐⭐⭐ | 0.5gen |
| 6 | D2 `img2px-pro` ← skin | 91×118 | DS 吸血鬼風格 | ⭐⭐⭐⭐ | 40gen |

### 最佳 CP 值推薦工作流

```python
# 步驟1: pixen 32x32（便宜，效果極好）
# 步驟2: pixflux 48x48 + color_image（便宜，配色精準）
# 步驟3: bitforge 32x32（便宜，最有氣質）
# → 總費用：約 2 gens，可得到 3 種商業級品質的角色！

# 只有在確認設計後才用：
# img2px-pro（40gens）← 用來製作最終高精度版本
# gen-with-style-v2（40gens）← 用來獲取 16 種變體供選擇
```

### mode E 圖片提取正確方式

```python
# generate-with-style-v2 background job completed:
images = job["last_response"]["images"]  # list of 16
for img_data in images:
    b64 = img_data["base64"]  # 直接在頂層！不是 img_data["image"]["base64"]
    w = img_data["width"]
    h = img_data["height"]
```

---

*Cookbook Version: 2.6 | Updated: 2026-06-16 | 依據：CHAR-006 V1~V14 完整實驗*


### 生成端調整（按效果排序）

| 參數組合 | 結構清晰度 | 備注 |
|---------|----------|------|
| `outline: "single color black outline"` + `shading: "flat shading"` | ⭐⭐⭐ 最硬 | 每區域純色，邊緣純黑 |
| `outline: "lineless"` + `shading: "flat shading"` | ⭐⭐⭐ 最簡 | 無邊線，色塊極乾淨 |
| `outline: "selective outline"` + `shading: "basic shading"` | ⭐⭐ 次之 | V9/V10 舊設定 |
| `outline: "selective outline"` + `shading: "detailed shading"` | ⭐ 最雜 | 禁止使用 |

```json
// ✅ 最乾淨設定（推薦）
{
  "outline": "single color black outline",
  "shading": "flat shading",
  "detail": "medium detail",
  "negative_description": "gradient, anti-aliasing, dithering, blurry, smooth shading"
}
```

### §O-10-1 強制：enhance-pixen-prompt 前置（0.05次）
```python
# 每次生成前必須先優化 Prompt！
result = api_post("enhance-pixen-prompt", {
    "description": your_raw_description,
    "image_size": {"width": w, "height": h},
    "outline": "single color black outline",
})
enhanced = result.get("enhanced_prompt", your_raw_description)
# 用 enhanced 描述生成，效果遠優於手寫 Prompt
```

### PIL 後處理流程（免費，無需 API）

```python
from PIL import Image

def remove_isolated_pixels(img):
    """消除孤立噪點：≤1個不透明鄰居的像素 → 刪除"""
    # 詳見 gen_v11_clean_structure.py

def quantize_keeping_transparency(img, num_colors=8):
    """保留透明通道的顏色量化"""
    # 分離 RGBA → RGB 量化 → 合回 alpha

# 推薦流程：去噪 → 量化 → 4x 放大檢視
img = Image.open("sprite.png").convert("RGBA")
cleaned = remove_isolated_pixels(img)
quantized = quantize_keeping_transparency(cleaned, 8)  # 8色最乾淨
big = quantized.resize((w*4, h*4), Image.NEAREST)  # 4x 放大看結構
```

### V11 視覺評估結論（48×48 尺寸）

| 方法 | 結構清晰度 | 配色 | 綜合 |
|------|----------|------|------|
| PIL去噪量化 v9b（8色） | ⭐⭐⭐ 最佳 | 保留原配色 | **推薦** |
| 2C lineless（pixflux） | ⭐⭐⭐ | 偏淡 | 極簡風格 |
| 2E pixen+hard outline | ⭐⭐ | 準確 | 良好 |
| 2A flat+hard outline | ⭐⭐ | 準確 | 良好 |
| 2D bitforge+init_v9b | ⭐ | 混亂 | 不推薦 |

**最終推薦**：先用 `pixflux + flat shading + single color outline + enhance-pixen-prompt`，
再做 PIL 8色量化+去噪後處理 = 最乾淨像素結構。

---

## §CK-12. V12 新方法實驗結論（2026-06-16）

### 最重要發現：medium shading 是黃金中間值

```
shading 完整枚舉（pixflux/bitforge）：
  flat shading         → 過薄，無立體感（V11 舊推薦）
  basic shading        → V9/V10 用過
  ★ medium shading     → 三層漸層，最佳結構/細節平衡！(V12 新推薦)
  detailed shading     → 過複雜
  highly detailed shading → 噪點最多

V12 實測：medium shading + single color black outline + text_guidance_scale:9.5
→ A2(64×80)、G1/G2(pixen) 是迄今最優的生成結果！
```

### Pro 端點（需 Pro 訂閱）實測結果

| 端點 | 結果 | 注意 |
|------|------|------|
| `generate-image-v2` | ✅ 異步，支援 style_options 複製風格 | style_image 需 `size` 子欄位 |
| `generate-with-style-v2` | ✅ 多風格 Sprite 參考，**必須正方形輸出** | 非正方形→HTTP 400 |
| `image-to-pixelart-pro` | ✅ 自動判斷像素密度，結果驚人 | 輸出較大（120-150px），背景黑色 |

### API 格式陷阱（V12 實測修正）

```python
# ❌ 錯誤（會 422）
"style_image": {"image": b64_obj(img), "width": 40, "height": 52}
"reference_images": [{"image": b64_obj(img), "width": 256, "height": 256}]

# ✅ 正確
"style_image": {"image": b64_obj(img), "size": {"width": 40, "height": 52}}
"reference_images": [{"image": b64_obj(img), "size": {"width": 256, "height": 256}}]

# bitforge: style_image 和 init_image 必須 resize 到精確輸出尺寸！
# 輸出 64×80 → style_image 必須也是 64×80
img_b64(LADY_SPRITE, exact_wh=(64, 80))  # ✅

# pixflux: init_image 也必須精確匹配輸出尺寸！
# 輸出 48×60 → init_image 必須也是 48×60
img_b64(LADY_ILLUST, exact_wh=(48, 60))  # ✅

# generate-with-style-v2: 只接受正方形 image_size
"image_size": {"width": 48, "height": 48}  # ✅ 正方形
"image_size": {"width": 48, "height": 60}  # ❌ HTTP 400
```

### negative_description 廢棄說明

```
pixflux 的 negative_description 已標記 (Deprecated)！
→ 在 pixflux payload 中加入完全無效！
→ 改用 bitforge + negative_description = 真正生效！
```

### V12 最佳結果排名

| 排名 | 圖片 | 策略 | 尺寸 | 評分 |
|------|------|------|------|------|
| 🥇 | A2 | pixflux + medium shading + single color outline | 64×80 | ⭐⭐⭐⭐⭐ |
| 🥈 | G2 | pixen + single color outline | 64×80 | ⭐⭐⭐⭐⭐ |
| 🥉 | E1(v01-v03) | gen-with-style-v2 + 3 Sprites | 48×48 | ⭐⭐⭐⭐ |
| 4 | G1 | pixen + single color black outline | 48×60 | ⭐⭐⭐⭐ |
| 5 | F2 | image-to-pixelart-pro + Amelia Illust | auto | ⭐⭐⭐⭐ |
| 6 | A3 | pixflux + medium shading + guidance 10.0 | 32×40 | ⭐⭐⭐⭐ |

### V12 新推薦工作流

```python
# 主力配置（適合 48×60 / 64×80）
{
    "outline": "single color black outline",  # 或 "single color outline"
    "shading": "medium shading",              # ★ 新！替代 flat shading
    "detail": "highly detailed",
    "text_guidance_scale": 9.5,               # ↑ 提高（原 8.0）
    "no_background": True,
    "color_image": b64_obj(lady_sprite_b64),  # Lady Sprite 配色引導
}
# 搭配 enhance-pixen-prompt 前置（§O-10-1）
# 搭配 PIL 8色量化+去噪後處理

# pixen 端點（結構最乾淨）
{
    "outline": "single color outline",
    "detail": "highly detailed",
    # ⚠️ pixen 不支援 shading/color_image/init_image
}

# image-to-pixelart-pro（直接插畫轉像素，驚人效果）
{
    "image": b64_obj(illustration_b64),
    "description": "clean pixel art, no dithering",
}
# 輸出尺寸自動決定（通常 120-200px），背景黑色
```

---

*Cookbook Version: 2.5 | Updated: 2026-06-16 | 依據：CHAR-006 V1~V14 完整實驗*
*V7B 新增：§CK-0 遊戲類型強制確認、view 有效值修正、髮色規範、enhance_prompt 陷阱*
*V8 新增：image-to-pixelart 端點（圖片直轉像素、同步、1次/張、支援任意小尺寸）*
*V9 新增：pixen/pixflux 正式生成策略、image-to-pixelart 棄用確認*
*V10 新增：bitforge style_image 尺寸限制、resize 端點加入決策樹、VfxMix 34色盤使用*
*V11 新增：flat shading + single color outline 策略、PIL 去噪量化後處理、enhance-pixen-prompt 強制前置*
*V12 新增：medium shading 黃金配置、Pro 端點（gen-v2/gen-with-style-v2/img2px-pro）、API size 子欄位格式修正、generate-with-style-v2 正方形限制、negative_description pixflux 廢棄說明*
*V13/V14 新增：§CK-15 img2px-pro 回傳格式（last_response.image 非 images list）、Skin 規格轉換三方案比較*

---

## §CK-15. image-to-pixelart-pro 正確回傳格式（V14 實測，2026-06-16）

> **關鍵區別**：`image-to-pixelart-pro` 的異步 job 完成後，回傳格式與 `generate-with-style-v2` 完全不同！

### 回傳格式對比

| 端點 | job last_response 結構 | 取圖方式 |
|------|----------------------|---------|
| `generate-with-style-v2` | `{"images": [...16 items...]}` | `images[i]["base64"]` （頂層直取）|
| **`image-to-pixelart-pro`** | `{"image": {...}, "quantized_image": {...}}` | `image["base64"]` 或 `quantized_image["base64"]` |

### img2px-pro 完整 last_response 鍵值

```python
# 確認的 last_response keys（V14 實測）：
{
    "seed": ...,
    "type": ...,
    "image": {"base64": "...", "width": 112, "height": 161},  # ★ 原始像素化結果
    "action": ...,
    "progress": ...,
    "billing_usage": ...,
    "generation_id": ...,
    "billing_charged": ...,
    "quantized_image": {"base64": "..."},  # 量化（減色）版本
    "generation_started_at": ...,
    "original_image_n_colors": ...,
    "quantized_image_n_colors": ...
}

# ✅ 正確取法：
img_b64 = job["last_response"]["image"]["base64"]  # 原始版
quantized_b64 = job["last_response"]["quantized_image"]["base64"]  # 量化版
```

### 輸出特徵（V14 Lady_of_the_Bloodline 插畫實測）

```
輸入：487×707px 插畫（縮至 176×256 後傳入）
輸出：112×161px 像素藝術（自動決定尺寸，保持比例）
品質：★★★★★ — 最高品質，完美保留 Lady 的特徵：
  - 白銀髮色（準確）
  - 深紫炭灰服裝（準確）
  - 深酒紅荷葉邊（準確）
  - 貓尾、貓耳（保留）
  - 紅眼（準確）
費用：~40 gen（高費用，必須用戶確認！）
後處理：PIL NEAREST resize to 40×52 → 完整保留細節
```

### 三方案比較（DS Skin 規格 40×52px 轉換）

| 方案 | 費用 | 品質 | 說明 |
|------|------|------|------|
| **A1 PIL NEAREST** | 0 gen | ⭐⭐ | 直接縮小，細節混亂，白色雜點 |
| **A2 LANCZOS→NEAREST** | 0 gen | ⭐⭐⭐ | 略好，但仍缺乏像素清晰度 |
| **B2 pixflux→PIL** | 0.5 gen | ⭐⭐⭐ | 全新生成，直立姿勢，配色OK |
| **C2 img2px-pro→PIL** | 40 gen | ⭐⭐⭐⭐⭐ | 最佳！完整保留插畫所有特徵 |

> **推薦**：**C2（img2px-pro）** 若預算允許為最佳選擇；若需省成本可用 **A2（PIL LANCZOS）**。

### 正確的異步流程（§O12 標準流程）

```python
# 1. 呼叫 img2px-pro（異步）
r = requests.post(f"{BASE_URL}/image-to-pixelart-pro", headers=HEADERS, json={
    "image": {"type": "base64", "base64": img_b64, "format": "png"},
    "description": "pixel art style",  # 可選但建議加
})
# 回傳：{"background_job_id": "...", "status": "processing", "usage": null}
job_id = r.json()["background_job_id"]

# 2. Poll（通常 10-30s）
job = poll_background_job(job_id)

# 3. 提取圖片（與 gen-with-style-v2 不同！）
img_b64 = job["last_response"]["image"]["base64"]  # ★ 不是 images list！

# 4. PIL resize 到 DS skin 規格
from PIL import Image
img = b64_to_img(img_b64)
skin = img.resize((40, 52), Image.NEAREST)
skin.save("output_40x52_skin.png")
```

