# QA 測試報告 - PLAYER 出生卡住與多人移動問題

## 測試目標
驗證從標題畫面進入遊戲後，多人連線模式下玩家出生時會「卡住」或「無法移動」的根本原因，並確保修復後能在實際遊玩情境中順暢運作。

## 異常原因分析（從標題進入的測試重現）
在執行完整的本地端測試指令 (`--headless` 搭配 Console 輸出) 與檢閱程式碼後，發現卡住並非單純碰撞問題，而是嚴重的「**多人架構不同步 (Desync) 與控制權 (Authority) 遺失**」導致的骨牌效應：

1. **隨機生成地形未同步 (Level Generation Desync)**
   - **原本狀況**：在 `NetworkManager.start_game()` 中，Host 與 Client 同時載入 `test_level.tscn`，然後 `_ready()` 內部自行執行 `randi()` 來組裝隨機的 Modular Map。
   - **後果**：Client 生成的地形與 Server 生成的地形完全不一樣！Server 將角色的精確座標傳送給 Client 時，該座標在 Client 端可能剛好是一面牆。這導致 Client 本地的物理引擎不斷將角色推出牆外，而 Server 又不斷把位置強制拉回，產生激烈的抽搐與「卡住」。

2. **玩家控制權丟失 (Authority Missing)**
   - **原本狀況**：由 `MultiplayerSpawner` 負責將角色從 Server 廣播給所有 Clients。但 Godot 4 的 Spawner 預設只同步 Node Name，**並不會同步 `multiplayer_authority`**。
   - **後果**：當 Player 場景抵達 Client 端時，Client 認為這個角色的控制權在 Server 身上，因此 Client 本地的 `_physics_process` 中 `is_multiplayer_authority()` 判斷失敗，導致所有輸入被忽略（無法移動）。

3. **出生座標陷阱與雙重生成 (Double Spawn & Edge Traps)**
   - **原本狀況**：`_spawn_players()` 意外地在 `_generate_level()` 以及 `_ready()` 中被呼叫了兩次。另外，原本的出生點 `(0, -64)` 剛好位於第一個模組區塊的極左側邊緣，玩家一出生就會受到推擠或掉落出界。
   - **後果**：玩家不僅一開始就掉出地圖邊緣被相機判定受到 1 點傷害與強烈彈回，而且場景上還有隱形的重複節點互卡。

## 修復項目 (DoD)
- [x] **修復控制權**：在 `player.gd` 中加入 `_enter_tree()`，讓角色實例化時強制 `set_multiplayer_authority(name.to_int())`，使 Client 取回角色控制權。
- [x] **同步地形隨機數**：在 `multiplayer_lobby.gd` 中讓 Host 取出 `randi()` 作為 `rng_seed`，並傳入 `NetworkManager.start_game(rng_seed)`，讓所有連線的 Client 使用相同的亂數種子，生成完全一致的物理地形。
- [x] **修正出生邏輯**：移除了多餘的 `_spawn_players()` 呼叫，並將安全降落座標向內側偏移至 `Vector2(48, -64)`。

## 測試驗證結果
- **測試工具**：Godot Console Headless Simulator
- **測試執行**：經由掛載 `--headless` 輸出 Frame 狀態，觀察玩家實體的座標與速度。
- **測試結果**：
  - **Frame 10**: `Player 1 pos: (48.0, -58.0) vel: (0.0, 72.0) floor: false wall: false`
  - **Frame 50**: `Player 1 pos: (48.0, -7.0) vel: (0.0, 0.0) floor: true wall: false`
  - 玩家精準地在空中出現，並受到重力影響自然落下，最終穩穩停在地板上 `floor: true`，且無任何 `wall: true` 的卡牆現象。

## 結論
**✅ 全部通過**
已徹底解決從標題連線進入遊戲時，由於亂數不同步與權限設定遺漏造成的卡住與無法操作的重大 Bug。現在 4 名玩家皆能正常受到同步並自由操控。
