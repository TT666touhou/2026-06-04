# 錯誤知識庫 — Error Knowledge Base
> **強制規則**：所有 Role 在修復錯誤後**必須更新此檔案**。
> **強制規則**：遇到任何錯誤，**必須先查詢此檔案**，再嘗試修復。
> 格式：`[日期] | [錯誤類型] | [錯誤訊息摘要] | [根本原因] | [修復方法]`

---

## 🔴 Critical — 必讀（曾造成重大損失）

| 日期 | 錯誤類型 | 錯誤訊息摘要 | 根本原因 | 修復方法 |
|------|---------|------------|---------|---------|
| 2026-06-12 | `.tscn` Parse Error | `Expected '['` 第一行即失敗 | PowerShell `Set-Content`/`Out-File` 預設寫入 **UTF-8 BOM** (`EF BB BF`)，Godot 解析器不支援 BOM | 用 `[System.IO.File]::WriteAllBytes` 或 `[System.IO.File]::WriteAllText($path, $text, [System.Text.Encoding]::UTF8)` 不帶 BOM；或 `Out-File -Encoding UTF8NoBOM`；hook 已有自動修復（`pre-commit` 規則 1b）|
| 2026-06-12 | GDScript 重複宣告 | `Variable "X" has the same name as a previously declared variable` (line N) | 同一個變數在 `@export var`（靠上）和 `var`（靠下）重複宣告，Godot 4 不允許 | 搜尋全檔所有 `player_prefix`（或該變數名）只保留一個宣告；若需要 `@export` 就移除無屬性的 `var` 版本 |
| 2026-06-12 | UID 未認識 | `Unrecognized UID: "uid://..."` + `Couldn't detect...` | 手工在 `.tscn` 第一行指定的 UID 字串，Godot 的 `.godot/uid_cache` 資料庫沒有記錄這個 UID | 移除 `.tscn` 第一行的 `uid=` 字段（改為 `[gd_scene format=4]`），或改用路徑（`res://...`）引用場景；Godot 首次載入時會自動生成 UID |
| 2026-06-12 | TileMap 資料損壞 | `Corrupted tile map data: tiles might be missing` | 跨 TileSet 複製 `tile_map_data = PackedByteArray(...)` —— 每個 TileSet 的 tile ID 映射不同，資料二進位不相容 | 移除 `.tscn` 中的 `tile_map_data`（讓 TileMapLayer 為空），由腳本動態載入；或在 Godot Editor 重新繪製地圖 |
| 2026-06-12 | `@onready` 節點找不到 | `Invalid get index 'X' on base 'null instance'` 在 `_ready()` | `@onready var X = $SomeNode` 中的 `SomeNode` 在 `.tscn` 中不存在或路徑拼錯 | 用 `get_node_or_null("SomeNode")` 取代 `$SomeNode` 並加 `assert(X != null, "X 必須存在")` 驗證；或確認 `.tscn` 有對應節點 |
| 2026-06-12 | Autoload 順序錯誤 | `get_node_or_null("/root/DebugBridge")` 在 DebugOverlay 中返回 null | Autoload 載入順序：`project.godot [autoload]` 決定順序，若 DebugBridge 在 DebugOverlay 之前宣告但使用 `_ready()` 時晚初始化，延遲取得節點 | `project.godot` 中的順序必須是 `NetworkManager → DebugOverlay → DebugBridge`；使用 `get_node_or_null` 延遲取得而非 `@onready` |

---

## 🟡 Warning — 常見陷阱

| 日期 | 錯誤類型 | 錯誤訊息摘要 | 根本原因 | 修復方法 |
|------|---------|------------|---------|---------|
| 2026-06-12 | `.uid` 檔案衝突 | Godot 啟動時 `player.gd` UID 不匹配 | `git` 操作後 Godot 重新生成 `.uid` 檔案，導致場景引用舊 UID | 在 `.gitignore` 加入 `*.uid`（已完成）；或每次 `git pull` 後重新在 Godot Editor 中開啟場景讓 Godot 自動修正引用 |
| 2026-06-12 | `player.gd` BOM | (同 Critical 第1條) 但出現在腳本而非場景 | 同上 | 同上，hook 自動修復 |
| 2026-06-12 | `multiplayer` 空指標 | `Invalid call. Nonexistent function 'is_server' on null` | 在 `_ready()` 中直接調用 `multiplayer.is_server()` 但 `MultiplayerAPI` 尚未設定 peer | 先用 `multiplayer.has_multiplayer_peer()` 確認有 peer 再調用其他方法 |
| 2026-06-12 | Godot `--check-only` 無法偵測 .tscn 錯誤 | `gw_err.log` 顯示腳本錯誤但 check 指令顯示通過 | `--check-only` 只驗證 GDScript，不完整載入場景 | 需要實際執行（不帶 `--check-only`）或用 `--headless --path <project>` 完整啟動才能發現 .tscn 問題 |
| 2026-06-12 | `AnimatableBody2D` 沒有碰撞 | 天花板/物理邊界沒有實際碰撞效果 | `AnimatableBody2D` 需要通過程式碼或動畫移動才會觸發碰撞，靜止時不阻擋 | 靜止的邊界牆/天花板改用 `StaticBody2D`；只有需要動態移動的平台才用 `AnimatableBody2D` |

---

## 🟢 Pattern — 已知最佳做法

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | 寫入 Godot 文件（.gd/.tscn/.tres）| 使用 `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))` 確保無 BOM |
| 2026-06-12 | 手動建立 `.tscn` | `[gd_scene format=4]`（不加 uid）+ `[ext_resource]` 只引用已存在的 UID；SubResource 定義必須在引用之前 |
| 2026-06-12 | 主場景設定 | `project.godot` 中用路徑 `res://scenes/level/game_world.tscn` 而非 UID，Godot 啟動後自動更新為 UID |
| 2026-06-12 | GDScript `@export var` vs `var` | 同一變數只宣告一次；需要 Inspector 可見用 `@export var`；私有狀態用 `var` 加 `_` 前綴 |
| 2026-06-12 | `multiplayer` 初始化 | 始終先 `has_multiplayer_peer()` 再呼叫 peer 相關 API；單機流程不需要 `ENetMultiplayerPeer` |
| 2026-06-12 | 玩家 group 追蹤 | `add_to_group("Players")` 在 `_ready()` 中執行；DebugBridge 和 MultiplayerCamera 都通過 `get_tree().get_nodes_in_group("Players")` 取得玩家 |
| 2026-06-12 | 相機 Limit Marker | CamLimit Marker2D 放在 MultiplayerCamera 的**子節點**下，NodePath 用相對路徑 `CamLimitTop` |
| 2026-06-12 | 多玩家輸入 | `player_prefix` 變數在 `@export_group("Multiplayer")` 下宣告；input action 格式為 `{prefix}move_left`，prefix 為 `""/"p1_"/"p2_"` 等 |
