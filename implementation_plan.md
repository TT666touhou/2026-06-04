# Implementation Plan — 繩改回自然鐘擺 + 針速加快（GAP-040，2026-06-20）

## 問題
GAP-039 的彈簧 `apply()`（`velocity += dir*pull*delta`）**主動注入朝錨點的速度** → 用戶感覺「特別添加的詭異上甩動量」。要的是**自然**：動量只來自重力盪繩，繩只做距離約束。

## A. 繩物理改回自然鐘擺約束（revert GAP-039 spring → GAP-037 constrain）
- `wire_constraint.gd`：
  - 移除 `stiffness/damping/max_accel` 與彈簧 `apply()`。
  - 改 `constrain(player_pos, velocity) -> Dictionary{pos, vel}`：
    - `dist ≤ max_length` → 原樣返回（鬆弛自由落）。
    - 否則繃緊：`new_pos = anchor - dir*max_length`（夾半徑圓）；`radial = vel·dir`；`if radial < 0: vel -= dir*radial`（**只消除朝外速度，不注入任何速度**）。
  - 保留 `max_length/min_length/auto_reel_speed/auto_reel/reel/tension_ratio`。
  - **無速度注入** = 自然：動量純由重力擺盪；收繩(縮 max_length)時夾位置→角動量守恆自然加速擺盪。
- `player.gd`：
  - 移除 exports `rope_stiffness/rope_damping/rope_max_accel`；保留 `auto_reel_speed/min_rope_length/reel_speed/swing_*`。
  - `_apply_wire`：`auto_reel` → E `reel` → `var r = _wire.constrain(...); global_position = r.pos; velocity = r.vel`（取代彈簧 apply）。
  - `_on_wire_anchor_ready`：移除 set `stiffness/damping/max_accel`。
- Verlet 視覺不動（用 `max_length`/`tension_ratio`）。

## B. 針飛行速度加快
- `needle_projectile.gd`：`@export flight_speed 1200 → 2400`。
- 抗穿牆確認：step=40px/frame、raycast 前探 `step*1.2=48px` > 16px 牆厚 → 不穿牆。`max_travel=2400` 仍 > 場景對角線 ~1469，安全網 OK。

## C. 測試（新驗證法，更新 GAP-039 過時測試）
GAP-039 移除 spring `apply()`、改回 `constrain()` → `test_rope_gap039.gd` 的彈簧/上甩斷言過時。改寫該測試驗證**自然**特性：
- **無動量注入**：靜止玩家(vel=0)在繃緊距離 → `constrain` 後 `vel` 仍 ≈ 0（彈簧會給朝錨點速度，自然約束不會）。
- 繃緊夾位置到 `max_length`、消除朝外徑向、切向速度保留。
- reel 夾 min；`max_needles==5`。

## 驗證
- `tests/test_rope_gap040.gd`（取代 gap039）→ 斷言自然約束。`test_rope_gap037.gd` 仍 PASS（Verlet+reel）。
- sensor 21/21、`--check-only` 0、run_project 冒煙（非主驗證，依 §F 新優先序）。

## 不影響
- 單按右鍵輸入(GAP-039)、針數5、Verlet 視覺、平台、F 回收、jump/inertia、針出界(GAP-038)。
