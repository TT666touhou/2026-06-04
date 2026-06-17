# DOC_INDEX.md — 專案文件總索引
# ============================================================
# 版本：v4 (2026-06-17 — 引入 Ponytail 7-rung ladder 規則)
# 維護者：所有 ROLE（每次新增文件時必須更新此索引）
# 讀取時機：每個 ROLE 工作開場 MUST-DO 清單「第 -2 步」
# ============================================================

> **強制規則**：新增任何文件時，必須在本索引新增一行。
> 切換 ROLE 時，set-role.ps1 會提示你讀取此索引。

---

## 📋 每個 ROLE 的文件職責矩陣

| 文件 | Designer | Architect | Developer | Reviewer | QA | Sensor |
|------|:--------:|:---------:|:---------:|:--------:|:--:|:------:|
| docs/GAME_DESIGN.md | **寫/讀** | 讀 | 讀 | 讀 | 讀 | 監控 |
| docs/PROJECT_STATUS.md | 讀 | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** | 讀 |
| docs/ERROR_LOG.md | 讀 | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** |
| implementation_plan.md | 讀 | **寫** | 讀 | 讀 | 讀 | - |
| docs/DOC_INDEX.md（本文件） | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** | **讀/寫** |
| workflow.md（KI） | 讀 | **讀/寫** | 讀 | **讀/寫** | 讀 | 監控 |
| roles/designer.md | 讀 | **讀/寫** | 讀 | **讀/寫** | 讀 | 監控 |
| roles/architect.md | 讀 | **讀** | 讀 | **讀/寫** | 讀 | 監控 |
| roles/developer.md | 讀 | **讀/寫** | **讀** | **讀/寫** | 讀 | 監控 |
| roles/reviewer.md | 讀 | **讀/寫** | 讀 | **讀** | 讀 | 監控 |
| roles/qa.md | 讀 | **讀/寫** | 讀 | 讀 | **讀** | 監控 |
| roles/sensor.md | 讀 | **讀/寫** | 讀 | **讀/寫** | 讀 | **讀/寫** |
| scripts/set-role.ps1 | - | **讀/寫** | 讀 | 讀 | - | 監控 |
| scripts/sensor-scan.ps1 | - | 讀 | **必讀** | **讀** | **讀** | **讀/寫** |
| scripts/dev-submit.ps1 | - | - | **讀** | 讀 | - | - |
| docs/review_reports/ | - | - | - | **寫** | 讀 | - |
| docs/qa-report-*.md | - | - | - | 讀 | **寫** | - |

**圖例**：
- **寫** = 此角色主要負責寫入/維護
- **讀** = 此角色必須讀取
- **讀/寫** = 此角色讀取且可能寫入
- 監控 = Sensor 持續監控此文件的結構完整性
- `-` = 通常不涉及

---

## 📁 完整文件清單

### 🎮 遊戲設計文件

| 文件路徑 | 負責角色 | 最後更新 | 說明 |
|---------|---------|---------|------|
| `docs/GAME_DESIGN.md` | Designer | 2026-06-16 | 唯一設計依據，所有角色遵循 |
| `docs/PROJECT_STATUS.md` | Architect/QA | 2026-06-16 | 各 Phase 進度，每次工作必讀 |
| `docs/arch_log.md` | Architect | 2026-06-16 | 架構決策日誌 |
| `docs/design_log.md` | Designer | 2026-06-16 | 設計決策日誌 |
| `docs/dev_log.md` | Developer | 2026-06-16 | 開發日誌 |
| `docs/review_log.md` | Reviewer | 2026-06-16 | 審查日誌 |
| `docs/qa_log.md` | QA | 2026-06-16 | QA 日誌 |
| `implementation_plan.md` | Architect | - | 當前開發計畫（動態） |

### 🔴 錯誤知識庫

| 文件路徑 | 負責角色 | 最後更新 | 說明 |
|---------|---------|---------|------|
| `docs/ERROR_LOG.md` | 所有 ROLE | 2026-06-16 | **每次工作必讀** — 65KB，包含 ERR-001~041 |

### 🎨 美術資源研究

| 文件路徑 | 負責角色 | 最後更新 | 說明 |
|---------|---------|---------|------|
| `docs/research-asset-sourcing.md` | Designer | - | 素材資源研究 |

### 👥 角色文件（6 個 ROLE 的工作規範）

| 文件路徑 | 角色版本 | 最後更新 | 關鍵特性 |
|---------|---------|---------|---------|
| `roles/designer.md` | v4 | 2026-06-17 | GDD 三項紀律，移除 PixelLab |
| `roles/architect.md` | v4 | 2026-06-17 | 物理 callback 架構約束，移除 PixelLab，ERR-001/006/007 |
| `roles/developer.md` | v5 | 2026-06-17 | 禁止直接 commit，dev-submit.ps1，Sensor 前置，移除 PixelLab |
| `roles/reviewer.md` | v5 | 2026-06-17 | 分支任務，移除 PixelLab |
| `roles/qa.md` | v6 | 2026-06-17 | 唯一 commit 角色，45分鐘測試流程，移除 PixelLab |
| `roles/sensor.md` | v5 | 2026-06-17 | DOC_INDEX 同步掃描 Level 2，移除 PixelLab |

### 🔧 自動化腳本（KEY Scripts）

| 腳本路徑 | 負責角色 | 說明 |
|---------|---------|------|
| `scripts/set-role.ps1` | Architect | **每次切換角色必用** — 設定 .agent-role 文件 |
| `scripts/sensor-scan.ps1` | Sensor | **每次 commit 前必跑** — 14/14 掃描項目 |
| `scripts/dev-submit.ps1` | Developer | 代碼提交前置流程 |
| `scripts/assert-clean.ps1` | Developer | 工作區清潔確認 |

### 📊 QA 報告（歸 QA 管理）

| 文件路徑 | 對應功能 | 說明 |
|---------|---------|------|
| `docs/qa-report-phase-7.0.md` | Phase 7.0 | Phase 7 QA 驗收報告 |
| `docs/qa-report-f6-walkin-fix.md` | F6 Walk-in | F6 場景 Walk-in 修復報告 |
| `docs/qa-report-playerdust-vfx.md` | PlayerDust VFX | 玩家塵埃特效 QA |

---

## 🔄 強制更新規則

### 新增文件時（任何 ROLE）

```
□ 1. 在本文件（DOC_INDEX.md）對應分類下加入一行
□ 2. 更新「每個 ROLE 的文件職責矩陣」（確認哪些角色需讀取）
□ 3. 在對應 ROLE 的 roles/*.md 開場清單中加入強制讀取步驟
□ 4. 在 docs/ERROR_LOG.md 說明新文件的用途（若與已知問題相關）
```

### 修改現有文件時（任何 ROLE）

```
□ 1. 更新本文件「最後更新」欄位
□ 2. 若是規則性修改 → 走 §MOD 5步驟 WORKFLOW 修改 SOP（見 workflow.md）
```

---

## 📖 WORKFLOW 修改 SOP（§MOD — 5步驟流程）

> **觸發時機**：用戶要求「修改 workflow / 強化規則 / 反省文檔」時

```
步驟 1（Sensor）：現狀掃描
  - 執行 scripts/sensor-scan.ps1，記錄當前掃描結果
  - 讀取 docs/ERROR_LOG.md 確認相關 ERR 條目
  - 確認 DOC_INDEX.md 是否需要更新

步驟 2（Architect）：差距分析
  - 分析現有規則與用戶需求的差距
  - 確定需修改的文件清單（更新 DOC_INDEX.md）
  - 輸出「修改計畫」給用戶確認

步驟 3（Developer）：實施修改
  - 依照計畫修改對應文件
  - 每次修改後確認文件落地（用 grep/Select-String 驗證）
  - 更新 DOC_INDEX.md 的「最後更新」

步驟 4（Reviewer）：審查新規則
  - 確認新規則不與現有規則衝突
  - 確認相關的 ERROR_LOG.md 條目已更新
  - 確認所有角色的 MUST-DO 清單已同步

步驟 5（QA）：測試驗證
  - 執行模擬測試（用假場景觸發新規則）
  - 確認規則在 pre-commit hook 和 sensor-scan.ps1 中有效
  - Git commit 並記錄在 docs/review_reports/
```

---

## 📖 文件讀取 SOP（§READ — ROLE 開場強制讀取）

> **觸發時機**：每次切換 ROLE 時（set-role.ps1 執行後，開始工作前）

```
第 -2 步（所有 ROLE 通用，不可跳過）：
  □ 讀取 docs/DOC_INDEX.md（本文件）
    Get-Content "D:\2026-06-04\docs\DOC_INDEX.md"
    - 確認自己角色在「職責矩陣」中的讀/寫職責
    - 找出本次任務涉及的文件類型（Godot/文件）
    - 依類型找到對應的「必讀文件清單」
  
  ⚠️ 若跳過此步驟 → 視為嚴重違規，Sensor 應介入中斷

第 -1 步（所有 ROLE 通用，不可跳過）：
  □ 讀取 docs/PROJECT_STATUS.md
  
第 0 步（所有 ROLE 通用，不可跳過）：
  □ 讀取 docs/ERROR_LOG.md
```

---

## 🔒 Sensor 文件監控清單

Sensor 監控以下文件的結構完整性：

| 文件 | 監控條件 | 觸發動作 |
|------|---------|---------|
| `docs/GAME_DESIGN.md` | Designer commit 後 | 驗證 §8.3/§8.3.1/§8.5 關鍵詞 |
| `roles/*.md` | 任何角色 commit | 確認 MUST-DO 清單包含 DOC_INDEX.md 讀取步驟 |
| `scripts/set-role.ps1` | 任何修改 | 確認文件為 UTF-8 無 BOM，可正常執行 |
| `docs/DOC_INDEX.md` | 新增文件後 | 確認新文件已被加入索引 |
| `docs/ERROR_LOG.md` | 任何 ERR 處理後 | 確認 ERR-042 以後的編號連續 |

---

*DOC_INDEX.md v1 建立於 2026-06-16 / v2 更新於 2026-06-16 / v3 更新於 2026-06-17（清理 PixelLab API 實驗）*
*由 Architect 角色首次建立，後由所有 ROLE 共同維護*
