# QA Report — GAP-035 彈力繩 + 移動手感 + 場景放大

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.3/9.1/9.4/9.5、implementation_plan.md
> 驗證方式：`mcp__godot__run_project` + `get_debug_output`

## 1. 自動化驗證

| 項目 | 結果 |
|------|------|
| `sensor-scan.ps1` | ✅ 21/21 PASS |
| Godot `--check-only` | ✅ 0 errors |
| .tscn 標頭/UID | ✅ 28 檔 header 正確、無 UID 自引用 |
| run_project 啟動（1280×720） | ✅ **errors: [] / 無警告**，乾淨啟動 |
| 無 dangling 參考 | ✅ 已移除 `reel_speed`/`reel_in`，全專案無殘留引用 |

## 2. 各部分驗證（靜態）

- **A 彈力繩**：`WireConstraint.apply()` 改 always-pull（`pull = min(stiffness*dist, max_accel)` 朝錨點 + 沿繩阻尼）→ 命中即自動拉近、彈性回彈。`max_length` 保留為視覺參考，renderer/debug 不受影響。✅
- **B 移動慣性**：非繩上 `velocity.x = move_toward(velocity.x, dir*move_speed, rate*delta)`，地面/空中分用 accel/friction。✅
- **C 跳躍機制**：`_update_jump` 以 `is_on_floor()`(上一幀) 設 coyote；buffer 遞減；兩者 >0 才起跳；放開跳鍵 `velocity.y *= jump_cut`（可變跳）。✅
- **D 性能**：`move_speed` 240、`jump_velocity` 540。✅
- **E 場景**：window 1280×720；外牆 Ground(640,712)/Ceiling(640,8)/WallLeft(8,360)/WallRight(1272,360) + 對應 shape/ColorRect 框滿 0..1280/0..720；平台與起點 ×4/3；相機 limits 1280×720。座標驗算外牆四面與視窗切齊。✅

## 3. 手動驗證清單（需玩家於遊戲中實測）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 右鍵+左鍵射出帶線針命中地形 | 玩家**被自動彈性拉向錨點**、過衝後回彈（彈力繩）|
| 2 | 拉近過程按 Q | 立即切斷、脫離 |
| 3 | 按住 E | 更快朝錨點拉近 |
| 4 | 地面左右移動 | 有**加速起步 / 放開減速**的慣性手感 |
| 5 | 落地前一瞬間按跳 | 落地即自動跳（jump buffer）|
| 6 | 走出平台邊緣後極短時間內按跳 | 仍可跳（coyote time）|
| 7 | 點一下跳 vs 按住跳 | 點一下小跳、按住高跳（可變跳）|
| 8 | 觀察四面外牆 | 與視窗邊緣切齊、場景放大為 1280×720 |

## 4. 手感調校（@export，玩家可即時調）

繩：`rope_stiffness=14`(拉力/懸掛距離≈gravity/stiffness)、`rope_damping=6`(回彈收斂)、`rope_max_accel=3500`、`reel_boost=2200`(E)、`swing_accel`/`swing_air_drag`。
移動：`move_speed=240`、`jump_velocity=540`、`ground_accel/friction`、`air_accel/friction`、`coyote_time=0.1`、`jump_buffer_time=0.1`、`jump_cut=0.45`。

## 5. 結論

- 自動化全 PASS、乾淨啟動。
- 場景放大與外牆切齊為確定性修正（座標可證）。
- 繩/移動/跳躍手感屬主觀，需玩家實測（情境 1–8）；全部開放 @export 微調。
- **QA 通過**，無未解決 [GDD TODO]。
