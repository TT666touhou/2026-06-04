# Implementation Plan — 統一回收距離 + 彈性繩物理（GAP-034，2026-06-20）

## 目標（源自 GDD §2.3/2.4/2.5）
1. 修正撿不到平台針：回收半徑太小（量測自玩家中心，腳邊針 ≥32px）。
2. 所有針一律需在回收半徑內（取消擺錘針「不限距離」）。
3. 繩子改為**彈性 spring-damper**，保留擺盪動量，達成 GDD「鐘擺物理 + 物理感」。

## 根因
- Player collision 32×64、中心在原點 → 腳在 +32px。`retrieve_radius=30` 量測自中心，腳邊/平台面的針恆 >30px → 撿不到。
- `player._apply_movement()` 每幀 `velocity.x = dir*move_speed` → 殺掉擺盪水平動量（詭異感主因）。
- `WireConstraint.apply()` 為硬性速度截斷（taut 時直接刪除徑向速度）→ 無彈性、生硬。

## 變更清單

### A. `scripts/needle_manager.gd`（Part 1+2）
- `@export var retrieve_radius` 預設 `30.0 → 60.0`（Player.tscn 未覆寫此值，改 script 預設即生效）。
- `get_retrieve_info()`：距離過濾改為**統一** `if dist > retrieve_radius: continue`（移除 `is_player_wire` 的不限距離例外）。`connected_anchor` 仍用於優先級與標籤。

### B. `scripts/wire_constraint.gd`（Part 3 — 彈性繩）
- 保留 property 名 `anchor_pos`、`max_length`（= 自然長度/rest length）、`slack`，避免動到 renderer/debug。
- 新增 `var stiffness: float = 80.0`、`var damping: float = 9.0`。
- `apply(player_pos, velocity, delta)`：
  - `dist ≤ max_length` → 鬆弛，原速度返回（純重力自由落）。
  - `dist > max_length` → 拉伸量 `stretch = dist - max_length`；
    - 彈簧：`velocity += rope_dir * (stiffness * stretch * delta)`（朝錨點）。
    - 阻尼：`radial = velocity.dot(rope_dir)`；`velocity -= rope_dir * (radial * clampf(damping*delta,0,1))`（吸收沿繩振盪，保留切向擺盪）。
- `reel_in()` 不變（縮短 `max_length`，由彈簧彈性拉近）。`tension_ratio()` 不變。

### C. `scripts/player.gd`（Part 3 — 整合）
- 新增 @export：`swing_accel=500.0`、`swing_air_drag=60.0`、`rope_stiffness=80.0`、`rope_damping=9.0`。
- `_apply_movement(delta)`（改帶 delta）：
  - 在繩上（`_wire != null`）：`velocity.x += dir * swing_accel * delta`；`velocity.x = move_toward(velocity.x, 0, swing_air_drag*delta)`（不再硬覆寫，保留擺盪動量 + 輕微空氣阻力收斂）。
  - 不在繩上：`velocity.x = dir * move_speed`（原行為）。
- `_apply_wire(delta)`：移除 E 鍵的手動位置位移（lines 89-93）；改 `velocity = _wire.apply(global_position, velocity, delta)`。
- `_on_wire_anchor_ready()`：set `_wire.stiffness = rope_stiffness`、`_wire.damping = rope_damping` 後再 `setup()`。
- `_physics_process()`：`_apply_movement(delta)`。

## 不影響
- 回收優先級邏輯、Q 斷線、平台建立/解散、sag、wire renderer（用 `max_length`/`anchor_pos` 不變）、debug overlay、GAP-033 提示 UI（同源 get_retrieve_info）。
- 不新增 class_name → 無需 --import 重建快取（沿用 GAP-033 教訓）。

## 風險與調校
- 繩子手感需玩家實測微調（4 個 @export 已開放）。預設 stiffness=80/damping=9：硬落時可見彈性拉伸（~60-90px）後阻尼回穩。
- 撿針半徑 60px：足夠涵蓋腳邊針，又不至於太遠誤撿。

## 驗證計畫（QA）
- sensor 21/21、`--check-only` 0、run_project errors 空。
- 手動：靠近平台針出現 `[F] 平台針` 且可撿（半徑修正）；遠處擺錘針按 F 無效（需靠近）；盪繩保留動量、繩有彈性回彈。
