# docs/DOC_INDEX.md — 文件索引 & 職責矩陣

> 版本：v1 (2026-06-19)
> 由 pre-commit [0f] 監控：roles/*.md 修改時此文件必須同步 staged。

---

## 一、角色職責矩陣

| 文件 | Designer | Architect | Developer | Reviewer | QA |
|------|---------|---------|---------|---------|---|
| `docs/GAME_DESIGN.md` | ✏️ 主要維護者 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `docs/implementation_plan.md` | 🔴 唯讀 | ✏️ 主要維護者 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `docs/ERROR_LOG.md` | - | ✏️ 記錄錯誤 | ✏️ 記錄修正 | 🔴 唯讀 | 🔴 唯讀 |
| `docs/DOC_INDEX.md` | - | ✏️ 同步更新 | - | - | - |
| `docs/PROJECT_STATUS.md` | - | ✏️ 維護 | - | - | ✏️ 更新 |
| `docs/sop-state.md` | - | ✏️ 管理 SOP | ✏️ 執行步驟 | - | ✏️ 執行步驟 |
| `docs/qa-report-*.md` | - | - | - | 🔴 唯讀 | ✏️ 建立 |
| `workflow.md` | 🔴 唯讀 | ✏️ 版本更新 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `roles/*.md` | 🔴 唯讀 | ✏️ 維護 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `hooks/*` | 🔴 唯讀 | ✏️ 維護 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `scripts/sensor-scan.ps1` | 🔴 唯讀 | ✏️ 維護 | 🔴 唯讀 | 🔴 唯讀 | 🔴 唯讀 |
| `.gd scripts` | ❌ 禁止 | ❌ 禁止 | ✏️ 主要開發者 | 🔴 唯讀 | ❌ 禁止 |
| `.tscn scenes` | ❌ 禁止 | ❌ 禁止 | ✏️ 需 LFS Lock | 🔴 唯讀 | ❌ 禁止 |
| `.tres resources` | ❌ 禁止 | ❌ 禁止 | ✏️ 需 LFS Lock | 🔴 唯讀 | ❌ 禁止 |

**圖例：** ✏️ 可修改  🔴 唯讀  ❌ 禁止修改  `-` 不適用

---

## 二、各角色強制讀取清單（§READ SOP 前置條件）

> 每次角色對話開始，AI 必須確認已讀取以下文件。
> 詳細讀取流程 → `workflow.md §READ`

### Designer 開場必讀
1. `docs/GAME_DESIGN.md` — 目前設計狀態
2. `docs/PROJECT_STATUS.md` — 專案整體進度
3. `roles/designer.md` — 角色規則與 MUST-DO

### Architect 開場必讀
1. `docs/implementation_plan.md` — 目前架構計劃
2. `docs/GAME_DESIGN.md` — 設計需求基礎
3. `docs/ERROR_LOG.md` — 已知技術債
4. `roles/architect.md` — 角色規則與 MUST-DO

### Developer 開場必讀
1. `docs/implementation_plan.md` — 本次 Sprint 任務
2. `roles/developer.md` — 角色規則、17 個錯誤模式 (a-r)
3. `docs/ERROR_LOG.md` — 禁止重蹈的已知錯誤

### Reviewer 開場必讀
1. `docs/implementation_plan.md` — 審查基準
2. `roles/reviewer.md` — 10 項阻斷條件
3. `docs/GAME_DESIGN.md` — 設計意圖驗證

### QA 開場必讀
1. `docs/implementation_plan.md` — DoD 定義
2. `roles/qa.md` — QA 流程與 DoD
3. `docs/qa-report-*.md` — 最新 QA 報告（若存在）

---

## 三、文件版本追蹤

| 文件 | 版本 | 最後更新 | 更新角色 |
|------|------|---------|---------|
| `docs/GAME_DESIGN.md` | v1 | 2026-06-19 | Designer |
| `docs/DOC_INDEX.md` | v1 | 2026-06-19 | Architect |
| `docs/PROJECT_STATUS.md` | v2 | 2026-06-19 | Architect |
| `docs/sop-state.md` | v1 | 2026-06-19 | Architect |
| `docs/ERROR_LOG.md` | — | 2026-06-19 | Architect |
| `workflow.md` | v7 | 2026-06-19 | Architect |
| `scripts/sensor-scan.ps1` | v11 | 2026-06-19 | Architect |
| `hooks/pre-commit` | v5 | 2026-06-19 | Architect |
| `hooks/commit-msg` | v2 | 2026-06-19 | Architect |

---

## 四、§EDIT Cascade 規則（機器強制部分）

當以下文件被修改時，必須同步更新對應文件：

| 被修改的文件 | 必須同步 staged | 強制層 |
|-------------|--------------|--------|
| `scripts/sensor-scan.ps1` | `workflow.md` | pre-commit [0e] WARN |
| `roles/*.md` | `docs/DOC_INDEX.md` | pre-commit [0f] WARN |
| `docs/GAME_DESIGN.md` + 新增 `[CONFIRMED]` | — | pre-commit [0c] **FAIL** |

→ 詳見 `workflow.md §EDIT` 完整 Cascade 矩陣
