# Implementation Plan — Ponytail 機制完整移除 + 防循環優化（GAP-031，2026-06-20）

## 目標
依用戶授權，將早期引入的 Ponytail 7-rung 機制從工作流**完整移除**，且**不影響其他功能**；同時優化工作流以修正「卡進 loop」問題。

## 範圍劃分

### 移除（Ponytail 舊機制）
- `hooks/commit-msg` v3→v4：刪除 `[Ponytail] rung=N` 強制區塊
- `hooks/pre-commit` v6→v7：刪除 `[Developer/Ponytail-A]` `.gd ponytail:` 注解檢查
- `scripts/sensor-scan.ps1`：刪除 Check 20（SAS-A Ponytail），22 → 21 checks
- `workflow.md`：移除 GLOBAL-RULE-002 階梯定義、§I 規則、§SAS-A、§AUDIT.2 SAS-A 掃描、§EDIT.2/.4、§LEARN 引用
- `docs/implementation_plan.md`、`scripts/*.gd`：移除 `# ponytail: rung=N` 注解與 Rung 欄位
- `tools/ponytail/`（未追蹤的上游套件目錄）：刪除

### 保留（其他功能，不得影響）
- 6 角色串行流（Designer→Architect→Developer→Reviewer→QA）+ Sensor 守衛
- 角色隔離閘門、BOM/UID/編碼驗證、物理回呼掃描（ERR-001 等）
- commit 格式驗證 `[ROLE] type: 描述`、fix commit ERR/GAP 提示
- CASCADE 0e/0f、SOP PENDING push 阻斷、DOC_INDEX/ERROR_LOG/PROJECT_STATUS 體系

### 優化（修正 loop）
- 新增 `workflow.md` GLOBAL-RULE-004：限制重試次數、commit 被阻斷時讀錯誤再修一次、需要輸入無回應時自行繼續、小型維護不啟動重型 5 角色 + feature branch 流程。

## 驗證
- `sensor-scan.ps1` 21/21 PASS（重編號後 1–21 全 PASS）
- `hooks/commit-msg`、`hooks/pre-commit` 以 `sh` 實測阻斷行為（§EDIT.2）
- 代碼類 commit 不再因缺 `[Ponytail]` 而 FAIL
