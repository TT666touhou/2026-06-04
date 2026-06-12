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
| 2026-06-12 | 多玩家輸入 | `player_prefix` 變數在 `@export_group("Multiplayer")` 下宣告；input action 格式為 `{prefix}move_left`，prefix 為 `""/"p1_/"p2_"` 等 |
| 2026-06-12 | 攻擊系統設計 | 短按 < 0.3s = 近戰 (`_perform_melee_attack`)；長按 >= 0.3s = 遠程 (`_fire_bullet`)；用 `_attack_hold_timer` 計時；翻滾時禁止攻擊 |
| 2026-06-12 | Rogue-lite 房間生成 | `DungeonGenerator` 用 `class_name DungeonGenerator`；GameWorld 的 `@onready var _dungeon: Node`（不能用 DungeonGenerator 型別因前向引用問題）；`advance_room()` 回傳 `String`，明確宣告 `var x: String = _dungeon.advance_room()` |

---

## Phase 1.5+3 新錯誤記錄（2026-06-12）

| 日期 | 錯誤類型 | 錯誤訊息摘要 | 根本原因 | 修復方法 |
|------|---------|------------|---------|---------| 
| 2026-06-12 | GDScript 型別推斷 | `Cannot infer the type of "X" variable` | `Array.duplicate()` 回傳 `Array`（非 `Array[String]`），`_dungeon.advance_room()` 回傳 `Variant`（因 _dungeon 是 Node 型別）；三元運算式 `A if cond else B` 若兩邊型別不同也無法推斷 | 明確標注型別：`var x: String = ...`；對 Array 用 `for p: String in CONST: arr.append(p)` 填入 `Array[String]` |
| 2026-06-12 | `class_name` 前向引用 | `Could not find type "DungeonGenerator" in the current scope` 在 game_world.gd | Godot `--check-only` 處理 `class_name` 跨腳本引用時有順序問題 | 在 GameWorld 中用 `Node` 而非 `DungeonGenerator` 型別，用 `.has_method()` 確認再呼叫 |
| 2026-06-12 | multi_replace 插入失敗 | Export 群組未被插入 | `multi_replace_file_content` 的 chunk 對應的行範圍太大或 TargetContent 有多處匹配時，靜默失敗 | 修複方案：改用 `replace_file_content`，或將插入 chunk 縮小到精確的 2-3 行範圍；插入後立即用 `view_file` 確認 |
| 2026-06-12 | GDScript 型別推斷 | `Cannot infer the type of "X" variable` | `Array.duplicate()` 回傳 `Array`（非 `Array[String]`），`_dungeon.advance_room()` 回傳 `Variant`（因 _dungeon 是 Node 型別）；三元運算式 `A if cond else B` 若兩邊型別不同也無法推斷 | 明確標注型別：`var x: String = ...`；對 Array 用 `for p: String in CONST: arr.append(p)` 填入 `Array[String]` |
| 2026-06-12 | `class_name` 前向引用 | `Could not find type "DungeonGenerator" in the current scope` 在 game_world.gd | Godot `--check-only` 處理 `class_name` 跨腳本引用時有順序問題 | 在 GameWorld 中用 `Node` 而非 `DungeonGenerator` 型別，用 `.has_method()` 確認再呼叫 |
| 2026-06-12 | multi_replace 插入失敗 | Export 群組未被插入 | `multi_replace_file_content` 的 chunk 對應的行範圍太大或 TargetContent 有多處匹配時，靜默失敗 | 修複方案：改用 `replace_file_content`，或將插入 chunk 縮小到精確的 2-3 行範圍；插入後立即用 `view_file` 確認 |
| 2026-06-12 | InputMap action 不存在 | `The InputMap action "attack" doesn't exist. Did you mean "p1_attack"?` — 每幀爆錯 | 單機 `_start_solo()` 設定 `player_prefix = ""`，導致 `"" + "attack" = "attack"` 不在 Input Map（只有 `p1_attack`, `p2_attack` 等）| **雙重修復**：1) `_start_solo()` 改為 `player_prefix = "p1_"`；2) `_handle_attack()` 加入 `if not InputMap.has_action(action_name): return` 守衛，防禦性設計 |

---

## 🔴 2026-06-12 17:24 — 控制台截圖 28 錯誤事件（ERR-001/002/003）

### ERR-001 | Physics Flush 崩潰（28次重複）
- **錯誤訊息**：`game_world.gd:235 @ _load_room_scene(): Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.`
- **根本原因**：`_on_body_entered`（物理 callback）→ `_check_transition` → `_trigger_transition` → `game_world.load_next_room()` → `_load_room_scene()` → `add_child()`。Godot 4 **禁止**在物理查詢刷新期修改場景樹。重複28次是因為無防重入守衛，玩家每幀持續觸發 body_entered。
- **修復**：
  1. `room_transition.gd` → `game_world.call_deferred("load_next_room")` 取代直接呼叫
  2. `game_world.gd` → 加入 `_is_loading_room` bool 防重入守衛
- **責任 ROLE**：Developer（主責）、Reviewer（次責）、QA（末責）
- **為何被忽略**：靜態 `--check-only` 不能偵測執行時期物理 callback 違規；所有 ROLE 都只跑靜態驗證，未親自觸發房間切換

### ERR-002 | Narrowing Conversion（float→int）
- **錯誤訊息**：`GDScript::reload: Narrowing conversion (float is converted to int and loses precision)`
- **根本原因**：`multiplayer_camera.gd` 用 `int(lim_top.global_position.y)` 賦值給 `Camera2D.limit_top`（int 屬性），`global_position.y` 是 float
- **修復**：改用 `roundi()` —— Godot 4 推薦的 float→int 轉換
- **責任 ROLE**：Developer

### ERR-003 | Ternary Not Mutually Compatible
- **錯誤訊息**：`GDScript::reload: Values of the ternary operator are not mutually compatible`
- **根本原因**：同上，三元運算符 `int(x) if cond else -10_000_000` 的型別推斷問題
- **修復**：展開為 if/else 區塊，每個分支明確賦值
- **責任 ROLE**：Developer

---

## 🟢 新增 PATTERN（2026-06-12 事件後）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | 物理 callback 中觸發場景切換 | **絕對禁止**在 `_on_body_entered`/`_on_area_entered` 中直接呼叫 `add_child()`/`queue_free()`/`load_next_room()`；必須用 `call_deferred()` |
| 2026-06-12 | float→int 轉換 | 使用 `roundi()` / `floori()` / `ceili()` 而非 `int()`；避免 narrowing conversion 警告 |
| 2026-06-12 | GDScript 三元運算符 | 兩個分支型別必須完全一致；不確定時展開為 if/else 區塊 |
| 2026-06-12 | 高頻觸發函式防重入 | 凡是從物理信號、timer、或連線信號出發的函式，若涉及場景操作，必須加入 `_is_xxx` bool 守衛 |

---

## 📋 Sensor 觸發關鍵字清單（Sensor ROLE 強制執行）

當在代碼中看到以下關鍵字，Sensor 必須觸發對應的二次審查：

| 關鍵字 / 模式 | 觸發的檢查 | 參考 ERR |
|------------|-----------|--------|
| `_on_body_entered` | 確認函式內無直接 add_child/queue_free/change_scene | ERR-001 |
| `_on_area_entered` | 同上 | ERR-001 |
| `body_entered.connect` | 確認 callback 的完整呼叫鏈無場景樹修改 | ERR-001 |
| `int(` | 確認來源是否為 float，應改 roundi() | ERR-002 |
| 三元 `if ... else` | 確認兩分支型別完全相同 | ERR-003 |
| `add_child(` | 確認不在物理 callback 內 | ERR-001 |
| `queue_free(` | 確認不在物理 callback 內 | ERR-001 |
| `change_scene_to_file` | 確認使用 call_deferred | ERR-001 |
| `load_next_room()` | 確認透過 call_deferred 呼叫 | ERR-001 |
| 無守衛的頻繁觸發函式 | 建議加入 _is_xxx bool 防重入守衛 | ERR-001 |
| `RectangleShape2D new()` | .tscn 禁止 inline new()，改用 SubResource | ERR-005 |
| `cam.zoom` 在 HUD 腳本中 | CanvasLayer 的 HUD 不應跟隨相機縮放 | ERR-HUD-001 |
| `global_position = Vector2(x, -50)` 在 _start_solo | 玩家生成前房間未載入，應先隱藏玩家 | ERR-SPAWN-001 |

---

## 🔴 2026-06-12 18:38 — 第二批 Console 錯誤（本次會話修復）

### ERR-004 | scene_camera.gd 同樣的 narrowing+ternary 問題（Reviewer 遺漏）
- **錯誤訊息**：`GDScript::reload: Narrowing conversion` + `Values of the ternary operator are not mutually compatible`（0:00:00:995 和 0:00:01:001）
- **根本原因**：`scene_camera.gd:80-83` 使用 `int(x) if cond else -10_000_000`，與 multiplayer_camera.gd 完全相同的問題
- **為何被漏掉**：修復 ERR-002/003 時只修了 `multiplayer_camera.gd`，Reviewer 沒有全局搜索相同模式是否存在於其他檔案
- **修復**：同 ERR-002/003，改為 if/else 區塊 + roundi()
- **責任 ROLE**：Reviewer（主責）— 應在審查 ERR-002 修復時執行 `Get-ChildItem scripts -Recurse | Select-String "int("` 全局掃描

### ERR-005 | rest_room.tscn Parse Error（shape = RectangleShape2D new()）
- **錯誤訊息**：`game_world.gd:238 @ _load_room_scene(): Parse Error; Parse error. [Resource file res://scenes/level/rest_room.tscn:18]`
- **根本原因**：`rest_room.tscn` 中 4 個 `CollisionShape2D` 的 shape 屬性使用了 `shape = RectangleShape2D new()` —— 這在 `.tscn` 格式中是**無效語法**。`new()` 只能在 GDScript 中使用，`.tscn` 必須用 `[sub_resource]` 定義再用 `SubResource("id")` 引用
- **修復**：重寫 rest_room.tscn，加入 4 個 `[sub_resource type="RectangleShape2D" id="..."]` 並用 `SubResource()` 引用
- **責任 ROLE**：Developer（主責）— 手寫 .tscn 時必須遵守格式；Reviewer（次責）— 審查 .tscn 時必須確認 shape 語法

### ERR-HUD-001 | HUD 血量 UI 變形（CanvasLayer 跟隨相機縮放）
- **錯誤訊息**：玩家看到血量圖示大小隨相機縮放而變形
- **根本原因**：`player_hud.gd` 的 `update_hearts()` 用 `heart_size = 8.0 * cam.zoom.x` 動態縮放心心大小。但 HUD 在 `CanvasLayer` 下，CanvasLayer 已自動與相機縮放解耦（螢幕座標），不需要也不應該手動縮放
- **修復**：改為固定 `heart_size = 24.0`，添加 `texture_filter = TEXTURE_FILTER_NEAREST` 和 `filter_clip = true`
- **責任 ROLE**：Designer（主責）— 設計 HUD 時未指定 CanvasLayer 的縮放隔離特性；Developer（次責）— 實作時誤解了 CanvasLayer 的行為

### ERR-SPAWN-001 | 玩家開場閃爍 + 墜入虛空
- **現象**：遊戲開始時玩家角色閃爍，然後從畫面上方墜落
- **根本原因**：`_start_solo()` 先建立玩家節點並設 `visible=true`（預設），再呼叫 `_load_room_scene()`（deferred）。房間尚未載入，玩家在虛空中出現並受重力影響下墜，產生閃爍
- **修復**：建立玩家時設 `visible = false` + `set_physics_process(false)`，等 `_reset_player_positions()` 在房間載入後才顯示
- **責任 ROLE**：Architect（主責）— 設計生成流程時未考慮 deferred 載入的時序問題；Developer（次責）— 實作時未意識到 `_load_room_scene()` 是 deferred

---

## 🟢 新增 PATTERN（2026-06-12 第二批）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | ERR 修復後的全局掃描 | 修復某個錯誤後，**必須**用 `Get-ChildItem scripts -Recurse | Select-String "關鍵字"` 確認同樣問題不存在於其他檔案 |
| 2026-06-12 | .tscn 中的 Shape 定義 | `CollisionShape2D.shape` 必須引用 `[sub_resource type="RectangleShape2D" id="xxx"]`，格式為 `shape = SubResource("xxx")`；禁止 `shape = RectangleShape2D new()` |
| 2026-06-12 | HUD 設計 | HUD 放在 `CanvasLayer` 下時，大小不需跟隨相機縮放；固定像素大小 + `TEXTURE_FILTER_NEAREST` + `filter_clip = true` |
| 2026-06-12 | 玩家生成時序 | 若房間載入是 deferred，玩家必須先 `visible=false` + `set_physics_process(false)` 建立，在 `_reset_player_positions()` 中才 `visible=true` + `set_physics_process(true)` |
