# 專案協同與 AI 開發規範 (RULES.md)

本文件是本專案的「開發憲法」。AI 助理（Antigravity）在進行任何代碼修改、分析或回應前，必須先閱讀並嚴格遵守本文件所載之所有規則。

---

## 🚫 一、 AI 行為與防跑偏限制 (Anti-Drift Constraints)

1. **嚴禁盲改與盲猜 (No Guessing)**：
   - 遇到 Bug 或測試失敗時，禁止在未加入 Debug Log 的情況下猜測修改代碼。
   - 必須先加入診斷性日誌，獲取真實的 Runtime Log，確認根源後才可提出修改計畫。
2. **實作前必須提交計畫 (Gated Workflow)**：
   - 任何涉及代碼邏輯的修改，必須先建立或更新 `implementation_plan.md`，等待人類用戶確認批准後方可執行。
   - 僅有 investigatory（調查性質）或極為微小的格式微調（如排版、註解）可免除計畫審查。
3. **事實閱讀原則 (Read Before Write)**：
   - AI 在分析代碼或回答邏輯前，必須使用 `view_file` 或 `grep_search` 驗證實際檔案內容，絕對不可僅憑大模型記憶或歷史對話進行推斷。
4. **偵錯熔斷機制 (Debugging Circuit Breaker)**：
   - 若針對同一個 Bug 連續修復 3 次皆失敗，AI 必須立即熔斷（停止修改），整理已嘗試的方案與失敗 Log，交還控制權給人類。

---

## 📂 二、 專案結構與模組化邊界 (Modularity Boundaries)

1. **基於功能的目錄結構 (Feature-Based Structure)**：
   - 專案程式碼應依照功能模組分門別類存放在 `src/features/[feature_name]/` 下。
   - 每個 Feature 資料夾應為自包含（Self-contained），包含其專屬的場景（.tscn）、腳本（.gd）以及單元測試（_test.gd）。
2. **跨模組調用限制 (Dependency Rules)**：
   - 嚴禁 Feature 與 Feature 之間產生直接的內部私有變數引用或循環依賴。
   - 跨模組的通信必須透過 `src/core/` 定義的 Global Singleton 介面，或使用 `Signal` 進行異步通信。
3. **代碼修改範圍限制 (Blast Radius Control)**：
   - AI 在開發特定 Feature 時，其檔案讀寫權限應限制在該 Feature 資料夾內，嚴禁無故修改其他模組的代碼。

---

## 🧪 三、 真實有效的驗證機制 (Auto-Verification Rules)

為了防止 AI 在自我驗證時寫出「無效 Assert」或「空測試」：

1. **測試代碼與業務代碼分離**：
   - 所有的單元測試必須繼承自專案規定的測試框架（如 Gut 或 gdUnit4），並存放在獨立的測試檔案中。
   - AI **嚴禁修改或刪除已有的基準測試 (Baseline Tests)**。若功能變更導致既有測試失敗，必須提出架構層面的解釋。
2. **Commit 前置語法檢查 (Pre-commit Git Hook)**：
   - 所有代碼在 commit 前，必須在本機通過 `godot --headless --check-only --path .` 的靜默語法與型別安全檢查。
   - 單元測試必須在本地運行通過。若有任何一項失敗，拒絕進行 Commit。
