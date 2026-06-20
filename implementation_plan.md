# Implementation Plan — 回收提示 UI（GAP-033，2026-06-20）

## 目標（源自 GDD §2.5）
在「當前可回收」的鋼針上方顯示世界座標文字標籤（`[F] 類型`），F 實際會收的那根高亮、其餘暗色，讓玩家確認回收目標（尤其平台針）。UI 架構可復用、後期可加 tween。

## 新增資源（資料夾已存在：`scripts/ui/`、`scenes/ui/`）

### A. 通用世界文字標籤（可復用元件）
- `scripts/ui/world_label.gd`（`class_name WorldLabel`，extends `Node2D`）
  - `set_content(text, color)`：設定 Label 文字與顏色
  - `follow(world_pos)`：將自身移到 `world_pos + world_offset`（`@export var world_offset := Vector2(0,-22)`）
  - `show_prompt()` / `hide_prompt()`：切換顯示；hidden→visible 時觸發 `play_appear()`（內部 `_active` 旗標避免每幀重觸發）
  - `play_appear()`：scale 0.7→1 + modulate.a 0→1 的小 tween（**這是後期擴充點**，可換成更花俏的效果而不動呼叫端）
- `scenes/ui/world_label.tscn`：`WorldLabel`(Node2D + script) → `Label`(置中、font_size 14、黑色 outline 提升可讀性)

### B. 提示控制器
- `scripts/ui/pickup_prompt_ui.gd`（`class_name PickupPromptUI`，extends `Node2D`）
  - `preload` world_label.tscn；維護 `WorldLabel` 物件池
  - `update_prompts(candidates: Array, target: Node)`：依候選數量擴充池，逐一 `set_content`+`follow`+`show_prompt`；多餘的 `hide_prompt`
  - 目標色 `target_color`、其餘 `other_color`（@export，便於後期主題化）
- `scenes/ui/pickup_prompt_ui.tscn`：`PickupPromptUI`(Node2D + script)

## 修改

### C. `scripts/needle_manager.gd`（DRY：單一回收邏輯來源）
- 新增 `get_retrieve_info(player_pos, connected_anchor=null) -> Dictionary`
  回傳 `{ "candidates": Array[{anchor,label,priority}], "target": Node }`，沿用既有優先級/距離規則。
- 新增 `_retrieve_label(anchor, is_platform, is_player_wire) -> String`：攻擊針→`[F] 攻擊針`、平台→`[F] 平台針`、相連→`[F] 擺錘針`、其餘→`[F] 鋼針`。
- `try_retrieve()` 改為呼叫 `get_retrieve_info()` 取 `target` 後 `_remove_anchor()`（行為不變，僅去重）。

### D. `scripts/player.gd`
- `_ready()`：`preload` pickup_prompt_ui.tscn、instantiate、`add_child`（純程式碼整合，**不改 Player.tscn**，沿用既有 `_platform_renderer` 程式碼建立慣例）。
- `_physics_process()` 末端呼叫 `_update_pickup_prompts()`：
  取 `needle_manager.get_retrieve_info(global_position, _wire_anchor)` → `_pickup_ui.update_prompts(info.candidates, info.target)`。

## 設計理由
- 兩層拆分（WorldLabel 元件 + 控制器）= 用戶要求的「可復用、可後期加 tween」結構；WorldLabel 也可用於傷害數字等。
- 世界座標 Node2D 標籤：相機跟隨玩家時自動正確定位，無需 world→screen 投影。
- needle_manager 統一回收資訊來源，UI 與實際 F 行為永遠一致（避免兩套邏輯漂移）。

## 不影響的既有功能
- try_retrieve 對外行為不變；_cut_wire、平台、sag、wire renderer、E 收線全不動。Player.tscn 不變。

## 已知簡化（後期可優化）
- 標籤物件池以索引對應候選；候選增減時可能短暫換位（針數 ≤3，影響極小）。後期可改以 anchor 身分對應 + tween 過場。

## 驗證計畫（QA）
- sensor-scan 21/21、`--check-only` 0 errors（Developer commit 自動）。
- run_project + get_debug_output：乾淨啟動無錯誤/警告。
- 手動：靠近平台針應看到亮色 `[F] 平台針`；攻擊針在旁時亮色移到攻擊針（驗證 target 高亮邏輯）。
