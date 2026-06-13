**GDD 最後同步：2026-06-14 v9** | 維護者：Designer 角色

# GAME DESIGN DOCUMENT
# ============================================================
# 由 Game Designer 維護
# 狀態標記：[DRAFT] 草稿中 | [CONFIRMED] 已確認 | [LOCKED] 不可再修改
#
# 規則：
# - 所有欄位必須由 Designer 填寫
# - Architect / Developer / QA 不可直接修改，有疑義請找 Designer
# ============================================================

---

## 📋 章節狀態總覽

| 章節 | 狀態 | 最後更新 |
|------|------|---------| 
| 遊戲核心概念 | [CONFIRMED] | 2026-06-06 |
| 視覺風格系統 | [CONFIRMED] | 2026-06-12 |
| 角色組成架構 | [CONFIRMED] | 2026-06-06 |
| 敵人設計 | [CONFIRMED] | 2026-06-06 |
| 多人系統 | [CONFIRMED] | 2026-06-12 |
| 玩家角色設計 | [CONFIRMED] | 2026-06-12 |
| 關卡結構 | [CONFIRMED] | 2026-06-14 |
| 戰鬥系統 | [CONFIRMED] | 2026-06-13 |
| VFX 視覺特效系統 | [CONFIRMED] | 2026-06-13 |
| 音效/音樂 | [DRAFT] | 2026-06-06 |
| 技術限制 | [CONFIRMED] | 2026-06-12 |
| 房間連接系統 | [CONFIRMED] | 2026-06-12 |
| **地圖房間結構設計規範** | **[CONFIRMED]** | **2026-06-14 v7** |

---

## 🎮 1. 遊戲核心概念

### 1.1 核心定位 [CONFIRMED]
> 一款 **2D 橫向捲軸多人動作遊戲**，以哥德式恐怖美學為基礎，
> 風格對標惡魔城（Castlevania）系列，但強化多人協作/競技體驗。
> 所有角色（玩家＋敵人）由 **tile 拼接組合而成**，實現模組化外觀系統。

### 1.2 遊戲類型 [CONFIRMED]
- **主類型**：2D 橫向捲軸動作（Castlevania-style）
- **次類型**：本地多人動作（Local Multiplayer Action）
- **視覺方向**：像素藝術（Pixel Art）＋哥德/恐怖風格

### 1.3 核心設計支柱 [CONFIRMED]
1. **Tile 複合角色**：所有可見實體（角色、敵人、Boss）均由 MRMOTEXT tile 拼接組成
2. **高性能設計**：使用 Godot 4 TileMapLayer 硬體加速，所有角色為高效率物件
3. **視覺多樣性**：透過 34 色 VfxMix 調色盤對 tile 染色，產生大量視覺變體
4. **多人體驗**：強調多人同屏互動，支援 2~4 人本地合作

### 1.4 核心循環 [CONFIRMED]
```
大廳組隊（1~4 人）→ 隨機地牢關卡 → 探索/戰鬥 → 擊敗 Boss → 進入下一區域 → 結算
房間序列：普通戰鬥房 × N → 精英房（30%機率）→ 休息房（可選）→ Boss 房
```

---

## 🎨 2. 視覺風格系統

### 2.1 Tile 視覺規格 [CONFIRMED]

| 規格 | 數值 | 說明 |
|------|------|------|
| 基礎 Tile 尺寸 | 8×8 px | MRMOTEXT Extended 原始尺寸 |
| 大型 Tile 尺寸 | 24×24 px | MRMOTEXT x3 版本 |
| 渲染縮放 | 4× | Camera2D zoom=4，等效 32px/tile 顯示 |
| 色彩模式 | 黑底白圖 + 色票染色 | Multiply 混色模式 |
| 調色盤 | VfxMix 34色 | 見 assets/vfxmix/palette.pal |

### 2.2 色彩配置規則 [CONFIRMED]

| 顏色角色 | 建議色票 Hex | 用途 |
|---------|------------|------|
| 普通敵人 | `#FFFFFF`（原色白） | 骷髏、幽靈、士兵 |
| 不死系敵人 | `#5DA16E`（綠）/ `#B1D368`（黃綠） | 殭屍、食屍鬼 |
| 魔法系敵人 | `#6F81B3`（紫藍）/ `#9D5789`（紫） | 巫師、惡魔 |
| Boss | 自定義多色組合 | 大型多部件 Boss |
| **玩家 P1** | **`#FF8C42`（暖橙）** | **[CONFIRMED]** |
| **玩家 P2** | **`#4CC9F0`（冷藍）** | **[CONFIRMED]** |
| **玩家 P3** | **`#5DA16E`（綠）** | **[CONFIRMED]** |
| **玩家 P4** | **`#9D5789`（紫）** | **[CONFIRMED]** |
| 環境/背景 | `#363232`（暗黑）/ `#453C3C`（暗褐） | 城堡牆壁、背景 |

### 2.3 VFX 系統 [CONFIRMED]
- **粒子特效**：使用 VfxMix `particle/` 素材作為 GPUParticles2D 貼圖
- **近戰攻擊特效**：`assets/vfxmix/fx/slash_01.png`（6幀，哥德式刀斬特效）
- **遠程發射特效**：`assets/vfxmix/fx/spark_01.png`（6幀，魔法火花）
- **命中特效**：`assets/vfxmix/fx/impact_01.png`（6幀，敵人受傷 impact）
- **死亡特效**：`assets/vfxmix/fx/death_01.png`（6幀，敵人消散爆裂）
- **形狀層疊**：VfxMix `shape/` 與 MRMOTEXT 風格一致（黑白輪廓），可直接疊用
- **行動煙塵**：見「PlayerDust — 玩家行動煙塵特效」章節

---

## 🧩 3. 角色組成架構（Tile Composite System）

### 3.1 設計哲學 [CONFIRMED]
> 所有角色**不使用預先繪製的精靈圖**，而是在場景中由多個 TileMapLayer
> 疊加組合，每個 layer 控制角色的一個部位（身體/頭部/手臂/武器）。
> 這使得角色可以輕易：
> - **換色**（改 Modulate 或切換染色版 Atlas Source）
> - **換部件**（切換不同 tile 進行組合）
> - **部位損傷**（移除特定 layer 的 tile）

### 3.2 已設計完成的形象（見 char_design.tscn） [CONFIRMED]

| 編號 | 名稱（暫定） | 外觀描述 | 顏色模式 | 尺寸估計 |
|------|------------|---------|---------|---------| 
| E-01 | 幽靈/靈魂 | 白色流動身形，骷髏頭，飄浮型 | 白色（原色） | 3×4 tiles |
| E-02 | 蝙蝠/鳥型 | 小型深色，展翅造型 | 深色 | 2×2 tiles |
| E-03 | 骷髏士兵 A | 簡易人形，甲胄，小型 | 白色 | 3×4 tiles |
| E-04 | 骷髏士兵 B | 人形，甲胄，中型，細節較多 | 白色 | 4×4 tiles |
| E-05 | 重甲骷髏 | 人形，厚甲，高對比細節，大型 | 白色 | 4×5 tiles |
| E-06 | 殭屍/食屍鬼 | 大頭，粉色眼睛，圓渾身形 | **綠色**（#5DA16E） | 5×5 tiles |
| E-07 | 苔蘚怪/植物系 | 圓形有機形態，叢狀 | **綠色**（#B1D368） | 4×4 tiles |

### 3.3 Tile 組合技術規範 [CONFIRMED]
- **單一角色** = 多個 `TileMapLayer` 節點（每部位一層，z_index 分層）
- **底層**：身體輪廓
- **中層**：裝備/武器
- **上層**：頭部/眼部高光
- **動畫**：透過切換 tile 座標實現（而非 AnimationPlayer 的整體替換）

---

## 👾 4. 敵人設計

### 4.1 敵人分類（基於現有設計）[CONFIRMED]

| 分類 | 代表形象 | 移動模式 | 攻擊模式 | 難度 |
|------|---------|---------|---------|------|
| **漂浮型** | 幽靈(E-01)、蝙蝠(E-02) | 自由浮動/飛行 | 接觸/衝刺 | ★ |
| **步行型-輕甲** | 骷髏士兵A(E-03) | 地面巡邏 | 近戰/投擲 | ★★ |
| **步行型-重甲** | 重甲骷髏(E-05) | 緩慢地面 | 重擊/衝鋒 | ★★★ |
| **有機型** | 殭屍(E-06)、苔蘚怪(E-07) | 緩慢地面/跳躍 | 接觸/噴吐 | ★★ |

### 4.2 敵人性能設計原則 [CONFIRMED]
- 使用 **CharacterBody2D** 作為物理主體（非 RigidBody2D）
- Tile 外觀層與物理層**完全分離**（外觀是 TileMapLayer，碰撞是獨立 CollisionShape2D）
- 敵人 AI 採用**狀態機（StateMachine）**設計
- 同屏敵人數量目標：**20~40 隻不卡頓**

### 4.3 敵人已實作系統 [CONFIRMED]
- **enemy1.gd**：地面巡邏，接觸攻擊，EnemyStats 資源注入
- **enemy2.gd**：地面巡邏，含射線感知，spawn_disabled 機制
- **enemy3.gd**：遠程射擊型，發射 bullet_enemy3.tscn
- **EnemyStats 資源**：`resources/enemy/basic_enemy_stats.tres`（max_health, speed, attack_damage）

### 4.4 敵人 VFX 系統 [CONFIRMED]
- **受傷特效**：超白閃（modulate.r=8）→ 紅色（0.05s）→ 原色（0.1s）+ 縮放震動（1.3,0.7 → 0.85,1.2 → 1.0,1.0）+ Impact 特效（`fx/impact_01.png`）
- **死亡特效**：縮放放大（→1.5x）+ 淡出（0.15s）+ 死亡爆裂 VFX（`fx/death_01.png`）
- **警戒特效**：警戒時紅色閃爍（0.07s 週期）

### 4.5 Boss 設計方向 [DRAFT]
> 待設計：大型 Boss 由多個獨立部件（子節點）組成，每個部件可被獨立攻擊/摧毀

---

## 👥 5. 多人系統

### 5.1 多人模式 [CONFIRMED]

**已確認選擇**：本地多人（Local Co-op），2~4 人

| 項目 | 確認內容 |
|------|---------|
| **模式** | 本地多人，同螢幕 |
| **玩家人數** | 2~4 人（彈性） |
| **輸入方式** | 每位玩家對應 p1_/p2_/p3_/p4_ 前綴的 Input Action |
| **相機** | 單一共用相機（MultiplayerCamera），動態縮放追蹤所有玩家 |
| **線上多人** | Phase 1 不做，設計上預留擴展空間 |

### 5.2 玩家輸入映射 [CONFIRMED]

| 玩家 | 移動 | 跳躍 | 翻滾 | **近戰（左鍵）** | **遠程（右鍵）** |
|------|------|------|------|--------------|--------------|
| P1 | A/D | W/Space | Shift | **滑鼠左鍵** | **滑鼠右鍵** |
| P2 | ←/→ | ↑ | Numpad Enter | **滑鼠左鍵** | **滑鼠右鍵** |
| P3 | 待設計 | 待設計 | 待設計 | **滑鼠左鍵** | **滑鼠右鍵** |
| P4 | 待設計 | 待設計 | 待設計 | **滑鼠左鍵** | **滑鼠右鍵** |

> **攻擊設計決策 [CONFIRMED 2026-06-12]**：
> - **左鍵（LMB）= 近戰**：立即觸發，短範圍矩形掃描攻擊
> - **右鍵（RMB）= 遠程**：立即觸發，發射玩家子彈
> - 廢棄舊設計（短按/長按同鍵），因左右鍵分離更直覺

---

## 🦸 6. 玩家角色設計

### 6.1 玩家外觀 [CONFIRMED]
- 使用 Tile Composite 系統，與敵人使用相同的 MRMOTEXT tileset
- 顏色方案：P1=橙(#FF8C42)、P2=藍(#4CC9F0)、P3=綠(#5DA16E)、P4=紫(#9D5789)
- 動態顏色採樣：`apply_player_color(skin_index)` 方法

### 6.2 玩家行動能力 [CONFIRMED]

| 能力 | 狀態 | 具體規格 |
|------|------|---------|
| 行走/跑步 | [CONFIRMED] | 最大速度 100px/s，加速度 800px/s²，地面摩擦 800px/s² |
| 空中移動 | [CONFIRMED] | 空中水平摩擦倍率 0.3 |
| 跳躍 | [CONFIRMED] | 初速 -297px/s，重力 980px/s²；Coyote Time 0.12s；Jump Buffer 0.15s |
| 二段跳（Apex Jump） | [CONFIRMED] | 上升期按跳躍→到達最高點自動觸發；下降期立即觸發；耐力消耗 |
| 蹬牆跳 | [CONFIRMED] | 垂直速度 -268.7px/s，水平速度 90px/s，方向鎖定 0.2s |
| 翻滾 | [CONFIRMED] | 速度 125px/s，持續 0.3s，冷卻 0.4s；翻滾中有 0.12s 無敵幀 |
| **近戰攻擊** | **[CONFIRMED]** | **左鍵**；PhysicsShapeQuery 矩形掃描 28px；傷害 1；冷卻 0.45s；持續 0.25s |
| **遠程攻擊** | **[CONFIRMED]** | **右鍵**；發射 player_bullet.tscn；速度 280px/s；傷害 1；冷卻 0.6s |
| 視覺傾斜（Sway） | [CONFIRMED] | Second Order Dynamics 彈簧系統；頻率 4.0，阻尼 0.35 |
| 位置像素對齊 | [CONFIRMED] | snap_position_to_pixel=true，避免 zoom 下模糊 |

### 6.3 耐力系統 [CONFIRMED]

| 參數 | 數值 |
|------|------|
| 最大耐力格數 | 3 格 |
| 恢復速度 | 0.8 格/秒 |
| 消耗：翻滾 | 1 格 |
| 消耗：蹬牆跳 | 1 格 |
| 消耗：二段跳 | 1 格 |
| 耐力為 0 時 | 無法使用耗耐力動作 |

### 6.4 生命系統 [CONFIRMED]

| 參數 | 數值 |
|------|------|
| 最大生命值 | 3 |
| 受傷無敵幀 | 1.5 秒 |
| 受傷視覺 | Sprite 快速閃爍（0.1s 週期），透明度交替 |
| 死亡 | 觸發 `died` 信號，場景負責處理重生/GameOver |

---

## 🏰 7. 關卡結構

### 7.1 關卡類型 [CONFIRMED]
**已確認選擇**：Rogue-lite 隨機生成（選項 C）

```
房間序列：戰鬥房（COMBAT）×N → 精英房（ELITE，30%）→ 休息房（REST，可選）→ Boss 房
實作：DungeonGenerator（scripts/level/dungeon_generator.gd）
```

### 7.2 場景美術方向 [CONFIRMED]
- 城堡內部（石牆、地下水道）
- 使用 MRMOTEXT tile 做環境拼接
- 各房間有獨立的地形設計，非程式生成

---

## ⚔️ 8. 戰鬥系統

### 8.1 攻擊輸入設計 [CONFIRMED]

> **核心決策（2026-06-12）**：左鍵=近戰，右鍵=遠程，無長短按判斷

| 攻擊類型 | 觸發 | 機制 | 傷害 | 冷卻 |
|---------|------|------|------|------|
| 近戰 | 滑鼠左鍵 | PhysicsShapeQueryParameters2D 矩形掃描 28px | 1 | 0.45s |
| 遠程 | 滑鼠右鍵 | 發射 player_bullet.tscn，速度 280px/s | 1 | 0.6s |

### 8.2 基礎戰鬥參數 [CONFIRMED]

| 參數 | 數值 |
|------|------|
| 近戰攻擊持續幀（秒） | 0.25s |
| 近戰冷卻 | 0.45s |
| 遠程冷卻 | 0.6s |
| 遠程子彈速度 | 280px/s |
| 子彈 collision_layer | 4（Enemies 層） |
| 子彈 collision_mask | 14（打敵人+地形） |
| 玩家受傷無敵幀 | 1.5s |
| 翻滾無敵幀 | 0.12s |
| 敵人同屏數量目標 | 20~40 隻 |

### 8.3 近戰 VFX [CONFIRMED] [UPDATED 2026-06-13 v3]

**3 擊 Combo 各擊對應不同 VFX：**

| 擊數 | VFX 場景 | 素材 | 幀數 | 播放速度 | 比例 |
|------|---------|------|------|------|------|
| 第 1 擊 | `MeleeSlash.tscn` | `slash_01.png`（91×96px/幀） | 16幀 | **60fps** | 0.35 |
| 第 2 擊 | `MeleeSlash2.tscn` | `slash_02.png`（72×105px/幀，flip_h） | 16幀 | **60fps** | 0.35 |
| 第 3 擊 | `MeleeImpact3.tscn` | `impact_01.png`（137×98px/幀） | 16幀 | **50fps** | 0.40 |

- VFX 使用**原色**（白色，不染玩家顏色） [CONFIRMED 2026-06-13]
- VisualPivot 縮放：scale→(1.20, 0.82) 0.06s，回彈 0.09s（保持正值避免子節點渲染問題）
- 攻擊期間 Combo 自動計時

**VFX 速度設計原則**：攻擊鎖定 0.15~0.20s，speed = frames/lock * 0.6 ≈ 60fps；避免 VFX 拖尾超過攻擊動作

### 8.3.1 近戰 VFX 定位架構 [CONFIRMED] [UPDATED 2026-06-13 v2]

**架構決策：Marker2D 定位 + Runtime 動態生成 VFX**

**場景結構：**
```
Player (CharacterBody2D)
└── MeleeVFXPivots (Node2D)
    ├── Hit1Pivot (Marker2D) ← 第1擊位置（以右為正）
    ├── Hit2Pivot (Marker2D) ← 第2擊位置
    └── Hit3Pivot (Marker2D) ← 第3擊位置
```

**位置調整方式（給設計師）：**
1. 在 Godot Scene Editor 開啟 player1.tscn（或 2/3/4）
2. 展開 MeleeVFXPivots → 選擇 Hit1Pivot / Hit2Pivot / Hit3Pivot
3. 直接在 Inspector 修改 Position，**以右方向為正 X**
4. 4個玩家場景分別調整（可有不同初始位置）

**鏡像規則（Runtime 自動）：**
- 面右（_facing=1）：使用 marker.position.x（正值）
- 面左（_facing=-1）：x 取負，自動鏡像
- `vfx.position = global_position + Vector2(_facing * marker.position.x, marker.position.y)`

**技術接口：**
- `_spawn_melee_vfx_at_marker(vfx_scene, marker)` — 主要接口
- `_get_marker(path) -> Marker2D` — 安全取得，缺失時 push_warning
- 舊 `_spawn_melee_vfx(scene, pos, flip_h)` 保留供其他用途

**顏色**：VFX 使用**原色**（不繼承玩家顏色） [CONFIRMED 2026-06-13]

### 8.4 遠程 VFX [CONFIRMED]
- 發射子彈瞬間，在子彈出生點生成 `RangedMuzzle.tscn`（spark_01.png 6幀動畫）
- 子彈繼承玩家顏色（modulate 染色）

---

## ✨ VFX 視覺特效系統 [CONFIRMED]

### PlayerDust — 玩家行動煙塵特效

#### BrickDebris（磚塊碎片）[CONFIRMED]

| 項目 | 規格 |
|---|---|
| 素材 | `assets/vfxmix/particle/brick_gray.png`（144×22，**6幀**，每幀 24×22px） |
| 觸發條件 | 消耗耐力的地形接觸動作：正常跳躍、翻滾（Shift）、蹬牆跳 |
| 地形接觸要求 | is_on_floor（跳/翻滾）或 is_on_wall（蹬牆）|
| 排除條件 | 二段跳（空中無地形接觸） |
| 飛出方向 | 地板法線反射：`velocity.bounce(terrain_normal)` |
| 顏色 | ShapeCast2D 採樣脚底磚塊中心像素，fallback 為灰色 |
| 粒子數 | 6 |
| 壽命 | 0.45s |
| 旋轉 | 每顆粒子隨機角速，产生在空中翻滾動感 |

#### DustCloud（落地煙塵雲）[CONFIRMED]

| 項目 | 規格 |
|---|---|
| 素材 | 程式化圓點粒子（無貼圖） |
| 觸發條件 | 落地瞬間 `not _was_on_floor and is_on_floor()` 且 `abs(velocity.x) > 10` |
| 顏色 | 固定灰色 `#AAAAAA` |
| 排除條件 | 衿落（velocity.x 接近零）、翻滾落地 |
| 飛出方向 | 略寬扇形向上，隔平地面 |
| 粒子數 | 12 |
| 壽命 | 0.5s |

#### 地板顏色偵測 [CONFIRMED]

- 使用 `ShapeCast2D`（矩形 10×2px，向下 4px）
- 取 TileMapLayer Atlas 貼圖磚塊中心像素顏色
- **不需要修改 TileSet**
- fallback：`Color(0.65, 0.65, 0.65)`

### 攻擊與敵人 VFX [CONFIRMED]

| VFX | 素材 | 幀數 | 觸發條件 |
|-----|------|------|---------|
| 近戰砍擊（MeleeSlash） | `fx/slash_01.png` | **16幀** | 近戰攻擊第1擊時 |
| 遠程發射（RangedMuzzle） | `fx/spark_01.png` | **16幀** | 發射子彈時 |
| 敵人受傷（EnemyHit） | `fx/impact_01.png` | **16幀** | 敵人 take_damage 時 |
| 敵人死亡（EnemyDeath） | `fx/death_01.png` | **24幀** | 敵人 die() 時 |

### 8.5 近戰 3 擊 Combo 系統 [CONFIRMED 2026-06-13] **[IMPLEMENTED]**

| 擊數 | 持續時間 | VFX 場景 | VFX 素材 | 染色 | Knockback |
|------|---------|---------|---------|------|----------|
| 第 1 擊 | 0.15s | `MeleeSlash.tscn` | `slash_01.png`（16幀 91×96px） | 原色 | 80px/s 水平 |
| 第 2 擊 | 0.15s | `MeleeSlash2.tscn` | `slash_02.png`（16幀 72×105px，反向） | 原色 | 80px/s 水平 |
| 第 3 擊 | 0.20s | `MeleeImpact3.tscn` | `impact_01.png`（16幀 137×98px） | 原色 | 80px/s 水平 |

**Combo Buffer**：第一擊結束後 **0.3s** 內再按左鍵即接第二擊；第三擊後重置

**方向設計**：近戰**只有前/後兩個方向**，依據 `_facing` 決定，不跟隨 8 方向瞄準

**移動鎖定**：攻擊動畫期間禁止水平移動（輸入儲存到 buffer）

**多人安全設計**：
- ✅ Knockback 80px/s（純視覺 + 物理，無同步問題）
- ❌ HitStop（多人同步問題，已駁回，見 MMP-001）
- ❌ 相機震動（多人同步問題，已駁回，見 MMP-002）

**實作狀態（2026-06-13）**：
- `scripts/player/player.gd` — Combo 計時 + `_spawn_melee_vfx_at_marker()`
- `scenes/VFX/MeleeSlash.tscn` — 第 1 擊 VFX 場景（slash_01.png 16幀 60fps）
- `scenes/VFX/MeleeSlash2.tscn` — 第 2 擊 VFX 場景（slash_02.png 16幀 60fps）
- `scenes/VFX/MeleeImpact3.tscn` — 第 3 擊 VFX 場景（impact_01.png 16幀 50fps）
- 定位由 `MeleeVFXPivots/HitNPivot` Marker2D 控制（見 8.3.1）

---

## 🎵 9. 音效/音樂

### 9.1 音樂風格 [DRAFT]
> 待確認：哥德管風琴風格？現代電子 + 管弦？

---

## 🚪 10. 房間連接系統（Room Portal System）[CONFIRMED]

> **設計靈感**：空洞騎士（Hollow Knight）的房間進出體驗
> **確認日期**：2026-06-12

### 10.1 核心概念 [CONFIRMED]

房間之間透過「實體化走廊洞口」連接，玩家實際走入走廊觸發場景切換，而非接觸到牆壁邊緣就瞬間切換。

```
[房間 A] ───── [走廊洞口] ──── Fade Out ──── Fade In ──── [走廊洞口] ───── [房間 B]
               ↑ 玩家走進來         ↑ 觸發切換                ↑ 玩家從此出現
```

### 10.2 過渡方式 [CONFIRMED]

| 項目 | 設計決策 |
|------|---------| 
| **視覺效果** | **漸黑/漸亮（Fade Out → 換場 → Fade In）** |
| **持續時間** | 可參數化，預設 0.3～0.5 秒 |
| **實作方式** | 新 CanvasLayer（z最高）+ ColorRect（純黑）+ Tween 拉透明度 |
| **HUD 提示** | **無**，全靠玩家自行探索發現 |

### 10.3 出口方向 [CONFIRMED]

支援四個方向：左 / 右（主要）、上 / 下（垂直探索）

### 10.4 多人觸發規則 [CONFIRMED]

- **全部玩家都必須進入走廊的 Area2D 觸發區**，才觸發換房間
- 與現有的 `_players_in_zone` 計數機制一致

---

## 💻 11. 技術限制與平台

### 11.1 目標平台 [CONFIRMED]

| 平台 | 狀態 |
|------|------|
| PC (Windows) | [CONFIRMED] 主要平台 |
| Web (HTML5) | [DRAFT] |
| Console | [DRAFT] |

### 11.2 技術選型 [CONFIRMED]

| 項目 | 選擇 |
|------|------|
| 引擎 | Godot 4.6.2 |
| 渲染模式 | 2D（Forward+） |
| 角色外觀 | TileMapLayer（Godot 4 新版） |
| 物理 | CharacterBody2D |
| **多人方案** | **Godot Multiplayer API（MultiplayerSpawner + MultiplayerSynchronizer）** |
| 版本控制 | Git + LFS |

### 11.3 Asset 資源清單 [CONFIRMED]

| 資源 | 路徑 | 用途 |
|------|------|------|
| MRMOTEXT Extended 1.1 | `assets/tilesets/mrmotext/MRMOTEXT_EX.png` | 角色/敵人主要 tileset |
| MRMOTEXT x3 | `assets/tilesets/mrmotext/MRMOTEXT-x3.png` | 大型元素 tileset |
| MRMOTEXT 染色版（34色） | `assets/tilesets/mrmotext/colored/` | 顏色變體 |
| VfxMix | `assets/vfxmix/` | 全套特效資源 |
| VfxMix 調色盤 | `assets/vfxmix/palette.pal` | 34色標準調色盤 |

---

## 📝 決策記錄（Decision Log）

| 日期 | 決策 | 理由 | 決策者 |
|------|------|------|-------|
| 2026-06-06 | 使用 MRMOTEXT tile 拼接角色 | 視覺風格統一、效能佳、易於產生變體 | 用戶 |
| 2026-06-06 | 採用 VfxMix 34色調色盤 | 與 MRMOTEXT 黑白底色搭配的 Multiply 染色 | 用戶 |
| 2026-06-06 | 敵人性能目標 20~40 隻同屏 | 確保多人遊戲戰場密度 | 用戶 |
| 2026-06-06 | CharacterBody2D 作為物理層 | 更精確的平台動作控制 | Designer |
| 2026-06-06 | 目標平台 PC Windows | 主要開發目標 | 用戶 |
| 2026-06-12 | 房間連接採用 Hollow Knight 走廊洞口風格 | 實體化走廊提供空間感 + 探索回饋 | 用戶 |
| 2026-06-12 | 過渡效果：漸黑漸亮 Fade（0.3~0.5秒） | 最接近空洞騎士體驗，簡單穩定 | 用戶 |
| 2026-06-12 | 本地多人模式，2~4 人 | 先本地後線上的階段性策略 | 用戶 |
| 2026-06-12 | 玩家顏色：P1橙、P2藍、P3綠、P4紫 | 視覺區分清晰，與 VfxMix 調色盤相容 | Developer |
| **2026-06-12** | **攻擊輸入：左鍵=近戰，右鍵=遠程** | **比短按/長按更直覺，降低輸入錯誤率** | **用戶** |
| **2026-06-12** | **VFX：slash/spark/impact/death 四種特效** | **VfxMix 現有素材直接利用，風格統一** | **Designer** |
| **2026-06-12** | **敵人死亡：縮放+淡出+死亡VFX** | **程式動畫比逐帧動畫更輕量且效果好** | **Developer** |
| **2026-06-13** | **近戰 3 擊 Combo（左→左反向→衝擊）** | **快速爽快型手感，參考 Hollow Knight；無 combo 冷卻** | **用戶** |
| **2026-06-13** | **Combo Buffer 0.3s（第一擊後窗口）** | **允許玩家節奏性連擊，不強制高頻點擊** | **用戶** |
| **2026-06-13** | **近戰方向只有前/後（_facing），不跟 8 方向** | **近戰應直覺跟隨移動方向，避免操作混亂** | **用�### 10.10 設計決策記錄：移除 BoundaryWalls [CONFIRMED — 2026-06-13]

**決策**：移除所有房間場景中的 `BoundaryWalls` 節點（StaticBody2D 邊界牆組合），改由 TileMapLayer 的 Physics Layer 作為**唯一的碰撞策略**。

**討論參與者**：Designer + Architect（2026-06-13 16:14）

**移除原因**：
1. **BoundaryWalls 從未生效**：所有 StaticBody2D 的 `collision_mask = 0`，不與任何 Physics Layer 碰撞，是廢節點
2. **重複系統**：TileMapLayer 的 TileSet 已在每個 Solid Tile 上設定 Physics Layer，玩家碰撞完全由此處理
3. **維護成本高**：每個房間需手動調整 4 個 StaticBody2D 的尺寸與位置，且容易與 TileSet 佈局不同步
4. **無腳本依賴**：`room_base.gd`、`game_world.gd` 均未引用 BoundaryWalls，不是架構的一部分

**取而代之的設計規範（強制）**：
> 「每個房間的 `PlatformLayer` 必須在四周繪製封閉的 Solid Tile 牆壁（帶 Physics Layer 碰撞的 Tile）。Portal 開口處的邊緣由 Portal 本身引導過渡。CameraZone 的可視範圍邊緣必須完全被 Tile 覆蓋，不得露出虛空。」

**標準房間節點結構（更新後）**：
```
RoomXxx (Node2D + RoomBase.gd)
├── CameraZone       (Area2D + camera_zone.gd)     ← 鏡頭範圍觸發
│   └── CollisionShape2D
├── TileLayers       (Node2D)
│   ├── BGLayer      (TileMapLayer, z=-10)          ← 背景裝飾，無碰撞
│   ├── PlatformLayer (TileMapLayer)                 ← 地形 + 碰撞（唯一碰撞來源）
│   └── FGLayer      (TileMapLayer, z=+10)          ← 前景裝飾，無碰撞
├── Portals          (Node2D)
│   └── XxxPortal    (Area2D + room_portal.gd)
├── SpawnPoint       (Marker2D)
└── Enemies          (Node2D)
```

**影響的文件**：
- `area_0_room_01.tscn`：已移除 BoundaryWalls（2026-06-13）
- `area_0_room_02.tscn`：已移除 BoundaryWalls（2026-06-13）
- 所有未來的房間模板不再包含 BoundaryWalls

---

### 10.11 空洞騎士風 Walk-in 轉場設計 [CONFIRMED — 2026-06-14]

**設計品質要求**：
玩家進入新房間時，應像「房間連接空間，玩家自然走入」，而不是「間視點傳送」。

**主流實作（空洞騎士 / Ori / Celeste 騗致做法）**：

| 階段 | 玩家為中時 | 玩家為未結板時 |
|------|---------|----------|
| 1 | 走進 Portal 洞口 | 走到 Portal 邊緣 |
| 2 | ScreenFader Fade to Black | ScreenFader Fade to Black |
| 3 | 玩家移動到新房間 SpawnMarker（門口邊緣） | 玩家移動到新房間 SpawnMarker（門口邊緣） |
| 4 | 玩家獲得小量初始進入方向的速度 | 玩家獲得小量初始進入新房間方向的速度 |
| 5 | ScreenFader Fade to Visible | ScreenFader Fade to Visible |
| 6 | 玩家已在行走進入新房間 | 玩家已在行走進入新房間 |

**技術實作細節**：
- `room_portal.gd`：`target_room_path` 改為 `@export_file("*.tscn")`（Inspector 可直接拖拽選擇）
- `game_world.gd` 的 `_reset_player_at_door()` ：玩家出現後，依据 entry door_id 警倹初始水平速度
  - LeftPortal 入口 → 玩家初始 velocity.x = +walk_speed（向右行走）
  - RightPortal 入口 → 玩家初始 velocity.x = -walk_speed（向左行走）
- `player.gd`：新增 `apply_entry_velocity(horizontal_speed: float)` 方法
  - 在 deferred 環境呼叫（ERR-001 安全）
  - 不乫擾玩家目前的 `_facing` 方向

**SpawnMarker 位置規範**：
- LeftPortal SpawnMarker：放在 Portal CollisionShape2D 內側右端（玩家從左做左入從右走）
- RightPortal SpawnMarker：放在 Portal CollisionShape2D 內側左端（玩家從右入從左走）
- Y 軸不可懸空，必須對齊地板

**能集 Walk-in 的走廈**：
玩家從逆 Portal 方向出現，帶著向內的速度，矠矠確證 Fade 全黑的瞬間玩家已正確定位。視覺上像「自然走進來」。

---
est_room** | **Designer+Developer** |
| **2026-06-14** | **移除 game_world.tscn 中的預設靜態碰撞牆（Ground/Ceiling/WallLeft/WallRight）** | **這 4 個節點是早期開發用的全局邊界牆，在正式地圖階段由 PlatformLayer TileSet 每房間自行提供碰撞封閉後已屬冗餘** | **Designer+Developer** |
| **2026-06-14** | **area_0_room_02 LeftPortal 必須雙向連結 area_0_room_01（修正 BUG）** | **LeftPortal 的 target_room_path 為空，導致無法從 room_02 返回 room_01，與 Portal 對接規則矛盾** | **Designer** |
| **2026-06-14** | **Portal @export 改用 @export_file("*.tscn")** | **Inspector 可直接用文件對話框選擇場景，降低手打路徑錯誤風險** | **Designer** |
| **2026-06-14** | **採用空洞騎士風 Walk-in 轉場（§10.11）** | **玩家出現在門口邊緣並帶初始方向速度，避免「瞬移割裂感」；SpawnMarker 位置規範同步更新** | **Designer** |

---

## ❓ 待確認事項（給用戶）

> 以下問題需要用戶回答才能繼續設計：

1. **P3/P4 鍵盤映射**：P3/P4 的移動/跳躍/翻滾鍵位需要確認（目前只設定了 P1/P2）
2. **Boss**：目前有設計任何 Boss 概念嗎？
3. **音樂**：有任何偏好的音樂風格？
4. **走廊尺寸**：走廊建議寬度和長度範圍有無特殊偏好（目前：寬 2 tile、長 4~8 tile）？
5. **近戰 VFX 方向**：slash VFX 是否需要鏡像翻轉以符合攻擊方向？（建議：是）

## 更新紀錄 (2026-06-13) - 玩家翻轉 + 八方向彈道

### 玩家視覺翻轉
- 移動方向改變時，整個 VisualPivot（精靈圖 + UI）跟隨翻轉
- scale.x = _facing（+1 向右，-1 向左）
- 視覺傾斜（Sway）已修正為翻轉後仍向前方傾斜

### 八方向彈道系統
- **水平方向**：由移動鍵（move_left / move_right）決定
- **垂直方向**：由 aim_up / aim_down 專用鍵決定  
- **P1 按鍵**：I = 向上射，K = 向下射（搭配 WASD 移動）
- **P2 按鍵**：Numpad 8 = 向上，Numpad 5 = 向下
- **退化模式**：無方向輸入 → 水平射擊（朝 _facing 方向）
- 子彈自動旋轉到 direction.angle()（player_bullet.gd 既有實作）
- 近戰 Hitbox 也跟隨 aim_dir 方向旋轉（支援上下近戰）
---

## 玩家操控更新（2026-06-13）

### 左右翻轉
- VisualPivot.scale.x 根據 _facing 翻轉（-1=左, 1=右）
- 由於 TileMapLayer 不支援 flip_h，改為翻轉整個 VisualPivot
- 傾斜（Sway）旋轉 = _sway_y * _facing，確保左向時傾斜方向正確

### 8方向彈道系統
- 右鍵攻擊（Ranged）時讀取當前 WASD 輸入決定射擊方向
- 水平：A（左）/ D（右）
- 垂直：W（上）/ S（下）
- 對角線：組合鍵（45度，向量自動標準化為 0.707）
- 無輸入：沿當前朝向（_facing）水平射擊

| 方向 | 按鍵 | 向量 |
|------|------|------|
| 右   | D    | (1, 0) |
| 左   | A    | (-1, 0) |
| 上   | W    | (0, -1) |
| 下   | S    | (0, 1) |
| 右上 | D+W  | (0.707, -0.707) |
| 右下 | D+S  | (0.707, 0.707) |
| 左上 | A+W  | (-0.707, -0.707) |
| 左下 | A+S  | (-0.707, 0.707) |

- 輸入映射新增：p1_move_up (W), p1_move_down (S), p2_move_up (↑), p2_move_down (↓)
- Muzzle Flash VFX 根據射擊角度旋轉，_spawn_vfx_aimed() 處理全方向特效

---

## 操控表更新（2026-06-13 v2）— 跳躍按鍵修正

### P1 操控表（最終版）

| 動作 | 按鍵 | 說明 |
|------|------|------|
| 移動左 | A | 水平移動 |
| 移動右 | D | 水平移動 |
| 跳躍 | **Space（唯一）** | W 已從 jump 移除，Space 是唯一跳躍鍵 |
| 翻滾 | Shift | 地面翻滾（消耗耐力） |
| 瞄準上 / 射擊上 | W | **只影響射擊方向，不再觸發跳躍** |
| 瞄準下 / 射擊下 | S | 只影響射擊方向 |
| 近戰攻擊 | 左鍵（LMB） | 即時觸發，矩形揄描 |
| 遠程攻擊 | 右鍵（RMB） | 方向由當前 WASD 決定（8方向） |

### 設計決策 [CONFIRMED 2026-06-13]
- W = 瞄準上（只在右鍵攻擊時採樣，不觸發跳躍）
- Space = 跳躍（唯一跳躍鍵）
- 此設計確保 W 按住射擊時不會意外跳躍

### UI 規格更新

| 元件 | 規格 |
|------|------|
| 心形血量 UI | 24×24px，STRETCH_KEEP_ASPECT_CENTERED，等比放大不變形 |
| 心形材質 | 8×8px atlas（mrmotext 圖集），AtlasTexture + filter_clip |

---

## 🗺️ 10. 地圖房間結構設計規範 [CONFIRMED 2026-06-13 v5]

> **本章節依據 /grill-me 設計訪談（2026-06-13）確認。**
> 適用於所有手動搭建的房間場景（scenes/levels/area_X/）。

### 10.1 房間分類與命名規範 [CONFIRMED]

```
scenes/
  levels/
    area_0/          ← 第一區域（地下城入口）
      area_0_room_01.tscn
      area_0_room_02.tscn
      ...
    area_1/          ← 第二區域（待定）
    area_2/          ← 第三區域（待定）
```

**命名規則**：`area_{區域編號}_room_{房間編號}.tscn`
- 區域編號：0 = 起始區，1 = 中段區，2 = 深部區
- 房間編號：兩位數（01、02...），從 01 開始，按關卡流程排序
- **設計師手動繪製 TileMap 地形**，不使用程式化生成地形

---

### 10.2 房間節點標準結構 [CONFIRMED]

```
RoomXX (Node2D)                  ← 房間根節點，掛 room_base.gd 腳本
├── CameraZone (Area2D)          ← 鏡頭邊界定義器（空洞騎士實作法）
│   └── CollisionShape2D         ← 由設計師手動調整大小 = 鏡頭可見範圍
│
├── TileLayers (Node2D)          ← 所有 TileMapLayer 的容器
│   ├── BGLayer (TileMapLayer)   ← 背景裝飾，z_index=-10，無碰撞
│   ├── PlatformLayer (TileMapLayer) ← 地形主層，z_index=0，有碰撞（唯一碰撞來源）
│   └── FGLayer (TileMapLayer)   ← 前景層（柱子邊緣/薄霧葉等），z_index=10，無碰撞
│
├── Portals (Node2D)             ← 所有 Portal 的容器
│   └── RightPortal (Area2D)     ← 右方出口（第一個房間只有右 Portal）
│       ├── CollisionShape2D     ← 觸發區
│       └── SpawnMarker (Marker2D) ← 玩家從這裡出現
│
├── SpawnPoint (Marker2D)        ← 玩家進入本房間的預設出現點（入口）
│
└── Enemies (Node2D)             ← 敵人容器（由設計師手動在 Editor 中配置）
```

> ⚠️ **注意**：`BoundaryWalls` 已於 2026-06-13 移除（見 §10.10）。地形碰撞完全依賴 `PlatformLayer` 的 TileSet Physics Layer。

---

### 10.3 TileMapLayer 分層規範 [CONFIRMED]

| 層名 | z_index | 碰撞 | 用途 |
|------|---------|------|------|
| BGLayer | -10 | 無 | 背景磚塊（石牆紋理、圖案）、遠景裝飾 |
| PlatformLayer | 0 | 有（collision_layer=1） | 地板、牆壁、天花板——玩家/敵人站立的主要地形 |
| FGLayer | 10 | 無 | 前景裝飾（柱子前方邊框、植被、霧氣效果）|

**擴展原則**：
- 新分層只往此三層補充，不另立新 z_index（保持簡潔）
- 若未來需要「裝飾牆柱」可在 PlatformLayer 旁加 DecoLayer（z=1，無碰撞）

---

### 10.4 鏡頭邊界系統（CameraZone）[CONFIRMED]

**設計決策**：採用 Area2D（空洞騎士實際做法），不使用 Marker2D 四點限制。

| 項目 | 規格 |
|------|------|
| 實作方式 | 每個房間含 **CameraZone（Area2D + CollisionShape2D）** |
| 調整方式 | 設計師在 Godot Editor 直接拖拉 CollisionShape2D 的大小 |
| 觸發時機 | 玩家進入 CameraZone 時，MultiplayerCamera 以 **Tween（0.3s）** 平滑更新 Camera2D 的 limit_left/right/top/bottom |
| 防虛空規則 | CollisionShape2D 大小 ≤ 房間 TileMap 繪製範圍；**設計師必須確認 Camera2D 看不到 TileMap 邊界外的虛空** |
| 子區域支援 | 同一房間可放多個 CameraZone，過渡銜接不同攝影機邊界 |

**MultiplayerCamera 升級需求**（交 Architect 規劃）：
- 新增 `set_limits_from_zone(zone: Area2D)` 方法
- 使用 Tween 平滑插值 limit_* 四個邊界
- 玩家離開舊 zone 且進入新 zone 時切換（防止邊界閃爍）

---

### 10.5 房間邊界牆設計 [❗ 已廢棄 — 見 §10.10]

> 此章節所描述的 BoundaryWalls 已於 2026-06-13 完全移除（見 §10.10）。
> 所有房間的碰撞封閉由 PlatformLayer TileSet Physics Layer 負責。
> Portal 開口處由地形設計師手動疫空不畫 Tile。

---

### 10.6 Portal 設計規範 [CONFIRMED]

**第一階段（Area_0）**：只配置右方出口（RightPortal）。

| 屬性 | 規格 |
|------|------|
| door_id | 方向字串（"right" / "left" / "top" / "bottom"） |
| target_room_path | 目標 .tscn 路徑（空字串 = 交由 DungeonGenerator 決定） |
| target_door_id | 對應房間的入口 door_id（右出 → 左入，即 "left"） |
| 觸發碰撞 | collision_mask=2（只偵測 Players 層） |
| SpawnMarker | 玩家從目標房間的 SpawnMarker 位置出現 |

**Portal 對接規則**：
```
area_0_room_01 RightPortal (door_id="right")
    ↕
area_0_room_02 LeftPortal (door_id="left")
```

---

### 10.7 互動物件規劃（MoSCoW）[DRAFT — 未實作]

> 以下為架構層級的預留設計，Area_0 前兩個房間不實作。

| 物件類型 | 技術實作 | 優先級 |
|---------|---------|-------|
| 木箱（可推動） | RigidBody2D | Should Have |
| 寶箱 | StaticBody2D + Area2D | Should Have |
| 移動平台 | AnimatableBody2D + Path2D | Could Have |
| 壓力板機關 | StaticBody2D（局部影） | Could Have |
| 單向跳台（one-way） | TileMapLayer 特殊圖層 | Could Have |

---

### 10.8 設計師工作流程（手動搭建房間）[CONFIRMED]

1. **Architect** 創建空白房間 `.tscn`，包含：CameraZone、TileLayers（BGLayer/PlatformLayer/FGLayer 空白）、Portal（含 SpawnMarker）
   - ⚠️ **不再包含 BoundaryWalls**（見 §10.10 設計決策）
2. **設計師（用戶）** 在 Godot Editor 中：
   - 在 `PlatformLayer` 繪製地板、牆壁、天花板（有碰撞的地形）
   - **必須在房間四周繪製封閉的 Solid Tile 牆壁**，確保玩家無法走出地形範圍
   - 在 `BGLayer` 繪製背景裝飾
   - 在 `FGLayer` 繪製前景（可選）
   - 拖拉 `CameraZone` 的 CollisionShape2D 覆蓋可見地形區域
   - 在 Portal 的 Inspector 設定 `target_room_path` 和 `target_door_id`
3. **開發驗證**：確認鏡頭不會露出虛空，Portal 觸發正確，四周 Tile 封閉

---

### 10.9 技術風險 [CONFIRMED]

| 風險 | 等級 | 緩解措施 |
|------|------|---------|
| CameraZone 與 MultiplayerCamera 整合 | 中 | Architect 在 impl_plan 中定義接口；Developer 新增 `set_limits_from_zone()` 方法 |
| 多個玩家分散在不同 CameraZone | 中 | 優先以 P1 所在的 zone 為基準；或取所有玩家 zone 的聯集 |
| 設計師忘記繪製封閉 Tile 牆壁 | 低 | QA 測試清單加入「從每個角落確認無虛空可見」；CameraZone 範圍必須完全被 Tile 覆蓋 |
| 設計師忘記調整 CameraZone 邊界 | 低 | QA 測試清單加入「從每個角落確認無虛空可見」 |

---

### 10.10 設計決策記錄：移除 BoundaryWalls [CONFIRMED — 2026-06-13]

**決策**：移除所有房間場景中的 `BoundaryWalls` 節點（StaticBody2D 邊界牆組合），改由 TileMapLayer 的 Physics Layer 作為**唯一的碰撞策略**。

**討論參與者**：Designer + Architect（2026-06-13 16:14）

**移除原因**：
1. **BoundaryWalls 從未生效**：所有 StaticBody2D 的 `collision_mask = 0`，不與任何 Physics Layer 碰撞，是廢節點
2. **重複系統**：TileMapLayer 的 TileSet 已在每個 Solid Tile 上設定 Physics Layer，玩家碰撞完全由此處理
3. **維護成本高**：每個房間需手動調整 4 個 StaticBody2D 的尺寸與位置，且容易與 TileSet 佈局不同步
4. **無腳本依賴**：`room_base.gd`、`game_world.gd` 均未引用 BoundaryWalls，不是架構的一部分

**取而代之的設計規範（強制）**：
> 「每個房間的 `PlatformLayer` 必須在四周繪製封閉的 Solid Tile 牆壁（帶 Physics Layer 碰撞的 Tile）。Portal 開口處的邊緣由 Portal 本身引導過渡。CameraZone 的可視範圍邊緣必須完全被 Tile 覆蓋，不得露出虛空。」

**標準房間節點結構（更新後）**：
```
RoomXxx (Node2D + RoomBase.gd)
├── CameraZone       (Area2D + camera_zone.gd)     ← 鏡頭範圍觸發
│   └── CollisionShape2D
├── TileLayers       (Node2D)
│   ├── BGLayer      (TileMapLayer, z=-10)          ← 背景裝飾，無碰撞
│   ├── PlatformLayer (TileMapLayer)                 ← 地形 + 碰撞（唯一碰撞來源）
│   └── FGLayer      (TileMapLayer, z=+10)          ← 前景裝飾，無碰撞
├── Portals          (Node2D)
│   └── XxxPortal    (Area2D + room_portal.gd)
├── SpawnPoint       (Marker2D)
└── Enemies          (Node2D)
```

**影響的文件**：
- `area_0_room_01.tscn`：已移除 BoundaryWalls（2026-06-13）
- `area_0_room_02.tscn`：已移除 BoundaryWalls（2026-06-13）
- 所有未來的房間模板不再包含 BoundaryWalls