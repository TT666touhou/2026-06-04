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
