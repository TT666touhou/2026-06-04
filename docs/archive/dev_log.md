# 📔 開發日誌 (dev_log.md)
> 所有 Developer 工作的記錄。每次工作結束後必須追加一條記錄。
> 格式：`### [YYYY-MM-DD HH:MM] [工作摘要]`

---

### 2026-06-12 Phase 1 多人基礎系統實作

- **實作了什麼**：
  - `debug_overlay.gd` — F3 Debug Overlay，顯示所有玩家狀態（位置/速度/HP/網路）
  - `debug_bridge.gd` — AI感知橋，每秒寫出 `user://debug_state.json`
  - `multiplayer_camera.gd` — 多人相機，追蹤所有玩家中心，動態縮放
  - `game_world.gd` — 主遊戲場景控制器，啟動參數解析與玩家生成
  - `launch_multiplay.ps1` — 一鍵多實例啟動器
  - `player.gd` 修改：加入 `player_prefix`、`_enter_tree` authority、`apply_player_color`、移除個人 Camera2D
  - `project.godot` 更新：加入 DebugOverlay/DebugBridge autoload，p1_/p2_ 輸入動作
  - 所有 `test/*.gd` 修正：改為 `extends "res://addons/gut/test.gd"`

- **遇到什麼問題**：
  - `debug_overlay.gd`：`DebugBridge` 在 autoload 需用 `/root/` 路徑呼叫
  - 型別推斷問題：多個地方 `:=` 無法推斷型別（ternary、get()）
  - `game_world.gd`：`_camera` onready 未使用
  - GutTest 找不到：需改為明確路徑繼承

- **怎麼解決的**：
  - 用 `get_node_or_null("/root/DebugBridge")` 替代直接呼叫
  - 所有模糊型別改為明確標注（`: Vector2`、`: String`、`: Error`）
  - 移除未使用的 `_camera` onready
  - 批次修復所有測試文件繼承

- **靜態錯誤清零了嗎**：✅（待 Godot check-only 驗證）
- **DebugBridge JSON 驗證了嗎**：⏳ 待執行遊戲驗證
- **交給 Reviewer 了嗎**：❌（Phase 1 尚未完整）
- **下次應該注意的事**：
  - Godot `--check-only` 在 headless 模式可能啟動遊戲邏輯，需設 timeout
  - ternary 右側不確定型別時絕對不用 `:=`
  - autoload 之間互相呼叫必須用 `/root/` 路徑
