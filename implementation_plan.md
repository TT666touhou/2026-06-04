# Implementation Plan — 繩索重做：Verlet 視覺 + 鐘擺物理（GAP-037，2026-06-20）

## 問題根因（詭異側向 S 彎曲）
`player._update_wire_renderer` 的擺錘分支以 `slack = max_length - dist` 呼叫 `_draw_catenary_line`，sag 方向是**垂直於繩**（`perp`）。繩近垂直時鬆弛量大 → 往側邊鼓出 → 截圖的 S 形假彎曲。視覺與物理（直線拉力）脫節。

## 技術選型（已研究）
- **採 Verlet integration 做繩**（CharacterBody2D 友善；CRope2D 等業界做法）。
- **不採 Joint2D**：需 RigidBody2D，會棄掉現有 CharacterBody2D 平台/移動/跳躍/慣性/鋼索平台實作，風險過高。

## 變更清單

### A. 新增 `scripts/verlet_rope.gd`（純資料，**不用 class_name**，由 player preload → 免 --import）
- `extends RefCounted`。`points/prev: PackedVector2Array`、`gravity=Vector2(0,980)`、`damping=0.98`、`iterations=10`。
- `init(start, end, count)`：沿 start→end 均佈 N 點。
- `update(start, end, total_length, delta)`：
  - 內部點 Verlet 積分（慣性*damping + 重力*dt²）。
  - 釘兩端 `points[0]=start`、`points[last]=end`。
  - 迭代距離約束（節長 = total_length/(N-1)）：每段把兩端各移半量、釘住的端點不動。
- 產出 `points` 給 Line2D 畫 → 自然下垂/繃緊變直。

### B. 改寫 `scripts/wire_constraint.gd`（鐘擺長度約束 + 拉近）
- 保留 `anchor_pos`、`max_length`(= 現繩長/擺盪半徑)、`tension_ratio()`（debug/renderer 用）。
- 新增 `min_length=24`、`auto_reel_speed=110`。
- `setup(pos, dist)`：`anchor_pos=pos; max_length=dist`。
- `auto_reel(delta)` / `reel(speed, delta)`：`max_length = max(min_length, max_length - spd*delta)`。
- `constrain(pos, velocity) -> Dictionary{pos, vel}`：
  - `dist ≤ max_length` 或 ~0 → 原樣返回（鬆弛自由落）。
  - 否則繃緊：`new_pos = anchor - dir*max_length`；`radial = vel·dir`；`if radial<0: vel -= dir*radial`（消除朝外速度，保留切向）→ 鐘擺。
- 移除舊 bungee 的 always-pull `apply()`/stiffness/damping/max_accel。

### C. `scripts/player.gd`
- @export 清理：移除 `rope_stiffness/rope_damping/rope_max_accel/reel_boost`；
  新增 `auto_reel_speed=110`、`min_rope_length=24`、`reel_speed=200`、`rope_segments=12`。保留 `swing_accel/swing_air_drag`。
- `const VerletRopeScript = preload("res://scripts/verlet_rope.gd")`；`var _verlet = null`。
- `_on_wire_anchor_ready`：set `_wire.min_length/auto_reel_speed`、`setup()`；`_verlet = VerletRopeScript.new(); _verlet.init(anchor_pos, global_position, rope_segments)`。
- `_apply_wire(delta)`：`_wire.auto_reel(delta)`；E → `_wire.reel(reel_speed,delta)`；`var r=_wire.constrain(global_position, velocity); global_position=r.pos; velocity=r.vel`。
- `_update_wire_renderer` 擺錘分支：改 `_verlet.update(anchor, global_position, _wire.max_length, delta_ish)` 後把 `_verlet.points` 寫入 `wire_renderer`（取代 `_draw_catenary_line`）。張力色仍由 `tension_ratio` 決定。
  - 註：renderer 在 `_physics_process` 後段呼叫，傳入固定 dt（用 `get_physics_process_delta_time()`）。
- 平台 renderer 維持 `_draw_catenary_line`（水平向下垂，正常，不動）。

## 不影響
- 平台建立/解散、sag/drop-through、F 回收/優先級、提示 UI、Q 斷線、debug overlay（用 `max_length`/`tension_ratio`）。
- 移動慣性/jump buffer/coyote（GAP-035）不動。
- 新針出界邊界（GAP-036）不動。

## 風險與驗證
- 位置夾鉗 + move_and_slide：開放空間擺盪穩定；撞牆由 move_and_slide 處理。
- Verlet 視覺需玩家實測（無側向彎曲、自然下垂/繃緊）。
- sensor 21/21、`--check-only` 0、run_project errors 空。`verlet_rope.gd` 無 class_name（preload）→ 免 --import。
