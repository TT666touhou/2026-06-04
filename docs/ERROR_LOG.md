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
| 2026-06-13 | [ERR-DOC-001] PowerShell regex 破壞文檔 | GDD 章節 8.3/8.3.1 內容被替換成亂碼或遺失 | `$content -replace '(pattern)', '$1replacement'` 中 `$1` 在 PowerShell **雙引號字串**中被當作 PS 變數展開（=空值），非 regex 回捕。反斜線也在 PS 字串中有意義。→ 替換結果靜默損壞中文內容 | **禁止** 用 `-replace` 操作多行中文文檔。修改文檔用 `replace_file_content` 工具直接替換。若必須用 PS，改用**單引號字串**：`'$1replacement'`（不展開 PS 變數） |
| 2026-06-13 | [ERR-028] SceneTree 腳本呼叫 get_tree() | `Parse Error: Function "get_tree()" not found in base self.` + `Failed to load script` | **QA 腳本使用 `extends SceneTree` 時**，`self` 就是 SceneTree 本身，無法再呼叫 `get_tree()`（那是 `Node` 的方法）。常見於 `await get_tree().process_frame` 或 `get_tree().change_scene_to_file()` 等寫法。 | 將 `get_tree().XXX` 改為 `self.XXX`（可省略 self）：`await process_frame`、`call_deferred("change_scene_to_file", ...)`。**Sensor 掃描新增規則**：凡 `extends SceneTree` 的 .gd 文件中出現 `get_tree()` → 立即標記為 ERR-028 |
| 2026-06-22 | [ERR-GAP048] 盪繩被地形卡住 | 右鍵勾牆盪繩時常卡在平台角落無法繼續移動 | `move_and_collide(correction)` 遇到幾何體完全停止；下一幀繩子繼續拉但玩家被卡死，形成惡性循環 | 把 constraint 位置修正轉換為 `velocity += correction / delta`，讓幀尾唯一的 `move_and_slide()` 統一處理，遇到角落自動沿牆面滑動而非停死 |
| 2026-06-22 | [ERR-GAP047] NeedleAnchor 不跟隨移動敵人 | 針視覺停在插入點，不隨敵人移動 | `NeedleAnchor` 是純資料 Node2D，`attached_body` 有值但無任何 `_process` 更新 `global_position` | 在 `needle_anchor.gd` 加 `_physics_process`：首幀計算 `_body_offset = global_position - attached_body.global_position`，後續每幀 `global_position = attached_body.global_position + _body_offset` |
| 2026-06-22 | [ERR-GAP047] 右鍵勾敵人玩家被拉動 | wire 鉤到敵人時玩家被拉向錨點，與預期相反 | `_apply_wire()` 無條件執行 `WireConstraint.constrain()`，沒有判斷錨點是否在移動 body 上 | `player.gd` `_apply_wire()` 加檢查：每幀同步 `_wire.anchor_pos = _wire_anchor.global_position`；若 `_wire_anchor.attached_body != null` 則 `return` 不執行 constraint |

---

## 🟡 Warning — 常見陷阱

| 日期 | 錯誤類型 | 錯誤訊息摘要 | 根本原因 | 修復方法 |
|------|---------|------------|---------|---------|
| 2026-06-12 | `.uid` 檔案衝突 | Godot 啟動時 `player.gd` UID 不匹配 | `git` 操作後 Godot 重新生成 `.uid` 檔案，導致場景引用舊 UID | 在 `.gitignore` 加入 `*.uid`（已完成）；或每次 `git pull` 後重新在 Godot Editor 中開啟場景讓 Godot 自動修正引用 |
| 2026-06-12 | `player.gd` BOM | (同 Critical 第1條) 但出現在腳本而非場景 | 同上 | 同上，hook 自動修復 |
| 2026-06-12 | `multiplayer` 空指標 | `Invalid call. Nonexistent function 'is_server' on null` | 在 `_ready()` 中直接調用 `multiplayer.is_server()` 但 `MultiplayerAPI` 尚未設定 peer | 先用 `multiplayer.has_multiplayer_peer()` 確認有 peer 再調用其他方法 |
| 2026-06-12 | Godot `--check-only` 無法偵測 .tscn 錯誤 | `gw_err.log` 顯示腳本錯誤但 check 指令顯示通過 | `--check-only` 只驗證 GDScript，不完整載入場景 | 需要實際執行（不帶 `--check-only`）或用 `--headless --path <project>` 完整啟動才能發現 .tscn 問題 |
| 2026-06-12 | `AnimatableBody2D` 沒有碰撞 | 天花板/物理邊界沒有實際碰撞效果 | `AnimatableBody2D` 需要通過程式碼或動畫移動才會觸發碰撞，靜止時不阻擋 | 靜止的邊界牆/天花板改用 `StaticBody2D`；只有需要動態移動的平台才用 `AnimatableBody2D` |
| 2026-06-13 | [ERR-HUD-003] GDScript Variant 推斷錯誤（Array.back()） | `The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)` line 83 `player_hud.gd` | `Array.back()` 在 GDScript 4 回傳 `Variant`（非型別化），用 `:=` 推斷時觸發 Variant warning→error | 用明確型別標注：`var last: Node = children.back()` 而非 `var last := children.back()`。原因：Developer 在上一輪修復 HUD 時未做靜態型別全面檢查，Sensor 沒有跑 `--check-only`（v3 缺少此步），未被攔截 |
| 2026-06-19 | [GAP-016] Shader cache 建立失敗 | `_initialize_cache: Unable to create shader cache directory [ShaderName]RD/... at user://shader_cache.` (10+ 條，D3D12 renderer 初始化時) | `config/name="[TBD]"` 含方括號 `[]`；Godot 的 D3D12 shader cache 在嘗試遞迴建立 `user://shader_cache/` 時失敗（Godot 的 DirAccess 對含有 `[]` 的路徑可能有 glob 解析衝突）。**根本原因**：project name 用佔位符 `[TBD]` 而非有效名稱。 | 1. 將 `config/name` 改為不含特殊字元的名稱（`needle_game`）2. 手動建立 `%APPDATA%\Godot\app_userdata\[ProjectName]\shader_cache` 目錄。**預防**：project name 永遠使用 `snake_case` 或純英數字，絕不使用 `[佔位符]` 格式 |

---

## 🟢 Pattern — 已知最佳做法

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-13 | [PATTERN-ARR] Array.back() 型別標注 |  ar last: Node = children.back() — 明確標注型別，不用 := | Array.back()/.front()/.pop_back() 等方法回傳 Variant，嚴格模式下 := 會觸發 Variant 推斷 warning→error。永遠使用  ar x: ActualType = arr.back() |
| 2026-06-13 | [PATTERN-VFX-FLIP] OneShotVFX 翻轉 | `spr.flip_h = (_facing < 0)` 直接賦值；**scene 內 flip_h 統一保持 false**。❌ 勿用 `not spr.flip_h`（toggle）——若場景有預設 flip_h 會雙重翻轉 |
| 2026-06-13 | [PATTERN-VFX-ADJUST] VFX 位置手動調整 | 方法A：開啟 tscn → 選 MeleeVFXPivots/HitNPivot Marker2D → Inspector 改 Position。以右為正 X，面左自動鏡像。方法B（舊）：改 player.gd 中的 hardcode 偏移值（已廢棄，不推薦） |
| 2026-06-13 | [PATTERN-VFX-MARKER] Marker2D VFX 定位系統 | **近戰 VFX 位置統一用 Marker2D 定義**（非 hardcode）。結構：Player/MeleeVFXPivots/Hit1Pivot（Marker2D）。以右為正 X，`_facing * marker.position.x` 自動鏡像。`_spawn_melee_vfx_at_marker(scene, marker)` 為標準接口。場景中可視化調整無需改代碼 |
| 2026-06-13 | [PATTERN-DOC-EDIT] Markdown 文檔修改 | **永遠使用 `replace_file_content` 或 `multi_replace_file_content` 工具**修改 .md 文檔，**禁止使用 PowerShell `-replace` 操作多行中文內容**。根源：PS `-replace` 在雙引號字串中 `$1` 被展開為 PS 變數（空值），導致中文內容靜默損壞（ERR-DOC-001） |
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
| 2026-06-13 | [PATTERN-VFX-POS] OneShotVFX 偏移 | `vfx_x_offset = _facing * melee_range * 0.8` ← 用攻擊範圍的 80% 作為偏移。固定值（如 14px）會讓所有特效疊在角色中心 |
| 2026-06-13 | [PATTERN-VFX-SPEED] OneShotVFX 速度 | speed≈(幀數/攻擊鎖定時間)*0.6。16幀/0.15s*0.6≈64 → 設 60fps。預設 24fps（16幀=0.667s）遠超攻擊動作，感覺「拖尾」 |
| 2026-06-13 | [PATTERN-VFX-FLIP] OneShotVFX 翻轉 | `spr.flip_h = (_facing < 0)` 直接賦值；**scene 內 flip_h 統一保持 false**。❌ 勿用 `not spr.flip_h`（toggle）——若場景有預設 flip_h 會雙重翻轉 |
| 2026-06-13 | [PATTERN-VFX-ADJUST] VFX 位置手動調整 | 方法A：開啟 tscn → 選 MeleeVFXPivots/HitNPivot → 2D 視圖拖曳。方法B：Inspector → Melee VFX Offsets 群組。X 以朝右為基準，runtime 自動鏡像 |

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

---

## 🔴 [ERR-016] — player_prefix 空字串造成攻擊完全靜默失敗

- **日期**：2026-06-12
- **報告 ROLE**：QA → Developer 修復
- **錯誤分類**：Logic Bug（攻擊功能整體無效）
- **錯誤訊息**：無任何錯誤訊息——攻擊功能靜默失敗（silent failure）
- **根本原因**：test_room_a.tscn 和 test_room_b.tscn 的 Player 節點沒有設定 `player_prefix = "p1_"`（預設為空字串 `""`），導致 `_handle_attack()` 嘗試查詢 `"melee"` / `"ranged"` action（缺少前綴），InputMap 找不到該 action，直接 `return` 無任何反應
- **修復**：
  1. test_room_a/b.tscn Player 節點加入 `player_prefix = "p1_"`
  2. player.gd 新增 `InputMap.has_action()` 防禦性檢查 + warning（已有）
  3. 攻擊邏輯從舊版短按/長按重構為 LMB/RMB 即時觸發
- **教訓**：任何測試場景在建立 Player 節點後，**必須立即在 Inspector 設定 player_prefix**，否則所有輸入功能全面失效但無提示

---

## 🟢 新增 PATTERN（2026-06-12 第五批）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | test 場景建立 Player 節點 | 立即設定 `player_prefix = "p1_"` + `bullet_scene`，否則攻擊/輸入靜默失敗 |
| 2026-06-12 | 攻擊輸入設計 | 優先使用即時觸發（`just_pressed`）而非需要精確計時的短按/長按，減少邊界條件 BUG |
| 2026-06-12 | VFX 場景設計 | 使用 one_shot_vfx.gd + `animation_finished.connect(queue_free)` 模式，保持輕量 |

---

## 🔴 ERR-017 VFX Spritesheet 切割錯誤（2026-06-12）

- **嚴重程度**：High（VFX 顯示完全錯誤、大幅超出比例）
- **錯誤分類**：VFX Configuration Error
- **錯誤現象**：所有 VFX 特效顯示為原始 PNG 全圖而非正確切割幀；特效大小遠超角色（角色~22px，VFX達96~139px）
- **根本原因 1**：VFX scenes 的 AnimatedSprite2D 使用整張紋理（無 AtlasTexture 切割），每幀都是整張 spritesheet
- **根本原因 2**：frame size 用了錯誤估算值（91px），未量測真實 PNG 尺寸
- **根本原因 3**：@export VFX 變數要求手動 Inspector 拖入場景引用，在多個場景中都未配置
- **根本原因 4**：all VFX scenes 的 autoplay 設為空字串 ""（應為 "default"）
- **修復**：
  1. one_shot_vfx.gd 改為自我配置腳本，在 _ready() 中動態建立 SpriteFrames + AtlasTexture
  2. 用 System.Drawing 量測 PNG 尺寸，計算正確的 frame_width/height/count
  3. 移除所有 @export VFX vars，改為 const path + _ready() auto-load
  4. VFX scale 根據玩家高度(~22px)設計比例：melee=0.28, ranged=0.18, hit=0.26, death=0.38
- **量測數據**：
  - slash_01 (1456x96): 16幀 91x96
  - spark_01 (2096x127): 16幀 131x127
  - impact_01 (2192x98): 22幀 98x98
  - explosion_little_02 (1424x93): 16幀 89x93
- **教訓**：
  - VFX 實作前必須先用 System.Drawing 量測 PNG 尺寸
  - 所有 spritesheet 的 frame count = width / height（當 sheet 是水平列幀時）
  - VFX 系統應使用自我配置腳本，而非依賴手動 Inspector 設定（零配置原則）
  - scale 設計必須基於角色碰撞體大小（CapsuleShape2D radius=4, height=14 → ~22px）

---

## 🔴 ERR-018 GDScript 重複變數宣告（spawn_pos）（2026-06-12）

- **嚴重程度**：Medium（IDE 報錯，功能受影響）
- **錯誤分類**：Syntax Error
- **錯誤訊息**：There is already a variable named "spawn_pos" declared in this scope.
- **位置**：player.gd:870
- **根本原因**：_fire_bullet() 函式中先在 L853 宣告 ar spawn_pos，VFX 部分又在 L870 重複宣告
- **修復**：刪除 L870 的重複宣告，VFX 直接複用 L853 已宣告的 spawn_pos
- **教訓**：複製貼上代碼時必須檢查變數名衝突；同一函式中使用 spawn_pos 的兩個用途應合併到一處

---

## 🟡 ERR-019 StringName/String Ternary 不相容（2026-06-12）

- **嚴重程度**：Low（Warning，可能導致微妙的型別問題）
- **錯誤分類**：INCOMPATIBLE_TERNARY Warning
- **錯誤訊息**：(INCOMPATIBLE_TERNARY): Values of the ternary operator are not mutually compatible
- **位置**：debug_bridge.gd（原 L136）
- **根本原因**：scene.name 是 StringName 型別，"null" 是 String，三元運算符的兩個分支型別不一致
- **修復**：String(scene.name) if scene != null else "null" 顯式轉型
- **教訓**：GDScript 的 StringName 和 String 雖然可以隱式轉換，但在三元運算符中需要顯式統一型別

---

## 🟡 ERR-020 Float-to-Int Narrowing（Engine.get_frames_per_second）（2026-06-12）

- **嚴重程度**：Low（Warning，精度可能損失）
- **錯誤分類**：NARROWING_CONVERSION Warning
- **錯誤訊息**：(NARROWING_CONVERSION): Narrowing conversion (float is converted to int and loses precision)
- **位置**：debug_overlay.gd:106
- **根本原因**：Engine.get_frames_per_second() 在 Godot 4.6 返回 float，直接賦值給 ar fps: int 產生 narrowing
- **修復**：改為 ar fps: int = roundi(Engine.get_frames_per_second())
- **教訓**：Godot 4 的 Engine API 有些返回 float 即使語義上是整數，應用 roundi()/floori() 明確轉型

---

## 🟢 新增 PATTERN（2026-06-12 第六批）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-12 | VFX Spritesheet 量測 | 實作前必須用 System.Drawing 量測 PNG: img = [Drawing.Image]::FromFile(); frameCount = round(width / height) |
| 2026-06-12 | VFX 系統架構 | one_shot_vfx.gd @export: texture_path/frame_width/frame_height/frame_count/fps/vfx_scale; _ready() 動態建立 AtlasTexture |
| 2026-06-12 | VFX 比例設計 | 以玩家碰撞體大小為基準（~22px）; scale = 目標顯示px / 原始幀px |
| 2026-06-12 | VFX 自動載入 | 移除 @export PackedScene VFX vars, 改用 const path + _ready() load() (零 Inspector 配置原則) |
| 2026-06-12 | StringName 型別安全 | 三元運算符兩側型別必須一致; StringName 賦值給 String 用 String(strname) 顯式轉型 |
| 2026-06-12 | Engine API 返回值 | get_frames_per_second() 返回 float; 賦值給 int 用 roundi()（非強制轉型） |


---

## ERR-021 VFX AnimatedSprite2D Scale Too Large (2026-06-12 Session 7)

- **Severity**: High (VFX covers entire screen)
- **Error Type**: VFX Scale Configuration Error
- **Symptom**: Sprite frames were correct (91x96, 131x127, 137x98, 132x126) but AnimatedSprite2D had no scale set, rendering at native pixel size far larger than player (~22px). EnemyDeath had scale=2.0 making it 264x252px.
- **Real PNG dimensions (Python measurement)**:
  - slash_01 (1456x96): 16 frames, each 91x96
  - spark_01 (2096x127): 16 frames, each 131x127
  - impact_01 (2192x98): 16 frames, each 137x98
  - death_01 (3168x126): 24 frames, each 132x126
- **Fix**:
  - MeleeSlash: scale = Vector2(0.35, 0.35) -> ~32x34px (~2 character widths)
  - RangedMuzzle: scale = Vector2(0.15, 0.15) -> ~20x19px (~1 character width)
  - EnemyHit: scale = Vector2(0.20, 0.20) -> ~27x20px (~1.7 character widths)
  - EnemyDeath: scale = Vector2(0.30, 0.30) -> ~40x38px (~2.5 character widths)
- **Lesson**: Always set scale on VFX AnimatedSprite2D. Base proportions on player height (~22px).

---

## ERR-022 @export VFX Vars Not Wired in .tscn Files (2026-06-12 Session 7)

- **Severity**: High (all VFX silently fail)
- **Error Type**: Export Property Misconfiguration
- **Symptom**: melee_slash_scene / muzzle_flash_scene / hit_vfx_scene / death_vfx_scene all null, no VFX on attack
- **Cause**: @export PackedScene vars declared in script but never assigned in player1-4.tscn / Enemy1-3.tscn
- **Fix Process**:
  1. Read target VFX scene UID from line 1 of .tscn
  2. Add [ext_resource type="PackedScene" uid="..." path="..." id="N_tag"]
  3. Add property_name = ExtResource("N_tag") to root node section
  4. Update load_steps=X (ext_resources + sub_resources + 1)
  5. Write with [System.IO.File]::WriteAllText() UTF-8 no-BOM (NOT Set-Content!)
  6. Validate with Godot headless --quit, check for no Parse Error
- **Lesson**: After creating scripts with @export VFX vars, MUST update all referencing .tscn files

---

## New Pattern (Session 7)

| Date | Context | Best Practice |
|------|---------|--------------|
| 2026-06-12 | VFX scale | AnimatedSprite2D must have scale; base on char height ~22px: melee=0.35 ranged=0.15 hit=0.20 death=0.30 |
| 2026-06-12 | After .tscn write | Check bytes[0..2] != EF BB BF; then run Godot headless --quit to confirm no Parse Error |
| 2026-06-12 | PNG size measurement | Use Python struct.unpack('>II', bytes[16:24]) from PNG header; PowerShell byte offset error-prone |
| 2026-06-12 | load_steps formula | ext_resource count + sub_resource count + 1 |

---

## ERR-023 .tscn Header Missing Opening '[' Bracket (2026-06-13)

- **Severity**: Critical (scene fails to parse entirely - identical symptom to BOM but different cause)
- **Error Message**: es://scenes/enemy/Enemy1.tscn:1 - Parse Error: Expected '['
- **Files Affected**: Enemy1.tscn, Enemy2.tscn, Enemy3.tscn, player1.tscn, player2.tscn, player3.tscn, player4.tscn (7 files)
- **Error Type**: .tscn Header Format Corruption
- **Root Cause**: In the previous session, a PowerShell script used -replace to update load_steps counts in .tscn headers. The regex pattern was '\[gd_scene load_steps=\d+' which matched [gd_scene load_steps=5. The replacement string should have been '[gd_scene load_steps=7' (including the [). The [ was PRESENT in the replacement string, so it should have worked. However, the files went through multiple write/read cycles using Set-Content -Encoding UTF8 (which adds UTF-8 BOM) followed by [System.IO.File]::ReadAllText(). In PowerShell, when Get-Content -Encoding UTF8 -Raw reads a BOM-prefixed file, it may inject the BOM character U+FEFF into the string at position 0. When this BOM-tainted string was then passed through another regex -replace, and written back with Set-Content, the BOM became embedded in the file content before the [, causing the effective first content character to be U+FEFF rather than [. The BOM-removal script then ran Substring(1) which removed U+FEFF but left the string starting with gd_scene (missing [). The final write preserved this broken state.
- **Distinction from ERR-022 (BOM)**: ERR-022 is EF BB BF 5B... (BOM bytes + [). ERR-023 is 67 64 5F... (gd_scene...) — no BOM, but [ is genuinely missing from the file content.
- **Diagnosis Command**:
  `powershell
  Get-ChildItem . -Recurse -Filter *.tscn | ForEach-Object {
       = [IO.File]::ReadAllBytes(.FullName)
       = if ([0] -eq 0xEF) { 3 } else { 0 }
      if ([char][] -ne '[') { Write-Host "BROKEN: " }
  }
  `
- **Fix**:
  `powershell
  System.Text.UTF8Encoding = New-Object System.Text.UTF8Encoding False
   = [IO.File]::ReadAllText()
  if ([0] -ne '[') { [IO.File]::WriteAllText(, '[' + , System.Text.UTF8Encoding) }
  `
- **Prevention**:
  1. NEVER use Get-Content -Encoding UTF8 -Raw on files that may have BOM — use [IO.File]::ReadAllText() instead
  2. NEVER use Set-Content -Encoding UTF8 — always use [IO.File]::WriteAllText() with UTF8NoBOM
  3. After ANY automated .tscn modification, run: $b=[IO.File]::ReadAllBytes(); if([char][0] -ne '[') { "BROKEN" }
  4. Run sensor-scan.ps1 (check 6/6) which now automatically detects this issue
  5. Pre-commit hook now blocks commits with broken .tscn headers (rule 1c)
- **Responsibility**: Developer (primary) — must verify .tscn header after any automated modification. Sensor (secondary) — scan 6/6 now added to catch this.

---

## New Pattern (Session 8 - ERR-023)

| Date | Context | Best Practice |
|------|---------|--------------|
| 2026-06-13 | Modifying .tscn headers with PowerShell | NEVER mix Get-Content + Set-Content for .tscn; use ONLY [IO.File]::ReadAllText + [IO.File]::WriteAllText(path, content, UTF8NoBOM) |
| 2026-06-13 | After any automated .tscn write | Immediately verify: =[IO.File]::ReadAllBytes(); if([char][0] -ne '[') { "ERR-023 DETECTED" } |
| 2026-06-13 | load_steps update pattern | Use  = .Replace('[gd_scene load_steps=OLD', '[gd_scene load_steps=NEW') not -replace to avoid regex ambiguity with '[' |
| 2026-06-13 | Sensor scan 6/6 | Run .\scripts\sensor-scan.ps1 before any commit involving .tscn files |

---

## ERR-024 VFX SpriteFrames 使用 texture+region 而非 AtlasTexture 導致整個 Sheet 顯示為一幀（2026-06-13）

- **Severity**: High（每次攻擊/受傷/死亡特效顯示整個 spritesheet 條帶，而非個別幀）
- **症狀**: 特效播放時顯示一條完整的橫向 spritesheet，而非切割後的動畫
- **Error Type**: SpriteFrames 幀定義格式錯誤（Godot 4 API 誤用）
- **受影響文件**: MeleeSlash.tscn, RangedMuzzle.tscn, EnemyHit.tscn, EnemyDeath.tscn

### 根本原因
Godot 4 SpriteFrames 資源的 frame dict 格式**不支援** 	exture + region 組合：
`
# ❌ WRONG - Godot 4 忽略 'region' 欄位，顯示整個紋理
"frames": [{
    "texture": ExtResource("2_tex"),
    "region": Rect2(0, 0, 132, 126)
}]
`

egion 鍵在 frame dict 中是 **Godot 4 的廢棄格式**，不會實際裁剪紋理。  
Godot 4 正確方法是使用 AtlasTexture sub-resource：
`
# ✅ CORRECT - 每幀一個 AtlasTexture sub-resource
[sub_resource type="AtlasTexture" id="AT_0"]
atlas = ExtResource("2_tex")
region = Rect2(0, 0, 132, 126)

"frames": [{"texture": SubResource("AT_0"), "duration": 1.0}]
`

### 修復
- 所有 4 個 VFX .tscn 文件重寫，每幀使用獨立的 AtlasTexture sub-resource
- load_steps = 2 (ext_resources) + N (AtlasTextures) + 1 (SpriteFrames) = N+3

### 幀規格（已驗證）
| VFX | PNG | 幀數 | 幀尺寸 | FPS | Scale |
|-----|-----|------|--------|-----|-------|
| MeleeSlash | slash_01.png 1456×96 | 16 | 91×96 | 24 | 0.35 |
| RangedMuzzle | spark_01.png 2096×127 | 16 | 131×127 | 24 | 0.15 |
| EnemyHit | impact_01.png 2192×98 | 16 | 137×98 | 24 | 0.20 |
| EnemyDeath | death_01.png 3168×126 | 24 | 132×126 | 20 | 0.30 |

### 防範措施
- 任何新 VFX .tscn 必須使用 AtlasTexture sub-resource 格式
- sensor-scan.ps1 新增 Check 6+（後續）：驗證 SpriteFrames frame 沒有 region 直接欄位

---

## New Pattern（Session 9 - ERR-024）

| Date | Context | Best Practice |
|------|---------|--------------|
| 2026-06-13 | Godot 4 SpriteFrames | 每幀 MUST 使用 AtlasTexture sub-resource (atlas=tex, region=Rect2); 直接在 frame dict 寫 region 會被忽略 |
| 2026-06-13 | VFX spritesheet load_steps | load_steps = 2 + frameCount + 1（2 ext_resource + N AtlasTexture + 1 SpriteFrames） |
| 2026-06-13 | VFX 驗證 | 建立 VFX 場景後在 Godot 編輯器打開確認 Animation Frames 面板顯示的是個別幀（非整條 sheet） |
---

## ERR-025 sensor-scan.ps1 Self-Defects (2026-06-13)

### Bug A: IDE Syntax Error (Line 190 area)
- Symptom: VS Code PS Language Server reports unexpected { } tokens in Where-Object
- Root Cause: Multi-line pipeline with Where-Object { } caused IDE parser misparse
- Fix: Use .Contains() instead of -notmatch regex inside multi-line pipelines

### Bug B: ERR-014 False Positives (CRITICAL)
- Symptom: @export var and @onready var (valid Godot 4 syntax) flagged as deprecated Godot 3
- Root Cause: Pattern '^export var' with TrimStart('^') left 'export var', matched anywhere in trimmed line including '@export var'
- Fix: Use .StartsWith('export var ') for exact prefix match (correctly excludes @export var)

### Bug C: Check 2/7 scope inconsistency
- Symptom: Check 2 only scanned scenes/ dir, checks 6 and 7 scanned all Root
- Fix: Unified all checks to use same tscnFiles list from Root

### v3 Fix Summary
- File lists collected once at top, reused across all 7 checks
- Where-Object with .Contains() -- no more multi-line brace confusion
- ERR-014 uses .StartsWith() -- precise prefix matching
- ERR-024 uses .Contains() -- no regex escape issues

### Prevention
- Any change to sensor-scan.ps1 must be followed by PS AST syntax check
- Use .Contains()/.StartsWith() over -match for deterministic string checks

---

## ERR-026 Melee VFX Not Visible — visible=false in Root Node (2026-06-13)

- **Severity**: High（近戰攻擊特效完全不可見）
- **Error Type**: VFX Visibility Bug
- **Files Affected**: MeleeSlash.tscn, MeleeSlash2.tscn, MeleeImpact3.tscn
- **Symptom**: 玩家近戰攻擊時無任何 VFX 顯示，但程式碼邏輯正確，headless 無錯誤
- **Root Cause A (Critical)**: `MeleeSlash.tscn` 和 `MeleeImpact3.tscn` 的根節點設有 `visible = false`。雖然 `one_shot_vfx.gd` 呼叫了 `_sprite.play("default")`，AnimatedSprite2D 子節點在動畫播放，但根節點不可見 → 整個 VFX 不顯示。
- **Root Cause B (Warning)**: `MeleeSlash2.tscn` 的 AnimatedSprite2D 設有 `frame = 15, frame_progress = 1.0`（最後一幀），Godot 場景載入時預設最後一幀狀態，若動畫未及時 reset 可能顯示靜止最後一幀後立即觸發 `animation_finished` 並 queue_free。
- **Root Cause C (Warning)**: `MeleeImpact3.tscn` 的 AnimatedSprite2D 有 `autoplay = ""`，雖然 one_shot_vfx.gd 有自己 play("default")，但留空 autoplay 不夠清晰。
- **Fix**:
  1. `MeleeSlash.tscn` — 移除根節點 `visible = false`
  2. `MeleeSlash2.tscn` — 移除 `frame = 15` 和 `frame_progress = 1.0` 預設值
  3. `MeleeImpact3.tscn` — 移除根節點 `visible = false`，移除 `autoplay = ""`
  4. `player.gd` — 移除 `_spawn_melee_vfx_at_marker` 中的 modulate 染色（GDD 更新為原色）
- **Design Change**: GDD [CONFIRMED 2026-06-13] 近戰 VFX 使用原色，不繼承玩家顏色
- **Prevention Rule**: **VFX 場景的根節點絕對不能設 `visible = false`**。`one_shot_vfx.gd` 依賴根節點可見才能顯示動畫。若需隱藏測試場景，使用 Godot Editor 的眼睛圖示（不寫入 tscn）。
- **Responsibility**: Developer（未在建立 VFX 場景後驗證在遊戲中可見性）

---

## 🟢 New Pattern (Session 10 - ERR-026)

| Date | Context | Best Practice |
|------|---------|----|
| 2026-06-13 | VFX 根節點可見性 | **VFX 根節點絕對不能有 `visible = false`**；one_shot_vfx.gd 依賴可見性播放動畫 |
| 2026-06-13 | AnimatedSprite2D frame 預設值 | 不要在 .tscn 中設 `frame = N`（尤其接近末尾），會讓動畫從非第0幀開始播放 |
| 2026-06-13 | VFX 場景建立後驗證 | 在 Godot Editor 打開場景，直接執行 preview；或 headless 加 debug 輸出確認 instantiate 被呼叫且節點可見 |

---

## ERR-027 player.tscn 缺少 VFX 配置 — 基底場景被遺漏 (2026-06-13)

- **Severity**: Critical（近戰攻擊特效在實際遊戲中完全無效）
- **Error Type**: Scene Configuration Error / Review Coverage Gap
- **File Affected**: `scenes/player/player.tscn`（基底玩家場景）
- **Symptom**: 即使 player1/2/3/4.tscn 已完整配置 VFX，在 test_room_a / test_room_b 中仍然看不到攻擊特效
- **Root Cause**: test_room_a 和 test_room_b 使用的是 `player.tscn`（基底場景），而非 `player1.tscn`。基底場景缺少：
  - `MeleeVFXPivots / Hit1Pivot / Hit2Pivot / Hit3Pivot`（Marker2D 節點群組）
  - `melee_slash_scene` / `melee_slash2_scene` / `melee_impact3_scene` @export 賦值
  - `muzzle_flash_scene` / `bullet_scene` @export 賦值
- **Detection Failure**: Developer 和 Reviewer 只驗證了 player1~4.tscn，**沒有追蹤測試場景實際載入的是哪個 player 場景**。QA 沒有執行「實際遊戲流程」的驗證（只做 headless VFX 場景測試，未測試 player scene 配置）。
- **Fix**: 更新 `player.tscn` 加入完整 VFX 配置，對齊 player1~4.tscn 的結構。
- **Workflow Failure Pattern**:
  1. **Developer** 在修復「所有 player 場景」時，未意識到基底場景 player.tscn 也需要更新
  2. **Reviewer** 審查時只看到「player1~4 有 VFX 配置」，未追蹤 test room 實際使用哪個場景
  3. **QA** 做 headless 驗證時直接測試 VFX 場景，未模擬完整玩家攻擊流程
  4. 三個角色都沒有「從使用者視角」追蹤：從主場景 → test_room → player 的完整引用鏈
- **Prevention Rules (新增)**:
  - **Rule 1**: 任何 player 場景修改後，必須追蹤所有引用該 player 場景的 .tscn（grep `player.tscn`）
  - **Rule 2**: QA 驗證 VFX 必須包含「從使用者視角的完整流程」（player instantiate → VFX spawn），不能只驗證孤立的 VFX 場景
  - **Rule 3**: @export PackedScene 修改後，必須確認**所有**引用該腳本的 .tscn（不只是 numbered 版本）
  - **Rule 4**: Reviewer 必須在 PR 中追蹤「測試場景使用的實際 player 場景」

---

## 🟢 New Pattern (Session 11 - ERR-027)

| Date | Context | Best Practice |
|------|---------|----|
| 2026-06-13 | Player 場景多版本管理 | player.tscn（基底）+ player1/2/3/4.tscn 修改後，必須同步所有版本。用 `grep -r "player.tscn"` 確認所有引用 |
| 2026-06-13 | QA 驗證覆蓋範圍 | VFX 驗證不能只測試 VFX 場景本身，必須從玩家場景出發（player instantiate → marker → VFX spawn 全流程） |
| 2026-06-13 | @export 配置覆蓋 | 新增 @export PackedScene 後，必須更新所有引用該腳本的 .tscn，包含基底場景 |
| 2026-06-13 | 工作流盲點 | AI 修改多版本場景時容易遺漏「主要使用的基底場景」。必須以測試場景（test_room）為起點追蹤引用鏈 |

---

## GAP-012 AI 在 GDD 重設時擅自標記 [CONFIRMED]（2026-06-19）

- **Severity**: Medium（設計流程污染，需要回滾）
- **類型（§LEARN）**: (C) 設計缺陷 — SOP 遺漏了必要的驗證步驟
- **發現者**: 用戶（人工審查）
- **發生場景**: AI 在「清空舊代碼、重設 GAME_DESIGN.md」任務中，將根據閒聊討論得出的設計方向直接標記為 `[CONFIRMED]`（包含 §1.1 核心定位、1.2 遊戲類型、1.3 核心設計支柱、7.2 可用資產等 5 處）
- **哪個步驟沒攔截它**: pre-commit hook 只驗證 Designer 身份，不驗證 [CONFIRMED] 是否有正式設計授權
- **根本原因**: 工作流 Bootstrap 流程（§D4）規定「從模板建立（所有欄位 [DRAFT]）」，但「重設既有 GDD」的 SOP 未明確指出同樣規則。AI 將非正式討論誤認為已確認的設計決策。
- **修復**: 將所有擅自標記的 [CONFIRMED] 改回 [DRAFT]（commit 27300b2）
- **防範規則（新增）**:
  - **Rule**: 任何情況下新寫入 GAME_DESIGN.md 的設計內容，一律從 [DRAFT] 開始，不論討論多麼明確
  - **Rule**: [CONFIRMED] 只能在用戶明確於設計對話中批准後由 Designer 角色修改
  - **升級路徑（§LEARN Step 4）**: ✅ 已升級至機器層（2026-06-19）：`hooks/pre-commit` v4 新增 [通用規則 0c] — 偵測到新增的 [CONFIRMED] 行時 FAIL（不僅是警告），阻斷提交

---

## GAP-013 workflow.md 從未 merge 進 main 分支（2026-06-19）

- **Severity**: High（主分支遺失核心工作流文件，若 feature 分支刪除則永久消失）
- **類型（§LEARN）**: (D) 流程空白 — 規則存在但無機制確保其有效性
- **發現者**: 用戶（人工審查）
- **發生場景**: `workflow.md` 自 2026-06-17 納入版控（commit 9c5c728，feature/enemy-spawner-rooms），但在 AI 清空 main 分支時發現它從未 merge 進 main。AI 執行清理前未確認 main 上是否存在此文件。
- **哪個步驟沒攔截它**: 清理前沒有 `git ls-files workflow.md` 確認文件存在；sensor-scan.ps1 不掃描 feature branch 是否有未 merge 的核心文件
- **根本原因**: workflow.md 只存在於 feature branch，從未被 merge 或 cherry-pick 進 main。清理計劃中也未列出「確認 workflow.md 在 main 上存在」的步驟。
- **修復**: `git checkout feature/enemy-spawner-rooms -- workflow.md`（commit 27300b2）
- **防範規則（新增）**:
  - **Rule**: 任何清理/重設 main 分支前，必須先執行 `git ls-files workflow.md roles/ hooks/` 確認核心工作流文件已在 main 上追蹤
  - **Rule**: workflow.md、roles/、hooks/ 屬於「永遠必須在 main 上存在」的文件，任何 merge/branch 操作後需確認
  - **升級路徑（§LEARN Step 4）**: ✅ 已升級至機器層（2026-06-19）：`hooks/pre-push` v2 新增 GAP-013 檢查 — push 至 main 時若 workflow.md / roles/ / hooks/ 不存在則 FAIL，阻斷推送

---

## GAP-014 GUT 測試在缺少 Addon 時造成 Parse Error（2026-06-19）

- **Severity**: Medium（Godot Editor 啟動即顯示錯誤，分散注意力，破壞 sensor --check-only）
- **類型（§LEARN）**: (C) 設計缺陷 — 測試框架依賴未被驗證即寫入
- **發現者**: 用戶（Godot Editor 錯誤通知）
- **症狀**: `Failed to load script "res://tests/test_needle_manager.gd" with error "Parse error".` 及 `test_wire_constraint.gd` 同樣錯誤
- **發生場景**: `tests/test_wire_constraint.gd` 和 `tests/test_needle_manager.gd` 均使用 `extends GutTest`，但 `addons/gut/` 目錄不存在。Godot 嘗試解析所有 `res://` 下的 .gd 文件，找不到 `GutTest` 類別 → Parse Error。
- **哪個步驟沒攔截它**: Sensor [8/21] `--check-only` 會發現但未能阻斷 Developer commit（應為 FAIL）；開發時誤以為 GUT 測試可以在無 Addon 的情況下存放於 res:// 目錄
- **根本原因**: Godot 在啟動時掃描整個 `res://` 下的所有 .gd 文件並嘗試解析；使用 `extends <未知類>` 會立即 Parse Error。`tests/` 目錄缺少 `.gdignore` 保護。
- **修復**:
  1. 在 `tests/` 目錄新增 `.gdignore` 空文件 → Godot 忽略此目錄（標準 Godot 做法）
  2. Sensor [22/22] 新增：偵測 tests/*.gd 使用 `extends GutTest` 但 `addons/gut/` 不存在 → WARN
- **防範規則（新增）**:
  - **Rule**: 任何使用第三方測試框架（GUT、WAT 等）的 .gd 測試文件，必須確保 `tests/.gdignore` 存在，否則 Godot 啟動即 Parse Error
  - **Rule**: 安裝 GUT addon 後刪除 `.gdignore` 才能讓 Godot Editor 的 GUT runner 發現測試
  - **升級路徑（§LEARN Step 4）**: ✅ 已升級至機器層（2026-06-19）：sensor v12 [22/22] — tests/*.gd 含 `extends GutTest` 但無 `addons/gut/` → WARN

---

## GAP-015 跨腳本 class_name 在 --check-only 模式導致 Parse Error（2026-06-19）

- **Severity**: High（Sensor [8/21] --check-only 失敗，阻斷所有 Developer commit）
- **類型（§LEARN）**: (A) 技術認知缺口 — Godot 4.6 class_name 跨腳本限制
- **發現者**: Sensor [8/21] --check-only（開發中間阻斷）
- **症狀**: Godot `--check-only` 對含有跨腳本 class_name 型別標注的 .gd 輸出 `ERROR: Parse error`
- **受影響文件**: `player.gd`、`needle_manager.gd`、`needle_anchor.gd`、`wire_platform.gd`、`debug_overlay.gd`（第一輪）；`needle_manager.gd`（第二輪，含更多跨腳本引用）
- **根本原因**: Godot 4.6 `--check-only` 在解析單一腳本時，不能保證其他腳本的 `class_name` 已被 Godot 完全注冊。導致：
  1. `var x: CustomClass` — `CustomClass` 不在當前解析上下文 → Parse Error
  2. `CustomClass.SomeEnum.VALUE` — 跨腳本 enum 存取 → Parse Error
  3. `CustomClass.new()` — 未 preload 的跨腳本實例化 → Parse Error
  4. `signal foo(param: CustomClass)` — 信號參數型別標注 → Parse Error
- **修復（已應用）**:
  1. 跨腳本型別變數 → 改用基礎型別：`var x: RefCounted`、`var y: Node`、`var z: Node2D`
  2. 跨腳本 enum 存取 → 改用本地整數常數：`const _ANCHOR_WIRE := 1  # NeedleAnchor.Type.WIRE`
  3. 跨腳本實例化 → 改用 preload：`const _Script = preload("res://scripts/foo.gd"); _Script.new()`
  4. 跨腳本方法呼叫 → 改用 `call()`：`obj.call("method_name", arg1, arg2)`
  5. 信號參數型別標注 → 移除或改用 `Object`：`signal foo(param)`
- **防範規則（新增）**:
  - **Rule**: 任何跨腳本的型別引用，一律使用以上 5 種 workaround pattern（見下方 PATTERN 條目）
  - **Rule**: 測試文件中的跨腳本 class_name 引用同樣適用此規則（GAP-015 的衍生問題：`test_needle_manager.gd` 使用 `NeedleManager.new()`、`NeedleAnchor.Type.ATTACK`）
  - **升級路徑（§LEARN Step 4）**: ✅ 已由 Sensor [8/21] --check-only 自動偵測（parse error → FAIL）；workaround pattern 記錄於下方 PATTERN 條目

---

## 🟢 Pattern — GAP-015 Workarounds（跨腳本 class_name 的 5 種解法）

| 場景 | 錯誤寫法 | 正確寫法 |
|------|---------|---------|
| 跨腳本型別標注 | `var x: WireConstraint = null` | `var x: RefCounted = null` |
| 跨腳本 Node 型別 | `var p: Player = null` | `var p: Node = null` |
| 跨腳本 Node2D 型別 | `var a: NeedleAnchor = null` | `var a: Node2D = null` |
| 跨腳本實例化 | `WireConstraint.new()` | `const _S = preload("res://scripts/wire_constraint.gd"); _S.new()` |
| 跨腳本 enum 存取 | `NeedleAnchor.Type.WIRE` | `const _WIRE := 1  # NeedleAnchor.Type.WIRE` |
| 跨腳本方法呼叫（typed） | `typed_node.custom_method()` | `typed_node.call("custom_method")` |
| 信號跨腳本型別參數 | `signal foo(p: CustomClass)` | `signal foo(p)` 或 `signal foo(p: Object)` |

---

## GAP-017 RayCast2D 方向在 Local vs World Space 混用（2026-06-20）

- **Severity**: Medium（斜向/垂直射擊時 RayCast2D 方向錯誤，僅水平射擊正常）
- **現象**: 鋼針以非水平方向射出時，`RayCast2D` 的碰撞偵測方向錯誤（偵測到不該偵測的位置），極端情況（90°）時射線方向與移動方向垂直；水平射擊（0°）不受影響。
- **根本原因**: `needle_projectile.gd` 中 `_ray.target_position = move * 1.2` — `move` 是 **world-space** 向量，但 `RayCast2D.target_position` 是 **local-space**。當節點旋轉（`rotation = direction.angle()`）時，兩者不等價：world `(0, spd)` 在 local space（旋轉 90°）會映射為 `(-spd, 0)`，射線向左而非向下。
- **修復**: `_ray.target_position = Vector2(step * 1.2, 0)`。由於針已旋轉至 `direction.angle()`，local X 軸在 world space 即為飛行方向，永遠正確。
- **副作用修復**: 加入邊界清除 (`queue_free()`) 當 projectile 逃出螢幕範圍（`x < -64 or x > 544 or y < -64 or y > 334`），防止 `_in_flight` 計數永遠累積、無法再射針。
- **場景問題（根本原因之二）**: MVP_Test.tscn 原本無牆壁/天花板，針射出後飛出螢幕邊界消失，`_in_flight` 不會歸零，3 根後完全無法射擊。已修復為封閉房間。
- **防範規則**: `RayCast2D.target_position` **永遠用 local-space 設置**；若節點有旋轉，沿 local X 軸的 `Vector2(距離, 0)` 即為射線正前方。

---

## GAP-018 UX 假陷阱：射擊成功但使用者無法察覺（2026-06-20）

- **Severity**: Low-Medium（功能管線正確，但使用者認為滑鼠無反應）
- **現象**: 點擊 LMB 後完全無視覺回饋 — 使用者回報「滑鼠沒有反應」。
  實際狀況：3 發針全部正確射出並嵌入牆面（`_spawn_projectile` 呼叫成功）；第 4 次點擊因 `max_needles=3` 達上限，`shoot_attack_needle()` 靜默 return 無任何提示。
  MCP debug 確認：`_spawn_projectile: scene=true layer=true from=(...) dir=(...)` 出現 3 次；第 4 次點擊只有 `count=3` → 無 spawn。
- **根本原因（三層疊加）**:
  1. 視窗 480×270 → 12×2 px 鋼針投影物在螢幕上幾乎不可見（1:1 像素）
  2. `NeedleAnchor.tscn` 無任何 Visual 節點 → 針嵌入後零視覺殘留，使用者無法確認位置
  3. `max_needles=3` 達到後 `shoot_attack_needle()` 直接 `return`，無 sound/flash/UI feedback
- **修復**:
  1. `project.godot` 視窗改為 960×540（canvas_items 2× 縮放，針放大至 24×4 視覺像素）
  2. `NeedleAnchor.tscn` 新增 8×8 黃色 ColorRect → 嵌入的針可見
- **診斷過程（MCP trace）**:
  - 在 `NeedleManager._ready()` 加入 print → 確認 `needle_layer=true`（排除 null 靜默失敗）
  - 在 `player.gd _unhandled_input` + `_spawn_projectile` 加入 print → 確認事件鏈完整
  - MCP `get_debug_output` 讀取確認所有 `[DBG]` 均在預期位置觸發
- **防範規則**:
  - QA **必須**驗證互動功能（LMB 射針、移動、跳躍），不能只確認啟動無錯誤
  - 任何「使用者觸發 → 系統反應」的功能必須有**可見視覺 feedback**（V1 TODO：max 提示）
  - `max limit 靜默 return` 視為 UX 缺陷，須加 UI feedback（Phase 1）

---

## GAP-019a `canvas_items` stretch 導致房間縮到視窗左上角（2026-06-20）

- **Severity**: High（房間永遠比視窗小，無法游玩）
- **現象**: 視窗 960×540，遊戲內容（480×270 房間）只佔視窗中央一個小矩形，四周深灰色。Camera2D limits (0–480 × 0–270) 把畫面釘在 canvas 左上角，外面是空 canvas 背景。
- **根本原因**: `canvas_items` 模式把 Canvas 擴大至視窗尺寸（960×540）。房間節點座標 0–480 × 0–270 只佔擴大後 canvas 的左上四分之一；Camera2D limit 限定攝影機只顯示那塊，顯示結果是小房間居中、周圍灰色。
- **修復**: `window/stretch/mode="viewport"` + `window/stretch/aspect="keep"`。`viewport` 先以 480×270 渲染再 2× 縮放填滿 960×540，房間完全貼齊視窗四邊。
- **防範規則**: 固定解析度 2D 遊戲一律用 `viewport`；`canvas_items` 用於 UI 隨視窗縮放場合。

## GAP-019b NeedleProjectile RayCast2D 偵測 Player，針立刻嵌入自身（2026-06-20）

- **Severity**: High（射針立刻卡在 player 旁邊，無法飛向牆壁）
- **現象**: LMB 點擊後黃色 anchor 立即出現在 ThrowOrigin 位置，不飛出去。
- **根本原因**: 所有 PhysicsBody2D 預設 Layer 1，`RayCast2D`（mask=1）因此也偵測到 Player（CharacterBody2D，layer=1）。ThrowOrigin 在 player 碰撞形狀邊緣，Ray 出發時觸及 player 自身 CollisionShape2D → 立即 embed。
- **修復**:
  - `Player.tscn`: `collision_layer=2, collision_mask=1`（player 在 layer 2，仍碰牆壁 layer 1）
  - `NeedleProjectile.tscn` RayCast2D: 明示 `collision_mask=1`（只偵測 layer 1 = 牆/平台）
- **防範規則**: 投射物/感測器建立時必須明確設 `collision_mask`；Layer 架構建議：Layer 1=World, Layer 2=Player, Layer 3=Enemy, Layer 4=Projectile。

---

## GAP-020 繩子系統三重 Bug + 房間太小（2026-06-20）

### GAP-020a WireRenderer 跟著滑鼠亂動

- **Severity**: High（視覺完全錯誤，繩子感覺「飄」到滑鼠位置）
- **現象**: 射出 Wire 針並嵌入後，黃色細線從 Player 出發，但終點似乎隨滑鼠移動。
- **根本原因**: `WireRenderer`（Line2D）是 Player 的子節點，繼承 Player 的 `scale.x = ±1`（左右翻轉鏡像）。`add_point(to_local(_wire.anchor_pos))` 數學上正確，但 Line2D 本身也被 scale 影響，導致視覺位置在 scale 切換時錯位。
- **修復**: `wire_renderer.top_level = true`（Line2D 在世界座標渲染，脫離 Player transform）；點改為全局座標 `add_point(global_position)` / `add_point(_wire.anchor_pos)`。
- **防範規則**: 任何需要「在世界空間固定顯示」的子節點 Line2D/Node2D，若父節點有 scale flip，必須設 `top_level = true`。

### GAP-020b 飛行中沒有繩子延伸視效

- **Severity**: Medium（使用者不知道「有沒有射出」，等針嵌入才看到線）
- **現象**: RMB+LMB 射出 Wire 針，飛行期間螢幕上只有一個 12×2 黃色小點飛過，沒有從 Player 拉出的線條。
- **根本原因**: `wire_anchor_ready` 信號在針**嵌入後**才發射，WireRenderer 才出現。飛行期間完全無視覺。
- **修復**: NeedleManager 新增 `wire_needle_launched(proj: Node)` 信號，Player 在 `_update_wire_renderer()` 每幀追蹤 `_wire_projectile.global_position`，畫出延伸線。
- **防範規則**: 任何飛行投射物若有「從發射點拉線」需求，必須在 launch 時（不是 embed 時）開始渲染視覺線。

### GAP-020c 射出第二根 Wire 針後第一條線仍存在

- **Severity**: Medium（視覺混亂，player 仍被第二個 anchor 約束而非脫繩）
- **現象**: 兩根 Wire 針都嵌入後，WirePlatform 出現於兩 anchor 之間，但 Player 的細黃線還在（指向第二個 anchor），Player 仍受 WireConstraint 約束。
- **根本原因**: `_try_create_platform()` 成功建立平台後，沒有通知 Player 切斷繩子約束。第二根針嵌入時 `wire_anchor_ready` 又發射一次，Player._wire 更新為第二個 anchor 的 WireConstraint，Player 繼續被約束在第二個 anchor 上。
- **修復**: NeedleManager 新增 `platform_created(anchor1, anchor2)` 信號，`_try_create_platform()` 成功後發射；Player 接收後呼叫 `_cut_wire()`（清空 `_wire`、隱藏 WireRenderer）。
- **防範規則**: 任何「狀態轉移（單針→雙針平台）」必須主動通知相關節點，不能依賴副作用。

### GAP-020d 場景對 Player 太小

- **Severity**: Medium（遊玩空間不夠，無法測試鐘擺和繩子甩動）
- **現象**: MVP_Test.tscn 房間 480×270 canvas px，player 32×64，內部高度僅 3.7 倍 player 身高，無空間測試 Wire 甩動物理。
- **根本原因**: 牆壁貼齊 viewport 邊緣，場景 = viewport，無滾動空間。
- **修復**: 場景擴大至 960×540 canvas px（5 個平台）；Camera2D limit 同步更新；Player 起始位置移至 (480, 490)；NeedleProjectile 安全邊界更新至 1024/604。
- **防範規則**: MVP 測試場景大小應至少 4× viewport area，確保有足夠空間測試所有移動機制。

---

## GAP-021 繩子系統三重修復：垂弧線 + 線條端點切換 + 單向平台（2026-06-20）

### GAP-021a 射出第二根針後第一條線消失（端點應切換而非清除）

- **Severity**: High（平台模式下無繩子視覺，設計規格違反）
- **現象**: 雙針展開成平台後，WireRenderer 消失（Player→anchor1 的線被清除），GDD §2.3 規定平台模式下應顯示 anchor1↔anchor2 垂弧線。
- **根本原因**: GAP-020c 修復（`_cut_wire()`）清空了所有繩子狀態，但 GDD 設計是「線的端點切換，不是線消失」。`_on_platform_created` 接收 `platform_created` 信號後直接呼叫 `_cut_wire()`，導致視覺被清除。
- **修復**: `_on_platform_created(a1, a2)` 改為：清空 `_wire`（釋放擺錘約束）但保留 `_wire_anchor=a1`，新增 `_wire_anchor2=a2`，設 `_platform_slack=40.0`；`_update_wire_renderer()` 新增 platform 模式分支：當 `_wire_anchor2 != null` 時畫 catenary(anchor1.global_position, anchor2.global_position, _platform_slack)。
- **防範規則**: 「狀態轉移」（擺錘模式→平台模式）必須明確辨別哪些視覺/物理狀態**繼承**（anchor1 位置）、哪些**替換**（線的另一端從 Player 改為 anchor2）、哪些**釋放**（WireConstraint）。

### GAP-021b 垂弧線（Catenary）品質驗證

- **Severity**: Medium（視覺效果問題）
- **設計要求**: GDD §2.3 要求「垂弧線（Catenary）」；用 8 段 Line2D 近似，sag = min(slack × 0.35, 60.0)，各中間點 +sag × sin(π × t) 偏移。
- **Debug 驗證（2026-06-20）**:
  - `mcp__godot__run_project` + `get_debug_output` 取得啟動時 auto-test 輸出：
    ```
    [QA] WireRenderer top_level=true (expect true)
    [QA] Catenary sag: slack=40→14.0 (expect 14.0) | slack=200→60.0 (expect 60.0)
    [QA] Catenary draw: points=9 (expect 9) | mid_y=114.0 (expect 114.0)
    ```
  - 數學驗證：from=(100,100) to=(400,100) slack=40 → sag=14 → t=0.5 → mid=(250, 100+14×sin(π×0.5)) = (250, 114) ✓
  - 上限驗證：slack=200 → sag=min(70, 60)=60 ✓（不超過 60px）
- **Godot 4 注意事項**: `Line2D.get_point_position(idx)` 回傳 `Variant`，必須明確標注型別：`var pt: Vector2 = renderer.get_point_position(i)`；用 `:=` 推斷會觸發 `Cannot infer type` parse error。
- **結論**: 垂弧線數學和渲染邏輯正確。視覺效果需用戶在遊戲中確認感受（線越鬆、弧度越深，最多 60px 下垂）。

### GAP-021c 平台從下方穿透失敗（one_way_collision 方向錯誤）

- **Severity**: High（平台設計核心機制失效：玩家無法從下方跳上去）
- **現象**: 在兩根 Wire 針之間展開的鋼索平台，玩家從下方跳躍會被整個擋住（無法穿透），且側面也有碰撞。
- **根本原因**: `WirePlatform`（StaticBody2D）的 `global_rotation = a.angle_to_point(b)` 讓整個剛體旋轉。Godot 的 `one_way_collision` 方向是相對於 **body 的世界朝上方向**（`(0, -1)` in world space）。當 body 旋轉後，one_way「朝上」方向也隨之旋轉 → 對角斜面的 one_way 方向完全錯誤。
- **修復**:
  - `global_rotation = 0.0`（body 永遠不旋轉，one_way 方向始終是世界座標的 -Y 即上方）
  - `_shape.rotation = a.angle_to_point(b)`（只旋轉 CollisionShape2D，讓形狀沿 Wire 方向對齊）
  - `_shape.one_way_collision_margin = 8.0`（增加穿透容差，避免角速度邊界滑動失敗）
- **防範規則**: 任何需要 `one_way_collision` 的平台，**body 必須保持 `global_rotation = 0`**；若平台本身是斜的，只旋轉 CollisionShape2D 子節點，body transform 不動。

---

## 🟢 Pattern — GAP-021 新增

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-20 | 繩子端點切換（擺錘→平台） | `_on_platform_created`：`_wire=null`（釋放約束），`_wire_anchor=a1`、`_wire_anchor2=a2`（保留視覺端點），不呼叫 `_cut_wire()`（那會清除全部） |
| 2026-06-20 | Catenary Line2D 多狀態管理 | `_update_wire_renderer()` 依序檢查 in-flight → platform(anchor1↔anchor2) → pendulum(player↔anchor1)，三種互斥模式分開處理 |
| 2026-06-20 | one_way_collision 斜面平台 | StaticBody2D `global_rotation=0`；CollisionShape2D `rotation=angle`；`one_way_collision_margin≥8.0` |
| 2026-06-20 | Line2D.get_point_position | Godot 4 回傳 Variant；需明確型別：`var pt: Vector2 = renderer.get_point_position(i)`；禁止 `:=` 推斷 |

---

## GAP-022 E 鍵縮線有彈簧感（應為繩子感）（2026-06-20）

**症狀**：按 E 時 player 會震盪、來回彈動，不像繩子被拉短，像彈簧。

**根本原因**：`_apply_wire()` 每 frame 執行 `velocity += to_anchor / dist * reel_speed`（速度累加），沒有位置限制。繩子超長時速度一直被推向錨點，離開後又受重力，形成振盪。

**修復**：改為直接位置收縮（winch 語意）：
```gdscript
_wire.reel_in(reel_speed, delta)          # 縮短 max_length
var to_anchor: Vector2 = _wire.anchor_pos - global_position
var dist: float = to_anchor.length()
if dist > _wire.max_length and dist > 0.0:
    position += (to_anchor / dist) * (dist - _wire.max_length)  # 立即拉齊
```
`WireConstraint.apply()` 後續仍執行速度投影，保留繩子物理。

**提交**：`241d4ed` [DEV] fix: 修正三針繩索顯示錯誤與第三針無法牽線 GAP-022/023

---

## GAP-023 第三針無法牽線（platform mode 早返阻斷）（2026-06-20）

**症狀**：在 platform mode（已有 anchor1+anchor2）時，射出第三根 wire needle 落點後，繩索系統無反應，第三針無法成為新的 pendulum anchor。

**根本原因（雙重）**：
1. `_on_wire_anchor_ready()` 開頭判斷 `if _wire_anchor2 != null: return`，platform mode 下直接跳出，新錨點被忽略。
2. `_try_create_platform()` 使用 `wire_anchors[0]` + `wire_anchors[1]`（舊 rolling），第三針落點後平台不更新。

**修復**：
- `_on_wire_anchor_ready()`：移除早返；新錨點永遠接管 `_wire_anchor`，清空 `_wire_anchor2`（讓 `platform_created` 重建平台）。
- `needle_manager._try_create_platform()`：改為 rolling window（最新兩錨點 `wire_anchors[n-2]` + `wire_anchors[n-1]`）。

**提交**：`241d4ed` [DEV] fix: 修正三針繩索顯示錯誤與第三針無法牽線 GAP-022/023

---

## GAP-024 第二針飛行途中繩線綁在兩端釘上（應顯示 anchor1→飛行針）（2026-06-20）

**症狀**：射出第二根 wire needle 飛行途中，線段立即固定顯示兩端已知錨點（anchor1↔anchor2 位置），看起來像繩已連接，視覺錯誤。

**根本原因**：`_update_wire_renderer()` Priority 2（pendulum 模式）在 `_wire_anchor` 有效時直接畫 player↔anchor1，未考慮同時有 `_wire_projectile` 在飛行中的情況。

**修復**：在 pendulum 之前插入新 Priority 2：
```gdscript
# anchor 存在 + 飛行針存在 → anchor → 飛行針
if _wire_anchor != null and _wire_projectile != null and is_instance_valid(_wire_projectile):
    wire_renderer.clear_points()
    wire_renderer.add_point(_wire_anchor.global_position)
    wire_renderer.add_point(_wire_projectile.global_position)
    return
```
結果：第二針飛行途中可清楚看到線從 anchor1 延伸至針尖（靈活延展效果）。

**提交**：`241d4ed` [DEV] fix: 修正三針繩索顯示錯誤與第三針無法牽線 GAP-022/023

---

## 🟢 Pattern — GAP-022/023/024 新增

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-20 | E 鍵縮線（winch）| 直接修改 position（winch 語意），不要累加 velocity（spring 語意）；`max_length` 同步縮短由 `reel_in()` 處理 |
| 2026-06-20 | NeedleManager 平台 rolling window | `_try_create_platform()` 永遠取 `wire_anchors[n-2]` + `wire_anchors[n-1]`（最新兩根），第三針才能觸發平台移位 |
| 2026-06-20 | 多針 wire renderer 優先順序 | P1=Platform(anchor1↔anchor2)；P2=Anchor+飛行針(anchor1→proj)；P3=Pendulum(player↔anchor1)；P4=僅飛行(player→proj) |
| 2026-06-20 | `_on_wire_anchor_ready` 不早返 | 永遠接受新錨點；platform mode 由 NeedleManager 的 `platform_created` 信號重建，player.gd 不負責 gate |

---

## GAP-025 第三針不解散舊平台 + 鋼針速度2倍（2026-06-20）

**症狀（雙重）**：
1. 射出第三根針後，舊平台（anchor1↔anchor2）立即解散，GDD §2.3「第三針在平台模式下的行為」規定平台應繼續存在。
2. 鋼針飛行速度過慢（600 px/s），難以命中目標。

**根本原因**：
1. `needle_manager._try_create_platform()` 採 rolling window（永遠用最新兩根），導致第三針落點後平台移位；`_remove_anchor` 未區分「平台端點」vs「其他針」，任何回收都觸發平台解散。
2. `needle_projectile.flight_speed = 600.0`——設計決策應為 1200 px/s（快速精準感）。

**修復**：
- `_try_create_platform`：僅在 `wire_anchors.size() == 2` 時觸發（不再 rolling），第三針只接管 pendulum anchor。
- 新增 `_platform_anchor_a/_b` 追蹤：只有平台端點回收才呼叫 `platform_dissolved`。
- `player.gd`：移除 `_wire_anchor2`，改用 `_platform_a/_platform_b` 獨立追蹤；新增 `_platform_renderer` (Line2D) 在 `_ready()` 建立，platform 金線與 pendulum wire 各自獨立渲染。
- `needle_projectile.flight_speed`：600.0 → 1200.0。

**提交**：`7f4d627`

---

## GAP-026 平台 one-way 卡頭 + 視覺細線 + wire_slack 收緊（2026-06-20）

**症狀（三重）**：
1. 玩家站在鋼索平台上時會有明顯「卡頭感」——腳陷入平台一截。
2. 平台線條太粗（3px），視覺上比擺錘繩線重，不協調。
3. 單錨點繩子初始下垂過大（slack=80），影響鐘擺感。

**根本原因**：
1. `platform_height = 24.0` 過高；玩家落地後腳底仍有 12px 深度才碰到碰撞底部 → 視覺「卡頭」。
2. `_platform_renderer.width = 3.0` 過粗。
3. `wire_slack = 80.0` 初始值過大。

**修復（wire_platform.gd + player.gd）**：
- `platform_height`：24.0 → 4.0（薄板，消除卡頭深度）
- `_platform_renderer.width`：3.0 → 1.5
- `wire_slack`：80.0 → 30.0

**one-way 法向重建**（本 GAP 包含的架構修正）：
- `global_rotation = wire_angle`（body 跟線旋轉）→ local +Y 垂直線段，one-way 法向在 world space 仍朝上
- `_shape.rotation = 0.0`（shape 保持 body local 座標）
- ⚠️ 此方案後來被 GAP-027 二次修正（見下）

**提交**：`94213f7`

---

## GAP-027 平台 one-way 方向在第一錨點靠右時翻轉（2026-06-20）

- **Severity**: High（右牆先射、左牆後射的平台，玩家從下方無法穿透）
- **類型（§LEARN）**: (A) 實作 Bug — Godot one-way_collision 方向理解錯誤
- **發現者**: 用戶（遊戲測試）
- **現象**: 先射右牆（anchor\_a = 右）、再射左牆（anchor\_b = 左）形成的平台，玩家從下方跳躍被完全擋住。先射左牆則正常。

**根本原因**：
- `global_rotation = a.angle_to_point(b)`：當 a 在右、b 在左時，`angle_to_point` 回傳約 π（180°），導致 StaticBody2D 旋轉 180°。
- Godot `one_way_collision` 的「朝上」方向是 body local space 的 `(0, -1)` 轉換到世界座標。body 旋轉 180° → world space 朝上變成朝下 → 平台只允許從**上方**穿透（即從下方被擋住）。
- GAP-026 的修正（`global_rotation = wire_angle`）在 anchor\_a < anchor\_b 時正確，在 anchor\_a > anchor\_b 時重現同問題。

**修復（wire\_platform.gd `_update_body()`）**：
```gdscript
var dir := b - a
if dir.x < 0.0:
    dir = -dir  # 強制 dir.x ≥ 0，讓旋轉角維持在 ±90° 內
global_rotation = dir.angle()
```

**防範規則（新增）**：
- `one_way_collision` 平台不得讓 body 旋轉超過 ±90°；確保 body local `-Y` 在世界空間仍朝上。
- **計算平台角度時永遠先正規化方向向量**：`if dir.x < 0: dir = -dir`。

**升級路徑（§LEARN Step 4）**: Sensor Check — wire_platform.gd `_update_body()` 若含 `angle_to_point` 且無方向正規化則 WARN（候補）。

**提交**：`d408e03`

---

## GAP-028 平台視覺下垂 + S 鍵穿透（2026-06-20）

- **Severity**: N/A（新功能，非 bug）
- **實作者**: Developer
- **GDD 依據**: §2.3 鋼索平台行為（更新版見 GAME_DESIGN.md）

**功能說明**：
1. **視覺下垂（Visual Sag）**：玩家站在平台上，catenary 曲線的 `_platform_slack` 朝 `SAG_WEIGHT=20.0` 插值；離開後朝 0 插值。
2. **S 鍵穿透（Drop-through）**：按下 `drop_through` action → 關閉 mask layer 4（平台碰撞），0.25s 後恢復。

**關鍵實作細節**：
- `WirePlatform`：`collision_layer` 改為 layer 4（bitmask = 8），不在 default layer 1。
- `player.gd _ready()`：`set_collision_mask_value(4, true)` → player 也感知 layer 4 的平台。
- `_update_platform_sag(delta)`：透過 `get_slide_collision(i).get_collider() is WirePlatform` 偵測站台；`lerpf` 控制 `_platform_slack`。
- Drop-through：`_drop_through_timer = 0.25`; `set_collision_mask_value(4, _drop_through_timer <= 0.0)` 在 `move_and_slide()` 前執行。

**GUT 自動化測試（7/7 PASS）**：
- layer bitmask = 8，one_way 保留，player mask 含 layer 4，timer 切換 mask，sag 數學（不超出 SAG_WEIGHT），sag 歸零，旋轉 <90°（GAP-027 隨測）。

**GUT 版本問題（衍生）**：GUT v9.6.0 無 `assert_le()`/`assert_ge()`，改用 `assert_true(value <= x)` / `assert_true(value >= x)`。

**提交**：`c257add` + `d5cc703` + `40d96e6`

---

## 🟢 PATTERN — 驗證 SOP（QA / Developer 通用）

| 日期 | 場景 | 正確做法 |
|------|------|---------|
| 2026-06-20 | Godot 遊戲執行驗證（QA） | 使用 `mcp__godot__run_project` + `mcp__godot__get_debug_output` 取得 runtime 輸出；或跑 GUT 自動化測試 |
| 2026-06-20 | **⚠️ computer-use 無法存取 Godot 遊戲** | `request_access` 只適用於 Windows 開始功能表已安裝的 App。Godot 遊戲 EXE（`./Godot_v4.6.2-stable_win64.exe`）不在開始功能表 → `request_access("Godot Engine")` 永遠失敗。正確方案：GUT 自動化測試（首選）；或 `mcp__godot__run_project` + `mcp__godot__get_debug_output`（MCP）；禁止嘗試 computer-use 存取 Godot EXE。 |
| 2026-06-20 | GUT v9.6.0 assert 語法 | 無 `assert_le()`/`assert_ge()`；改用 `assert_true(value <= x, "msg")` 和 `assert_true(value >= x, "msg")` |
| 2026-06-20 | one_way_collision 角度計算 | 計算前先正規化：`if dir.x < 0: dir = -dir`；確保 body rotation 在 ±90° 內，否則 one-way normal 翻轉 |

---

## GAP-029 F 回收鐘擺錨點後線跳到舊錨點（2026-06-20）

- **Severity**: High（操作錯誤：使用者想停止盪繩，結果線移到不相關的錨點）
- **現象**: 在鐘擺模式（單一 wire anchor 盪繩）按 F 回收當前錨點後，線跳到另一根已嵌入但沒有連線的舊 wire anchor。
- **根本原因**: `needle_manager._remove_anchor()` 最後無條件執行：
  ```gdscript
  var remaining := get_wire_anchors()
  if remaining.size() > 0:
      wire_anchor_ready.emit(remaining[0])  # 永遠 re-emit！
  ```
  這讓 player.gd 的 `_on_wire_anchor_ready` 重新建立一條到 `remaining[0]` 的線，覆蓋了 `needle_retrieved` 的清空動作。
- **修復**: 加入 `platform_dissolved` flag，只在平台解散時才 re-emit（平台端點回收 → 轉換為鐘擺是設計意圖；鐘擺錨點回收 → 線應消失）：
  ```gdscript
  if platform_dissolved:
      var remaining := get_wire_anchors()
      if remaining.size() > 0:
          wire_anchor_ready.emit(remaining[0])
  ```
- **防範規則**: 任何「回收後自動轉換」的邏輯，必須區分「主動解散（平台）」vs「單純回收（鐘擺）」兩種情境。
- **提交**: `707d051`

## GAP-030 Ponytail 強制機制文件與實作脫節（2026-06-20）

> ⚠️ **已於 2026-06-20 由 GAP-031 撤銷**：本條目「補實作」的 Ponytail 強制機制本身即為用戶早已決定移除的舊機制。當時 session 誤判前次移除為「未授權」而重新加回——此判斷錯誤。以下保留為歷史記錄。

- **Severity**: Medium（工作流合規缺口，commit-msg 宣稱強制但未實際阻斷）
- **現象 1**: `hooks/commit-msg` header 寫 `v2`，但 echo 輸出 `[commit-msg v3]` — 版本自洽性失效，sensor Check 19/22 無法偵測（只看 pre-commit）。
- **現象 2**: `workflow.md §I` 宣稱 `commit-msg v3 FAIL` 強制 `[Ponytail] rung=N`；實際 commit-msg 被前 AI session 以「用戶決定移除」為由刪除此邏輯（無用戶授權）。
- **現象 3**: `hooks/pre-commit` v6 header 宣稱有 `[Developer/Ponytail-A]` 檢查；實際 Developer 區塊中無此代碼。
- **根本原因**: AI session 修改 hook 時未執行 §EDIT.2（Hook 邏輯驗證），未用實際 sh 測試驗證修改後行為，導致文件聲稱的強制機制為空殼。
- **修復**:
  1. `hooks/commit-msg` → v3 統一；新增 Ponytail 強制（feat/fix/refactor/style/perf → FAIL if no `[Ponytail] rung=N`）+ fix/ERR hint（WARN）
  2. `hooks/pre-commit` → 在 Developer 區塊末端加入 `[Developer/Ponytail-A]` 實際代碼
- **防範規則**: 修改任何 hook 後必須用 `sh hook_file tmp_commit_msg_file` 實際執行測試（§EDIT.2），不可假設文件描述等於實際阻斷行為。
- **提交**: 本次 commit

## GAP-031 Ponytail 7-rung 機制完整移除（用戶授權，2026-06-20）

- **Severity**: Medium（移除舊機制；不影響遊戲功能與其他工作流閘門）
- **背景**: Ponytail 7-rung ladder 為早期引入的開發哲學機制（GLOBAL-RULE-002）。用戶先前已決定移除，但移除不徹底；GAP-030 session 更誤判該移除為「未授權」而重新加回強制邏輯。
- **用戶裁定**: 用戶明確確認 Ponytail 為**舊機制，應完整移除**，且 GAP-030 的回加屬錯誤判斷。
- **移除範圍**:
  1. `hooks/commit-msg` v3→v4：刪除 `[Ponytail] rung=N` 強制區塊（代碼類 commit 不再 FAIL）
  2. `hooks/pre-commit` v6→v7：刪除 `[Developer/Ponytail-A]` `.gd ponytail:` 注解檢查
  3. `scripts/sensor-scan.ps1`：刪除 Check 20（SAS-A Ponytail 7-rung 重複偵測），22 checks → 21 checks
  4. `workflow.md`：移除 GLOBAL-RULE-002 階梯定義、§I 規則表、§SAS-A、§EDIT.2/.4、§LEARN 等所有 Ponytail 引用
  5. `docs/implementation_plan.md`、`scripts/*.gd`：移除 `# ponytail: rung=N` 注解與 Rung 欄位
- **保留（未受影響的其他功能）**: 6 角色串行流、角色隔離閘門、BOM/UID/編碼驗證、物理回呼掃描、commit 格式驗證、`[ROLE] type:` 規範、CASCADE 0e/0f、SOP PENDING push 阻斷。
- **附帶優化**: 新增 GLOBAL-RULE-004（防止鬼打牆/無限循環）——限制重試次數、commit 被阻斷時讀錯誤再修、小型維護不啟動重型 5 角色流程，修正「卡進 loop」問題。
- **防範規則**: Ponytail 為用戶授權移除之機制；**後續 session 不得以「未授權」為由重新加回**（避免重演 GAP-030）。
- **驗證**: `sensor-scan.ps1` 21/21；commit-msg/pre-commit 以 sh 實測（§EDIT.2）。
- **提交**: 本次 commit

## GAP-032 Q 斷線 / F 優先級回收重做（2026-06-20）

- **Severity**: Feature（操控語意調整，非錯誤修復）
- **需求（用戶）**:
  1. **Q** 只能切斷「當前與 player 相連的擺錘線」；線若已成平台則 Q 無法切斷，須先用 F 回收平台一端。
  2. **F** 可回收當前與 player 相連的線。
  3. 回收**優先級**：無牽線鋼針（攻擊針）> 與 Player 連接的鋼針（擺錘）> 建立平台的鋼針。
- **實作**:
  - `scripts/player.gd`：`_cut_wire()` 僅在有 active 擺錘（`_wire/_wire_anchor`）時生效，且不再清平台狀態；retrieve 改傳 `_wire_anchor`。
  - `scripts/needle_manager.gd`：`try_retrieve(player_pos, connected_anchor)` 改為依 `_retrieve_priority()`（攻擊0<wire1<平台2）擇一；相連針不限距離、其餘需在 `retrieve_radius` 內、同級取最近。
- **QA 發現並修復**: `run_project` 載入時 GDScript 警告 — 區域變數 `is_connected` 遮蔽 `Object.is_connected()`；改名 `is_player_wire`（commit 646d117）。靜態 `--check-only` 未攔截到，凸顯 QA run_project 的價值。
- **防範規則**: 命名區域變數時避免與 Godot 基底類別方法/屬性同名（`is_connected`、`connect`、`name`、`position` 等）；QA 應以 `run_project` 補靜態檢查未覆蓋的載入期警告。
- **驗證**: sensor 21/21；`--check-only` 0 errors；修復後 run_project errors 為空。GDD §2.4 為設計權威。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-033 回收提示文字 UI + 新 class_name 快取 gotcha（2026-06-20）

- **Severity**: Feature（UX）+ Lesson（工具鏈）
- **需求（用戶）**: 玩家難以判斷哪些鋼針（尤其平台針）可回收 → 加文字 UI 標示可回收針；建立 `scripts/ui`、`scenes/ui` 資料夾；UI 結構可復用、後期可加 tween。
- **實作**:
  - `scripts/ui/world_label.gd` + `scenes/ui/world_label.tscn`：可復用世界座標文字標籤（`follow`、`show/hide_prompt`、`play_appear` tween 擴充點）。
  - `scripts/ui/pickup_prompt_ui.gd` + `scenes/ui/pickup_prompt_ui.tscn`：物件池控制器，在可回收針上方顯示 `[F] 類型`，F 目標亮色、其餘暗色。
  - `needle_manager.gd`：新增 `get_retrieve_info()`（候選+target，DRY），`try_retrieve()` 復用；新增 `_retrieve_label()`。
  - `player.gd`：`_ready` 程式碼 instantiate UI（`top_level=true` 防面向翻轉鏡像），`_physics_process` 每幀更新。
- **開發中發現的 gotcha（Type D 流程空白）**:
  - 新增 `class_name WorldLabel` 後，孤立 `godot --check-only`（pre-commit / sensor 使用）報 `Could not find type "WorldLabel"`，因 global class cache（`.godot/`，gitignored）未更新。
  - **修復**: `godot --headless --path . --import` 重新匯入即註冊。
- **防範規則**: **新增任何 `class_name` 腳本後，先執行 `godot --headless --path . --import`（或開一次編輯器）更新 global class cache，再 commit/跑 sensor-scan**；否則 `--check-only` 會因找不到型別而 FAIL（非真錯誤）。
- **驗證**: sensor 21/21；`--check-only` 0 errors；run_project errors 空。視覺標籤需玩家實測（qa-report 清單）。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-034 撿不到平台針（回收半徑根因）+ 繩子改彈性物理（2026-06-20）

- **Severity**: Bug（回收幾何）+ Feature（繩子物理重做）
- **現象 1（撿不到平台針）**: 即使加了提示 UI（GAP-033），玩家走到平台針旁仍撿不起來。
  - **根因**: 回收距離以玩家**中心**量測，但 Player collision 32×64、中心在原點 → 腳在中心下方 32px。落在腳邊/平台面的針恆 ≥32px，而 `retrieve_radius=30` → **數學上永遠碰不到**。
  - **修復**: `retrieve_radius` 30 → **60**（NeedleManager 的 @export 預設；Player.tscn 未覆寫故改 script 即生效）。
- **現象 2（擺錘針不該無視距離）**: GAP-032 曾讓「與玩家相連的擺錘針」不限距離可回收，用戶要求所有針一律需夠近。
  - **修復**: `get_retrieve_info` 距離過濾統一為 `dist > retrieve_radius → continue`，移除擺錘針例外（`connected_anchor` 僅留作優先級/標籤）。
- **現象 3（繩子手感詭異）**: 繩與玩家互動生硬。
  - **根因 A**: `WireConstraint.apply()` 為硬性截斷（taut 直接刪除徑向速度）→ 無彈性。
  - **根因 B**: `player._apply_movement()` 每幀 `velocity.x = dir*move_speed` → **殺掉擺盪水平動量**（最大主因）。
  - **修復**: 繩改 **spring-damper 彈性繩**（Hooke 彈簧 + 沿繩阻尼、保留切向擺盪）；繩上時 `velocity.x` 改為空中控制加速度 + 輕微 air drag，保留鐘擺動量。新增 4 個 @export 供手感微調。
- **防範規則**:
  - 凡「以單點距離判定互動範圍」者，須考量該點與角色實際碰撞體的偏移（中心 vs 腳/手），半徑要 ≥ 偏移量 + 期望伸手距離。
  - 角色在受約束（繩/鉤）狀態下，**不要每幀硬覆寫速度分量**，否則會抹除物理動量；改用加速度疊加。
- **驗證**: sensor 21/21；`--check-only` 0；run_project errors 空。繩手感與撿針需玩家實測（qa-report 清單）。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-035 彈力繩自動拉近 + 移動手感機制 + 場景放大（2026-06-20）

- **Severity**: Feature（繩重做 + 手感機制 + 場景）
- **需求（用戶）**: (1) 繩仍不滿意 → 改「錨點一建立就自動把玩家拉過去」的**彈力繩**，Q 決定切斷，換實作。(2) 外牆沒跟視窗切齊 → 放大對齊。(3) 稍微強化 Player 性能。(4) 加左右移動慣性。(5) 加 buffer 等 2D 必備機制。
- **實作**:
  - **彈力繩**（換實作）：`wire_constraint.gd` 由「繃緊才作用的彈簧」改為 **always-pull elastic tether**——恆定朝錨點施加 `min(stiffness*dist, max_accel)` 的彈性拉力 + 沿繩阻尼。命中即自動拉近、過衝回彈；懸掛距離 ≈ `gravity/stiffness`。移除 `reel_in`，E 改為額外朝錨點加速。`max_length` 保留為視覺參考。
  - **移動慣性**：`player._apply_movement` 非繩上改 `move_toward(velocity.x, dir*move_speed, rate*delta)`，地面/空中分用 `ground/air_accel`、`ground/air_friction`。
  - **跳躍必備機制**：`_update_jump` 加 coyote time（離地寬容）+ jump buffer（落地前緩衝）；放開跳鍵 `velocity.y *= jump_cut` 可變跳高。
  - **性能微調**：`move_speed` 200→240、`jump_velocity` 501→540。
  - **場景放大**：`project.godot` 視窗 960×540→**1280×720**；`MVP_Test.tscn` 四面外牆重框 0..1280/0..720、內部平台與玩家起點 ×4/3、相機 limits→1280×720。
- **根因（外牆未切齊）**: 外牆原本框 960×540，視窗放大／不一致時不再框滿。統一視窗、外牆、相機 limits 為同一尺寸即切齊。
- **防範規則**: 邊界外牆尺寸、相機 limits、視窗解析度三者必須一致；改其一須同步另兩者。
- **驗證**: sensor 21/21；`--check-only` 0；run_project errors 空（1280×720）。繩/移動/跳躍手感需玩家實測，全開 @export 微調（qa-report 清單）。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-036 射不出任何鋼針（GAP-035 場景放大的回歸）（2026-06-20）

- **Severity**: High（核心功能失效：完全無法射針）
- **現象**: 按左鍵/右鍵都射不出任何鋼針（攻擊針與帶線針皆然）。
- **根因**: `needle_projectile.gd` 的 escape 安全邊界**硬編碼為舊 960×540 場景**（`x > 1024`、`y > 604`）。GAP-035 將場景放大到 1280×720，玩家出生點移到 `y=653`，針從 throw_origin（≈ y653）出生時**已超過舊 y=604 邊界 → 第一個 physics frame 就 `queue_free()`**，故任何針都「射出即消失」。
- **修復**: 邊界改由 `get_viewport_rect().size` 推導（`±64` 邊距），隨場景尺寸自動調整，不再硬編碼。
- **驗證**: 算術可證 — 出生 y≈653 < 720+64=784（新邊界內），舊邏輯 653 > 604（被刪）。sensor 21/21；`--check-only` 0；run_project errors 空。實際射針手感請玩家確認。
- **防範規則**: **禁止硬編碼場景/視窗尺寸於遊戲邏輯**（邊界、出界判定等）→ 一律由 `get_viewport_rect()` 或場景參數推導；改場景尺寸時須複查所有座標常數（沿用 GAP-035「視窗/外牆/相機 limits 三者一致」並擴及子彈出界邏輯）。
- **提交**: 本次 commit（[DEV] 修復 → [QA] 驗收）

## GAP-037 繩索詭異側向 S 彎曲 → Verlet 物理繩重做（2026-06-20）

- **Severity**: Feature/Bug（繩視覺與物理重做）
- **現象（用戶截圖）**: 帶線繩從錨點往**側邊**鼓出成 S 形，非自然繩索。
- **根因**: `player._update_wire_renderer` 擺錘分支以 `slack = max_length - dist` 餵 `_draw_catenary_line`，sag 方向是**垂直於繩（perp）**。繩近垂直時鬆弛量大 → 往側邊鼓出（假彎曲）；且 bungee 的 `max_length` 是過時的初始距離，被拉近後 slack 暴增 → 彎曲更誇張。視覺與物理（直線拉力）脫節。
- **技術選型（用戶問「能不能用 Joint」）**: 經網路研究——**採 Verlet integration**（CharacterBody2D 友善，業界 2D 繩首選，如 CRope2D）；**不採 Joint2D**，因其需 RigidBody2D，會棄掉現有 CharacterBody2D 平台/移動/跳躍/慣性/鋼索平台實作，風險過高（社群回報 Joint 抓鉤調校困難）。
- **重做**:
  - 新增 `scripts/verlet_rope.gd`（preload，免 --import）：Verlet 積分繩，兩端釘錨點/玩家，重力下垂 + Jakobsen 距離約束 → 自然下垂/繃緊變直，**無側向假彎曲**。
  - `wire_constraint.gd` 改鐘擺長度約束 `constrain()`：鬆弛自由、繃緊夾位置 + 消朝外徑向速度（真鐘擺）；+ `auto_reel`/`reel`。移除 bungee always-pull。
  - `player.gd`：`_apply_wire` 用 constrain、`_update_wire_renderer` 擺錘分支改畫 Verlet 點、wire 清除各路徑 null `_verlet`。
- **開發中編譯錯（已修）**: `var tension := _wire.tension_ratio(...)` ——`_wire` 型別為 `RefCounted`，回傳 Variant，`:=` 無法推型別。改 `var tension: float =`。教訓：對 `RefCounted` 型別變數的方法回傳值用 `:=` 會 FAIL，需顯式標型別。
- **防範規則**: (1) 繩索/鏈視覺一律用 Verlet 之類**物理**模型，勿用「垂直於線的假 sag」；(2) 對泛型 `RefCounted` 持有者（鴨子型別）取回傳值要顯式標型別，不可 `:=`。
- **驗證**: **headless 單元測試 `tests/test_rope_gap037.gd` → ROPE_TEST_PASS**（Verlet 釘端/有限值、鐘擺夾位+消徑向、reel 夾 min）；sensor 21/21；`--check-only` 0；run_project errors 空。繩視覺最終觀感需玩家實測（qa-report 清單）。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-038 針飛到一半消失（GAP-036 用 get_viewport_rect 當世界邊界之誤）（2026-06-20）

- **Severity**: High（核心功能：射針半路消失）
- **現象**: 針射出後飛到一半就不見（非嵌牆，無錨點留下）。
- **根因（實機插樁抓到）**: GAP-036 改用 `get_viewport_rect().size` 當**世界出界邊界**。實機 log 顯示它回傳 **(1152, 648)**（= 0.9×1280/720，受 stretch/scale 影響的視窗尺寸），**非 1280×720 世界**。於是出界框 `1216×712` < 外牆 1280×720 → 針在抵達外牆前（x>1216/y>712）就被判出界刪除。
- **修復**: 移除 viewport 出界判定，改以**飛行距離** `max_travel=2400`（>場景對角線 ~1469）當安全網；正常射擊由封閉外牆攔截嵌入，與視窗/縮放/相機無關。
- **實機驗證**: 插樁 auto-fire → 修復後 `[needle] EMBED at (1264,485) traveled=640`（命中右外牆內面），不再提早消失。插樁已還原。
- **防範規則（修正 GAP-036）**: `get_viewport_rect()` 是**視窗/螢幕尺寸（受 stretch/scale 影響）≠ 世界座標範圍**。**禁止用 viewport 尺寸做世界出界/可視判定**；世界範圍回收改用**飛行距離/生命週期**或實際場景/世界參數。（GAP-036 當時以為 viewport 是「非硬編碼」的正解，實為錯誤。）
- **方法論**: 無法用工具輸入時，以**暫時插樁（auto-fire + print）+ run_project + get_debug_output** 取得實機真值定位（本例一次抓到 vp=1152×648），勝於純臆測。
- **提交**: 本次 commit（[DEV] 修復 → [QA] 驗收）

## GAP-039 彈性快速收繩(上甩) + 單按右鍵 + 針數5 + 驗證法改良（2026-06-20）

- **Severity**: Feature（手感/操作/數值）+ Process（驗證法）
- **需求（用戶）**: (1) 線收縮更快 + 一定彈力，達成「朝上射右鍵→上甩→適時第二右鍵成平台→帶動能站上」。(2) 帶線針改單按右鍵。(3) 針數 3→5。(4) workflow 實機驗證效果差/效率低 → 改更好方式（不一定實機）。
- **實作**:
  - 繩：`wire_constraint` 由 GAP-037 鐘擺硬約束(`constrain` 夾位置) 改回**彈性 spring + 快 auto-reel**（`apply`：`pull=min(stiffness*stretch,max_accel)` 朝錨點 + 沿繩阻尼；`auto_reel_speed=320`、`stiffness=40`、`damping=4`）。Verlet 視覺保留。收繩快→朝上射針上甩→第二針成平台釋放→帶動能站上。
  - 輸入：`player._unhandled_input` 右鍵→帶線針、左鍵→攻擊針；`_shoot_needle(wire:bool)`。
  - 針數：`needle_manager.max_needles 3→5`；`debug_overlay` count/cap 動態。
  - 驗證法：`workflow §F` 新增**驗證優先序**（1 headless 自動化測試首選 / 2 暫時插樁+run_project 取實機真值 / 3 run_project 純開機僅冒煙 / 4 玩家手感）；`§I-C Rule 24` 改述。
- **連帶**: GAP-039 移除 `constrain()` → `tests/test_rope_gap037.gd` 的 constrain 斷言過時失效；已修剪為僅測 VerletRope+reel（WireConstraint 由 `test_rope_gap039.gd` 覆蓋）。教訓：改動公開 API（如 constrain→apply）須同步更新對應測試。
- **驗證（新法示範）**: `test_rope_gap039.gd` → **ROPE39_TEST_PASS**（針數5、彈性朝錨點、**上甩 vel.y<0 & pos 上移**、reel 夾 min）；`test_rope_gap037.gd` → ROPE_TEST_PASS；sensor 21/21；`--check-only` 0；run_project 冒煙 errors 空。連段手感需玩家實測。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-040 上甩動量不自然(彈簧注入) → 改回自然鐘擺 + 針速2400（2026-06-20）

- **Severity**: Feature（手感）
- **需求（用戶）**: (1) GAP-039 的上甩動量「很怪、是特別添加的」，要**自然**（不要人工注入動量）。(2) 針飛行速度太慢，加快。
- **根因（手感）**: GAP-039 的 `wire_constraint.apply()` 用彈簧 `velocity += dir*pull*delta`，**主動注入朝錨點的速度** → 玩家感覺被「特別添加」地往上甩，不自然。
- **修復**:
  - 繩物理改回**自然鐘擺長度約束** `constrain()`：繃緊時只**夾位置到半徑圓** + **消除朝外徑向速度**，**絕不注入任何速度**。動量純由重力盪繩；收繩(縮 `max_length`)靠位置約束 → 角動量守恆自然加速擺盪（如收手加快旋轉）。移除 `stiffness/damping/max_accel` 與彈簧 `apply()`。
  - `needle_projectile.flight_speed 1200→2400`（抗穿牆：raycast 前探 48px>16px 牆；`max_travel` 仍>對角線）。
- **驗證（新法）**: `tests/test_rope_gap040.gd` → **ROPE40_TEST_PASS**，關鍵斷言「靜止玩家繃緊 → `constrain` 後 vel≈0（無注入）」直接證明自然；切向保留、徑向消除、reel 夾 min、針數5。sensor 21/21；`--check-only` 0；run_project 冒煙空。
- **過程教訓**: `git add a b c <不存在>` 會因 pathspec fatal **中斷且未暫存任何檔**，導致該次 commit 漏掉實際代碼（只含先前 `git rm` 的刪除）→ 後續 ff merge 看似只動 1 檔即露餡。**防範**：刪檔用 `git rm`（已自動暫存），其餘 `git add` 勿混入不存在路徑；commit 後核對 `git show --stat` 檔數符合預期。
- **設計演進記錄**: 繩經 GAP-034(彈簧)→035(bungee)→037(Verlet視覺+鐘擺)→039(彈簧上甩)→**040(自然鐘擺，無注入)**。結論：視覺用 Verlet、物理用**無注入的鐘擺約束**最自然。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-041 大幅簡化：移除平台/Q/E/F + 右鍵按住盪繩（2026-06-20）

- **Severity**: Feature（重大簡化/重構）
- **需求（用戶）**: 決定移除複雜機制——(1) 移除平台建立機制，只留盪繩。(2) 盪繩改右鍵按住發射 + 自動收繩；鬆開自動斷開且鋼針一併回收。(3) 移除 Q/E/F 功能。(4) 左鍵攻擊針靠近時自動回收。
- **實作**:
  - `needle_manager.gd` 重寫：移除 `wire_platform_scene`/平台/`get_retrieve_info` 優先級/`try_retrieve`；改單一 `_wire_anchor`+`_wire_proj`；新增 `release_wire()`（鬆開取消飛行針或回收錨）、`auto_retrieve_attack(pos)`（攻擊針近距自動回收）。
  - `player.gd` 重寫：右鍵 pressed→`_start_grapple`（射抓鉤）、released→`_release_grapple`（`release_wire`+清狀態）；`_wire_held` 守「飛行中放開」；左鍵攻擊；每幀 `auto_retrieve_attack`；移除平台/drop-through/pickup UI/Q/E/F/`_cut_wire`/`_draw_catenary`/sag。保留移動慣性/跳躍/Verlet/自然鐘擺。
  - 刪 `scripts/wire_platform.gd`、`scenes/WirePlatform.tscn`；`Player.tscn` 移除 WirePlatform ext_resource(5_wpscene) + `wire_platform_scene` 賦值。
  - 保留為未引用資產：`scenes/ui/*`(pickup UI)、project.godot 的 cut_wire/reel_wire/retrieve_needle/drop_through 輸入動作、MVP_Test 的 WireLayer。
- **驗證**: `test_rope_gap041.gd` → **NM41_TEST_PASS**（max=5、攻擊針近收遠留、release_wire 安全）；gap040/037 PASS；sensor 21/21；`--check-only` 0；run_project 冒煙空（Player.tscn 移除 ext_resource 後載入正常）。淨減 193 行。
- **防範規則**: 移除 .tscn 的 ext_resource 時，必須同時移除所有對該 id 的賦值（如 `wire_platform_scene = ExtResource("5_wpscene")`），否則 broken ref → 以 run_project 冒煙確認載入。
- **提交**: 本次 commit（[DESIGN]→[ARCH]→[DEV]→[REVIEW]→[QA] 串行）

## GAP-042 盪繩收繩穿過平台（直接設 global_position 繞過碰撞）（2026-06-20）

- **Severity**: High（核心：盪繩穿過平台）
- **現象（用戶）**: 玩家勾到牆壁、被往牆上收繩時，會**穿過中間的平台**；希望被卡住。
- **根因**: `player._apply_wire` 以 `global_position = r["pos"]`（繩約束位置夾鉗）**直接瞬移**玩家。直接設 `global_position` **繞過 CharacterBody2D 碰撞** → 收繩路徑上的平台不擋人。
- **修復**: 改 `move_and_collide(r["pos"] - global_position)`，碰撞感知移動，遇牆/平台停住（卡住）。
- **驗證（暫時插樁 + run_project）**: 自動朝上抓鉤 + log `move_and_collide` 碰撞 → **`blocked by Platform_C at y≈436`（× 1044 幀）**，玩家被平台擋住卡住、未穿過。插樁已還原。sensor 21/21、`--check-only` 0。
- **防範規則**: **CharacterBody2D 任何需要碰撞的位移，禁止用 `global_position =`／`position =` 直接設定（會瞬移穿牆）**；改用 `move_and_collide`（單次、會回報碰撞）或 `move_and_slide`（速度驅動）。位置型約束（繩/夾鉗）一律走 `move_and_collide`。
- **提交**: 本次 commit（[DEV] 修復 → [QA] 驗收）
