# 錯誤知識庫 — Error Knowledge Base
> **強制規則**：所有 Role 在修復錯誤後**必須更新此檔案**。
> **強制規則**：遇到任何錯誤前必須先查詢此檔案。

## 🔴 Critical — 必讀（曾造成重大損失）

| 日期 | 錯誤類型 | 錯誤訊息摘要 | 根本原因 | 修復方法 |
|------|---------|------------|---------|---------|
| 2026-06-12 | .tscn Parse Error | `Expected '['` 第一行即失敗 | PowerShell `Set-Content`/`Out-File` 預設寫入 **UTF-8 BOM** (`EF BB BF`)，Godot 解析器不支援 BOM | 用 `[System.IO.File]::WriteAllText(, , [System.Text.Encoding]::UTF8)` 不帶 BOM；或 `Out-File -Encoding UTF8NoBOM`；hook 已有自動修復 |
| 2026-06-12 | GDScript 重複宣告 | `Variable "X" has the same name as a previously declared variable` | 同一個變數在 `@export var` 和 `var` 重複宣告，Godot 4 不允許 | 搜尋全檔只保留一個宣告；若需要 `@export` 就移除無屬性的 `var` 版本 |
| 2026-06-12 | UID 未認識 | `Unrecognized UID: "uid://..."` | 手工在 `.tscn` 第一行指定 UID，Godot 的 uid_cache 沒有記錄 | 移除 `.tscn` 第一行的 `uid=` 字段（改為 `[gd_scene format=4]`），Godot 首次載入時自動生成 UID |
| 2026-06-12 | TileMap 資料損壞 | `Corrupted tile map data: tiles might be missing` | 跨 TileSet 複製 `tile_map_data = PackedByteArray(...)` —— tile ID 映射不同，資料不相容 | 移除 `.tscn` 中的 `tile_map_data`（讓 TileMapLayer 為空），由腳本動態載入；或在 Godot Editor 重新繪製地圖 |
| 2026-06-12 | `@onready` 節點找不到 | `Invalid get index 'X' on base 'null instance'` 在 `_ready()` | `@onready var X = ` 中的節點在 `.tscn` 中不存在或路徑拼錯 | 用 `get_node_or_null("SomeNode")` 取代 `` 並加 `assert(X != null)` 驗證 |
| 2026-06-12 | Autoload 順序錯誤 | `get_node_or_null("/root/DebugBridge")` 返回 null | Autoload 載入順序問題，DebugBridge 在 DebugOverlay 之前宣告但晚初始化 | `project.godot` 中的順序必須是 `NetworkManager → DebugOverlay → DebugBridge`；使用 `get_node_or_null` 延遲取得 |
| 2026-06-12 | [ERR-008] .tscn SubResource 未聲明 | `!int_resources.has(id)` ERR_INVALID_PARAMETER + Parse Error | 在 `.tscn` 中使用 `shape = SubResource("RectangleShape2D_1")` 但未聲明對應 `[sub_resource]`。`--check-only` 無法偵測！ | 在 ext_resource 區段後、第一個 `[node]` 之前加入 `[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]` `size = Vector2(48, 96)` |
| 2026-06-12 | [ERR-009] GDScript class body 呼叫 | `Parse Error: Unexpected identifier "add_to_group" in class body` | 在 class 頂層直接呼叫 `add_to_group()`，GDScript 不允許在 class body 中直接執行語句 | 將 `add_to_group()` 移入 `_ready()` 函式中執行 |
| 2026-06-12 | [ERR-010] .tscn UID 重複 | `UID duplicate detected between res://scenes/player/player2.tscn and ...` | 複製 .tscn 文件後沒有修改第一行的 `uid=` 字段，所有複本共用同一個 UID | 為每個複製的 `.tscn` 手動生成唯一 UID（用 PowerShell New-GodotUID 腳本），或在 Godot Editor 重新保存場景 |
| 2026-06-12 | [ERR-011] UTF-16 BOM 腳本 | `Unicode parsing error, Invalid UTF-8 leading byte (ff/fe)` + `Script contains invalid unicode` | 用某些編輯器（如記事本 Windows）儲存 .gd 文件時選擇 UTF-16 編碼，產生 FF FE 前綴 | 用 `[System.IO.File]::WriteAllText(, , New-Object System.Text.UTF8Encoding(False))` 轉換為 UTF-8 無 BOM；pre-commit hook 已可自動偵測 |
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

---

## 🔴 2026-06-12 第三批 Console 錯誤（截圖：29 Errors）

### ERR-006 | boss.gd 不存在（Developer 創建場景時未創建腳本）
- **錯誤訊息**：
  - `game_world.gd:247 @ _load_room_scene(): Attempt to open script 'res://scripts/enemy/boss.gd' resulted in error 'File not found'`
  - `game_world.gd:247 @ _load_room_scene(): Failed loading resource: res://scripts/enemy/boss.gd`
  - `res://scenes/enemy/boss.tscn:11 - Parse Error: [ext_resource] referenced non-existent resource at: res://scripts/enemy/boss.gd`
  - `res://scenes/level/boss_room.tscn:118 - Parse Error: [ext_resource] referenced non-existent resource at: res://scripts/enemy/boss.gd`
- **根本原因**：`boss.tscn` 和 `boss_room.tscn` 均引用 `res://scripts/enemy/boss.gd`，但此檔案**從未被創建**。Developer 在實作 boss 場景時只創建了 `.tscn`，沒有配套的 `.gd` 腳本。
- **修復**：創建 `scripts/enemy/boss.gd`，實作巡邏→衝刺→冷卻三狀態 Boss AI，HP=30，攻擊力=2
- **責任 ROLE**：Developer（主責）— 創建引用 Script 的 .tscn 後，**必須**確認對應的 .gd 存在；QA（次責）— 未在房間載入測試中發現 boss_room 載入失敗

### ERR-007 | ERR-001 再次出現（`_load_room_scene` add_child 仍在 physics flush）
- **錯誤訊息**：`game_world.gd:255 @ _load_room_scene(): Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.` × 多次
- **根本原因**：
  - 第一次修復（ERR-001）：在 `room_transition.gd` 用 `call_deferred("load_next_room")` 跳出 `_on_body_entered`，這是正確的。
  - 但 `boss_room.tscn` 中有 Area2D 節點，當 `_load_room_scene()` 被 `load_next_room()` 的 deferred 呼叫後，`add_child(_current_room_node)` 使 Area2D 的 `_ready()` 立刻執行，其中有物理信號連結操作（`body_entered.connect()`），此時 Godot 的 **physics server 仍在同一 deferred frame 中 flushing**，導致再次崩潰。
  - 根本根本原因：`_load_room_scene()` 雖然是 deferred 呼叫的，但 `instantiate() + add_child()` 仍在**同一個 deferred callback** 內 — 這個 callback 本身執行時 physics 仍然 flushing。
- **修復**：
  1. 在 `_load_room_scene()` 中，`instantiate()` 後**不**立刻 `add_child()`
  2. 改用 `call_deferred("_finish_room_load", scene_path)` 再把 `add_child + cleanup + reset` 全部放到新的 `_finish_room_load()` 函式中
  3. 這樣 `add_child()` 的執行在**下下幀**，確保完全遠離 physics flush
- **責任 ROLE**：Architect（主責）— 第一次設計 ERR-001 修復時，對 deferred 呼叫鏈的理解不夠深入，以為「外層 call_deferred 就夠了」，沒有考慮到 boss_room 的 Area2D `_ready()` 時序問題；Developer（次責）— 應深入測試 boss_room 的載入

---

## 🟢 新增 PATTERN（2026-06-12 第三批）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | 創建引用 Script 的 .tscn 時 | 必須同時創建對應的 .gd 腳本；建立 .tscn 後，立刻確認 `Get-ChildItem scripts -Recurse \| Where-Object Name -eq "xxx.gd"` 存在 |
| 2026-06-12 | ERR-001 深層修復（Area2D _ready 時序） | 「呼叫端 call_deferred」不夠；`add_child()` 後的整個處理鏈也必須放到**另一個** call_deferred 中（`_finish_room_load` 模式），確保 physics flush 已完全結束 |
| 2026-06-12 | 房間載入最佳架構 | 1→`load_next_room()`（call_deferred 呼叫）→ 2→`_load_room_scene()`（instantiate only）→ 3→`_finish_room_load()`（add_child + cleanup + reset，call_deferred 呼叫） |

---

## 🟢 Phase 4 新增 PATTERN（2026-06-12 Portal 系統）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | Fade 過渡換房間（四層 deferred） | `body_entered` → `call_deferred("_do_trigger")` → `game_world.load_next_room_portal()` → `fader.fade_out()` → `faded_out signal` → `call_deferred("_do_portal_room_change")` → 三層 deferred 換場。共四層，確保任何一層都不在 physics flush 中執行 |
| 2026-06-12 | CONNECT_ONE_SHOT 信號用法 | 當只需要連接一次的 signal（如 Fade Out 完成後換場），使用 `signal.connect(callback, CONNECT_ONE_SHOT)` 避免重複觸發或手動 disconnect |
| 2026-06-12 | Paired Door ID 房間配對 | 每個 RoomPortal 有 `door_id` 和 `target_door_id`。A房間的 `door_id="right"` 連到 B房間的 `target_door_id="right"`，B房間的 `door_id="right"` 有一個 `SpawnMarker` 子節點作為玩家出現位置 |
| 2026-06-12 | ScreenFader CanvasLayer 層級 | ScreenFader 的 `layer = 128` 確保在所有遊戲 UI 之上（HUD layer=10）。`mouse_filter = 2` 讓輸入穿透，不阻擋玩家操作 |
| 2026-06-12 | class_name 全域可用性 | GDScript 4 的 `class_name RoomPortal` 在整個專案中全域可用，其他腳本可直接用 `child is RoomPortal` 做型別檢查，不需 preload |

---

## 🔴 2026-06-12 第四批 Console 錯誤（本次會話修復）

### ERR-012 | boss.gd 非 UTF-8 編碼（文件儲存編碼錯誤）
- **錯誤訊息**：`Unicode parsing error, Invalid UTF-8 leading byte (ff/fe)` + `Script 'res://scripts/enemy/boss.gd' contains invalid unicode (UTF-8), so it was not loaded.`
- **根本原因**：`boss.gd` 文件由 AI 生成後，以 Windows 預設的非 UTF-8 編碼（可能是 CP950/Big5 或 ANSI）儲存，中文註解中包含高位元組字元，Godot 4 解析器無法處理。雖然第一行是純 ASCII（`extends CharacterBody2D`），但後續的中文註解行含有 0x80+ 位元組。
- **根本區別於 ERR-011（UTF-16 BOM）**：ERR-011 是 UTF-16 的 BOM 問題（FF FE 開頭），ERR-012 是整個文件編碼錯誤（Big5/CP950/ANSI），字串中任意位置出現不合法的 UTF-8 位元組序列。
- **修復**：重新撰寫 `boss.gd`，所有中文註解改為英文，確保文件為純 ASCII 內容（ASCII 是 UTF-8 的子集，永遠相容）；用工具寫出時指定 `UTF8Encoding(false)` 無 BOM。
- **責任 ROLE**：Developer（主責）— 在非 UTF-8 環境中撰寫中文註解的 .gd 文件，應確認儲存編碼；Sensor（次責）— 應在 Level 2 觸發表中加入「含中文的 .gd 文件必須確認 UTF-8 儲存」的掃描項目
- **防範措施**：
  1. 所有 .gd 文件的中文內容應先確認編輯器設定 UTF-8
  2. 或統一改用英文撰寫（最安全，無編碼風險）
  3. Pre-commit hook 應加入 UTF-8 驗證

### ERR-013 | 玩家場景 ext_resource UID 指向場景自身（UID 自引用）
- **錯誤訊息**：`ext_resource, invalid UID: uid://cgxc5o3rdglr5 - using text path instead` × 多個場景；`UID duplicate detected between res://scenes/player/player2.tscn and res://scenes/player/player1.tscn` × 3 對
- **根本原因**：複製 player.tscn 建立 player1-4.tscn 時，每個場景的 `[ext_resource]` 的 uid 屬性被設為與場景頭的 `uid=` 完全相同的值（即場景自身的 UID 而非資源的 UID）。這導致：
  1. 四個場景中所有同類 ext_resource 都指向不同的 UID → Godot 找不到對應資源
  2. 四個場景的 UID 互相重複（每個場景 UID 被同名資源的 UID 覆蓋）
- **正確做法**：`[ext_resource]` 的 `uid=` 必須是**被引用資源**的 UID（可從 `.uid` 副檔名文件或資源文件的 `[gd_scene format=3 uid="xxx"]` 行讀取），絕對不能是當前場景的 UID
- **修復**：查詢各資源的真實 UID，更新 player1-4.tscn 的所有 ext_resource 引用；同時新增 `player_prefix` 屬性讓各場景對應正確的輸入組
- **責任 ROLE**：Developer（主責）— 複製場景後沒有驗證 ext_resource UID 的正確性；Reviewer（次責）— 審查 .tscn 時應核對 ext_resource UID 與 .uid 文件是否一致
- **快速驗證腳本**：
  ```powershell
  # 確認場景的 ext_resource UID 不等於場景本身 UID
  $tscn = Get-Content "D:\2026-06-04\scenes\player\player1.tscn" -Raw
  $sceneUID = [regex]::Match($tscn, 'gd_scene.*uid="([^"]+)"').Groups[1].Value
  $extUIDs = [regex]::Matches($tscn, 'ext_resource.*uid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $bad = $extUIDs | Where-Object { $_ -eq $sceneUID }
  if ($bad) { Write-Host "❌ ext_resource UID 與場景 UID 相同！" } else { Write-Host "✅ 無 UID 自引用問題" }
  ```

### ERR-014 | test_stretch.gd 使用 Godot 3 廢棄 API
- **錯誤訊息**：`Script 'res://test_stretch.gd' contains invalid unicode (UTF-8), so it was not loaded.`（間接）+ `ERROR: res://test_stretch.gd:1 - Parse Error: Invalid character` 
- **實際問題**：`TextureRect.STRETCH_KEEP_ASPECT_CENTERED` 是 Godot 3 的常數，在 Godot 4 中已廢棄（移至 `TextureRect.StretchMode` 枚舉，常數名稱改變）。此外，腳本格式也有問題（單行格式在 Godot 4 headless 中可能有相容性問題）。
- **修復**：重寫為多行格式，使用 Godot 4 的 `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` 常數
- **責任 ROLE**：Developer（主責）— 使用了 Godot 3 API 而非 Godot 4 API；Sensor（次責）— 應在 Level 2 觸發表中加入「TextureRect.STRETCH_*」等已廢棄常數的掃描項目

### ERR-015 | test_*.gd 文件 UTF-8 BOM 問題（AI 工具寫入問題）
- **錯誤訊息**：`Unicode parsing error, Invalid UTF-8 leading byte (ff)` / `Invalid UTF-8 leading byte (fe)` 對應 test_grad.gd, test_img.gd, test_source.gd, test_src.gd, test_tm.gd, test_tm2.gd
- **根本原因**：test_*.gd 文件（根目錄下的測試腳本）以 UTF-8 BOM（EF BB BF）儲存。Godot 4 的腳本解析器不接受任何形式的 BOM（包括 UTF-8 BOM）。PowerShell 的 `Set-Content` 和 `Out-File` 在某些版本中預設寫入 UTF-8 BOM。
- **修復**：用 `[System.IO.File]::WriteAllText(path, content, New-Object System.Text.UTF8Encoding($false))` 重新儲存所有 test_*.gd 文件
- **責任 ROLE**：Developer（主責）— 使用了會產生 BOM 的工具寫入 .gd 文件；Sensor 觸發表的 ERR-011 條目已涵蓋此類問題，但未被執行

---

## 🟢 新增 PATTERN（2026-06-12 第四批）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | 含中文的 .gd 文件 | 統一使用英文撰寫所有 .gd 文件的代碼和註解（最安全）；若必須中文，確保編輯器設為 UTF-8 無 BOM 儲存，並在寫入後用 `[IO.File]::ReadAllBytes` 驗證頭部無 0xFF/0xFE/0xEF |
| 2026-06-12 | 複製 .tscn 後 ext_resource UID 驗證 | 複製場景後立即執行 UID 自引用檢查腳本，確認每個 ext_resource 的 UID 來自被引用資源的 .uid 文件，而非場景自身的 UID |
| 2026-06-12 | Godot 3 → Godot 4 API 遷移 | `TextureRect.STRETCH_*` → 使用 `TextureRect.StretchMode` 枚舉；任何涉及 Godot 3 常數的腳本在 Godot 4 中必須使用 Godot 4 對應的 API |
| 2026-06-12 | 工具腳本的 UTF-8 BOM 預防 | 在 pre-commit hook 或 CI 中加入掃描：`$b=[IO.File]::ReadAllBytes($path); if ($b[0] -eq 0xEF -and $b[1] -eq 0xBB) { "UTF-8 BOM 錯誤" }` |