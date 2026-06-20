# Implementation Plan — 大幅簡化：移除平台/Q/E/F + 右鍵按住盪繩（GAP-041，2026-06-20）

## 範圍
只保留盪繩抓鉤。移除平台、S 穿透、Q/E/F、回收提示 UI。盪繩改右鍵按住。

## A. `scripts/needle_manager.gd`（重寫，簡化）
- 移除：`wire_platform_scene`、`_current_platform/_platform_anchor_a/b`、`_wire_layer`、`platform_created` signal、`_try_create_platform`、`get_wire_anchors`、`get_retrieve_info/_retrieve_priority/_retrieve_label/try_retrieve`、`_remove_anchor` 的平台解散邏輯。
- 保留/新增：
  - `_wire_anchor`（唯一抓鉤錨）、`_wire_proj`（飛行中帶線針，供鬆開取消）。
  - `shoot_attack_needle/shoot_wire_needle`（受 `max_needles=5` 限制）；`_spawn_projectile`（WIRE 時記 `_wire_proj` + emit `wire_needle_launched`）。
  - `_on_embedded`：建錨點；WIRE 時 `anchor.wire=WireConstraint.new()`、`_wire_anchor=anchor`、`_wire_proj=null`、emit `wire_anchor_ready`。**無平台邏輯**。
  - `auto_retrieve_attack(player_pos)`：每幀由 player 呼叫；攻擊針在 `retrieve_radius` 內 → `_remove_anchor`（回收）。
  - `release_wire()`：鬆開右鍵；飛行中 `_wire_proj` → free + `_in_flight-1`；有 `_wire_anchor` → `_remove_anchor`（回收）。冪等。
  - `_remove_anchor`：erase + `needle_retrieved.emit` + `queue_free`。
- signals：`wire_anchor_ready`、`needle_retrieved`、`wire_needle_launched`。

## B. `scripts/player.gd`（重寫，簡化）
- 移除：所有 `_platform_*`、`_on_wire_platform`、`_drop_through_timer`、`_pickup_ui`、`PickupPromptScene`、`SAG_*`/`WIRE_SEGMENTS`/`DROP_THROUGH_TIME` consts、`_update_platform_sag`、`_draw_catenary_line`、`_on_platform_created`、`_cut_wire`、`_update_pickup_prompts`、`set_collision_mask_value(4,…)`、drop_through/cut_wire/reel_wire/retrieve_needle 輸入、彈簧/E 相關。
- 保留：移動慣性、jump buffer/coyote/可變跳、Verlet 視覺、aim pivot、自然鐘擺 `_apply_wire`（constrain）。
- 新增/改：
  - 輸入：左鍵 pressed → `_shoot_attack()`；右鍵 pressed → `_start_grapple()`；右鍵 released → `_release_grapple()`。
  - `_wire_held: bool`；`_start_grapple`：set held、若無 active wire/proj 則 `shoot_wire_needle`；`_release_grapple`：`needle_manager.release_wire()` + 清 `_wire/_anchor/_proj/_verlet`、隱藏 renderer。
  - `_on_wire_anchor_ready`：若 `not _wire_held`（已放開）→ `release_wire()` 不接；否則接上、建 Verlet。
  - `_physics_process`：…move_and_slide → `needle_manager.auto_retrieve_attack(global_position)` → renderer/aim。
  - `_update_wire_renderer`：有 wire → Verlet；飛行中 → 直線 player→proj；否則隱藏（移除平台分支）。

## C. 場景/檔案
- 刪除 `scripts/wire_platform.gd`、`scenes/WirePlatform.tscn`。
- `scenes/Player.tscn`：移除 `WirePlatform.tscn` 的 ext_resource(5_wpscene) 與 NeedleManager 的 `wire_platform_scene = ...` 賦值。
- 保留（未引用，無害）：`scenes/ui/*`(pickup UI)、project.godot 的 cut_wire/reel_wire/retrieve_needle/drop_through 輸入動作、MVP_Test 的 WireLayer 節點。

## D. 測試（headless，新驗證法）
- `tests/test_rope_gap041.gd`（取代 gap040 重點）：
  - `WireConstraint.constrain` 自然（無速度注入）— 沿用。
  - `NeedleManager`：`max_needles==5`；填入假 NeedleAnchor 攻擊錨點，`auto_retrieve_attack` 近的被回收、遠的留；`release_wire()` 空呼叫不崩。
- sensor 21/21、`--check-only` 0、run_project 冒煙。

## 風險
- 重寫 player/needle_manager 範圍大 → 逐項對照保留清單；--check-only + headless 測試守底。
- Player.tscn 移除 ext_resource 須同時移除賦值行，否則 broken ref（pre-commit .tscn 標頭檢查 + run_project 冒煙把關）。
