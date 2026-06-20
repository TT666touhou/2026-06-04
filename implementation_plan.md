# Implementation Plan — Q 斷線 / F 優先級回收（GAP-032，2026-06-20）

## 目標（源自 GDD §2.4）
1. **Q（cut_wire）** 只切斷「當前 active 擺錘線」；已成平台（無 active 擺錘）時 Q 無作用，且不影響平台狀態。
2. **F（retrieve_needle）** 依優先級回收：無牽線針(攻擊) > 與玩家相連針(擺錘) > 平台端點針。
3. 與玩家相連針**不限距離**可回收；其他針需在 `retrieve_radius` 內。同優先級取最近。

## 現況分析
- `player._cut_wire()`：目前會清掉 `_wire/_wire_anchor` **以及** `_platform_a/_platform_b/_platform_slack` 並隱藏平台 renderer → 等於 Q 也「切斷」平台連結。**不符新設計**。
- `needle_manager.try_retrieve(player_pos)`：目前對 `_anchors` 依陣列順序取第一個在半徑內者，**無優先級**，且無法區分「與玩家相連」的錨點（該資訊只存在 player `_wire_anchor`）。
- 平台端點資訊在 needle_manager：`_platform_anchor_a/_platform_anchor_b`；攻擊針判斷：`anchor.type == _ANCHOR_ATTACK`。

## 變更清單

### A. `scripts/player.gd`
1. `_cut_wire()` 改為：僅當 `_wire != null and _wire_anchor != null` 時清 `_wire/_wire_anchor` 並隱藏 `wire_renderer`；**不再觸碰** `_platform_*` 與平台 renderer。無 active 擺錘時直接 return（Q 無作用）。
2. `_unhandled_input` 中 retrieve 呼叫改為傳入當前擺錘錨點：
   `needle_manager.try_retrieve(global_position, _wire_anchor)`

### B. `scripts/needle_manager.gd`
1. `try_retrieve(player_pos: Vector2, connected_anchor: Node = null)`：
   - 遍歷 `_anchors`，對每個有效錨點計算：
     - `is_connected = anchor == connected_anchor`
     - `is_platform = anchor == _platform_anchor_a or anchor == _platform_anchor_b`
     - `dist = anchor.global_position.distance_to(player_pos)`
     - `in_range = is_connected or dist <= retrieve_radius`（相連針不限距離）
   - 在 `in_range` 候選中，依 `_retrieve_priority()`（小=先）選出，最後以 `dist` 破平手。
   - 選到 → `_remove_anchor(best)`（沿用既有平台解散 / GAP-029 轉擺錘邏輯）。
2. 新增 `_retrieve_priority(anchor, is_connected, is_platform) -> int`：
   - 攻擊針（`type == _ANCHOR_ATTACK`）→ 0
   - 平台端點（`is_platform`）→ 2
   - 其餘 wire 針（含相連針與脫離後的孤兒 wire 針）→ 1

## 邊界情境
- **Q 切斷第三針擺錘**：player 清擺錘狀態，該 wire 針成孤兒（仍在 `_anchors`，優先級 1），平台不受影響。
- **平台存在 + 按 F（不靠近任何針）**：平台端點不在半徑內而跳過；若有 active 擺錘（第三針）則回收之，否則無動作。
- **平台端點 + 旁邊有攻擊針**：攻擊針優先級 0 先被收，不會誤拆平台。

## 不影響的既有功能
- `shoot_attack/wire_needle`、平台建立 `_try_create_platform`、`_remove_anchor` 的平台解散與 wire 轉擺錘、sag/drop-through、wire renderer 優先序、E 收線 全部不動。

## 驗證計畫（QA）
- run_project + get_debug_output，手動/腳本驗證：
  1. 擺錘中 Q → 線斷、針留、平台旗標不變
  2. 平台模式 Q → 無作用
  3. F 在攻擊針與相連針同在 → 先收攻擊針
  4. F 無攻擊針時 → 收相連擺錘針（不限距離）
  5. F 靠近平台端點且無更高優先 → 收端點、平台解散、另一端轉擺錘
- sensor-scan.ps1 21/21 PASS（auto on Developer commit）
