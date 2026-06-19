# docs/sop-state.md — SOP 執行狀態追蹤
> **由 Sensor [21/21] 在提交前讀取**；有 PENDING 項目時輸出 WARN。
> **由 set-role.ps1 在角色切換時讀取**；顯示當前角色應接手的 PENDING 步驟。
>
> 更新規則：
> - 每個 SOP 步驟完成後，立即將 `PENDING` 改為 `DONE` 並填入完成時間
> - SOP 全部完成後，將整個區塊移至「已完成 SOP 歷史」
> - 格式：SOP名稱 + 觸發事件 + 開始日期

---

## 進行中 SOP

### §IMPL — MVP Wire Physics System（開始：2026-06-19）

**觸發原因**：GDD MVP 規格完成，進入實作階段：PlayerController + NeedleProjectile + WireConstraint + WirePlatform

| 步驟 | 名稱 | 狀態 | 執行角色 | 完成時間 |
|------|------|------|----------|---------|
| Step ① | Sensor scan — 確認 clean baseline | DONE | Sensor | 2026-06-19 |
| Step ② | Architect plan — 節點架構 + wire physics 技術決策 | DONE | Architect | 2026-06-19 |
| Step ③ | Developer impl — 實作所有模組 (.gd + .tscn) | DONE | Developer | 2026-06-19 |
| Step ④ | Reviewer review — 審查模組化設計與 Ponytail 合規 | PENDING | Reviewer | — |
| Step ⑤ | QA verify + commit — 物理驗證 + sensor PASS + commit | PENDING | QA | — |

---

### §MOD — Ponytail/SOP 強化（開始：2026-06-19）

**觸發原因**：Ponytail `rung=N` 格式未強制、`.gd` ponytail: 注解未驗證、sop-state PENDING 未阻斷 push

| 步驟 | 名稱 | 狀態 | 執行角色 | 完成時間 |
|------|------|------|----------|---------|
| Step ① | Sensor scan — 確認基線（sensor 21/21 PASS） | DONE | Sensor | 2026-06-19 |
| Step ② | Architect plan — 分析 Ponytail/SOP 執行漏洞，規劃 3 hook 升版 + workflow v8 | DONE | Architect | 2026-06-19 |
| Step ③ | Developer impl — commit-msg v3 + pre-commit v6 + pre-push v3 + workflow v8 | DONE | Developer | 2026-06-19 |
| Step ④ | Reviewer review — 審查 hook 邏輯（Ponytail rung= 邏輯正確、SOP check 限 main） | DONE | Reviewer | 2026-06-19 |
| Step ⑤ | QA verify + commit — sensor 21/21 PASS + commit-msg v3 rung= 測試全通過 | DONE | QA | 2026-06-19 |

---

## 已完成 SOP 歷史

### §MOD — 全面機械化（2026-06-19 完成）

**觸發原因**：用戶要求將所有 workflow 規則盡可能升級至機器強制層

| 步驟 | 名稱 | 狀態 | 執行角色 | 完成時間 |
|------|------|------|----------|---------|
| Step ① | Architect plan — 差距分析 + Block 1-6 計畫（12 項可機械化規則） | DONE | Architect | 2026-06-19 |
| Step ② | Developer impl — Block 1-6 實作（sensor v11/21, pre-commit v5, commit-msg v2, DOC_INDEX.md, workflow v7） | DONE | Developer | 2026-06-19 |
| Step ③ | Reviewer review — 審查所有變更（sensor 21 checks、cascade rules、Ponytail enforcement） | DONE | Reviewer | 2026-06-19 |
| Step ④ | QA verify + commit — 驗收並執行最終 commit+push | DONE | QA | 2026-06-19 |

### §LEARN — GAP-012, GAP-013（2026-06-19 完成）

**觸發原因**：GAP-012（AI 擅自標記 [CONFIRMED]）、GAP-013（workflow.md 從未 merge 至 main）

| 步驟 | 名稱 | 狀態 | 執行角色 | 完成時間 |
|------|------|------|----------|---------|
| Step 1 | CAPTURE — 記錄至 ERROR_LOG.md (GAP-012/013) | DONE | Architect | 2026-06-19 |
| Step 2 | CROSS-REF — 確認 GAP-012/013 相互關聯，同步至 workflow.md §I-B | DONE | Architect | 2026-06-19 |
| Step 3 | PROPAGATE — 傳播至 hooks/pre-commit, hooks/pre-push, sensor-scan.ps1 | DONE | Developer | 2026-06-19 |
| Step 4 | ENFORCE — 機器層實作完成（Block 1-5 all done） | DONE | Developer | 2026-06-19 |
| Step 5 | VERIFY — 執行 sensor-scan.ps1 確認 PASS | DONE | Developer | 2026-06-19 |
| Step 6 | COMMIT — [ARCH] chore: commit all workflow enforcement changes | DONE | Architect | 2026-06-19 |

### §MOD — workflow 強化（2026-06-19 完成）

**觸發原因**：用戶要求所有 workflow 規則與 SOP 具備機械層強制力（第一輪）

| 步驟 | 名稱 | 狀態 | 執行角色 | 完成時間 |
|------|------|------|----------|---------|
| Step ① | Sensor scan — 執行 sensor-scan.ps1 掃描現況 | DONE | Sensor | 2026-06-19 |
| Step ② | Architect plan — 差距分析 + 4+1 個 Block 計畫 | DONE | Architect | 2026-06-19 |
| Step ③ | Developer impl — Block 1-5 實作 (v10/15 sensor, hook v4/v2, sop-state.md) | DONE | Developer | 2026-06-19 |
| Step ④ | Reviewer review — 審查所有變更 | DONE | Reviewer | 2026-06-19 |
| Step ⑤ | QA verify + commit — 驗收並執行最終 commit+push | DONE | QA | 2026-06-19 |

---

## SOP 狀態說明

| 標記 | 含義 |
|------|------|
| `DONE` | 步驟已完成，有完成時間記錄 |
| `PENDING` | 步驟尚未開始或進行中，需要對應角色執行 |
| `SKIPPED` | 步驟因特殊原因跳過（需在備註欄說明） |
