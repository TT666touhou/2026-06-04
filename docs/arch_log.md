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

## 2026-06-14 Phase 6.5 Architect 反省 — Portal Walk-in 轉場

### 失誤分析
- **失誤**：初期設計 SpawnMarker 系統時，_reset_player_at_door() 只做「瞬間 teleport 到 SpawnMarker」
- **根因**：只考慮了「位置正確」，沒有考慮**玩家進入感知體驗**
- **影響**：SpawnMarker 位置稍微偏差就產生割裂感，且不符合 2D Metroidvania 業界標準

### 設計教訓
- 2D Metroidvania（空洞騎士/Celeste/Metroid Dread）標準轉場流程：
  Fade Out → 場景切換 → Fade In → **Walk-in（短暫鎖定輸入+自動向內行走 40-60px）**
- Walk-in 期間重力正常，只鎖定水平輸入方向控制
- 進入方向由 door_id 自動推導（left→向右，right→向左）

### 架構升級
- oom_portal.gd：新增 enter_direction @export（auto/right/left/up/down）
- player.gd：新增 start_room_entry(dir, dist, dur) 封裝 entry 狀態
- game_world.gd：_reset_player_at_door() 改為呼叫 walk-in 而非直接 teleport

### ERR 提案
- 將「SpawnMarker 放置未考慮 walk-in 方向」加入 Sensor Level 2 觸發清單
