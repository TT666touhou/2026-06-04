**GDD 最後同步：2026-06-16 v12** | 維護者：Designer 角色

# GAME DESIGN DOCUMENT
# ============================================================
# 由 Game Designer 維護
# 狀態標記：[DRAFT] 草稿中 | [CONFIRMED] 已確認 | [LOCKED] 不可再修改
#
# 規則：
# - 所有欄位必須由 Designer 填寫
# - Architect / Developer / QA 不可直接修改，有疑義請找 Designer
# - Designer 編輯前必須：①確認無衝突內容 ②確認無過時資訊 ③不得僅在文件後段堆積新內容
# ============================================================

---

## 📋 章節狀態總覽

| 章節 | 狀態 | 最後更新 |
|------|------|---------|
| §1 遊戲核心概念 | [CONFIRMED] | 2026-06-06 |
| §2 視覺風格系統 | [CONFIRMED] | 2026-06-15 |
| §3 角色組成架構 | [CONFIRMED] | 2026-06-15 |
| §4 敵人設計 | [PARTIAL] | 2026-06-15 |
| §5 多人系統 | [CONFIRMED] | 2026-06-12 |
| §6 玩家角色設計 | [CONFIRMED] | 2026-06-13 |
| §8 戰鬥系統 | [CONFIRMED] | 2026-06-13 |
| §9 音效/音樂 | [DRAFT] | 2026-06-06 |
| §10 地圖與房間系統 | [CONFIRMED] | 2026-06-14 v7 |
| §11 技術限制與平台 | [CONFIRMED] | 2026-06-12 |
| 附錄 A 決策記錄 | [CONFIRMED] | 2026-06-14 |
| 附錄 B 待確認事項 | [OPEN] | 2026-06-15 |

---

## 🎮 §1. 遊戲核心概念

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
大廳組隊（1~4 人）→ 固定關卡序列 → 探索/戰鬥 → 擊敗 Boss → 進入下一區域 → 結算
房間序列：設計師手工決定的固定順序（area_X_room_XX.tscn），非隨機生成
```
> ⚠️ [Phase-7.0 更新 2026-06-14] 地圖採用**非程序化固定序列**設計。
> 所有房間由設計師在 `scenes/levels/area_X/` 下手工建立並排序，
> DungeonGenerator 僅負責按 AREA_0_ROOMS 陣列順序載入，不進行任何隨機化。
> 詳見 §10「房間與地圖系統」。

---

## 🎨 §2. 視覺風格系統

### 2.1 Tile 視覺規格 [CONFIRMED]

| 規格 | 數值 | 說明 |
|------|------|------|
| 基礎 Tile 尺寸 | 8×8 px | MRMOTEXT Extended 原始尺寸 |
| 大型 Tile 尺寸 | 24×24 px | MRMOTEXT x3 版本 |
| 渲染縮放 | 4× | Camera2D zoom=4，等效 32px/tile 顯示 |
| 色彩模式 | 黑底白圖 + 色票染色 | Multiply 混色模式 |
| 調色盤 | VfxMix 34色 | 見 assets/vfxmix/palette.pal |

### 2.2 VFX 系統 [CONFIRMED]
- **粒子特效**：使用 VfxMix `particle/` 素材作為 GPUParticles2D 貼圖
- **近戰攻擊特效**：`assets/vfxmix/fx/slash_01.png`（6幀，哥德式刀斬特效）
- **遠程發射特效**：`assets/vfxmix/fx/spark_01.png`（6幀，魔法火花）
- **命中特效**：`assets/vfxmix/fx/impact_01.png`（6幀，敵人受傷 impact）
- **死亡特效**：`assets/vfxmix/fx/death_01.png`（6幀，敵人消散爆裂）
- **形狀層疊**：VfxMix `shape/` 與 MRMOTEXT 風格一致（黑白輪廓），可直接疊用
- **行動煙塵**：見 §8「PlayerDust 煙塵特效」

---

## 🧩 §3. 角色組成架構（Tile Composite System）

### 3.1 設計哲學 [CONFIRMED]
- 所有角色（玩家/敵人/Boss）的視覺表現均由 **TileMapLayer 節點** 拼接而成
- 不使用傳統 AnimatedSprite2D 或 Sprite2D 逐幀動畫
- 外觀變體透過**調色盤染色**產生，不製作獨立精靈圖
- 角色動畫由**腳本驅動 tile 位置偏移**實現，非影格動畫

### 3.2 已設計完成的形象 [CONFIRMED]

> 以下欄位由設計師填入，並在 `scenes/char_design/char_design.tscn` 中查驗。

| 角色 ID | 類型 | 外觀描述 | 場景路徑 | 狀態 |
|---------|------|---------|---------|---------|
| **CHAR-007** | NPC / 玩家候選 | 白髮吸血鬼女孩，2D橫向捲軸，**嚴格 3色**：黑 `#363232` + 白 `#F2F9F8` + 緋紅 `#E55C5C`（VfxMix 34色調色盤 Index 1/34/12）；緋紅用於眼睛和蝴蝶結 | `assets/characters/vampire_girl_char007/` | [CONFIRMED 2026-06-16] PixelLab 生成完成，3 尺寸（16×16 / 32×32 / 48×48），含 3 色量化後製版 |

---

## 👾 §4. 敵人設計

### 4.2 敵人性能設計原則 [CONFIRMED]
- 同屏最大數量目標：20~40 隻
- 每隻敵人使用 TileMapLayer（Tile Composite）外觀，不使用 AnimatedSprite2D
- 死亡動畫：縮放淡出 + 死亡 VFX（程式動畫，比逐幀更輕量）

### 4.3 敵人已實作系統 [CONFIRMED]

| 腳本 | 路徑 | 說明 |
|------|------|------|
| enemy1.gd | `scripts/enemy/enemy1.gd` | 基礎敵人 |
| enemy2.gd | `scripts/enemy/enemy2.gd` | 基礎敵人變體 |
| enemy3.gd | `scripts/enemy/enemy3.gd` | 基礎敵人變體 |
| enemy_stats.gd | `scripts/resources/enemy_stats.gd` | 敵人數值資源 |
| boss.gd | `scripts/enemy/boss.gd` | Boss 基礎腳本（骨架） |

### 4.4 敵人 VFX 系統 [CONFIRMED]

| VFX | 素材 | 幀數 | 觸發條件 |
|-----|------|------|---------|
| 近戰砍擊（MeleeSlash） | `fx/slash_01.png` | 16幀 | 近戰攻擊第1擊時 |
| 遠程發射（RangedMuzzle） | `fx/spark_01.png` | 16幀 | 發射子彈時 |
| 敵人受傷（EnemyHit） | `fx/impact_01.png` | 16幀 | 敵人 take_damage 時 |
| 敵人死亡（EnemyDeath） | `fx/death_01.png` | 24幀 | 敵人 die() 時 |

### 4.5 Boss 設計方向 [DRAFT]
> [DRAFT] 尚未開始設計

---

## 👥 §5. 多人系統

### 5.1 多人模式 [CONFIRMED]
- **本地多人**：同一台電腦，2~4 人共用螢幕
- **未來擴展**：線上多人（第二階段，目前不實作）
- **MultiplayerCamera**：統一鏡頭，覆蓋所有玩家位置

**多人觸發規則（Portal 換房）[CONFIRMED]**：
- **全部玩家都必須進入走廊的 Area2D 觸發區**，才觸發換房間
- 與現有的 `_players_in_zone` 計數機制一致

### 5.2 玩家輸入映射 [CONFIRMED]

| 玩家 | 移動 | 跳躍 | 翻滾 | 近戰（左鍵） | 遠程（右鍵） | 瞄準上 | 瞄準下 |
|------|------|------|------|------------|------------|--------|--------|
| P1 | A/D | Space | Shift | 滑鼠左鍵 | 滑鼠右鍵 | W | S |
| P2 | ←/→ | ↑ | Numpad Enter | 滑鼠左鍵 | 滑鼠右鍵 | Numpad 8 | Numpad 5 |
| P3 | 待設計 | 待設計 | 待設計 | 滑鼠左鍵 | 滑鼠右鍵 | 待設計 | 待設計 |
| P4 | 待設計 | 待設計 | 待設計 | 滑鼠左鍵 | 滑鼠右鍵 | 待設計 | 待設計 |

> **攻擊設計決策 [CONFIRMED 2026-06-12]**：
> - **左鍵（LMB）= 近戰**：即時觸發，短範圍矩形掃描攻擊
> - **右鍵（RMB）= 遠程**：即時觸發，方向由當前 WASD 決定（8方向）
> - W = 瞄準上（只在右鍵攻擊時採樣，不觸發跳躍）
> - Space = 跳躍（唯一跳躍鍵）
> - 廢棄舊設計（短按/長按同鍵），因左右鍵分離更直覺

---

## 🦸 §6. 玩家角色設計

### 6.1 玩家外觀 [CONFIRMED]
- 使用 Tile Composite 系統，與敵人使用相同的 MRMOTEXT tileset
- **玩家顏色方案**：[DRAFT 待用戶確認] — 各玩家 (P1-P4) 使用不同染色區分
- 動態顏色採樣：`apply_player_color(skin_index)` 方法（已實作，顏色參數待確認）

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
| 視覺翻轉 | [CONFIRMED] | VisualPivot.scale.x 根據 _facing 翻轉（-1=左, 1=右） |
| 8方向彈道 | [CONFIRMED] | 右鍵射擊時讀取 WASD 方向；無輸入則沿 _facing 水平射擊 |

**8方向彈道向量表**：

| 方向 | 按鍵 | 向量 |
|------|------|------|
| 右 | D | (1, 0) |
| 左 | A | (-1, 0) |
| 上 | W | (0, -1) |
| 下 | S | (0, 1) |
| 右上 | D+W | (0.707, -0.707) |
| 右下 | D+S | (0.707, 0.707) |
| 左上 | A+W | (-0.707, -0.707) |
| 左下 | A+S | (-0.707, 0.707) |

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

## ⚔️ §8. 戰鬥系統

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

### 8.3 近戰 3 擊 Combo 系統 [CONFIRMED 2026-06-13] **[IMPLEMENTED]**

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

**顏色**：VFX 使用**原色**（不繼承玩家顏色） [CONFIRMED 2026-06-13]

### 8.4 遠程 VFX [CONFIRMED]
- 發射子彈瞬間，在子彈出生點生成 `RangedMuzzle.tscn`（spark_01.png 6幀動畫）
- 子彈繼承玩家顏色（modulate 染色）

### 8.5 近戰 VFX 規格（各擊對應）[CONFIRMED] [UPDATED 2026-06-13 v3]

| 擊數 | VFX 場景 | 素材 | 幀數 | 播放速度 | 比例 |
|------|---------|------|------|------|------|
| 第 1 擊 | `MeleeSlash.tscn` | `slash_01.png`（91×96px/幀） | 16幀 | **60fps** | 0.35 |
| 第 2 擊 | `MeleeSlash2.tscn` | `slash_02.png`（72×105px/幀，flip_h） | 16幀 | **60fps** | 0.35 |
| 第 3 擊 | `MeleeImpact3.tscn` | `impact_01.png`（137×98px/幀） | 16幀 | **50fps** | 0.40 |

- VFX 使用**原色**（白色，不染玩家顏色） [CONFIRMED 2026-06-13]
- VisualPivot 縮放：scale→(1.20, 0.82) 0.06s，回彈 0.09s（保持正值避免子節點渲染問題）

**VFX 速度設計原則**：攻擊鎖定 0.15~0.20s，speed = frames/lock * 0.6 ≈ 60fps；避免 VFX 拖尾超過攻擊動作

### 8.6 PlayerDust — 玩家行動煙塵特效 [CONFIRMED]

#### BrickDebris（磚塊碎片）

| 項目 | 規格 |
|---|---|
| 素材 | `assets/vfxmix/particle/brick_gray.png`（144×22，**6幀**，每幀 24×22px） |
| 觸發條件 | 消耗耐力的地形接觸動作：正常跳躍、翻滾（Shift）、蹬牆跳 |
| 地形接觸要求 | is_on_floor（跳/翻滾）或 is_on_wall（蹬牆） |
| 排除條件 | 二段跳（空中無地形接觸） |
| 飛出方向 | 地板法線反射：`velocity.bounce(terrain_normal)` |
| 顏色 | ShapeCast2D 採樣脚底磚塊中心像素，fallback 為灰色 |
| 粒子數 | 6 |
| 壽命 | 0.45s |
| 旋轉 | 每顆粒子隨機角速，產生在空中翻滾動感 |

#### DustCloud（落地煙塵雲）

| 項目 | 規格 |
|---|---|
| 素材 | 程式化圓點粒子（無貼圖） |
| 觸發條件 | 落地瞬間 `not _was_on_floor and is_on_floor()` 且 `abs(velocity.x) > 10` |
| 顏色 | 固定灰色 `#AAAAAA` |
| 排除條件 | 靜落（velocity.x 接近零）、翻滾落地 |
| 飛出方向 | 略寬扇形向上，橫跨地面 |
| 粒子數 | 12 |
| 壽命 | 0.5s |

#### 地板顏色偵測
- 使用 `ShapeCast2D`（矩形 10×2px，向下 4px）
- 取 TileMapLayer Atlas 貼圖磚塊中心像素顏色
- **不需要修改 TileSet**
- fallback：`Color(0.65, 0.65, 0.65)`

---

## 🎵 §9. 音效/音樂

### 9.1 音樂風格 [DRAFT]
> 待確認：哥德管風琴風格？現代電子 + 管弦？

---

## 🗺️ §10. 地圖與房間系統 [CONFIRMED 2026-06-14 v7]

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

> ⚠️ **注意**：`BoundaryWalls` 已於 2026-06-13 移除（見 §10.8）。地形碰撞完全依賴 `PlatformLayer` 的 TileSet Physics Layer。

---

### 10.3 TileMapLayer 分層規範 [CONFIRMED]

| 層名 | z_index | 碰撞 | 用途 |
|------|---------|------|------|
| BGLayer | -10 | 無 | 背景磚塊（石牆紋理、圖案）、遠景裝飾 |
| PlatformLayer | 0 | 有（collision_layer=1） | 地板、牆壁、天花板——玩家/敵人站立的主要地形 |
| FGLayer | 10 | 無 | 前景裝飾（柱子前方邊框、植被、霧氣效果） |

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

### 10.5 房間邊界牆設計 [❗ 已廢棄 — 見 §10.8]

> 此章節所描述的 BoundaryWalls 已於 2026-06-13 完全移除（見 §10.8）。
> 所有房間的碰撞封閉由 PlatformLayer TileSet Physics Layer 負責。
> Portal 開口處由地形設計師手動留空不畫 Tile。

---

### 10.6 Portal 設計規範 [CONFIRMED]

**第一階段（Area_0）**：只配置右方出口（RightPortal）。

| 屬性 | 規格 |
|------|------|
| door_id | 方向字串（"right" / "left" / "top" / "bottom"） |
| target_room_path | 目標 .tscn 路徑（`@export_file("*.tscn")`，Inspector 可直接拖拽選擇） |
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

### 10.8 設計決策：移除 BoundaryWalls [CONFIRMED — 2026-06-13]

**決策**：移除所有房間場景中的 `BoundaryWalls` 節點，改由 TileMapLayer 的 Physics Layer 作為**唯一的碰撞策略**。

**移除原因**：
1. **BoundaryWalls 從未生效**：所有 StaticBody2D 的 `collision_mask = 0`，不與任何 Physics Layer 碰撞，是廢節點
2. **重複系統**：TileMapLayer 的 TileSet 已在每個 Solid Tile 上設定 Physics Layer
3. **維護成本高**：每個房間需手動調整 4 個 StaticBody2D，容易與 TileSet 佈局不同步
4. **無腳本依賴**：`room_base.gd`、`game_world.gd` 均未引用 BoundaryWalls

**取而代之的設計規範（強制）**：
> 「每個房間的 `PlatformLayer` 必須在四周繪製封閉的 Solid Tile 牆壁（帶 Physics Layer 碰撞的 Tile）。Portal 開口處的邊緣由 Portal 本身引導過渡。CameraZone 的可視範圍邊緣必須完全被 Tile 覆蓋，不得露出虛空。」

**標準房間節點結構（更新後）**：見 §10.2

**影響的文件**：
- `area_0_room_01.tscn`：已移除 BoundaryWalls（2026-06-13）
- `area_0_room_02.tscn`：已移除 BoundaryWalls（2026-06-13）
- 所有未來的房間模板不再包含 BoundaryWalls

---

### 10.9 設計師工作流程（手動搭建房間）[CONFIRMED]

1. **Architect** 創建空白房間 `.tscn`，包含：CameraZone、TileLayers（BGLayer/PlatformLayer/FGLayer 空白）、Portal（含 SpawnMarker）
   - ⚠️ **不再包含 BoundaryWalls**（見 §10.8）
2. **設計師（用戶）** 在 Godot Editor 中：
   - 在 `PlatformLayer` 繪製地板、牆壁、天花板（有碰撞的地形）
   - **必須在房間四周繪製封閉的 Solid Tile 牆壁**，確保玩家無法走出地形範圍
   - 在 `BGLayer` 繪製背景裝飾
   - 在 `FGLayer` 繪製前景（可選）
   - 拖拉 `CameraZone` 的 CollisionShape2D 覆蓋可見地形區域
   - 在 Portal 的 Inspector 設定 `target_room_path` 和 `target_door_id`
3. **開發驗證**：確認鏡頭不會露出虛空，Portal 觸發正確，四周 Tile 封閉

---

### 10.10 技術風險 [CONFIRMED]

| 風險 | 等級 | 緩解措施 |
|------|------|---------| 
| CameraZone 與 MultiplayerCamera 整合 | 中 | Architect 在 impl_plan 中定義接口 |
| 多個玩家分散在不同 CameraZone | 中 | 優先以 P1 所在的 zone 為基準；或取所有玩家 zone 的聯集 |
| 設計師忘記繪製封閉 Tile 牆壁 | 低 | QA 測試清單加入「從每個角落確認無虛空可見」 |
| 設計師忘記調整 CameraZone 邊界 | 低 | QA 測試清單加入「從每個角落確認無虛空可見」 |

---

### 10.11 Walk-in 房間進入轉場設計 [CONFIRMED — 2026-06-13]

**設計目標**：玩家穿越 Portal 進入新房間時，不直接「彈出」於洞口，而是執行一段 Walk-in 動畫，模擬玩家從走廊走進房間的物理感（參考 Hollow Knight）。

#### Walk-in 機制規格

| 屬性 | 規格 |
|------|------|
| 鎖定期間 | 玩家輸入完全被忽略（移動/跳躍/攻擊），只有重力正常施加 |
| 移動速度 | `speed` 參數的 100%（與正常移動速度一致） |
| 移動距離 | 48 px（一個走廊深度） |
| 持續時間 | 48px / 100px/s ≈ 0.48 秒 |
| 接口 | `player.start_room_entry(direction: Vector2, distance: float, duration: float)` |

#### 進入方向規則

| 觸發門 (door_id) | Walk-in 方向 | 說明 |
|----------------|------------|------|
| `left` | `Vector2.RIGHT`（+X） | 從左門進入 → 向右走 |
| `right` | `Vector2.LEFT`（-X） | 從右門進入 → 向左走 |
| `top` | `Vector2.DOWN`（+Y） | 從頂部進入 → 向下走 |
| `bottom` | `Vector2.UP`（-Y） | 從底部進入 → 向上走 |

#### 實作位置
- `scripts/player/player.gd`：`start_room_entry()` 方法 + `_entry_locked` 狀態機
- `scripts/level/game_world.gd`：`_reset_player_at_door()` — 根據 `entry_door_id` 決定方向並呼叫 `start_room_entry()`

#### 目前限制
- Walk-in 期間不能跳躍（設計決策：防止玩家在進入動畫中意外輸入）
- 多人模式下每個玩家獨立執行 Walk-in（無同步問題，因為是本地動畫）

---

### 10.12 F6 房間直跑 Debug Player 系統 [CONFIRMED — 2026-06-14]

**設計目標**：讓開發者在 Godot Editor 中按 F6 直接執行任何 room 場景時，自動獲得一個可操控的玩家，無需手動配置 GameWorld 或切換主場景。

#### 實作位置
- **`scripts/level/rooms/room_base.gd`**：`_maybe_spawn_debug_player()` + `_get_debug_spawn_pos()` + `_add_debug_camera()`

#### 運作機制

| 步驟 | 說明 |
|------|------|
| 1. 偵測模式 | `_ready()` 呼叫 `call_deferred("_maybe_spawn_debug_player")` |
| 2. 條件判斷 | `get_tree().current_scene == self` → 表示此 RoomBase 是根場景（F6 模式） |
| 3. 玩家生成 | 載入 `scenes/player/player.tscn`，設 `player_prefix = "p1_"`，注入 `bullet_scene` |
| 4. 顏色設定 | 呼叫 `apply_player_color(0)`（預設第1套顏色） |
| 5. 生成位置 | 優先使用第一個 Portal 的 SpawnMarker（偏移 60px 向內），否則預設 (80, -80) |
| 6. 相機注入 | 加入 Camera2D（zoom=**4x**，smoothing=5.0）作為 player 的子節點 |

#### 不干擾正常流程
- 在 GameWorld 流程中，`get_tree().current_scene` 是 `GameWorld` 節點而非 `RoomBase`，條件不成立，此函式立即返回

#### 使用說明

在 Godot Editor 中開啟任意 `area_0_room_XX.tscn`，按 F6 後鍵位如下：

| 動作 | 鍵位 |
|------|------|
| 左/右移動 | A / D |
| 跳躍 | Space |
| 翻滾 | Shift |
| 近戰攻擊（Melee） | 滑鼠左鍵（LMB） |
| 遠程攻擊（Ranged） | 滑鼠右鍵（RMB） |

#### 限制

| 限制 | 說明 |
|------|------|
| Portal 不工作 | F6 模式無 GameWorld，Portal 觸發後無法換房間（正常） |
| 單人限制 | 只生成一個 debug player（p1_） |
| 縮放固定 4x | 與 MultiplayerCamera.max_zoom=4.0 一致 |

---

### 10.13 Checkpoint 系統 [CONFIRMED — 2026-06-14]

> **設計決策日期**: 2026-06-14 | 來源: /grill-me 設計討論

#### 概念
類似《艾爾登法環》的「賜福」。玩家在房間中找到 Checkpoint，靠近後按 F 鍵激活，之後成為 F6 debug 出生點。

#### 設計共識

| 決策 | 結果 |
|------|------|
| 名稱 | **Checkpoint**（暫定英文，未來可改世界觀名稱） |
| 激活鍵 | **F 鍵**（`ui_interact` action） |
| F6 有 Checkpoint | 在 Checkpoint.SpawnMarker 旁直接出現（無 Walk-in 動畫） |
| F6 無 Checkpoint | **Walk-in 模式**（由 Portal SpawnMarker 決定進入方向） |
| 入口方向指定 | Checkpoint 節點的 `@export entry_direction: String`，設計時 Inspector 手動指定 |
| 持久化範圍 | **Session-local**（本次遊戲記憶，重開遊戲重置） |
| 外觀 | 設計師用 Tileset 搭建外型；腳本控制激活前/後 AnimatedSprite2D 視覺差異 |

#### Checkpoint 場景結構

```
Checkpoint (Area2D, checkpoint.gd)
├── CollisionShape2D          <- 互動感應範圍（CircleShape2D, radius=40）
├── SpawnMarker (Marker2D)    <- 玩家 F6 生成位置（position = (24, -16)）
├── ActivationVFX (AnimatedSprite2D)  <- 激活視覺（未激活=灰暗，激活=金黃色）
└── InteractHint (Label)      <- 互動提示（靠近顯示 "[F] Activate Checkpoint"）
```

#### 激活流程

1. 玩家進入 Checkpoint Area2D 範圍
2. InteractHint 出現（"[F] Activate Checkpoint"）
3. 玩家按 **F 鍵**（`ui_interact`）
4. `activate()` 執行：`_activated = true`
5. ActivationVFX 切換至激活態（modulate 金黃色 `Color(1.2, 1.0, 0.3, 1.0)`）
6. 發送 `player_activated(self)` 信號

#### F6 Spawn 優先順序（room_base.gd）

```
優先 1: Checkpoint (group "Checkpoints") 存在於房間
  → 在 checkpoint.get_spawn_position() 生成
  → _facing 設定為 entry_direction 的方向

優先 2: Portal SpawnMarker 存在
  → 計算 entry_direction（靠近哪側門）
  → 玩家從邊界外 Walk-in（64px, 0.5s）

Fallback: Vector2(80, -80)
  → 向右 Walk-in
```

#### Inspector 設定（entry_direction 值）

| 值 | 含義 | Walk-in 向量 |
|----|------|-------------|
| `"right"` | 從左側門進入，玩家朝右走 | Vector2.RIGHT |
| `"left"` | 從右側門進入，玩家朝左走 | Vector2.LEFT |
| `"up"` | 從下方進入，玩家朝上走 | Vector2.UP |
| `"down"` | 從上方進入，玩家朝下走 | Vector2.DOWN |

#### 現有配置（area_0_room_01）
- **位置**: 房間左側 (80, -96)
- **entry_direction**: `"right"`（玩家從左側進入，面朝右）
- **用途**: 第一個房間的出生點

#### 未來擴展方向（現階段不實作）
- 死亡時回到最後激活的 Checkpoint（需要 GlobalState）
- 多個 Checkpoint 的持久化存檔（需要 SaveSystem）
- 多人模式：全員進入才激活

---

## 💻 §11. 技術限制與平台

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
| 腳本組織 | `scripts/autoload/`、`scripts/enemy/`、`scripts/player/`、`scripts/level/`、`scripts/ui/`、`scripts/utils/`、`scripts/vfx/` |

### 11.3 Asset 資源清單 [CONFIRMED]

| 資源 | 路徑 | 用途 |
|------|------|------|
| MRMOTEXT Extended 1.1 | `assets/tilesets/mrmotext/MRMOTEXT_EX.png` | 角色/敵人主要 tileset |
| MRMOTEXT x3 | `assets/tilesets/mrmotext/MRMOTEXT-x3.png` | 大型元素 tileset |
| MRMOTEXT 染色版（34色） | `assets/tilesets/mrmotext/colored/` | 顏色變體 |
| DungeonMode bitmap | `assets/tilesets/dungeonmode/dungeon-mode.png` | 地牢環境專用 tileset（16×16格，8×8px/tile） |
| DungeonMode 染色版（34色） | `assets/tilesets/dungeonmode/colored/` | 地牢環境顏色變體（與 MRMOTEXT 同調色盤） |
| VfxMix | `assets/vfxmix/` | 全套特效資源 |
| VfxMix 調色盤 | `assets/vfxmix/palette.pal` | 34色標準調色盤 |

---

## 📝 附錄 A：決策記錄

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
| 2026-06-12 | **攻擊輸入：左鍵=近戰，右鍵=遠程** | 比短按/長按更直覺，降低輸入錯誤率 | 用戶 |
| 2026-06-12 | **VFX：slash/spark/impact/death 四種特效** | VfxMix 現有素材直接利用，風格統一 | Designer |
| 2026-06-12 | **敵人死亡：縮放+淡出+死亡VFX** | 程式動畫比逐帧動畫更輕量且效果好 | Developer |
| 2026-06-13 | **近戰 3 擊 Combo（左→左反向→衝擊）** | 快速爽快型手感，參考 Hollow Knight；無 combo 冷卻 | 用戶 |
| 2026-06-13 | **Combo Buffer 0.3s（第一擊後窗口）** | 允許玩家節奏性連擊，不強制高頻點擊 | 用戶 |
| 2026-06-13 | **近戰方向只有前/後（_facing），不跟 8 方向** | 近戰應直覺跟隨移動方向，避免操作混亂 | 用戶 |
| 2026-06-13 | **移除 BoundaryWalls** | BoundaryWalls 從未生效，TileSet Physics Layer 是唯一碰撞策略 | Designer+Developer |
| 2026-06-14 | **導入 DungeonMode tileset** | 補充地牢環境所需特殊牆壁/門/地板圖形，與 MRMOTEXT 同為 8×8px 可共用染色流程 | 用戶 |
| 2026-06-14 | **DungeonMode 使用 34色調色盤** | 保持視覺風格統一，不引入第二套色票系統 | 用戶 |
| 2026-06-14 | **DungeonMode 不生成 x3 縮放版** | 環境磚塊統一使用 8px 原版，透過 Camera zoom 控制顯示大小 | 用戶 |
| 2026-06-14 | **area_0_room_02 LeftPortal 必須雙向連結 room_01（修正 BUG）** | LeftPortal 的 target_room_path 為空，導致無法返回 | Designer |
| 2026-06-14 | **Portal @export 改用 @export_file("*.tscn")** | Inspector 可直接用文件對話框選擇場景，降低手打路徑錯誤風險 | Designer |
| 2026-06-14 | **採用空洞騎士風 Walk-in 轉場（§10.11）** | 玩家出現在門口邊緣並帶初始方向速度，避免「瞬移割裂感」 | Designer |
| 2026-06-14 | **移除 game_world.tscn 中的預設靜態碰撞牆** | 在正式地圖階段由 PlatformLayer TileSet 每房間自行提供碰撞封閉後已屬冗餘 | Designer+Developer |
| 2026-06-14 | **地圖採用非程序化固定序列** | DungeonGenerator 僅按 AREA_0_ROOMS 陣列順序載入，不進行隨機化 | 用戶 |

---

## ❓ 附錄 B：待確認事項

> 以下問題需要用戶回答才能繼續設計：

1. **玩家顏色方案**：P1-P4 各自的正確顏色 HEX 值（目前 `apply_player_color()` 待填入）
2. **P3/P4 鍵盤映射**：P3/P4 的移動/跳躍/翻滾鍵位需要確認
3. **Boss 設計方向**：目前有任何 Boss 概念嗎？（boss.gd 腳本已存在骨架）
4. **音樂風格**：有任何偏好的音樂風格？
5. **角色形象**：§3.2 形象表格待填入（PixelLab 生成的角色設計）