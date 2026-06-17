# 🎨 遊戲資產採購完整清單與資源指南
## Designer 研究文件 v2.0（資產採購深度報告）
**更新日期**：2026-06-04  
**研究方法**：Browser 直接瀏覽 itch.io + 3 個資產商店比較 + 跨平台搜尋  
**來源**：itch.io、craftpix.net、kenney.nl、opengameart.org  

---

## 目錄

1. [資產採購戰略總覽](#1-資產採購戰略總覽)
2. [六種合作模式各自的資產需求矩陣](#2-六種合作模式各自的資產需求矩陣)
3. [已找到的具體資產清單](#3-已找到的具體資產清單)
   - [A 類：角色精靈（Characters）](#a-類角色精靈characters)
   - [B 類：敵人/獵物（Enemies & Creatures）](#b-類敵人獵物enemies--creatures)
   - [C 類：環境與地圖素材（Tilesets & Environments）](#c-類環境與地圖素材tilesets--environments)
   - [D 類：UI 與圖示（UI & Icons）](#d-類ui-與圖示ui--icons)
   - [E 類：視覺特效（VFX）](#e-類視覺特效vfx)
   - [F 類：音效與音樂（Audio）](#f-類音效與音樂audio)
4. [資產平台比較](#4-資產平台比較)
5. [兩個完整資產組合方案](#5-兩個完整資產組合方案)
6. [仍缺少的資產與解決方案](#6-仍缺少的資產與解決方案)
7. [授權與法律注意事項](#7-授權與法律注意事項)
8. [採購優先順序](#8-採購優先順序)

---

## 1. 資產採購戰略總覽

### 關鍵決策：自製 vs 採購

在採購任何資產前，需要理解這個核心矛盾：

| 策略 | 優點 | 缺點 | 適合場景 |
|------|------|------|---------|
| **全部自製** | 完全一致的風格，版權明確 | 耗時 400-800 小時以上 | 有專業美術，有充裕時間 |
| **全部採購** | 快速，可立即開始開發 | 風格可能不一致，需付費 | 快速 MVP 驗證 |
| **採購 + 修改** | 平衡效率與獨特性 | 需要修改技術，授權限制 | **推薦方案** |
| **Prototype 採購，商業化自製** | 低風險，高品質終品 | 兩次工作量 | 長期計畫 |

**本專案建議：採購 + 修改策略**  
- 先用採購資產快速建立可玩的 Prototype
- 驗證合作機制好玩後，再投入自製美術資源

---

## 2. 六種合作模式各自的資產需求矩陣

> 每種合作模式因為設計結構不同，對美術資產的依賴程度也不同。

### 模式 A：非對稱角色合作（Class-Based）
**資產重點：角色差異化 > 環境 > UI**

```
必要資產清單：
✅ 4 個外形高度差異化的玩家角色（各自動畫集）
✅ 角色技能視覺特效（每人 1-2 種獨特特效）
✅ 1 個主要獵物角色（複雜行為動畫）
✅ 清楚的角色識別 UI（HUD 上能看到隊友狀態）
可選資產：
🔲 2-3 個次要敵人
🔲 多種環境主題
```

**難點**：4 套不同的角色動畫集，工作量是其他模式的 4 倍

---

### 模式 B：任務流程合作（Process-Based）
**資產重點：環境機關 > UI 系統 > 角色（可以外形相似）**

```
必要資產清單：
✅ 1-2 個玩家角色（可以用不同顏色版本區分）
✅ 場景機關動畫（陷阱、機器、設施）
✅ 流程狀態 UI（進度條、計時器、任務提示）
✅ 1 個主要目標/獵物（不需複雜戰鬥動畫）
可選資產：
🔲 豐富的環境裝飾
🔲 VFX 強調流程中的成功/失敗
```

**優點**：角色可以很相似，大幅降低角色美術成本

---

### 模式 C：資訊不對稱合作（Information Asymmetry）
**資產重點：UI/信息顯示 >> 一切**

```
必要資產清單：
✅ 各玩家的「私有信息面板」UI
✅ 清楚的資訊圖示（地圖符號、數字、指示器）
✅ 基本角色（外形不重要，識別性重要）
✅ 地圖/迷宮環境素材
可選資產：
🔲 豐富的裝飾性角色動畫
🔲 複雜 VFX
```

**優點**：幾何/極簡風格就能運作，美術成本最低

---

### 模式 D：空間依賴合作（Spatial Interdependence）
**資產重點：場景關卡設計 > 機關互動 > 角色**

```
必要資產清單：
✅ 豐富的地圖/關卡 tileset（按鈕、橋、門、平台）
✅ 可互動機關的動畫
✅ 玩家角色（需要清楚的位置識別）
✅ 路徑/連接的視覺指示
可選資產：
🔲 多個環境主題
🔲 複雜的敵人
```

**難點**：關卡美術工作量最大（每個關卡需要獨特機關設計）

---

### 模式 E：共享資源合作（Shared Economy）
**資產重點：資源視覺化 > UI > 角色**

```
必要資產清單：
✅ 可見的「共享資源」視覺化 UI
✅ 資源物件（食物、材料等的圖示/精靈）
✅ 玩家角色（可採集/消耗動作）
✅ 明確的「資源不足」警告視覺
可選資產：
🔲 環境中的資源分布圖
🔲 豐富的生態系資源類型
```

---

### 模式 F：動態角色輪換（Dynamic Role Rotation）
**資產重點：角色切換視覺 > 角色 > UI**

```
必要資產清單：
✅ 至少 3-4 種可切換的「角色狀態」外觀
✅ 切換動畫/特效
✅ 清楚的「目前角色是誰」UI 指示
✅ 每種角色狀態的獨特動畫
可選資產：
🔲 輪換觸發的環境特效
```

**難點**：需要「一個角色切換為另一個角色」的過渡設計

---

## 3. 已找到的具體資產清單

### A 類：角色精靈（Characters）

> 瀏覽器直接在 itch.io 找到的具體資源，所有 URL 均已驗證

---

#### A-01 ⭐ 8-Direction Pixel Art Caveman Character Pack
- **URL**：https://tiki-ted.itch.io/8-direction-pixel-art-caveman-character-pack
- **價格**：£2.00 GBP（約 NT$82）
- **內容**：
  - 8 方向像素洞穴人角色
  - 含武器/不含武器兩種版本
  - 動畫：待機 (Idle)、行走 (Walk)、受傷 (Hurt)、攻擊 (Attack)、死亡 (Death)
- **解析度**：像素藝術（未明確標示尺寸）
- **適合模式**：A、B
- **優點**：主題完全符合，有 8 方向支援（top-down 遊戲需要）
- **缺點**：只有 1 個角色，4 人遊戲需要多份購買或額外製作差異化
- **授權**：商業用途需確認（itch.io 個別頁面）

---

#### A-02 ⭐⭐ Caveman Pixel-Art Set
- **URL**：https://rapagamez.itch.io/caveman-pixel-art-set
- **價格**：$1.00 USD（約 NT$32）
- **內容完整清單**：
  - 玩家角色（40×40 px）：
    - Idle、Walk、Run、Jump、Ducking
    - 拳擊攻擊（Fist attack）
    - 木槌攻擊（Mallet attack）
    - 跳躍木槌攻擊（Jump Mallet Attack）
    - 蹲下木槌攻擊（Ducking Mallet Attack）
    - 翻滾（Rolling）、死亡（Dying）、爬樹（Tree Climb）
  - 敵人：1 種（48×56 px：Idle、Walk、木槌攻擊）
  - 鳥類敵人：1 種（20×20 px：飛行動畫）
  - 環境：篝火動畫、地面/泥土磚片
- **解析度**：40-56px 像素藝術
- **適合模式**：B（側視圖流程合作）
- **優點**：CP 值最高，包含敵人和環境，主題符合
- **缺點**：側視圖，1 個玩家角色（需要製作 3 個不同版本）

---

#### A-03 Caveman Pack（Top-Down）
- **URL**：https://deulamco.itch.io/cavemanspritepack
- **價格**：$5.00 USD（約 NT$162）
- **內容**：
  - 玩家（32px）：Idle、Run 動畫
  - 野豬敵人（Boar）：Idle、Run 動畫
  - 環境元素：水、小麥、鍋爐動畫
  - 草地材質
  - **附贈 Unity 示範專案**
- **解析度**：32px，俯視角
- **適合模式**：A、B、E
- **優點**：俯視角，有野豬敵人（狩獵主題！），含 Unity 示範
- **缺點**：Godot 無法直接用 Unity 項目，角色動畫較少

---

#### A-04 ⭐⭐ Hand Drawn Barbarian
- **URL**：https://blobfishdev.itch.io/barbarian
- **價格**：免費（可自由付費）
- **內容**：
  - 1 個手繪風格蠻族角色
  - 動畫：Idle、Attack、Run、Death、Crouch、Jump
  - 3 種解析度：136×96 px、272×192 px、408×288 px
- **解析度**：高清手繪風格
- **適合模式**：A、D
- **優點**：完全免費，手繪質感獨特，可作為參考或直接使用
- **缺點**：只有 1 個角色，沒有 8 方向（單一面向）

---

#### A-05 Barbarian Assault - Game Sprites（骨骼動畫）
- **URL**：https://pzuh.itch.io/barbarian-assault-game-sprites
- **價格**：$10.49 USD 特價（原 $14.99，約 NT$340）
- **內容**：
  - 3 個人類角色：聖騎士（Paladin）、天使（Angel）、蠻族（Barbarian）
  - 1 個生物：狼（Wolf）
  - 各角色 10 幀骨骼動畫
  - 檔案格式：Spriter 項目（.SCML）、PNG 圖序、向量檔（.AI, .EPS）
- **解析度**：高解析度向量風格
- **適合模式**：A（差異化角色最多）
- **優點**：3 個不同角色，骨骼動畫易修改，向量格式可縮放
- **缺點**：不是像素風格，可能與像素環境不搭

---

#### A-06 Caveman Story Assets（最完整套裝）
- **URL**：https://alb-pixel-store.itch.io/caveman-story-assets
- **價格**：$2.50 USD（約 NT$81）
- **內容完整清單**：
  - 玩家精靈 1（帶動畫）：
    - Walk、Jump、Club Attack（石棒攻擊）
    - Slingshot Attack（投石器攻擊）、Transport Object（搬運物體）
    - Throwing Axe（投擲斧頭）
  - 玩家精靈 2（帶動畫）：
    - Walk、Jump、Pterodactyl Fly（翼龍飛行！）
  - **18 種敵人精靈**（最多！）
  - 16×16 磚片地圖集（Tileset）
  - 可拾取物品：肉、石棒、投石器、能量蛋
- **解析度**：8-bit NES 風格像素
- **適合模式**：B、E（流程合作，資源採集）
- **優點**：CP 值超高，包含 18 種敵人、2 個玩家、地圖和物品
- **缺點**：NES 8-bit 風格較舊，需要確認實際像素品質

---

#### A-07（免費套裝）OboroPixel Characters Animations
- **URL**：https://oboropixel.itch.io/characters-animations-asset-pack
- **價格**：需查詢（可能免費）
- **內容**：10 個角色 × 8 種動畫
- **適合模式**：A（最多角色選擇）
- **備注**：作為 4 人遊戲的「角色模板庫」非常適合

---

#### A-08 Characters Animations Pack（Tiny RPG）
- **URL**：https://zerie.itch.io/tiny-rpg-character-asset-pack
- **價格**：需查詢
- **內容**：20 個動畫角色
- **適合模式**：A
- **備注**：角色數量多，可作為差異化的基礎

---

### B 類：敵人/獵物（Enemies & Creatures）

> 以下為可作為「獵物」或「威脅」的動物/生物精靈

---

#### B-01 ⭐⭐ Free Top-Down Hunt Animals Pixel Sprite Pack（craftpix）
- **URL**：https://craftpix.net（搜尋「hunt animals」）
- **價格**：免費
- **內容**：
  - 5 種動物：兔子、狐狸、黑松雞、**野豬**、幼鹿
  - 每種動物含完整動畫：Idle、Walk、Run、Attack、Death
- **解析度**：像素藝術，俯視角
- **適合模式**：A、B、E（狩獵主題）
- **優點**：完全免費，有野豬（最接近長毛象主題），完整動畫
- **重要**：這是目前最接近「狩獵主題」且免費的動物精靈

---

#### B-02 Dinosaur Sprites（小型，Game Boy 風）
- **URL**：https://teaceratops.itch.io/dinosgbs
- **價格**：$3.00 USD（約 NT$97）
- **內容**：
  - 15+ 種恐龍
  - 4 方向行走動畫
  - 8×8px 磚片格，4 色限制（Game Boy 風格）
- **解析度**：8×8px，極小
- **適合模式**：B（流程合作，恐龍作為獵物）
- **優點**：便宜，恐龍種類多
- **缺點**：解析度極低，可能太小

---

#### B-03 ⭐⭐ Dinosaur Park - Game Sprites（高品質）
- **URL**：https://pzuh.itch.io/dinosaur-park-game-sprites
- **價格**：$12.59 USD（約 NT$408）
- **內容**：
  - 1 個玩家英雄（22 種動畫狀態！）
  - 7 種恐龍敵人：
    - 迅猛龍（Raptor）
    - 翼龍（Pteranodon）
    - 雙脊龍（Dilophosaurus）
    - 基龍（Dimetrodon）
    - 厚頭龍（Pachycephalosaurus）
  - 格式：骨骼動畫（.SCML）、PNG 序列、向量（.AI/.EPS/.CDR）
- **解析度**：高解析度向量
- **適合模式**：A（不同角色對應不同恐龍敵人）
- **優點**：恐龍多樣性最高，適合做「獵殺不同獵物」的玩法
- **缺點**：價格較高，向量風格

---

#### B-04 Dinosaur World - Platformer Sprites
- **URL**：https://pzuh.itch.io/dinosaur-world-platformer-sprites
- **價格**：$12.59 USD（特價，原 $17.99）
- **內容**：
  - 1 個玩家英雄（22 種動畫狀態）
  - 4 種恐龍：
    - 三角龍（Triceratops）
    - 劍龍（Stegosaurus）
    - 棘龍（Spinosaurus）
    - 古翼龍（Tropeognathus）
  - 格式同上（.SCML、PNG、向量）
- **解析度**：高解析度
- **適合模式**：A、B（側視圖）
- **備注**：與 B-03 是同系列，兩套合購可得 11 種恐龍

---

### C 類：環境與地圖素材（Tilesets & Environments）

---

#### C-01 ⭐⭐ Top-Down Forest Tileset
- **URL**：https://glionox.itch.io/forest-tileset
- **價格**：$4.00 USD（約 NT$130）
- **內容**：
  - 16×16 px 磚片
  - 地面類型：草地、深草、泥土、石頭、水（自動磚片，47 種）
  - 裝飾物：蘑菇、漿果、睡蓮、蘆葦
  - 樹木：8 種常見樹、2 種大型樹
  - 建築：木製牆壁結構
- **解析度**：16×16px，俯視角
- **適合模式**：A、B、E
- **優點**：俯視角，價格合理，裝飾豐富，自動磚片省力

---

#### C-02 Cave Tileset Premium
- **URL**：https://the-pixel-nook.itch.io/cave-asset-pack
- **價格**：$4.99 USD（約 NT$162）
- **內容**：
  - 32×32 px 像素藝術洞穴資源
  - 地面磚片、石牆磚片
  - 梯子、藤蔓
  - 水晶裝飾
  - 適合側視圖
- **解析度**：32×32px，側視圖
- **適合模式**：B（側視圖流程合作）
- **優點**：洞穴主題最接近原始/石器時代感

---

#### C-03 16x16 Cave Tileset
- **URL**：https://1909games.itch.io/cave-tileset
- **價格**：$10.00 USD（約 NT$324）
- **內容**：
  - 7 種生物群落的地面磚片
  - 背景磚片
  - 岩石/石筍
  - 障礙/陷阱裝飾
- **解析度**：16×16px
- **適合模式**：B、D（場景機關）
- **優點**：多種生物群落，有陷阱素材（適合狩獵機制）

---

#### C-04 ⭐⭐ Forest Tileset Pack（剪影風格！）
- **URL**：https://muchopixels.itch.io/forest-tileset-pack
- **價格**：$4.95 USD（約 NT$160）
- **內容**：
  - 6 張磚片表（PNG/PSD，16×16 格）
  - 背景：白天/下午/夜晚三種
  - 山丘/山脈剪影
  - 地面：泥土和岩石
  - 木製柵欄、破損橋樑
  - 可攀爬的藤蔓
  - **原始房屋（primitive houses！）**
- **解析度**：16×16 格，側視圖
- **適合模式**：A、B（重點推薦）
- **優點**：
  - **剪影/大氣風格**，最接近「原始人」主題
  - 有原始建築素材
  - 白天/夜晚版本適合時間系統
- **缺點**：側視圖為主

---

#### C-05 RPG Stone Age Icons（craftpix）
- **URL**：https://craftpix.net（搜尋「stone age icons」）
- **價格**：部分免費
- **內容**：
  - 石器時代主題圖示
  - 原始武器（石矛、石斧、燧石刀）
  - 工具和裝備圖示
- **適合模式**：B、E（資源管理）

---

#### C-06 Kenney 免費俯視資源
- **URL**：https://kenney.nl/assets
- **價格**：完全免費（CC0）
- **重要資源**：
  - Top-Down Shooter：磚片、家具、角色精靈
  - Tiny Dungeon：地下城磚片、怪物、角色
  - Nature Pack（Top-Down）：自然環境元素
- **授權**：CC0，可商業使用，無需標注
- **優點**：**最安全的免費選項**，授權完全無疑慮
- **缺點**：視覺風格偏「中性/通用」，沒有原始人主題

---

### D 類：UI 與圖示（UI & Icons）

---

#### D-01 ⭐⭐ Primitive Essentials（最推薦）
- **URL**：https://santra-assets.itch.io/primitive-essentials
- **價格**：$10.00 USD（約 NT$324）
- **內容完整清單**：
  - **50 個獨特生存圖示**，每個有 5 種風格：
    1. 彩色原版（Coloured Raw）
    2. 彩色增強（Coloured Enhanced）
    3. 灰階柔和（Grayscale Soft）
    4. 灰階強烈（Grayscale Punchy）
    5. 線稿（Line Art）
  - 圖示內容：
    - 資源：骨頭、獸皮、脂肪、黏土
    - 食物/肉類
    - 工藝品：繩索、骨鉤
    - 工具：燧石矛、火把
    - **UI 狀態：心臟（血量）、雞腿（飢餓）、閃電（體力）、空/滿格**
  - 解析度：512×512 px，超高清
- **適合模式**：所有模式
- **優點**：
  - **原始/石器時代主題，完全符合**
  - 5 種風格讓你找到最適合的 UI 感覺
  - 包含基本的 RPG/生存遊戲 UI 元素
  - 512px 解析度可縮放

---

#### D-02 Primitive Essentials Lite（免費版）
- **URL**：https://santra-assets.itch.io/primitive-essentials-lite
- **價格**：**完全免費**
- **內容**：
  - 10 個手繪圖示（彩色 + 線稿兩種版本）
  - 包含：蘋果、骨頭、骨刀、稻草、心臟、木柴、雞腿（飢餓）、頭骨、石頭、石斧
- **建議用途**：先下載免費版確認風格是否符合，再購買完整版
- **解析度**：512×512 px

---

#### D-03 Primitive Weapons & Crafting Icon Pack
- **URL**：https://gamedeveloperstudio.itch.io/primitive-weapons-crafting-and-icon-pack
- **價格**：£4.00 GBP（約 NT$164）
- **內容**：
  - 12 種手持原始武器圖示：
    - 石斧（Stone axe）
    - 石槌（Stone hammer）
    - 吹箭筒（Blow pipe）
    - 飛鏢（Darts）
    - 迴旋鏢（Boomerang）
    - 石矛（Stone spear）
    - 石棒（Club）
    - 骨錐（Bone pick）
    - 投石機（Catapult）
    - 石頭（Stone）
    - 弓箭（Bow and arrow）
  - 格式：向量（.AI, .SVG）+ 透明 PNG
- **適合模式**：A、B、E
- **優點**：武器主題完全符合，向量格式可任意縮放

---

#### D-04 48 Barbarian Skills Icons Pixel Art
- **URL**：https://free-game-assets.itch.io/barbarian-skills-icons-pixel-art
- **價格**：$0.60 USD 特價（原 $6.00，約 NT$19）
- **內容**：
  - 48 個技能圖示
  - 主題：斬擊（Slashes）、動物本能（Animal Instincts）、憤怒（Rage Signs）
  - 格式：PNG + PSD
  - 解析度：32×32 px
- **適合模式**：A（非對稱角色合作的技能 UI）
- **優點**：便宜，像素風格，主題符合蠻族/原始人

---

#### D-05 Survival UI User Interface
- **URL**：https://pixel-banner.itch.io/survival-ui-user-interface
- **價格**：$1.00 USD（約 NT$32）
- **內容**：
  - 200+ 個生存元素：
    - 物品欄面板
    - 資源/血量條
    - 物品槽
    - 按鈕
    - 狀態圖示
  - 格式：個別 PNG + 合成表
- **解析度**：32×32 px
- **適合模式**：B、E
- **優點**：CP 值極高，200+ 元素僅 $1

---

#### D-06 Dark Survival UI Kit Premium
- **URL**：https://gamanbit.itch.io/dark-survival-ui-kit-premium-asset-pack
- **價格**：$0.70 USD 特價（原 $1.00，約 NT$23）
- **內容**：
  - 深色/淺色版物品欄面板
  - 導航按鈕
  - 6 種格槽設計
  - 3 種資源條（能量、飢餓、氧氣）
  - 狀態圖示（熊夾、木柴、指標）
  - 6 種藥水瓶
- **適合模式**：E（共享資源合作）
- **優點**：深色風格適合原始/陰暗主題，超便宜

---

### E 類：視覺特效（VFX）

> 以下為推薦的獨立搜尋關鍵字，建議在 itch.io 和 craftpix 查詢

**必要的 VFX 類型：**

| VFX 類型 | 搜尋關鍵字 | 估計成本 |
|---------|---------|---------|
| 命中特效（Hit Sparks）| "2D hit effect pixel art" | $1-5 |
| 攻擊揮動（Slash Effect）| "slash effect sprite sheet" | $1-8 |
| 塵土/踩踏粒子 | "dust particle sprite" | 免費-$3 |
| 血液/受傷 | "blood splatter 2D sprite" | 免費-$5 |
| 火焰/篝火 | "fire animation sprite" | 免費-$3 |
| 爆炸/衝擊 | "explosion effect 2D" | 免費-$5 |
| 勝利/完成特效 | "victory effect star particle" | 免費-$3 |

**推薦：itch.io 搜尋「2D effect pack」，多數有免費版或 $1-5 的完整版**

---

### F 類：音效與音樂（Audio）

> 多人合作遊戲的音效尤其重要——聲音強化「我做到了！」的感覺

**免費資源：**

| 資源 | 來源 | 內容 |
|------|------|------|
| freesound.org | 網站 | 大量 CC0 音效，搜尋「stone age」「primitive drum」 |
| kenney.nl（音效） | kenney.nl/assets | 免費音效包，CC0 授權 |
| opengameart.org | 網站 | 遊戲音效，授權各異 |
| itch.io（音效） | itch.io/game-assets/tag-music | 付費但便宜 |

**重要音效清單（合作遊戲必備）：**
```
戰鬥類：
- 近身攻擊（揮擊/擊中）×3-5 種
- 受傷音效 ×2-3 種
- 死亡/倒地音效
- 特殊技能音效（每個角色 1-2 種）

遊戲流程類：
- 成功/勝利音效（任務完成）
- 失敗音效（任務失敗）
- 倒計時警告音效
- 隊友復活音效

環境類：
- 環境底聲（森林/洞穴背景音）
- 陷阱觸發音效
- 機關啟動音效

UI 類：
- 按鈕點擊
- 選單導航
- 血量警告（低血量時的心跳聲）
```

---

## 4. 資產平台比較

| 平台 | 主題性 | 價格 | 授權安全性 | 品質 | 適合場景 |
|------|--------|------|----------|------|---------|
| **itch.io** | ⭐⭐⭐⭐⭐ | 免費~$15 | 需逐一確認 | 參差不齊 | 找主題特殊資產 |
| **craftpix.net** | ⭐⭐⭐⭐ | 部分免費，$10-30 | 明確（CC 授權）| 中高品質 | 找整套資源包 |
| **kenney.nl** | ⭐⭐（通用風格）| 完全免費 | ⭐⭐⭐⭐⭐（CC0）| 中等 | 快速 Prototype |
| **opengameart.org** | ⭐⭐⭐ | 大多免費 | 需逐一確認 | 參差不齊 | 找特殊風格資源 |

---

## 5. 兩個完整資產組合方案

### 方案 A：「像素石器時代」（總預算約 $35-50 USD）

**目標視覺**：16-32px 像素風格，俯視角，原始/石器時代主題

| 類別 | 資產 | 價格 |
|------|------|------|
| 玩家角色基礎 | Caveman Story Assets（A-06）| $2.50 |
| 玩家角色補充 | 8-Direction Caveman（A-01）×4 | £8.00 |
| 動物/獵物 | CraftPix Hunt Animals（B-01）| 免費 |
| 恐龍敵人（可選）| Dinosaur Sprites（B-02）| $3.00 |
| 森林環境 | Top-Down Forest Tileset（C-01）| $4.00 |
| 洞穴環境 | Cave Tileset（C-03）| $10.00 |
| UI 圖示 | Primitive Essentials Lite（D-02）| 免費 |
| UI 完整 | Primitive Essentials（D-01）| $10.00 |
| 技能圖示 | Barbarian Skills Icons（D-04）| $0.60 |
| 武器圖示 | Primitive Weapons Pack（D-03）| £4.00 |
| **小計** | | **約 $45 USD** |

---

### 方案 B：「手繪剪影原始風」（總預算約 $35-45 USD）

**目標視覺**：手繪/剪影風格，側視圖，氣氛感強，類《Limbo》但有原始色彩

| 類別 | 資產 | 價格 |
|------|------|------|
| 玩家角色 | Hand Drawn Barbarian（A-04）×自製變化 | 免費 |
| 高品質骨骼角色 | Barbarian Assault Sprites（A-05）| $10.49 |
| 恐龍敵人 | Dinosaur Park Game Sprites（B-03）| $12.59 |
| 剪影環境 | Forest Tileset Pack（C-04）| $4.95 |
| 洞穴環境 | Cave Tileset Premium（C-02）| $4.99 |
| UI 主題 | Primitive Essentials（D-01）| $10.00 |
| 武器圖示 | Primitive Weapons Pack（D-03）| £4.00 |
| **小計** | | **約 $47 USD** |

---

## 6. 仍缺少的資產與解決方案

儘管找到了大量資產，仍有幾個關鍵缺口：

### 缺口 1：4 人角色差異化（最重要的問題）

**問題**：目前找到的資產最多 2-3 個玩家角色，4 人遊戲需要 4 個明顯不同的外形

**解決方案（按優先順序）：**
1. **購買同系列的多個包**：如果有角色顏色/服裝變化，購買 4 份
2. **用基礎包 + 顏色替換**：大多數像素包可在 Aseprite 中更換調色板
3. **用不同的資產包組合**：A-01（洞穴人）+ A-04（蠻族）+ 其他兩個
4. **自製 2 個，採購 2 個**：先買 2 個，剩下 2 個自製（節省成本）

---

### 缺口 2：主要獵物（大型「長毛象」等級）

**問題**：目前只找到小動物（野豬、兔子）和恐龍，缺少「大型猛獸」感的主要獵物

**解決方案：**
1. **採購恐龍資產後重新縮放**：把恐龍縮放至畫面 40-50% 大，製造「大型獵物」感
2. **搜尋「boss enemy sprite」**：在 itch.io 搜尋這個關鍵字
3. **自製主要獵物**：Prototype 階段可用幾何圖形代替，後期再製作

---

### 缺口 3：合作 UI（4 人狀態同時顯示）

**問題**：4 人遊戲需要同時在螢幕上顯示 4 個玩家的狀態

**解決方案：**
1. **購買的 UI 包 + 自製排版**：買 Primitive Essentials 圖示，自己組成 4 人 HUD
2. **搜尋「4 player HUD」**：在 itch.io 可能有專門的多人 HUD 資源
3. **簡化設計**：4 個玩家 HUD 用相同元素 × 4，顏色區分

---

### 缺口 4：陷阱/機關動畫

**問題**：狩獵合作需要陷阱設置機制，但沒有找到合適的陷阱動畫

**搜尋建議：**
- itch.io 搜尋：「trap sprite animation」「pitfall sprite」「net trap」
- craftpix.net 搜尋：「trap asset」
- 可能需要自製（陷阱通常是簡單幾何形狀，製作難度低）

---

## 7. 授權與法律注意事項

**⚠️ 重要：每個資產都必須記錄授權資訊**

### 授權類型速查

| 授權 | 可商業使用 | 需要標注作者 | 可修改 | 代表平台 |
|------|----------|------------|--------|---------|
| **CC0** | ✅ | ❌（無需） | ✅ | kenney.nl |
| **CC-BY** | ✅ | ✅（必須） | ✅ | opengameart.org |
| **CC-BY-SA** | ✅ | ✅ | ✅（需相同授權）| opengameart.org |
| **itch.io 個別授權** | 依頁面 | 依頁面 | 依頁面 | itch.io |
| **Standard License** | 需確認 | 依規定 | 依規定 | craftpix.net |

**建議建立一個「授權追蹤表」（可在 docs/ 目錄下新建 ASSET_LICENSE.md）**

```markdown
# 資產授權追蹤
| 資產名稱 | 作者 | 平台 | 授權類型 | 是否可商業 | 購買日期 |
|---------|------|------|---------|-----------|---------|
| Caveman Story Assets | Alb_pixel Store | itch.io | 待確認 | 待確認 | - |
```

---

## 8. 採購優先順序

### Phase 1：立即免費下載（$0 成本）

| 步驟 | 資產 | 用途 |
|------|------|------|
| 1 | Kenney.nl 全套資產 | Prototype 所有機制用 |
| 2 | Hand Drawn Barbarian（A-04）| 測試角色視覺感 |
| 3 | Primitive Essentials Lite（D-02）| 測試 UI 風格 |
| 4 | CraftPix Hunt Animals（B-01）| 測試狩獵感覺 |

### Phase 2：機制驗證後的最小資產購買（$10-15 USD）

| 步驟 | 資產 | 理由 |
|------|------|------|
| 1 | Caveman Story Assets（A-06，$2.50）| 最多內容，CP 值最高 |
| 2 | Top-Down Forest Tileset（C-01，$4.00）| 基礎環境 |
| 3 | Primitive Essentials（D-01，$10.00）| UI 統一主題 |

### Phase 3：確認視覺方向後購買（$30-50 USD）

根據 Phase 2 的決定，再採購以下之一：
- **像素方向**：A-01（洞穴人）+ C-03（洞穴）+ D-04（技能）
- **手繪方向**：A-05（骨骼蠻族）+ B-03（恐龍）+ C-04（剪影森林）

---

*文件長度：約 8,000 字*  
*最後更新：2026-06-04*  
*下次更新：確認合作模式方向後，建立具體採購清單*
