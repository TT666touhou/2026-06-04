# PROJECT STATUS — 4人 Rogue-lite 遊戲原型
> **🔴 強制規則**：所有 Role 在任何工作開始前**必須先讀這份文件**。
> **🔴 強制規則**：任何 Phase 的進度變更，**當事 Role 必須在同次 commit 前更新此文件**。
> 格式：`更新時間 | 更新角色 | 更新內容`
> 
> **這是全專案唯一的真相來源（Single Source of Truth）。**
> 所有角色的工作都以此為基準，不以口頭描述或 commit 訊息為準。

---

## 📋 快速總覽

| Phase | 名稱 | 狀態 | 最後更新 |
|-------|------|------|---------| 
| 1.1 | 玩家生成系統（MultiplayerSpawner）| ✅ DONE | 2026-06-12 |
| 1.2 | 本地多人輸入系統 | ✅ DONE | 2026-06-12 |
| 1.3 | 玩家顏色系統 | ✅ DONE | 2026-06-12 |
| 1.4 | 多玩家相機系統 | ✅ DONE | 2026-06-12 |
| 1.5 | 近戰/遠程戰鬥迴路 | ✅ DONE | 2026-06-12 |
| 2.1 | DebugOverlay（F3）| ✅ DONE | 2026-06-12 |
| 2.2 | AI感知 JSON 橋（DebugBridge）| ✅ DONE | 2026-06-12 |
| 2.3 | 多實例啟動器（launch_multiplay.ps1）| ✅ DONE | 2026-06-12 |
| 2.5 | 角色工作流（5個 Role）| ✅ DONE | 2026-06-12 |
| 2.6 | 靜態錯誤全清（0 ERROR）| ✅ DONE | 2026-06-12 |
| 3.1 | 房間系統（4種類型場景）| ✅ DONE | 2026-06-12 |
| 3.2 | 關卡生成器（DungeonGenerator）| ✅ DONE | 2026-06-12 |
| 3.3 | 房間轉場（RoomTransition）| ✅ DONE | 2026-06-12 |
| 3.4 | 場景流程（Title→Game→結算）| ✅ DONE | 2026-06-12 |
| 3.5 | 玩家死亡/重生 | ✅ DONE | 2026-06-12 |
| 3.6 | HUD 血條（PlayerHUD）| ✅ DONE | 2026-06-12 |
| 3.7 | 結算/GameOver 畫面 | ✅ DONE | 2026-06-12 |
| 3.8 | 房間衝突修復（清除硬編碼玩家/相機）| ✅ DONE | 2026-06-12 |
| 3.9 | **[HOTFIX] Physics Flush 崩潰修復（ERR-001/002/003）** | ✅ DONE | 2026-06-12 17:24 |
| — | **[HOTFIX-2] Boss 腳本缺失+Physics深層修復（ERR-006/007）** | ✅ DONE | 2026-06-12 17:51 |
| — | Sensor ROLE（關鍵字觸發守衛）| ✅ DONE | 2026-06-12 |
| — | 敵人 AI（巡邏/追擊，Enemy1/2/3）| ✅ DONE | 2026-06-12 |
| — | Boss AI（巡邏/衝刺，boss.gd 創建）| ✅ DONE | 2026-06-12 17:51 |
| — | 敵人生成系統 | ❌ TODO | — |
| — | 線上多人（ENet）| 🔒 BLOCKED | 設計決策：Phase 1 不做 |
| **4.1** | **ScreenFader（漸黑漸亮過渡）** | **✅ DONE** | 2026-06-12 |
| **4.2** | **RoomPortal（洞口觸發節點）** | **✅ DONE** | 2026-06-12 |
| **4.3** | **game_world.gd Portal 擴充** | **✅ DONE** | 2026-06-12 |
| **4.4** | **四方向走廊場景（left/right/top/bottom）** | **✅ DONE** | 2026-06-12 |
| **4.5** | **test_room_a/b 改造（RoomPortal 整合）** | **✅ DONE** | 2026-06-12 |
| **5.1** | **攻擊輸入重新綁定（左鍵=近戰/右鍵=遠程）** | **✅ DONE** | 2026-06-12 |
| **5.2** | **修正 test_room player_prefix + bullet fallback** | **✅ DONE** | 2026-06-12 |
| **5.3** | **VFX 系統（MeleeSlash/RangedMuzzle/EnemyHit/EnemyDeath）** | **✅ DONE** | 2026-06-12 |
| **5.4** | **數文同步 Routine（GDD + ROLE 強化）** | **✅ DONE** | 2026-06-12 |
| **5.5** | **VFX Spritesheet 切割修正（ERR-017）+ 自動配置** | **✅ DONE** | 2026-06-12 |
| **5.6** | **BUG 修復：spawn_pos重複/StringName-String/NARROWING(ERR-018-020)** | **✅ DONE** | 2026-06-12 |
| **6.1** | **Area_0 房間結構框架（room_base/camera_zone/area_0_room_01/02）** | **✅ DONE** | 2026-06-13 |
| **6.2** | **Area_0 Room_01/02 地形手動搭建（玩家完成）** | **✅ DONE** | 2026-06-14 |
| **6.3** | **遊戲進入點修正：Title→area_0_room_01（DungeonGenerator 固定進入點）** | **✅ DONE** | 2026-06-14 |
| **6.4** | **移除 game_world.tscn 中全局碰撞牆 Ground/Ceiling/WallLeft/WallRight（玩家在房間內被意外阻擋 BUG 修正）** | **✅ DONE** | 2026-06-14 |
| **6.5** | **Portal 系統強化：@export_file 優化 + walk-in 轉場 + room_02 LeftPortal→room_01 雙向連結修復** | **✅ DONE** | 2026-06-14 |
| **6.6** | **[HOTFIX] ERR-029 Portal 重觸發黑屏修復（entry portal walk-in 保護機制）** | **✅ DONE** | 2026-06-14 |
| **6.7** | **[DEV TOOL] F6 房間直跑 Debug Player 自動生成（room_base.gd 偵測根場景，自動注入玩家+相機）** | **✅ DONE** | 2026-06-14 |
| **6.8** | **F6 鏡頭縮放修復（3x→4x），移除 test_room_a/b，重構 DungeonGenerator 為固定序列模式** | **✅ DONE** | 2026-06-14 |

---

## ✅ 已完成（DONE）

### Phase 1.1 — 玩家生成系統
- **完成日期**：2026-06-12
- **完成驗證**：headless 執行確認玩家正確生成
- **關鍵檔案**：
  - `scenes/player/player.tscn` ← 玩家場景
  - `scripts/player/player.gd` ← 玩家腳本（MultiplayerSynchronizer, `_enter_tree` 設定 authority）
  - `scenes/level/game_world.tscn` ← 主場景（MultiplayerSpawner, spawn→Players）
  - `scripts/level/game_world.gd` ← `_start_solo()`, `_start_as_server()`, `_start_as_client()`
- **已知限制**：MultiplayerSpawner 需要 scene 的 name = str(peer_id)
- **測試指令**：
  ```powershell
  # 單機啟動
  & "C:\Users\88698\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "D:\2026-06-04"
  ```

### Phase 1.2 — 本地多人輸入系統
- **完成日期**：2026-06-12
- **完成驗證**：project.godot 確認有 p1_/p2_ 前綴的 action
- **關鍵檔案**：
  - `project.godot` ← Input Map（p1_move_left/right/jump/roll/attack, p2_同上）
  - `scripts/player/player.gd` ← `player_prefix` @export var，`player_prefix + "move_left"` 模式
- **重要規則**：
  - 單機 `_start_solo()` 必須設定 `player_prefix = "p1_"`（**不能是空字串 ""**）
  - `_handle_attack()` 必須先用 `InputMap.has_action(action_name)` 守衛
- **已知 BUG 歷史**：`player_prefix = ""` 導致 `"attack" doesn't exist` 每幀崩潰 → 見 ERROR_LOG.md

### Phase 1.3 — 玩家顏色系統
- **完成日期**：2026-06-12
- **完成驗證**：QA 視覺確認
- **關鍵檔案**：`scripts/player/player.gd` ← `apply_player_color(skin_index: int)`
- **顏色映射**：0=暖橙(#FF8C42), 1=冷藍(#4CC9F0), 2=綠(#5DA16E), 3=紫(#9D5789)

### Phase 1.4 — 多玩家相機系統
- **完成日期**：2026-06-12
- **完成驗證**：場景包含 MultiplayerCamera 節點
- **關鍵檔案**：
  - `scripts/camera/multiplayer_camera.gd` ← 追蹤 "Players" group，動態縮放
  - `scenes/level/game_world.tscn` ← MultiplayerCamera 子節點

### Phase 1.5 — 近戰/遠程戰鬥迴路
- **完成日期**：2026-06-12
- **完成驗證**：headless 執行 0 ERROR，debug_state.json 包含 attack_state
- **關鍵檔案**：
  - `scripts/player/player.gd` ← `_handle_attack(delta)`, `_perform_melee_attack()`, `_fire_bullet()`
  - `scripts/player/player_bullet.gd` ← 玩家子彈，`setup()` 方法
  - `scenes/player/player_bullet.tscn` ← 子彈場景
- **攻擊設計**：短按 < 0.3s = 近戰（PhysicsShapeQueryParameters2D）；長按 ≥ 0.3s = 遠程（實例化子彈）
- **待強化**：近戰攻擊缺少視覺回饋（VisualPivot 縮放動畫）；敵人需要 `take_damage()` 方法

### Phase 2.1 — DebugOverlay（F3）
- **完成日期**：2026-06-12
- **完成驗證**：執行遊戲後 F3 出現半透明面板
- **關鍵檔案**：`scripts/autoload/debug_overlay.gd`（Autoload 名：DebugOverlay）
- **快捷鍵**：F3=切換, F4=碰撞框, F5=強制輸出 JSON

### Phase 2.2 — AI感知 JSON 橋
- **完成日期**：2026-06-12
- **完成驗證**：`debug_state.json` 包含 players/dungeon 欄位
- **關鍵檔案**：`scripts/autoload/debug_bridge.gd`（Autoload 名：DebugBridge）
- **輸出路徑**：`%APPDATA%\Godot\app_userdata\2026 06 04\debug_state.json`
- **JSON 結構**：
  ```json
  {
    "timestamp": 1234567890.0,
    "fps": 60,
    "peers": 1,
    "players": [{"id": 1, "name": "SoloPlayer", "pos": [100,200], "hp": 3, "attack_state": "IDLE"}],
    "enemies": [],
    "dungeon": {"total_rooms": 5, "current_index": 0, "progress": 0.2, "rooms": [...]}
  }
  ```

### Phase 2.3 — 多實例啟動器
- **完成日期**：2026-06-12
- **完成驗證**：腳本存在
- **關鍵檔案**：`scripts/launch_multiplay.ps1`
- **使用方式**：`.\scripts\launch_multiplay.ps1 -Players 2`

### Phase 2.5 — 角色工作流
- **完成日期**：2026-06-12
- **關鍵檔案**：`roles/designer.md`, `roles/architect.md`, `roles/developer.md`, `roles/reviewer.md`, `roles/qa.md`
- **強制流程**：每個 Role 第一件事讀 `docs/PROJECT_STATUS.md`，第零步讀 `docs/ERROR_LOG.md`

### Phase 3.2 — DungeonGenerator（關卡生成器）
- **完成日期**：2026-06-12
- **關鍵檔案**：
  - `scripts/level/dungeon_generator.gd`（class_name DungeonGenerator）
  - `scripts/level/game_world.gd` ← 整合，`load_next_room()`, `_load_room_scene()`
  - `scenes/level/game_world.tscn` ← DungeonGenerator 子節點
- **[2026-06-14 更新] 重構為固定序列模式**：地圖不是程序化生成的，而是設計師預先決定的。
  - `AREA_0_ROOMS` 固定陣列取代舊的 `COMBAT_ROOMS`（隨機池）
  - 移除廢棄的 `ELITE_ROOMS`（原包含 test_room_b.tscn）、`@export` 隨機化參數
  - 新增 `generate_run()` 非隨機版本，依序推進固定場景
- **API 保持相容**：`generate_run()`, `advance_room()`, `get_current_room()`, `get_debug_info()` 同名同簽名
- **重要**：`game_world.gd` 使用 `@onready var _dungeon: Node`（不用 `DungeonGenerator` 型別，避免 class_name 前向引用問題）

---

## ⚠️ 部分完成（PARTIAL）— 需繼續實作

### Phase 3.1 — 房間系統（房間類型定義）
- **狀態**：場景存在但內容極簡
- **已完成**：
  - `RoomType` enum 定義（COMBAT/ELITE/BOSS/REST）
  - `dungeon_generator.gd` 有房間場景路徑清單
  - `room_transition.gd` 更新為呼叫 `GameWorld.load_next_room()`
- **未完成**：
  - `scenes/level/boss_room.tscn` ← **不存在**（DungeonGenerator 將 fallback 到 ENTRY_ROOM）
  - `scenes/level/rest_room.tscn` ← **不存在**
  - 房間門/傳送點機制未完成（RoomTransition 只有基礎節點）
- **下一步**：實作最小可用房間（有平台可站立 + RoomTransition 觸發點）

### Phase 3.3 — 房間轉場
- **狀態**：腳本存在，功能基礎
- **已完成**：`scripts/level/room_transition.gd` 呼叫 `GameWorld.load_next_room()`
- **未完成**：無實際視覺轉場效果；轉場觸發需要玩家踩到 Area2D 才能呼叫

### 敵人系統
- **狀態**：敵人場景存在但功能不完整
- **已完成**：敵人有 HP 系統，被近戰命中時呼叫 `take_damage()`
- **未完成**：
  - 敵人 AI（巡邏/追擊）未實作
  - 敵人死亡動畫/移除未實作
  - 敵人生成（Spawner）機制缺失
- **已知**：`[Player] Took damage!` 出現在 headless log，代表有敵人存在並能攻擊玩家

---

## ❌ 尚未開始（TODO）

| 功能 | 優先級 | 依賴 | 說明 |
|------|--------|------|------|
| Boss 房間場景 | HIGH | Phase 3.1 | 需要 boss_room.tscn 實際存在 |
| 休息房間場景 | MEDIUM | Phase 3.1 | 需要 rest_room.tscn 實際存在 |
| 敵人 AI（巡邏/追擊）| HIGH | 敵人系統 | 目前敵人為靜態 |
| 敵人生成系統 | HIGH | 敵人系統 | 房間進入後動態生成 |
| 近戰視覺回饋 | MEDIUM | Phase 1.5 | VisualPivot 縮放動畫 |
| 玩家死亡/重生 | MEDIUM | Phase 1.5 | HP 歸零後處理 |
| 遊戲結算畫面 | LOW | Phase 3 | Run 完成後顯示 |
| HUD（血條顯示）| MEDIUM | Phase 1.5 | 玩家 HP 常駐顯示 |
| 本地 2-4 人測試 | HIGH | Phase 1 | 目前只測試單機 |

---

## 🔒 已鎖定設計決策（不可更改，來自 GAME_DESIGN.md）

| 決策 | 內容 | 鎖定原因 |
|------|------|---------|
| 多人模式 | 先本地後線上（階段性）| 用戶確認 |
| 玩家人數 | 2-4人彈性 | 用戶確認 |
| 相機 | 單一共用相機 + 動態縮放 | 用戶確認 |
| 戰鬥 | 短按近戰 / 長按遠程 | 實作完成且驗證 |
| 關卡 | Rogue-lite 隨機房間 | 用戶確認 |
| 角色外觀 | 共用外觀，顏色區分 | 用戶確認 |
| Debug | DebugOverlay(F3) + JSON橋 + DebugBridge | 已實作 |

---

## 📁 關鍵檔案索引

### 腳本
| 檔案 | 功能 | 狀態 |
|------|------|------|
| `scripts/player/player.gd` | 玩家主腳本 | ✅ |
| `scripts/player/player_bullet.gd` | 玩家子彈 | ✅ |
| `scripts/camera/multiplayer_camera.gd` | 多人相機 | ✅ |
| `scripts/autoload/debug_overlay.gd` | Debug Overlay | ✅ |
| `scripts/autoload/debug_bridge.gd` | JSON 橋 | ✅ |
| `scripts/autoload/network_manager.gd` | 網路管理 | ✅ |
| `scripts/level/game_world.gd` | 主世界控制 | ✅ |
| `scripts/level/dungeon_generator.gd` | 地牢生成 | ✅ |
| `scripts/level/room_transition.gd` | 房間轉場 | ⚠️ |
| `scripts/launch_multiplay.ps1` | 多實例啟動 | ✅ |

### 場景
| 場景 | 狀態 | 說明 |
|------|------|------|
| `scenes/level/game_world.tscn` | ✅ | 主遊戲場景 |
| `scenes/player/player.tscn` | ✅ | 玩家場景 |
| `scenes/player/player_bullet.tscn` | ✅ | 子彈場景 |
| `scenes/level/boss_room.tscn` | ❌ | 不存在 |
| `scenes/level/rest_room.tscn` | ❌ | 不存在 |

### 文件
| 文件 | 功能 | 強制讀取 |
|------|------|---------|
| `docs/PROJECT_STATUS.md` | **本文件** — 全專案狀態 | ✅ **所有 Role 事前必讀** |
| `docs/ERROR_LOG.md` | 錯誤知識庫 | ✅ **所有 Role 事前必讀** |
| `docs/GAME_DESIGN.md` | 遊戲設計文件 | ✅ Designer/Architect 必讀 |
| `roles/designer.md` | 設計師角色規則 | ✅ |
| `roles/architect.md` | 架構師角色規則 | ✅ |
| `roles/developer.md` | 開發者角色規則 | ✅ |
| `roles/reviewer.md` | 審查員角色規則 | ✅ |
| `roles/qa.md` | QA角色規則 | ✅ |

---

## 🔄 更新日誌

| 時間 | 角色 | 更新內容 |
|------|------|---------|
| 2026-06-12 16:52 | QA/Developer | 初始建立：記錄 Phase 1~3 完成狀態，標注 PARTIAL 和 TODO 項目 |
| 2026-06-12 20:30 | Designer | Phase 5.4: GDD 全面同步了實際代碼現況，所有已實作功能更新為 [CONFIRMED]|
| 2026-06-12 20:30 | Designer | Phase 5.4: 強化全部標 Role 文件，加入文件同步 Routine |
| 2026-06-12 20:30 | Developer | Phase 5.1: 攻擊輸入重新綁定（左鍵=近戰, 右鍵=遠程），座弱舊短按/長按設計 |
| 2026-06-12 20:30 | Developer | Phase 5.2: 修正 test_room player_prefix 和 bullet fallback 路徑（攻擊系統主要 BUG 修復） |
| 2026-06-12 20:30 | Developer | Phase 5.3: 建立 4 個 VFX 場景（MeleeSlash/RangedMuzzle/EnemyHit/EnemyDeath）+ 強化 enemy take_damage/die |
| 2026-06-12 21:00 | Developer/Architect | Phase 5.5: VFX 切割修正、自動配置、比例調整。ERR-017~020 記錄至 ERROR_LOG |
| 2026-06-13 14:45 | Developer/Reviewer/Sensor | **[ERR-026] 近戰 VFX 不可見修復**：MeleeSlash/Impact3 根節點 visible=false；MeleeSlash2 frame=15預設值；VFX 改為原色（GDD同步）。Sensor v4 8/8 PASS |
| 2026-06-13 15:00 | QA/Architect/Developer | **[ERR-027] 真正根本原因發現與修復**：ERR-026 修復後仍不可見。QA 實機測試發現 test_room_a/b 使用 player.tscn（基底），而非 player1.tscn。基底場景完全缺少 MeleeVFXPivots 和 @export VFX 賦值。修復：player.tscn 加入完整 VFX 配置。**Workflow 強化**：新增 L 節（跨角色通知協議）、reviewer.md ERR-027 防護規則、qa.md 引用鏈驗證步驟。Sensor v4 8/8 PASS |
| 2026-06-13 15:39 | Developer | **Phase 6.1 Area_0 房間結構框架完成**：建立 room_base.gd（SpawnPoint查詢+CameraZone通知）、camera_zone.gd（空洞騎士風格鏡頭邊界）、area_0_room_01/02.tscn（含CameraZone/BoundaryWalls/TileLayers三層/Portal）。MultiplayerCamera 新增 set_limits_from_zone()（Tween 0.3s）。game_world 新增 apply_room_camera_zone + _find_portal_by_door_id（遞迴搜尋）。dungeon_generator COMBAT_ROOMS 加入 area_0 路徑。Sensor v4 8/8 PASS。 |
| 2026-06-13 15:50 | Developer/Sensor | **[ERR-028] SceneTree 腳本呼叫 get_tree() 修復**：`qa_vfx_test2.gd:46` 的 `await get_tree().process_frame` 改為 `await process_frame`。**Sensor v5 升級**：sensor-scan.ps1 新增 Check 9/9 自動偵測 ERR-028。Sensor v5 9/9 PASS。 |
| 2026-06-13 16:19 | Designer/Developer | **[設計決策] 移除 BoundaryWalls**：Designer+Architect 討論確認，TileMapLayer Physics Layer 為唯一碰撞策略，BoundaryWalls (collision_mask=0) 從未生效。從 area_0_room_01/02.tscn 移除所有 BoundaryWalls 節點與 sub_resource。更新 GAME_DESIGN.md §10.8/10.9/10.10 記錄決策。Sensor v5 9/9 PASS。 |
| **2026-06-14** | **QA** | **Phase 6.8**：修復 F6 縮放（room_base.gd zoom 3→4，與 MultiplayerCamera.max_zoom 一致）；刪除廢棄的 test_room_a.tscn 和 test_room_b.tscn；重構 dungeon_generator.gd 為固定序列模式（移除 COMBAT_ROOMS/ELITE_ROOMS 隨機池、廢棄 @export 參數）；更新 GAME_DESIGN.md §10.12、reviewer.md、qa.md、PROJECT_STATUS.md，清除所有 test_room 殘留引用。 |



---

> **⚠️ 更新規則**：
> - Phase 狀態從 TODO → PARTIAL → DONE 的變更：當事角色必須在同次 git commit 前更新此文件
> - 新發現的 Bug 或技術債：立即在「待強化」或「尚未開始」中加入
> - 設計變更：必須同時更新「已鎖定設計決策」和 `docs/GAME_DESIGN.md`
> - 每次更新：在「更新日誌」加入一行記錄



---

> **⚠️ 更新規則**：
> - Phase 狀態從 TODO → PARTIAL → DONE 的變更：當事角色必須在同次 git commit 前更新此文件
> - 新發現的 Bug 或技術債：立即在「待強化」或「尚未開始」中加入
> - 設計變更：必須同時更新「已鎖定設計決策」和 `docs/GAME_DESIGN.md`
> - 每次更新：在「更新日誌」加入一行記錄
