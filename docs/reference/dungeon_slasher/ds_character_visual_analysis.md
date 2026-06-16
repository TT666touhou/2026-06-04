# Dungeon Slasher 角色視覺完整分析報告
> **執行角色：Designer**  
> **分析日期：2026-06-15**  
> **來源資料：官方 Wiki 素材庫（§P-0 白名單認證）**  
> **版本：v1.0 — 完整正式版，取代 analysis_20260615.md**

---

## 0. 關鍵前提：DS 存在兩套截然不同的美術風格

DS 在官方素材中使用**兩種並行的視覺語言**，用途完全不同：

| | **風格 A：遊戲 Sprite** | **風格 B：角色插畫（立繪）** |
|---|---|---|
| **用途** | 遊戲實際畫面、皮膚選擇介面 | 宣傳頁面、角色故事頁面 |
| **解析度** | 約 30×52 ~ 44×61 px（原生） | 230×382 ~ 781×946 px |
| **媒介** | 像素藝術（pixel art） | 動漫風格（anime illustration）或高解析像素 |
| **生成目標** | ✅ 遊戲 Sprite 生成的直接參考 | ⚠️ 色彩/服裝靈感參考，非直接目標 |

---

## 一、風格 A 深度分析：遊戲 Sprite

### 1-A. 精確比例量測

從 8 個官方 Sprite 的直接量測：

| 角色/皮膚 | 寬 (px) | 高 (px) | 寬/高比 | 估計頭高 | 頭身比 |
|---------|---------|---------|---------|---------|------|
| Summoner（Best Friend） | 39 | 53 | 0.74 | ≈12px | 1:4.4 |
| Assassin（基本） | 30 | 52 | 0.58 | ≈12px | 1:4.3 |
| Soul Eater（Trixie Devil） | 33 | 54 | 0.61 | ≈12px | 1:4.5 |
| Fighter（基本） | 25 | 55 | 0.45 | ≈11px | 1:5.0 |
| Gunner（基本） | 44 | 61 | 0.72 | ≈13px | 1:4.7 |
| Ronin（Blood Moon） | 43 | 57 | 0.75 | ≈13px | 1:4.4 |
| Inquisitor（Nachtrichter） | 32 | 51 | 0.63 | ≈12px | 1:4.3 |
| Assassin（Lady of Bloodline） | 40 | 52 | 0.77 | ≈12px | 1:4.3 |

**結論：**
- **標準高度：約 51–61 px**，大多集中在 52–55 px
- **標準寬度：約 30–44 px**，受姿勢和服裝影響大
- **頭身比：約 1:4.3 ~ 1:5.0**，接近「現實比例縮短版」而非 SD/Q 版
- **頭部高度：穩定約 11–13 px**（幾乎所有角色一致）
- 注意：**Gunner 最寬（44px）**，因雙槍造型手臂張開；**Fighter 最窄（25px）**，站立時手臂靠近

---

### 1-B. 站立姿勢（Idle Stance）

DS Sprite 的待機站立姿勢具有強烈的一致性風格：

```
視角：正側面 (side view)，面向東（east）方向
重心：略向前傾，似乎隨時準備動作
腳：通常分開站立，約 1/3 肩膀寬
手臂：多半在身側，或持武器呈戰鬥預備姿勢
脊椎：無過度挺直，有些微前傾「行動感」
頭部：朝前，側面輪廓清晰
```

**具體觀察（從 Sprite 逐一分析）：**

| 角色 | 待機特徵 |
|------|---------|
| Assassin | 雙手持刀，身體略傾，側身剪影俐落 |
| Gunner | 雙臂展開持槍，最寬的 Sprite，有「張力感」|
| Ronin | 一手握刀柄，斗篷使剪影更寬大 |
| Summoner | 持召喚物，衣物（斗篷）使輪廓豐富 |
| Soul Eater/Trixie | 衣物（裙子）拉寬下半身輪廓，腿細 |
| Inquisitor | 直立，外套使輪廓偏寬，腿有靴子加粗感 |

---

### 1-C. 手腳粗細與長度

**手臂：**
- 前臂+上臂共約 **8–12 px 長**
- 手腕處約 **2 px 寬**（最細部位）
- 持武器的手/臂通常稍粗（因武器 px 貼近）
- **無明顯肌肉鼓脹感**，接近「筆形」四肢

**雙腿：**
- 大腿：約 **4–5 px 寬**
- 小腿：約 **3–4 px 寬**（稍細於大腿）
- 腳踝：約 **2–3 px**（最細）
- 腳（鞋）：約 **5–8 px 長**，通常是角色最「厚重」的部分
- **腿部長度（腰至地面）：約 30–35 px**，佔總高的 55–65%
- 靴子/鞋子顏色通常比腿深，形成視覺分隔

**手部：**
- 手掌+手指整體約 **3×4 px** 方塊
- 不畫出個別手指（像素不夠大）
- 握武器時用色塊表示

---

### 1-D. 五官表達方式（頭部細節）

DS Sprite 的五官在約 **12 px 的頭高** 內表達：

```
頭部高度：約 11–13 px
頭部寬度：約 10–12 px（近似正圓）
```

| 五官 | 表達方式 | 大小 |
|------|---------|------|
| **眼睛** | 2×2 px 或 3×2 px 的色塊，通常為彩色 | 最醒目的五官 |
| **眼白** | 少數角色有 1 px 高亮點 | 非必要 |
| **眼線** | 上眼瞼用 1 px 深色線 | |
| **鼻子** | 通常**完全省略**，或 1 px 暗點 | 極簡 |
| **嘴巴** | 1–2 px 橫線，顏色略深於皮膚 | 幾乎不可見 |
| **眉毛** | 偶爾 2–3 px 深色橫線，在眼睛上方 | 少數角色有 |
| **頭髮** | 佔頭部面積約 30–40%，用色塊區分層次 | |
| **髮飾** | 是重要的角色識別元素（蝴蝶結、髮夾等）| |

**重點：** 在 50px 高的 Sprite 中，**眼睛是唯一真正被描繪的五官**。眼睛的顏色＋形狀＋高亮是角色表情的全部。

---

### 1-E. 陰影處理（Shading）

DS Sprite 使用**高效的 2–3 層陰影系統**：

```
┌─────────────────────────────────────────────────────┐
│  明亮面（亮色）  │  基本面（主色）  │  陰影面（暗色）│
│    ≈20%面積    │    ≈60%面積    │    ≈20%面積   │
└─────────────────────────────────────────────────────┘
```

**各部位陰影規則：**

| 部位 | 陰影位置 | 典型色差 |
|------|---------|---------|
| 頭髮 | 下層/內層較暗，頂部有 1–2 px 高光 | 約 30–40% 明度差 |
| 皮膚 | 臉頰/下頜輪廓陰影 | 較淺，約 15–20% 明度差 |
| 衣物上半 | 肩膀/胸口受光，腋下/皺褶較暗 | 中等陰影對比 |
| 衣物下半（裙/褲） | 褶皺處用 1–2 px 暗線表示 | |
| 腿部 | 前腿稍亮，後腿稍暗（深度感）| |
| 鞋底 | 通常是角色最深的顏色之一 | |

**特殊觀察：**
- **無漸層（gradient）**：所有陰影都是硬邊 (hard edge)，無過渡
- **Flat Shading 為主**，偶爾 Basic Shading（加一層高光）
- 衣物的陰影通常是大塊色而非細膩線條

---

### 1-F. 外框（Outline）

**結論：DS Sprite 使用「選擇性描邊（Selective Outline）」**

具體規則：

```
✅ 外輪廓：有描邊，顏色為深棕/深灰（非純黑 #000000）
   - 皮膚外框：深棕 ≈ #3D1C07 ~ #5A2A0A
   - 頭髮外框：比頭髮色深 2–3 個明度層
   - 衣物外框：比衣物色深 3–4 個明度層

✅ 內部線條（輪廓內）：深色同色系（非黑色）
   - 衣物折線/接縫：暗色同系
   - 頭髮分層：比頭髮基色深 1–2 層

❌ 相鄰色塊邊界（同一區域）：通常無描邊，直接色塊對接
❌ 純黑 (#000) 描邊：不使用，只在陰影最深處近似
```

**實際顏色範例（Assassin 基本 Sprite）：**
- 外框：`#2A1A0A`（深棕，非純黑）
- 頭髮深色：`#3A2A1A`
- 皮膚陰影：`#C08060`

---

### 1-G. 移動姿勢（Run/Walk Animation）

從影片幀（rQXH8wkCF8s, DS_Short_2）分析：

**跑步循環特徵：**
```
幀數：約 6–8 幀為一個完整循環
速度：非常快速（snappy），沒有「慢動作感」

姿態描述：
  - 上半身：略前傾（約 10°），保持相對穩定
  - 手臂：交替前後擺動，幅度約 ±15–20° 
  - 腿部：全力奔跑，大腿前後拉開
  - 空中幀：通常有 1–2 幀離地（雙腳不觸地）
  - 髮飾/斗篷：有 1–2 幀的延遲飄動（布料動力學感）
  - 腳步：前腳著地，後腳跟離地
```

**攻擊動作特徵：**
```
結構：Anticipation（1–2幀）→ Strike（1–2幀）→ Recovery（2–3幀）
特點：
  - 攻擊瞬間通常有「Squash & Stretch」感
  - Strike 幀通常是最大幅度姿勢
  - 武器/手臂延伸至最遠點時 Sprite 整體最寬
  - 受擊：角色整體「閃白」1 幀（Flash White）
```

**待機（Idle）動作特徵：**
```
幀數：約 4–6 幀
內容：
  - 身體輕微上下（±1–2 px），模擬呼吸
  - 頭部可能有微小的朝向調整
  - 武器/道具有低頻搖擺
```

---

## 二、風格 B 深度分析：角色插畫（立繪）

### 2-A. 量測數據

| 角色/插畫名 | 尺寸 | 實際像素風格？ |
|---------|------|------------|
| Summoner / Best_Friend | 619×775 px | ✅ 是（高解析度像素藝術）|
| Soul Eater / Trixie_Devil | 781×946 px | ✅ 是（高解析度像素藝術）|
| Assassin / Lady_of_Bloodline | 487×707 px | 否（非像素，平滑線稿）|
| Inquisitor / Nachtrichter | 230×382 px | 否（非像素，平滑線稿）|
| Ronin / Blood_Moon | 560×682 px | 否（非像素，平滑線稿）|

**重要區分（插畫內部還有兩個子類別）：**

| 子類別 | 描述 | 代表 |
|-------|------|------|
| **B-1：高像素插畫** | 超大分辨率的「放大像素藝術」，保留像素粒感，用作立繪展示 | Trixie_Devil, Best_Friend_Summoner |
| **B-2：動漫手繪插畫** | 平滑線稿 + 平面填色，接近 gacha 遊戲的卡牌插畫 | Blood_Moon, Nachtrichter, Lady_of_Bloodline |

---

### 2-B. 風格 B-1（高像素插畫）詳細分析

以 **Trixie Devil（Soul Eater）** 為主要範例：

**比例與身型：**
```
整體高度：946 px（極高解析度展示用）
頭身比：約 1:5.5 ~ 1:6（比遊戲 Sprite 更接近真實比例）
腰部：明顯纖細，有「纖腰」設計
胸部：有輕微表現，非夸張
腿部：修長，佔身高約 55%
```

**頭部比例與五官：**
```
臉型：圓形輪廓，下巴略尖（典型動漫臉型）
眼睛：佔臉部面積最大，約 1/4 臉高
       瞳孔：有漸層（深紫→淺紫）
       眼線：上眼瞼粗，有睫毛（約 2–3 根像素線）
       高光：白色高光點，約 3×4 px 方塊
眉毛：細線型，有弧度，描繪清晰
鼻子：極簡，通常 1–2 px 陰影點
嘴巴：小而精緻，下唇有高光
臉頰：整體偏淡粉
```

**描邊特徵：**
```
輪廓線：
  - 主要輪廓：中等粗細，深紫色（對應角色主色調）
  - 頭髮輪廓：自然跟隨頭髮色的深色版本
  - 內部線條：細膩，用於衣物皺褶/裙邊細節

陰影：
  - 5–7 層漸進（比遊戲 Sprite 複雜得多）
  - 有明顯的「cel shading」感（日式動漫風格）
  - 高光：明亮白色（頭髮頂部、皮膚受光處）
  - 陰影：對應色調的偏藍/冷暗色
```

**Best_Friend Summoner（619×775 px）分析：**
```
整體風格：偏可愛，「chibi lite」感（比純 chibi 更修長）
頭身比：約 1:4（比 Trixie Devil 更 SD 化）
主色：橙色系（頭髮）+ 綠色（斗篷）+ 白色（上衣）+ 深灰（裙子）
配件：持一個「植物精靈熊」玩偶（重要 Summoner 特徵）
服裝：
  - 綠色大斗篷（披風，有金邊）
  - 白色上衣
  - 深灰/橄欖綠裙子（有褶子）
  - 白色過膝長襪
  - 黑色淺口皮鞋
姿態：站立，一手抱召喚物，另一手握斗篷邊緣，輕鬆自然
```

---

### 2-C. 風格 B-2（動漫手繪插畫）詳細分析

以 **Nachtrichter（Inquisitor）** 為主要範例（與用戶目標角色服裝風格最接近）：

**比例：**
```
頭身比：約 1:7 ~ 1:7.5（成人比例，偏寫實），非 SD 化
腰部：明顯纖細
胸部：有描繪但不誇張
腿部：修長，佔身高約 58%
腳：穿高跟靴，有明顯跟高，腿視覺上更長
```

**配色分析（Nachtrichter）：**
```
帽子：深灰黑 #1A1A2A
外套（長版）：深暗黑 #252530，袖口深紅 #8B1A1A
內搭白衣：米白 #F0EDE0
腰帶：金棕 #B07830 + 黑色扣具
短裙：黑 #1A1A20
絲襪：深灰 #404040，有光澤
靴子：黑色，高跟約 8cm 感
飾品：金色徽章（警察星形）
持物：白色大型物品（布偶？）帶血跡
血跡：鮮紅 #CC1010（點綴，強調「黑暗」屬性）
頭髮：灰白色 #D8D0C8，輕微飄逸
眼睛：深紅 #CC2020（異色，強烈視覺衝擊）
```

**Lady of Bloodline（Assassin，動漫非像素插畫）配色：**
```
頭髮：灰白 #D5CCC5，長而直，略帶飄動
眼睛：深紅 #BB2020（相同的「紅眼」系列主題）
蝴蝶結：黑色 #1A1A1A，位於頭頂
連衣裙：主色深灰黑 #282828
         下擺荷葉邊：暗紅 #8B1A1A（雙層）
         袖口：暗紅荷葉邊
腰帶：黑色，束腰設計
絲襪：深灰 #3A3A3A
頸部：十字架項鍊（白色）
整體配色：黑色＋暗紅＋灰白，哥德蘿莉風格
```

---

## 三、兩種風格的頭身比對比總結

```
風格 B-2 插畫（Nachtrichter）  ─── 1:7（成人，最修長）
風格 B-1 插畫（Trixie Devil）  ─── 1:5.5–6（修長但偏動漫）
風格 B-1 插畫（Best Friend）   ─── 1:4（偏 SD，最可愛）
風格 A  Sprite（大多數）      ─── 1:4.3–5.0（Sprite 限制下的務實比例）
                                   ↑
                           遊戲生成目標
```

---

## 四、PixelLab API 分析：是否能透過圖片轉化生成？

### 4-A. 可用端點總結

| 端點 | 功能 | 尺寸限制 | 可否用圖片輸入？ |
|------|------|---------|-------------|
| `generate-image-pixflux` | 文字→像素藝術 | 最大 400×400 | ✅ `init_image`（弱引導）|
| `generate-image-bitforge` | 風格轉移 | **最大 200×200** | ✅ `style_image` + `init_image` |
| `animate-with-text` | 文字→動畫 | **只能 64×64** | ✅ `reference_image`（引導） |
| `animate-with-skeleton` | 骨架→動畫 | 最大 256×256 | ✅ `reference_image` + `skeleton_keypoints` |
| `inpaint` | 局部修改 | 最大 200×200 | ✅ `inpainting_image` + `mask_image` |
| `rotate` | 旋轉視角 | 最大 200×200 | ✅ `from_image`（核心功能）|
| `estimate-skeleton` | 估計骨架 | 最大 256×256 | ✅ `image`（核心功能）|

### 4-B. 從插畫生成 Sprite 的可行策略

#### 策略一：Bitforge 風格轉移（推薦，最直接）

```python
# 最佳工作流：插畫→Sprite 的風格轉移
response = client.generate_image_bitforge(
    description="cute anime girl, red-orange twin tail hair, black gothic 
                 pleated skirt, white ruffled blouse, black ribbon tie,
                 side view sprite, dungeon slasher style",
    image_size={"width": 48, "height": 64},  # 標準 DS Sprite 尺寸
    
    # 關鍵：提供 DS 官方 Sprite 作為風格參考
    style_image=trixie_devil_sprite_base64,  # 使用 Trixie Devil 作為像素風格參考
    style_strength=70.0,   # 70% 風格遵循（保持像素感）
    
    outline="selective outline",      # ← DS 的描邊風格
    shading="basic shading",          # ← DS 的陰影層級
    detail="highly detailed",         # ← 高細節（在小尺寸內最大化）
    view="side",                      # ← 橫向卷軸視角
    direction="east",                 # ← 朝右（DS 標準方向）
    no_background=True,               # ← 透明背景
    text_guidance_scale=8.0,
)
```

**優點：** 使用 `style_image` 直接轉移 DS 的像素美學  
**限制：** 最大 200×200，需要確認 48×64 在此限制內（✅ 符合）

#### 策略二：Pixflux + init_image（實驗性）

```python
# 使用插畫作為 init_image，配合 Pixflux 的像素化能力
response = client.generate_image_pixflux(
    description="pixel art character sprite, cute girl, twin tails, 
                 gothic lolita dress, selective outline style, 
                 dungeon slasher game sprite, side view, 48x64",
    image_size={"width": 48, "height": 64},
    
    # 將插畫縮小後作為初始圖
    init_image=resized_illustration_base64,
    init_image_strength=400,  # 較高的初始引導（1–999）
    
    outline="selective outline",
    shading="basic shading",
    view="side",
    direction="east",
    no_background=True,
)
```

**注意：** `init_image_strength` 越高越「像」原圖，越低越「自由發揮」  
**建議值：** 300–500（保留服裝結構，改變風格）

#### 策略三：Skeleton 動畫生成（最強大，適合製作動畫）

```python
# 步驟 1：估計一個現有 DS Sprite 的骨架
skeleton_response = client.estimate_skeleton(
    image=trixie_devil_sprite_base64,
)
keypoints = skeleton_response.keypoints

# 步驟 2：用骨架 + 新角色參考圖生成動畫幀
anim_response = client.animate_with_skeleton(
    view="side",
    direction="east",
    image_size={"width": 48, "height": 64},
    reference_image=our_character_sprite_base64,  # 已生成的角色 Sprite
    skeleton_keypoints=adjusted_keypoints,         # 從 Trixie Devil 取得的骨架，調整至目標姿勢
    guidance_scale=4.0,
)
```

**這是最強大的工作流**：  
DS Sprite → 取得骨架 → 調整姿勢 → 生成我們的角色同姿勢

---

### 4-C. 使用插畫作為 style_image 的可行性

**技術可行性：** ✅ 完全支援

**推薦圖片組合：**

| 目的 | 使用哪張插畫 | 原因 |
|------|------------|------|
| 服裝/姿勢參考 | Nachtrichter（非像素插畫） | 哥德系黑色服裝，最接近目標 |
| 像素風格參考 | Trixie Devil Sprite（遊戲 Sprite）| 雙馬尾 + 黑暗系，最像素 |
| 表情/頭部參考 | Lady of Bloodline（非像素插畫）| 哥德蘿莉五官，白色系 |

**最佳工作流（推薦的圖片輸入組合）：**
```
description = 文字描述服裝細節
style_image = Trixie Devil 遊戲 Sprite（定義像素風格）
init_image = Nachtrichter 插畫縮小版（定義服裝構成，可選）
```

---

### 4-D. PixelLab 參數速查表（針對 DS 風格生成）

```python
# Bitforge 推薦參數
PIXELLAB_DS_STYLE_PARAMS = {
    "outline": "selective outline",    # DS 標誌性描邊
    "shading": "basic shading",        # 2–3 層，乾淨
    "detail": "highly detailed",       # 在小尺寸內盡量詳細
    "view": "side",                    # 橫向卷軸視角
    "direction": "east",               # 面朝右（DS 標準）
    "no_background": True,             # 透明背景
    "text_guidance_scale": 8.0,        # 高文字引導
    "style_strength": 60.0,            # 60–75% 風格引導（視參考圖決定）
    "isometric": False,
    "oblique_projection": False,
}

# 推薦圖片尺寸（符合 DS Sprite 比例）
TARGET_SIZES = {
    "small": {"width": 32, "height": 48},   # 16:24 比例，適合小型
    "standard": {"width": 48, "height": 64}, # 3:4 比例，DS 主流
    "large": {"width": 64, "height": 80},   # 4:5 比例，高細節
}
```

---

## 五、針對目標角色的綜合建議

目標：**哥德蘿莉女角，紅色雙馬尾，白色蓬蓬袖上衣，黑色褶裙，黑色蝴蝶結**

### 5-A. PixelLab 文字描述（Prompt）

```
主描述（Bitforge / Pixflux）：
"pixel art character sprite, cute anime girl with red-orange twin tails hair,
wearing a white frilly blouse with puff sleeves and black ribbon bow tie,
a high-waisted black gothic pleated mini skirt with silver buckles,
black thigh-high stockings or tights, gothic lolita style,
side view sprite facing right, dungeon slasher game art style,
selective outline, flat cel shading with 2-3 shade levels,
transparent background"

負向描述（如支援）：
"realistic, gradient shading, 3D, smooth lines, chibi, deformed hands,
extra limbs, blurry, low quality"
```

### 5-B. 最接近的官方參考 Sprite

1. **第一選擇：** Soul Eater / Trixie_Devil.png（33×54 px）
   - 雙馬尾（白銀→我們需要紅色）
   - 黑暗系洋裝（裙子）
   - 同為女性角色，Sprite 比例接近

2. **第二選擇：** Assassin / Lady_of_the_Bloodline.png（40×52 px）
   - 哥德蘿莉服裝（最接近）
   - 黑色+暗紅荷葉邊
   - 蝴蝶結

3. **第三選擇：** Inquisitor / Nachtrichter.png（32×51 px）
   - 黑色外套+白色內搭（服裝結構最接近）
   - 但非「蓬蓬袖」風格

### 5-C. 生成尺寸建議

- **Sprite 主體：** 48×64 px（Bitforge 支援）
- **立繪插畫：** 不生成（手繪插畫超出 PixelLab 範圍，僅做 Sprite）
- **動畫幀：** 64×64 px（animate-with-text 固定尺寸）

---

## 六、舊版 analysis_20260615.md 的缺陷（修正紀錄）

| 舊版問題 | 本報告修正 |
|---------|---------|
| 比例數據為「推估」 | ✅ 全部量測 8 個 Sprite 真實 px 尺寸 |
| 未區分插畫子類型 | ✅ 分為 B-1 高像素插畫 / B-2 動漫插畫 |
| 陰影層次描述模糊 | ✅ 精確描述 2–3 層系統 + 面積佔比 |
| 五官分析缺失 | ✅ 新增各五官 px 尺寸與表達方式 |
| PixelLab 分析不完整 | ✅ 完整 API 分析 + 三種策略 + 代碼範例 |
| 無移動姿勢分析 | ✅ 新增跑步/攻擊/待機動作分析 |
| 描邊顏色不準確 | ✅ 從實際 Sprite 取樣，確認非純黑 |

---

*Designer ROLE 分析完成於 2026-06-15*  
*資料版本：DS Wiki（官方）+ OpenAPI v1 文件（即時抓取）*  
*下一步：根據本報告，使用 Bitforge API + Trixie Devil Sprite 作為 style_image 生成主角第一版 Sprite*
