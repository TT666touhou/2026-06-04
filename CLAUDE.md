# CLAUDE.md — Mandatory Session Bootstrap
# Claude Code 在每次對話開始時自動讀取此文件。
# workflow.md 是完整規則的唯一來源。

@workflow.md

---

## ⛔ SESSION START — 強制執行清單（不可跳過）

每次對話開始，AI 必須立刻依序執行以下步驟，任何步驟跳過 = Sensor Level 3 觸發：

```
1. Read D:\2026-06-04\.agent-role          → 確認當前角色
2. Read D:\2026-06-04\docs\PROJECT_STATUS.md → 了解當前開發狀態
3. Read D:\2026-06-04\docs\ERROR_LOG.md    → 了解所有已知問題
```

---

## ⛔ 修完 BUG 後強制清單（Developer / QA / 任何角色）

每次修復 bug 或實作功能後，**在 commit 之前**，必須完成以下項目：

| 必做 | 操作 | 對應文件 |
|------|------|---------|
| ✅ | 在 ERROR_LOG.md 新增 GAP-XXX 條目（症狀、根本原因、修復方法、防範規則） | `docs/ERROR_LOG.md` |
| ✅ | 確認 GAME_DESIGN.md 是否需要更新（功能行為改變 → Designer 必須更新） | `docs/GAME_DESIGN.md` |
| ✅ | 更新 PROJECT_STATUS.md 的「更新日誌」一行 | `docs/PROJECT_STATUS.md` |

> **不更新 ERROR_LOG 就 commit = 知識丟失 = 下次浪費同樣的時間。**
> 即使任務看起來很小，只要是 bug fix 或新功能，這三步驟都是必須的。

---

## ⛔ computer-use 驗證限制（QA 必讀）

- `request_access` 只對 Windows 開始功能表已安裝的 App 有效。
- Godot 遊戲 EXE（`Godot_v4.6.2-stable_win64.exe`）不在開始功能表 → 永遠失敗。
- **正確驗證方式**：GUT 自動化測試（首選）或 `mcp__godot__run_project` + `mcp__godot__get_debug_output`。
- 禁止嘗試用 computer-use 存取 Godot 遊戲 process，浪費時間。
