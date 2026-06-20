# Implementation Plan — 彈力繩 + 移動手感 + 場景放大（GAP-035，2026-06-20）

## 範圍（5 部分，源自 GDD §2.3/9.1/9.4/9.5）

### A. 彈力繩自動拉近（換實作）— `wire_constraint.gd` + `player.gd`
- 換掉「繃緊才作用的彈簧」為**恆定朝錨點的彈性拉力**（always-pull elastic tether）。
- `wire_constraint.gd`：
  - `apply(pos, vel, delta)`：`dir = (anchor-pos).normalized()`；`pull = minf(stiffness*dist, max_accel)`；`vel += dir*pull*delta`；沿繩阻尼 `vel -= dir*(vel·dir)*clampf(damping*delta,0,1)`。
  - `max_length` 保留為**視覺參考**（= 初始距離，給 renderer/`tension_ratio`）；物理不再用它當門檻。
  - 移除 `reel_in`（自動拉近取代手動收線）；新增 `stiffness/damping/max_accel`。
- `player.gd`：
  - `_on_wire_anchor_ready`：設 `_wire.stiffness/damping/max_accel`、`setup()`。
  - `_apply_wire(delta)`：`velocity = _wire.apply(...)`；E 鍵改為「額外朝錨點加速」`velocity += dir*reel_boost*delta`。
  - 懸掛距離 ≈ `gravity/stiffness`；預設 `rope_stiffness=14`（≈70px）、`rope_damping=6`、`rope_max_accel=3500`、`reel_boost=2200`。
- Q 切斷、平台建立/解散、F 回收皆**不變**（沿用 `_cut_wire`、`needle_manager`）。

### B. 左右移動慣性 — `player.gd`
- `_apply_movement(delta)`（非繩上時）：`target = dir*move_speed`；`accel = is_on_floor() ? (dir!=0?ground_accel:ground_friction) : (dir!=0?air_accel:air_friction)`；`velocity.x = move_toward(velocity.x, target, accel*delta)`。
- 繩上時維持空中控制（`swing_accel`+`swing_air_drag`，GAP-034）。
- @export：`ground_accel=2200`、`ground_friction=2600`、`air_accel=1400`、`air_friction=900`。

### C. Jump buffer + Coyote + 可變跳躍 — `player.gd`
- 狀態：`_coyote_timer`、`_jump_buffer_timer`。@export：`coyote_time=0.1`、`jump_buffer_time=0.1`。
- `_unhandled_input`：跳鍵**按下** → `_jump_buffer_timer = jump_buffer_time`；跳鍵**放開**且 `velocity.y<0` → `velocity.y *= jump_cut`（可變跳，`jump_cut=0.45`）。
- `_physics_process`（move_and_slide 前）：
  - `is_on_floor()` → `_coyote_timer = coyote_time`，否則遞減。
  - `_jump_buffer_timer` 遞減；若 `>0` 且 `_coyote_timer>0` → 起跳（`velocity.y=-jump_velocity`，清兩計時器）。
- 移除舊 `_unhandled_input` 內 `is_on_floor` 直接起跳。

### D. Player 性能微調 — `player.gd`
- `move_speed` 200→**240**、`jump_velocity` 501→**540**（稍微，可再調）。

### E. 場景放大 + 外牆切齊 — `project.godot` + `scenes/MVP_Test.tscn`
- `project.godot`：`window/size` 960×540 → **1280×720**。
- `MVP_Test.tscn`：四面外牆重框 0..1280 / 0..720（16px 厚）：
  - Ground (640,712) 1280×16；Ceiling (640,8) 1280×16；WallLeft (8,360) 16×720；WallRight (1272,360) 16×720（+對應 ColorRect/Shape）。
  - 內部平台 A–E 與 Player 起點座標 ×4/3 等比放大，保留版面。
  - Camera2D limits → right=1280、bottom=720。
- 根因說明：外牆原本 960×540，視窗放大後不再框滿；統一改 1280×720 並讓外牆與相機界線一致。

## 不影響
- F 回收/優先級、提示 UI、平台 sag/drop-through、wire renderer（用 `max_length`/`anchor_pos` 視覺參考）、debug overlay。
- 不新增 class_name → 無需 --import。

## 風險與調校
- 繩手感（拉力/阻尼/上限）與移動手感（加速/摩擦/buffer/coyote）皆主觀 → 全開 @export 供即時調。
- 場景 .tscn 多座標編輯：逐一核對外牆框 = 0..1280/0..720、相機 limits 一致；commit 前跑 ERR-023 標頭檢查（pre-commit 自動）。

## 驗證計畫（QA）
- sensor 21/21、`--check-only` 0、run_project errors 空（含 .tscn 改動）。
- 手動：帶線針命中即被拉向錨點且彈性回彈；Q 可切；左右有加速慣性；落地前按跳會 buffer；離地後短時間仍可跳；放開跳鍵變矮跳；外牆四面與視窗切齊。
