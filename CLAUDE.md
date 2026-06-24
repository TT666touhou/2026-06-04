# CLAUDE.md — AI 工作守則（Session 強制規範）
# 完整 workflow 規範：workflow.md | 角色職責：roles/<role>.md

---

## ⛔ STEP 0：對話第一個動作（不可跳過）

```powershell
powershell -NoProfile -File "D:\2026-06-04\scripts\session-start.ps1"
```

執行後**依序讀取**（全部必讀，跳過任何一個 = 違規）：
1. `workflow.md` — 完整角色規則與 SOP
2. `roles\<role>.md` — 當前角色職責（.agent-role 的值）
3. `docs\DOC_INDEX.md` — 文件索引與職責矩陣
4. `docs\ERROR_LOG.md` — 已知錯誤（避免重蹈）
5. `docs\PROJECT_STATUS.md` — 當前開發狀態

---

## ⛔ 6 角色工作流（每次實作都必須遵守）

```
Designer → Architect → Developer → Reviewer → QA
（設計）    （架構）     （實作）      （審查）    （驗收）
                                              ↑ Sensor（隨時插入守衛）
```

**角色由 `.agent-role` 文件控制**。切換角色：`.\scripts\set-role.ps1 <role>`

| 角色 | 能 commit 的文件 | 禁止 commit | 前綴 |
|------|----------------|------------|------|
| designer | `docs/GAME_DESIGN.md`, `docs/*.md` | `.gd/.tscn/.tres` | `[DESIGN]` 或 `docs:` |
| architect | `implementation_plan.md`, `docs/`, `roles/` | `.gd/.tscn/.tres` | `[ARCH]` |
| developer | 代碼透過 dev-submit.ps1；docs/ | 不可直接 commit `.gd/.tscn/.tres` | `[DEV]` |
| reviewer | 只審查，不提交代碼 | 修改任何代碼 | `[REVIEW]` |
| qa | `.gd/.tscn/.tres` + `docs/qa-report-*.md` | 自行撰寫新代碼 | `[QA]` |

**實際操作簡化（單 AI session）**：
- 設計/GDD 變更 → 切換 designer → 更新 GAME_DESIGN.md → commit `docs:`
- 代碼實作 → 切換 developer → 寫代碼 → commit `[DEV]`
- 兩件事同一 session → 分兩次 commit，先 designer 後 developer

---

## ⛔ commit 前強制檢查清單（缺任一 = 知識丟失）

| 必做 | 說明 |
|------|------|
| ✅ `docs/ERROR_LOG.md` | 新增 GAP-XXX 條目 |
| ✅ `docs/GAME_DESIGN.md` | **行為/設計改變** → 切換 Designer 更新 GDD（不能跳過！） |
| ✅ `docs/PROJECT_STATUS.md` | 更新日誌加一行 |
| ✅ 角色正確 | `.agent-role` 符合你要 commit 的文件類型 |

**commit 前自問**：
1. 我改的每一行，用戶有沒有明確要求？
2. 有沒有「感覺應該順便加的」內容？→ 刪掉或先問。
3. GDD 有沒有因此需要更新？→ 一定要更新。

---

## ⛔ 場景內容保護規則（違反 = 超出要求範圍）

> 未獲用戶明確要求，**絕對禁止**修改：
> - 場景平台位置/數量（不得新增或刪除）
> - 世界尺寸（Ground/Ceiling/WallLeft/WallRight 的 shape size 和 position）
> - 任何 StaticBody2D 的幾何形狀
>
> **判斷原則**：「加鏡頭」≠ 許可「改世界大小或加平台」
> 有疑問 → **先問用戶**，不要假設

---

## ⛔ 核心禁止行為（workflow.md GLOBAL-RULE 摘要）

| 規則 | 禁止行為 |
|------|---------|
| GR-001 | 禁止使用 browser_subagent；改用 WebFetch/WebSearch/PowerShell |
| GR-003 | 選項收集用 AskUserQuestion（非 show_widget）；問題不問超過 2 次 |
| GR-004 | 同一指令失敗最多試 2 次；同一 bug 失敗 3 次 → 切換 Architect 重設計 |
| GR-005 | 只做用戶明確要求的事；不自行擴大範圍（典型錯誤：「加鏡頭」→自改世界大小） |
| I-C-5 | 同一 bug 失敗 3 次 → 熔斷，切換 Architect |
| 測試規則 | commit 前用 `mcp__godot__run_project` + `get_debug_output` 確認無 error |
| 場景保護 | 見上方場景保護規則 |

---

## ⛔ Godot 驗證規則

- **禁止** computer-use 存取遊戲 EXE（request_access 永遠失敗）
- 正確方式：`mcp__godot__run_project` → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`
- 有 error → 修復；只有 warning → 評估是否需要修

---

## ⛔ 文件守護責任（Designer 角色核心義務）

- **任何遊戲機制改變** → 必須更新 `docs/GAME_DESIGN.md`
- Designer 是 GAME_DESIGN.md 的唯一維護者
- Developer commit 後，如果行為與 GDD 不符 → 切換 Designer 補更新
- QA 若發現 `[GDD TODO]` 未解決 → 禁止 QA 通過

---

## ⛔ §MOD SOP（修改 workflow/規則時必走 5 步驟）

修改 `workflow.md`、`CLAUDE.md`、`roles/`、`hooks/` 時，**必須**走以下流程：

```
① Sensor：sensor-scan.ps1 現狀掃描
② Architect：差距分析 + 修改計畫（等用戶確認）
③ Developer：實施修改
④ Reviewer：確認不衝突，ERROR_LOG 已更新
⑤ QA：模擬測試 → git commit
```

> 完整 §MOD SOP 細節：`workflow.md §MOD`

---

## 參考

| 文件 | 用途 |
|------|------|
| `workflow.md` | 完整 6 角色工作流、所有 SOP、Global Rules 詳細版 |
| `roles/<role>.md` | 當前角色的詳細職責與禁止事項 |
| `docs/DOC_INDEX.md` | 文件索引、職責矩陣 |
| `docs/ERROR_LOG.md` | 所有已知錯誤與修復方法 |
| `docs/GAME_DESIGN.md` | GDD（唯一設計真相來源） |
| `docs/PROJECT_STATUS.md` | 開發進度 |
