# QA 報告：PlayerDust VFX 雙粒子系統

**日期**：2026-06-09  
**版本**：`feature/player1-base-setup` @ `cd7f5f8`  
**測試員**：QA Agent  

---

## 測試範圍

| 模組 | 測試類型 |
|---|---|
| player_dust.gd | 靜態審查 + 邊界值 |
| player1.gd | 觸發邏輯審查 |
| PlayerDust.tscn | 節點結構驗證 |
| player1.tscn | 場景完整性驗證 |

---

## QA-01 GDScript 語法驗證

```
godot --headless --check-only
```

| 檔案 | 結果 |
|---|---|
| scripts/vfx/player_dust.gd | ✅ PASS |
| scripts/player/player1.gd | ✅ PASS |

---

## QA-02 TSCN 結構驗證

### PlayerDust.tscn

| 檢查項 | 值 | 結果 |
|---|---|---|
| UID | `uid://c031iasmaeovd` | ✅ 與舊版相同（不影響現有引用） |
| BrickDebris 節點 | GPUParticles2D | ✅ |
| DustCloud 節點 | GPUParticles2D | ✅ |
| emitting | false | ✅ 不自動噴發 |
| one_shot | true | ✅ 一次性爆發 |
| local_coords | false | ✅ 粒子留在世界座標 |

### player1.tscn

| 檢查項 | 結果 |
|---|---|
| FloorCast (ShapeCast2D) 存在 | ✅ |
| FloorCast shape = RectangleShape2D(10,2) | ✅ |
| FloorCast position = (0,6) | ✅ |
| FloorCast target_position = (0,4) | ✅ |
| FloorCast collision_mask = 1 | ✅ |
| PlayerDust 實例存在 | ✅ |
| PlayerDust 引用 uid://c031iasmaeovd | ✅ |

---

## QA-03 API 簽名驗證

| 方法 | 簽名 | 結果 |
|---|---|---|
| emit_bricks | `(terrain_normal: Vector2, launch_velocity: Vector2, floor_color: Color) -> void` | ✅ |
| emit_dust | `(direction: float) -> void` | ✅ |
| _get_floor_color | `() -> Color` | ✅ |

---

## QA-04 觸發邏輯 × 設計文件對照

| 動作 | 觸發條件 | 效果 | 符合設計 |
|---|---|---|---|
| 地面普通跳 | `_was_on_floor == true` | `emit_bricks(UP, velocity, floor_color)` | ✅ |
| 蹬牆跳 | `is_on_wall_only() and _has_stamina()` | `emit_bricks(wall_normal, velocity, GRAY)` | ✅ |
| 地面翻滾 | `is_on_floor() and _has_stamina()` | `emit_bricks(UP, velocity, floor_color)` | ✅ |
| 二段跳 | — | 無 emit（空中無地形接觸） | ✅ |
| 落地（水平速度>10） | `not _was_on_floor and is_on_floor()` | `emit_dust(sign(velocity.x))` | ✅ |
| 落地（靜止/垂直） | `abs(velocity.x) <= 10` | 無效果 | ✅ |
| 翻滾落地 | — | 無 DustCloud（不符合條件） | ✅ |

---

## QA-05 地板顏色採樣邊界值

| 情境 | 預期行為 | 代碼驗證 |
|---|---|---|
| 無碰撞體 | fallback Color(0.65,0.65,0.65) | ✅ is_colliding() 判斷 |
| 碰撞體非 TileMapLayer | fallback | ✅ `if not col is TileMapLayer` |
| source_id < 0 | fallback | ✅ `if src_id < 0` |
| TileSetAtlasSource == null | fallback | ✅ `if source == null` |
| texture == null | fallback | ✅ `or source.texture == null` |
| get_image() == null（VRAM壓縮）| fallback | ✅ `if img == null` |
| 正常 TileMapLayer | 返回中心像素顏色 | ✅ |

---

## QA-06 節點引用完整性

| `@onready` 路徑 | 對應 player1.tscn 節點 | 結果 |
|---|---|---|
| `$StaminaBar` | ✅ 存在 | ✅ |
| `$PlayerDust` | ✅ 存在（新增） | ✅ |
| `$FloorCast` | ✅ 存在（新增） | ✅ |

---

## QA-07 清理確認

| 殘留物 | 是否存在 |
|---|---|
| `const _DUST_SCENE` preload | ❌ 已完全移除 |
| `dust_foot_offset` export | ❌ 已完全移除 |
| `_spawn_landing_dust()` 函數 | ❌ 已完全移除 |
| GroudFlash Sprite2D | ❌ 已從 PlayerDust.tscn 移除 |

---

## QA-08 粒子系統配置（腳本內部驗證）

### BrickDebris
| 參數 | 設定值 |
|---|---|
| Amount | 6（= brick_gray.png 幀數）|
| Lifetime | 0.45s |
| One Shot | true |
| Local Coords | false |
| AtlasTexture frames | 6 個預快取（24×22px 各幀）|
| Gravity | (0, 300, 0) |
| Spread | 30° |

### DustCloud  
| 參數 | 設定值 |
|---|---|
| Amount | 12 |
| Lifetime | 0.5s |
| One Shot | true |
| Local Coords | false |
| Color | #AAAAAA |
| Gravity | (0, 150, 0) |
| Spread | 55° |

---

## QA-09 已知限制與手動驗證項目

> 以下需要在 Godot Editor 執行後人工確認：

| 測試 ID | 測試步驟 | 預期結果 |
|---|---|---|
| MT-01 | 在地面按跳躍 | BrickDebris 磚塊向前下方飛出 |
| MT-02 | 靠牆按跳躍 | 灰色 BrickDebris 向牆壁方向飛出 |
| MT-03 | 在地面按 Shift 翻滾 | BrickDebris 向移動方向飛出 |
| MT-04 | 高速落地（落差 > 2 格） | DustCloud 灰塵雲向後飄起 |
| MT-05 | 原地落下 | **無** DustCloud（velocity.x < 10） |
| MT-06 | 站在彩色地板上跳躍 | BrickDebris modulate 應反映地板色 |
| MT-07 | 二段跳 | **無** BrickDebris |

---

## 總結

| 評分項 | 狀態 |
|---|---|
| 語法正確性 | ✅ PASS |
| 節點結構完整 | ✅ PASS |
| 觸發邏輯符合設計 | ✅ PASS |
| 邊界值處理 | ✅ PASS |
| 清理完整 | ✅ PASS |
| **整體結論** | **🟢 通過，建議合併** |

> ⚠️ MT-06（顏色採樣）取決於 TileSet Atlas 貼圖是否開啟 `compress/mode = Lossless`。
> 若 `get_image()` 返回 null，系統會自動降級為灰色，不會崩潰。
