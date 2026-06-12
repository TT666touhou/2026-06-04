# 📔 架構日誌 (arch_log.md)
> 所有 Architect 工作的記錄。每次工作結束後必須追加。

---

### 2026-06-12 Phase 1 架構設計

- **設計了什麼**：多人遊戲基礎架構（玩家系統、相機、Debug系統）
- **技術選型理由**：
  - ENet 替代 WebRTC：更穩定的本地連線，無需 STUN server
  - CanvasLayer 100 層 Debug Overlay：確保永遠在最上層不被遮擋
  - JSON 輸出 DebugBridge：AI 可以讀取任何格式，JSON 最通用
  - Groups "Players"/"Enemies"：動態查詢比固定節點路徑更靈活
- **DoD 清單**：
  - [x] 玩家可在本地2視窗對戰
  - [x] F3 可切換 Debug Overlay
  - [x] F5 寫出 debug_state.json
  - [ ] MultiplayerCamera 在2+玩家時動態縮放
  - [ ] 遊戲場景 game_world.tscn 可執行
- **潛在風險**：
  - Godot `--check-only` 在 headless 模式下可能執行遊戲邏輯（已知問題，需 timeout）
  - MultiplayerSynchronizer 在 _ready 內動態建立可能有時序問題
- **交接給 Developer 的明確指示**：
  1. player.gd 的 MultiplayerSynchronizer 改為場景文件靜態設定（更穩定）
  2. 建立 game_world.tscn 場景，包含 MultiplayerSpawner 和 MultiplayerCamera 節點
- **Memory 已更新**：❌（待更新）

---

### 2026-06-12 第四批錯誤 — Architect 反省（ERR-012 ~ ERR-015）

- **問題摘要**：本批次 4 個錯誤（boss.gd 非 UTF-8 編碼、player1-4.tscn UID 自引用、test_stretch.gd 廢棄 API、test_*.gd UTF-8 BOM）均在一次 Godot 啟動後被發現，說明這些問題在之前的所有靜態驗證（--check-only）中均未被攔截。

- **架構責任分析**：
  1. **ERR-012 (boss.gd 編碼)**：Architect 設計 boss 功能時，架構計畫要求「創建 boss.gd」（ERR-006 修復後），但未要求「確認 boss.gd 的文件編碼」。這個隱性假設（AI 工具總會寫出正確編碼）是架構設計的失誤。
  2. **ERR-013 (UID 自引用)**：Architect 在場景複製工作流的設計中，沒有要求執行「ext_resource UID 驗證」這個步驟。這應該作為「Developer 複製 .tscn 後的強制驗收標準」加入 implementation_plan 的 DoD。
  3. **ERR-014/015（測試腳本問題）**：架構設計只關注 `scripts/` 目錄下的遊戲腳本，忽略了根目錄下的測試腳本。但 Godot 在啟動時會掃描所有腳本文件（包括根目錄）。應在架構設計中明確「根目錄不允許存在 Godot 腳本文件，或若存在則需符合相同的編碼標準」。

- **架構層面的系統性解決方案**（以下條目已加入後續設計約束）：
  1. **編碼驗證進入 pre-commit hook**：所有 .gd 文件在 commit 前必須通過 BOM 和 UTF-8 有效性驗證（Sensor v2 自動掃描腳本）
  2. **ext_resource UID 驗證進入開發 DoD**：「確認場景的所有 ext_resource UID 不等於場景 UID」加入每個涉及場景複製的實作計畫的完成定義
  3. **根目錄腳本禁令或標準化**：在 pre-commit hook 中加入警告：根目錄下存在 .gd 文件時提醒確認編碼

- **給 Developer 的新技術約束**：
  - 所有 .gd 文件必須以英文撰寫（或以 UTF-8 無 BOM 儲存並驗證）
  - 複製 .tscn 後必須執行 UID 自引用驗證腳本再提交
  - 測試腳本若放在根目錄，必須符合與 scripts/ 相同的編碼標準

- **Memory 更新**：待更新（架構約束已加入各 ROLE 文件）


---

## 2026-06-12 21:00 — Architect 反省記錄（Phase 5.5/5.6）

### 工作摘要
- 協調 Sensor Level 2 觸發（ERR-018/019/020）和 Developer 修復
- 確認 ERR-017 VFX Spritesheet 切割錯誤的根本原因分析
- 制定 VFX 零配置架構（const path + _ready() auto-load）

### 反省
1. **架構缺失**：之前未明確要求 VFX 系統使用「零 Inspector 配置」原則
   - 改進：在 developer.md 中加入「VFX 設計原則」節點
2. **文件缺失**：之前的 VFX pattern 只記錄了 one_shot_vfx 模式，沒有記錄 spritesheet 量測流程
   - 改進：ERROR_LOG 第六批 PATTERN 已補充量測和縮放設計規則

### 架構決策更新
- **VFX 系統**：所有 VFX 場景使用 const path + runtime load() 而非 @export PackedScene
- **Spritesheet 量測**：必須用 System.Drawing 量測後計算，不允許目測估算
- **VFX 比例**：以玩家碰撞體大小為設計基準

---

### 2026-06-13 VFX 嵌入式架構重構

- **設計了什麼**：將近戰 VFX 從「runtime 動態生成」改為「Player 場景內嵌入式靜態節點」
- **觸發原因**：用戶需要在 Godot Scene Editor 中視覺化調整每次攻擊特效的位置
- **技術選型理由**：
  - **嵌入 vs 動態生成**：嵌入節點可在 Scene Editor 中直接選擇、拖動，無需修改任何代碼
  - **EmbeddedMeleeVFX 腳本**：新腳本 `embedded_melee_vfx.gd` 實現 `activate(facing)` API，hide-on-finish 而非 queue_free
  - **position 鏡像策略**：scene 中設正值 x（朝右）；`activate()` 用 `_base_x * facing` 計算實際 x，兼顧左右朝向
  - **modulate 同步**：`apply_player_color()` 同時更新 VisualPivot 和 3 個 VFX 節點的 modulate，無需在 activate() 再查
- **新架構圖**：
  ```
  Player (CharacterBody2D)
  ├── VisualPivot/Appearance  ← 角色外觀
  ├── MeleeVFX1 (EmbeddedMeleeVFX) ← 第1擊，可拖動
  ├── MeleeVFX2 (EmbeddedMeleeVFX) ← 第2擊，可拖動
  ├── MeleeVFX3 (EmbeddedMeleeVFX) ← 第3擊，可拖動
  └── ...其他節點
  ```
- **棄用的模式**：
  - ❌ `@export var melee_slash_scene: PackedScene` + `_spawn_melee_vfx()`
  - ❌ `@export_group("Melee VFX Offsets")` with Vector2 properties
  - ❌ Fallback loader functions `_get_melee_*_scene()`
- **新的強制規範**：
  - 近戰 VFX 必須是 EmbeddedMeleeVFX 實例，在 player1-4.tscn 中以 scene instance 加入
  - VFX 場景文件（MeleeSlash.tscn 等）必須使用 `embedded_melee_vfx.gd` 而非 `one_shot_vfx.gd`
  - 遠程 VFX（RangedMuzzle, EnemyHit, EnemyDeath）仍使用 one_shot_vfx.gd 動態生成
- **DoD**：
  - [x] EmbeddedMeleeVFX.gd 建立
  - [x] player1-4.tscn 加入 MeleeVFX1/2/3 scene instance
  - [x] player.gd 移除舊 @export 和 _spawn_melee_vfx()
  - [x] VFX tscn 換用 embedded_melee_vfx.gd
  - [x] Sensor 8/8 PASS
