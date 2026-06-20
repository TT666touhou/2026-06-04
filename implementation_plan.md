# Implementation Plan — 彈性快速收繩+上甩連段 / 單按右鍵 / 針數5 / 驗證法改良（GAP-039，2026-06-20）

## A. 彈性快速收繩（上甩接平台連段）— `wire_constraint.gd` + `player.gd`
換掉 GAP-037 的鐘擺硬約束（夾位置 `constrain()`），改回**彈性 spring + 快速 auto-reel**（保留 GAP-037 的 Verlet 視覺）。
- `wire_constraint.gd`：
  - vars：`anchor_pos`、`max_length`（rest 長，Verlet 視覺也用）、`min_length=24`、`auto_reel_speed=320`(快)、`stiffness=40`、`damping=4`(低→彈力/保動能)、`max_accel=5000`。
  - `auto_reel/reel`：縮短 `max_length`（同前）。
  - `apply(pos, vel, delta) -> Vector2`：`dist>max_length` 時 `pull=min(stiffness*stretch, max_accel)` 朝錨點加速 + 沿繩阻尼；`dist<=max_length` 鬆弛不施力。移除 `constrain()`。
  - `tension_ratio()` 保留。
- `player.gd`：
  - exports：`auto_reel_speed=320`、`rope_stiffness=40`、`rope_damping=4`、`rope_max_accel=5000`、保留 `min_rope_length/reel_speed/swing_*`。
  - `_apply_wire`：`auto_reel` → E `reel` → `velocity = _wire.apply(...)`（取代 constrain 的位置夾鉗）。
  - `_on_wire_anchor_ready`：set `stiffness/damping/max_accel/auto_reel_speed/min_length`。
- **上甩連段**：朝上射針 → 快收繩 + 彈力 → 向上加速（上甩動能）；射第二針 → `get_wire_anchors()==2` 成平台、`_on_platform_created` 清 `_wire`（釋放）→ 玩家帶上甩動能站上平台。既有平台邏輯不動。

## B. 單按右鍵射帶線針 — `player.gd`
- `_unhandled_input` 滑鼠分流：左鍵 pressed → 攻擊針；**右鍵 pressed → 帶線針**（不再 hold+左鍵）。
- `_shoot_needle()` 改 `_shoot_needle(wire: bool)`；右鍵呼叫 `_shoot_needle(true)`、左鍵 `_shoot_needle(false)`。

## C. 針數 3→5 — `needle_manager.gd`
- `@export var max_needles: int = 3` → `5`（Player.tscn 未覆寫，改 script 即生效）。
- debug_overlay 顯示 `count: N / 3` → 改用 `max_needles` 動態（避免硬編碼 3）。

## D. 驗證方式改良（workflow.md，回應「實機驗證效果差/效率低」）
新增**驗證優先序**，以 headless 自動化測試為首選：
1. **Headless 自動化測試**（GUT 或 `godot --headless --script` extends SceneTree）— 首選：可重複、快、能斷言邏輯/數值，無需人工輸入。純函式/RefCounted（物理/狀態機）一律優先寫測試。
2. **暫時插樁 + run_project + get_debug_output** — 需實機真值（座標/碰撞/viewport）時；用完即還原。
3. **run_project 純開機** — 僅確認載入無錯，**不算行為驗證**。
4. **玩家手動實測** — 主觀手感。
- 改 `workflow.md §F` 使用規範區塊；`§I-C Rule 24`（GUT）改述；`§G-1` QA 路徑備註。

## E. 本次驗證（示範新方法）
- `tests/test_rope_gap039.gd`（headless）：
  - 彈性收繩**上甩**：錨點在玩家上方，跑 `auto_reel`+`apply` 數十步，斷言玩家**獲得朝上（朝錨點）速度** 且位置上移。
  - 彈力：`dist>max_length` 時 `apply` 使 `vel·dir(朝錨點) > 0`。
  - 針數：`NeedleManagerScript.new().max_needles == 5`。
- sensor 21/21、`--check-only` 0。run_project 僅作開機冒煙（非主驗證）。

## 不影響
- Verlet 視覺、平台建立/解散/sag、F 回收/優先級/提示 UI、Q 斷線、jump/inertia(GAP-035)、針出界(GAP-038)。
- 不新增 class_name（test 用 preload）→ 免 --import。
