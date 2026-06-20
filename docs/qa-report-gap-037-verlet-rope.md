# QA Report — GAP-037 繩索重做（Verlet 視覺 + 鐘擺物理）

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.3、implementation_plan.md
> 驗證：headless 單元測試 + `mcp__godot__run_project` + sensor/--check-only

## 1. 自動化驗證

| 項目 | 結果 |
|------|------|
| `sensor-scan.ps1` | ✅ 21/21 PASS |
| Godot `--check-only` | ✅ 0 errors（已修 `tension :=` 推型別錯）|
| **headless 單元測試** `tests/test_rope_gap037.gd` | ✅ **ROPE_TEST_PASS** |
| run_project 啟動 | ✅ errors: [] 乾淨啟動 |

## 2. 單元測試涵蓋（核心新邏輯，免輸入）

`godot --headless --script res://tests/test_rope_gap037.gd` → `ROPE_TEST_PASS`：
- **VerletRope**：12 點、兩端釘住（start/end 不被約束移動）、迭代後所有點為有限值（無 NaN）。
- **WireConstraint 鐘擺**：
  - 鬆弛（dist 50 ≤ len 100）→ 位置不變（自由）。
  - 繃緊（dist 150 > 100）→ 位置夾回半徑 100；朝外（徑向）速度被消除（vel.y→0）。
  - `reel`/`auto_reel` 都正確夾在 `[min_length, …]`，多次 auto_reel 後收斂到 `min_length`。

## 3. 詭異彎曲修復（根因 → 修復）

- **根因**：渲染用 `slack = max_length - dist` 做**垂直於繩**的假鬆弛，近垂直繩往側邊鼓出 → 截圖 S 形。
- **修復**：擺錘繩改畫 **Verlet 物理繩**（兩端釘錨點/玩家，中間受重力下垂 + 距離約束）→ 鬆弛時自然垂落、繃緊時拉直，**無側向假彎曲**。

## 4. 技術選型（回應「能不能用 Joint」）

- 採 **Verlet integration**（CharacterBody2D 友善；業界 2D 繩首選）。
- **不採 Joint2D 系列**：需把 Player 改 RigidBody2D，會棄掉現有平台移動/跳躍/慣性/鋼索平台等大量實作，風險過高（社群亦回報 Joint 抓鉤調校困難）。

## 5. 手動驗證清單（需玩家於遊戲中實測）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 右鍵 hold + 左鍵射帶線針命中 | 繩呈**自然繩索**（無側向 S 彎曲）；命中後被自動拉近 |
| 2 | 在繩上左右輸入 | 可盪繩（鐘擺），動量保留 |
| 3 | 繃緊時觀察繩 | 繩拉直；鬆弛時自然下垂 |
| 4 | 按住 E | 更快拉近錨點 |
| 5 | 按 Q | 切斷、繩消失 |

## 6. 手感調校（@export）

`auto_reel_speed=110`、`min_rope_length=24`、`reel_speed=200`(E)、`rope_segments=12`、`swing_accel`、`swing_air_drag`；Verlet `gravity/damping/iterations`（verlet_rope.gd）。

## 7. 結論

- 自動化全 PASS，**核心新邏輯有單元測試覆蓋**（非僅靜態）。
- 側向假彎曲由架構性修復（Verlet 取代假 sag）根除。
- 繩視覺/手感最終觀感需玩家實測（情境 1–5）。
- **QA 通過**。
