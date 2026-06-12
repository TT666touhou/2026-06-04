# 📔 審查日誌 (review_log.md)
> 所有 Reviewer 工作的記錄。每次審查後必須追加。

---

### 2026-06-12 ERR-012/013/014/015 — Reviewer 審查後反省

- **審查結論**：❌ 退回（事後修復，未在 PR 時攔截）
- **靜態錯誤狀況**：Godot --check-only 無法偵測這幾類錯誤（runtime-only 或文件系統錯誤）
- **主要問題**：
  1. **ERR-012**：`boss.gd` 中文內容以非 UTF-8 儲存 → Reviewer 審查時沒有執行 BOM 掃描腳本
  2. **ERR-013**：`player1-4.tscn` 中 ext_resource UID 全部指向場景自身的 UID → Reviewer 審查 .tscn 文件時沒有核對 ext_resource UID 與實際資源 UID 的對應
  3. **ERR-014**：`test_stretch.gd` 使用 Godot 3 廢棄 API → 測試腳本未納入審查範圍
  4. **ERR-015**：`test_*.gd` 文件有 UTF-8 BOM → 根目錄下的測試腳本被 Reviewer 忽略
- **根本失敗原因**：
  1. Reviewer 審查清單中有 SubResource 驗證（ERR-008）但沒有 ext_resource UID 驗證（ERR-013）
  2. Reviewer 的 BOM 掃描只涵蓋 UTF-16（ff/fe）未涵蓋 UTF-8 BOM（ef/bb/bf）和 non-UTF-8 編碼
  3. 根目錄下的測試腳本被視為「臨時文件」而未審查，但 Godot 啟動時會載入所有腳本
- **新增 Reviewer 強制步驟**：
  - 審查任何包含場景複製的 PR 時：必須執行 UID 自引用驗證腳本
  - 審查任何 .gd 文件時：執行 BOM 掃描（涵蓋 UTF-8 BOM + UTF-16 BOM + 非 UTF-8 位元組）
  - **根目錄下的所有 .gd 文件也需納入審查**（不是只有 scripts/ 目錄）
- **給 Developer 的建議**：
  - 統一以英文撰寫 .gd 文件（零編碼風險）
  - 每次複製 .tscn 後立即執行 UID 自引用驗證
- **給 QA 的測試重點提示**：
  - 啟動遊戲時是否有 Unicode parsing error？
  - 所有玩家場景（player1-4.tscn）是否能正確載入？
  - Boss 場景是否能進入且 Boss AI 正常運行？

### [模板] YYYY-MM-DD PR#N [功能描述]
- **審查結論**：✅ 通過 / ❌ 退回
- **靜態錯誤狀況**：0 ERROR
- **DoD 符合度**：N/N 項通過
- **DebugBridge 驗證**：✅ / ❌
- **給 Developer 的建議**：
- **給 QA 的測試重點提示**：


---

## 2026-06-12 21:00 — Reviewer 審查記錄（Phase 5.5/5.6）

### 審查範圍
- one_shot_vfx.gd 自我配置重寫
- 4個 VFX scenes（MeleeSlash/RangedMuzzle/EnemyHit/EnemyDeath）
- player.gd、enemy1/2/3.gd VFX auto-load 修改
- debug_bridge.gd、debug_overlay.gd 警告修復

### 審查結論
- ✅ BOM 掃描全通過
- ✅ spawn_pos 重複宣告已修復（只剩 L853 一個）
- ✅ StringName→String 顯式轉型正確
- ✅ roundi() 替換 narrowing 轉型正確
- ✅ AtlasTexture region 計算邏輯正確（i * frame_width, 0, frame_width, frame_height）
- ✅ VFX UID 格式已修正為 13位英數字 Godot 標準格式
- ✅ 所有 VFX scene 的 scale 設計符合比例要求

### 建議
- 未來 VFX 添加時，建議在 one_shot_vfx.gd 中加入 @tool 標註方便在 Editor 中預覽

