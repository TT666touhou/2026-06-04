# CLAUDE.md — Mandatory Session Bootstrap
# Claude Code 每次對話開始時自動讀取此文件。
# 所有指令為強制性，違反即為流程失敗。

## ⛔ 對話開始強制步驟（任何角色，無例外）

**在執行任何其他動作之前，必須依序完成以下所有步驟：**

```
STEP 0  確認 Godot 專案：  Test-Path "D:\2026-06-04\project.godot"
STEP 1  讀取角色文件：      Get-Content "D:\2026-06-04\.agent-role"
STEP 2  讀取 workflow.md：  完整閱讀 D:\2026-06-04\workflow.md
STEP 3  讀取 DOC_INDEX.md： 完整閱讀 D:\2026-06-04\docs\DOC_INDEX.md
STEP 4  讀取對應角色定義：  D:\2026-06-04\roles\<role>.md
STEP 5  讀取 ERROR_LOG.md： 完整閱讀 D:\2026-06-04\docs\ERROR_LOG.md（最近10條）
STEP 6  讀取 PROJECT_STATUS.md
```

跳過任何一步 = 本次對話流程無效，必須從 STEP 0 重新開始。

---

## 🔴 六角色序列（嚴格有序，不可跳步）

```
Designer → Architect → Developer → Reviewer → QA
```

| 角色 | .agent-role | 職責 | 必須留下的產出 |
|------|-------------|------|--------------|
| Designer | `designer` | 在 GAME_DESIGN.md 確認設計 | GDD 更新 commit `[DESIGN]` |
| Architect | `architect` | implementation_plan.md | 計劃 commit `[ARCH]` |
| Developer | `developer` | .gd / .tscn 實作 | feature branch commit `[DEV]` |
| Reviewer | `reviewer` | 審查 diff，寫 review_log.md | review commit `[REVIEW]` |
| QA | `qa` | sensor scan + 遊戲測試 | qa-report commit `[QA]` |

**Developer 在提交前必須先確認 Designer 已更新 GDD。**
**QA 在通過前必須確認 Reviewer 已簽核。**
**任何 WARN 或 FAIL 都必須處理或明確決策後才能繼續。**

---

## 🔴 WARN/FAIL 處理規則

- Sensor WARN → 必須記錄決策（修復 / 延後 / 豁免）並在 commit message 說明
- Sensor FAIL → 阻斷，必須修復後才能繼續任何步驟
- QA report 中任何 WARN → 必須在 QA commit 說明處理方式，不得靜默跳過

---

## 🔴 GDD 更新規則

- 任何影響遊戲行為的實作（移動、碰撞、視覺、輸入）→ Designer 必須先更新 GDD
- 不得先實作後補文件（補文件是補救，不是正常流程）
- GAME_DESIGN.md 只有 `designer` 角色可修改

---

## 🔴 角色切換規則

切換角色時必須：
1. 更新 `.agent-role` 文件
2. 讀取對應的 `roles/<new-role>.md`
3. 明確宣告：「現在以 [角色] 身份執行以下工作」

---

## 📋 當前專案速查

- **專案路徑**：`D:\2026-06-04`
- **引擎版本**：Godot 4.6.2
- **Sensor**：`.\scripts\sensor-scan.ps1`（v12 / 22 checks）
- **角色文件**：`roles/<role>.md`
- **Hooks**：自動執行（`git config core.hooksPath hooks` 已設定）
- **GDD**：`docs/GAME_DESIGN.md`（[DRAFT] 狀態，Designer 維護）
- **ERROR_LOG**：`docs/ERROR_LOG.md`（修復前必讀）

---

## ⚠️ 已知未解決問題

- **GAP-014**：GUT 測試 addon 未安裝 → 自動化測試無法執行 → QA 只能靜態驗證
  - 決策待定：安裝 GUT addon / 移除 test 文件 / 保持現狀
  - 每次 QA 必須在報告中明確說明此限制，不得靜默跳過
