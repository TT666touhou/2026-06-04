# Implementation Plan — 全面機械化工作流規則（2026-06-20）

## 目標
將 workflow.md 中所有可機械強制的規則升級至 [HOOK] 或 [SENSOR] 層，消除「文件說有但 hook 沒實作」的空殼問題。

## 已完成（Pre-conversation）
- Block 1: `docs/DOC_INDEX.md` 建立（所有 ROLE 開場必讀索引）
- Block 3: `hooks/pre-commit` v5→v6（CASCADE 0e/0f + Designer/3 + Developer/auto-sensor）
- Block 4: `scripts/sensor-scan.ps1` v11→v12（15→22 checks，補 Checks 16-22）

## 本次完成
- Block 2+5: `hooks/commit-msg` v2→v3
  - 修復 header/echo 版本不一致（header v2 vs echo v3）
  - 新增 Ponytail 強制：feat/fix/refactor/style/perf → `[Ponytail] rung=N` → FAIL
  - 新增 fix/ERR hint：fix commit 無 ERR-XXX/GAP-XXX → WARN
- `hooks/pre-commit` v6（補實作）
  - 新增 `[Developer/Ponytail-A]` 代碼（header 宣稱但原本無實作）

## 驗證
- commit-msg 測試 7/7 PASS（sh hook 實際執行，非假設）
- sensor-scan.ps1 22/22 PASS

## 剩餘（Block 6 — workflow.md §I 重分類）
- workflow.md §I 已正確記錄所有規則，無需重分類（實作補齊後文件已與實作一致）
