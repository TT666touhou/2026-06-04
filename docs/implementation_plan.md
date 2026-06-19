# Implementation Plan — MVP Wire Physics System
> 維護者：Architect | 建立：2026-06-19 | SOP：§IMPL MVP Wire Physics System

---

## 1. 技術決策摘要（Ponytail 合規）

| 元件 | 方案 | Ponytail Rung | 理由 |
|------|------|--------------|------|
| Player 物理體 | `CharacterBody2D` | Rung 2 | Godot 內建平台標準 |
| Wire 繩索約束 | 速度投影約束（自訂 ~20 行） | Rung 5 | 符合「鬆-緊-E 收線」設計 |
| Wire 視覺 | `Line2D` 固定顏色 | Rung 2 | Godot 內建，MVP 不需張力色 |
| 針碰撞偵測 | `RayCast2D` | Rung 2 | 防穿牆，Godot 內建 |
| 鋼索平台 | 動態生成 `StaticBody2D` | Rung 5 | 兩針間建立一次性物體 |
| 驗證 | GUT 單元測試 + Debug Overlay | — | 邏輯與實機雙重驗證 |

---

## 2. 場景樹結構

```
scenes/
  MVP_Test.tscn          ← 測試場景（主入口）
  Player.tscn            ← CharacterBody2D 玩家
  NeedleProjectile.tscn  ← Node2D 針（飛行中）
  NeedleAnchor.tscn      ← Node2D 針（插入地形後的錨點）
  WirePlatform.tscn      ← StaticBody2D（兩針間動態生成）

scripts/
  player.gd              ← 玩家控制、跳躍、wire 輸入
  needle_manager.gd      ← 持有數量追蹤（最多 3 根）
  needle_projectile.gd   ← 飛行邏輯 + RayCast2D 嵌入
  needle_anchor.gd       ← 錨點邏輯（供 wire 掛鉤、F 回收）
  wire_constraint.gd     ← 純約束邏輯（無 Node 繼承，class_name WireConstraint）
  wire_renderer.gd       ← Line2D 更新（依 anchor 位置）
  wire_platform.gd       ← 動態 StaticBody2D 控制

tests/
  test_wire_constraint.gd  ← GUT：純數學邏輯驗證
  test_needle_manager.gd   ← GUT：持有數量上限驗證
```

---

## 3. MVP_Test.tscn 場景樹

```
MVP_Test (Node2D)
├── World (Node2D)
│   ├── Ground (StaticBody2D)
│   │   ├── ColorRect [32×480px, bottom]
│   │   └── CollisionShape2D [RectangleShape2D]
│   ├── Platform_A (StaticBody2D)   ← 測試用平台
│   ├── Platform_B (StaticBody2D)
│   └── NeedleLayer (Node2D)        ← 所有針生成到此
├── Player (CharacterBody2D)        ← instance of Player.tscn
├── WireLayer (Node2D)              ← WirePlatform 生成到此
└── DebugOverlay (CanvasLayer)
    └── DebugPanel (PanelContainer)
        └── DebugLabel (Label)      ← 顯示即時物理數據
```

---

## 4. Player.tscn 場景樹

```
Player (CharacterBody2D)
├── Body (ColorRect [32×64])
├── CollisionShape2D [RectangleShape2D 32×64]
├── AimPivot (Node2D)           ← 跟隨滑鼠旋轉
│   └── ThrowOrigin (Marker2D)  ← 針生成點
├── WireRenderer (Line2D)       ← 顯示 player → anchor 的線
└── Scripts: player.gd, needle_manager.gd
```

---

## 5. Wire 約束核心邏輯（wire_constraint.gd）

```gdscript
# wire_constraint.gd
# ponytail: rung=5 — one-liner core + minimal wrapper (~25 lines)
class_name WireConstraint

var anchor_pos: Vector2      # 針錨點世界座標
var max_length: float        # 最大允許長度（E 鍵縮短）
var slack: float = 10.0      # 初始鬆弛量（比投擲距離稍長）

func apply(player_pos: Vector2, velocity: Vector2, delta: float) -> Vector2:
    var to_anchor := anchor_pos - player_pos
    var dist := to_anchor.length()
    if dist <= max_length:
        return velocity   # 鬆弛：不干涉

    # 繃緊：移除「遠離錨點」的速度分量 → 剩餘切線速度 = 鐘擺
    var rope_dir := to_anchor.normalized()
    var radial := velocity.dot(rope_dir)
    if radial < 0.0:
        velocity -= rope_dir * radial

    # 位置修正：不超過 max_length
    # （由 player.gd 在套用後執行）
    return velocity

func reel_in(speed: float, delta: float) -> void:
    max_length = max(MIN_LENGTH, max_length - speed * delta)

func tension_ratio(player_pos: Vector2) -> float:
    return (anchor_pos - player_pos).length() / max_length

const MIN_LENGTH := 20.0
```

---

## 6. Player 核心腳本（player.gd）— @export 參數清單

```gdscript
# player.gd — 所有魔術數字均為 @export，無硬編碼
# ponytail: rung=2+5 (CharacterBody2D + velocity projection)

@export var move_speed: float = 200.0        # px/s 水平速度
@export var jump_velocity: float = 501.0     # px/s 起跳速度（對應 128px 高）
@export var gravity: float = 980.0           # px/s²
@export var reel_speed: float = 100.0        # px/s E 鍵收線速度
@export var wire_slack: float = 10.0         # px 初始鬆弛量
```

---

## 7. Needle 系統（needle_manager.gd + needle_projectile.gd）

**NeedleManager（@export）：**
```gdscript
@export var max_needles: int = 3
@export var retrieve_radius: float = 30.0   # F 鍵回收範圍（px）
```

**NeedleProjectile 飛行邏輯：**
- `flight_speed: float = 600.0`（@export）
- 每幀：`position += direction * flight_speed * delta`
- RayCast2D 從上一幀位置射向本幀位置
- 碰到 PhysicsBody2D → 呼叫 `embed(collision_point, collider)`
- embed 後：停止移動，通知 NeedleManager 記錄錨點

---

## 8. WirePlatform（動態生成）

當 NeedleManager 偵測到「第二根帶線針」插入時：
1. 計算兩針座標 A, B
2. 在 `WireLayer` 生成 `WirePlatform` 節點
3. `StaticBody2D` 位置 = 兩針中點
4. `RectangleShape2D` 長度 = `A.distance_to(B)`，旋轉 = `A.angle_to_point(B)`
5. 設定為單向平台（`one_way_collision = true`）

回收任一針（F 鍵）：
- 呼叫 `WirePlatform.dissolve()`
- 剩餘針自動成為 WireConstraint 錨點

---

## 9. Debug Overlay 輸出欄位（DebugLabel）

```
[Wire]
  max_length:   142.3 px
  dist:         138.7 px
  tension:       0.97  ← 接近 1 = 即將繃緊
  state:         TAUT

[Player]
  velocity:     (200.0, -87.3)
  on_floor:     false

[Needles]
  count:        2 / 3
  #0 type:      WIRE_ANCHOR
  #1 type:      WIRE_ANCHOR
```

---

## 10. GUT 測試範圍（tests/）

| 測試項目 | 驗證點 |
|---------|-------|
| `test_wire_constraint.gd` | 鬆弛時 velocity 不變；繃緊時移除遠離分量；E 收線縮短 max_length |
| `test_needle_manager.gd` | 超過 3 根時拒絕；F 回收後計數正確；wire 針轉 anchor 正確 |

---

## 11. 模組依賴圖

```
player.gd
  ├── uses: WireConstraint (class)
  ├── reads: NeedleManager.get_active_anchors()
  └── reads: NeedleManager.needle_count

needle_manager.gd
  ├── spawns: NeedleProjectile
  ├── spawns: WirePlatform (when 2nd wire needle lands)
  └── signals: needle_retrieved(needle), wire_platform_dissolved()

wire_constraint.gd
  └── pure logic (no node inheritance, no signals)
```

---

## 12. 實作順序（Developer 參考）

1. `wire_constraint.gd` — 純邏輯，可先單獨用 GUT 驗證
2. `player.gd` — 基礎移動（不含 wire），確認 WASD 跳躍正確
3. `needle_projectile.gd` + `needle_manager.gd` — 投擲、嵌入、回收
4. Wire 整合：player 加入 WireConstraint 呼叫
5. `wire_platform.gd` — 兩針平台
6. `debug_overlay.gd` — Debug 面板
7. GUT 測試補齊
