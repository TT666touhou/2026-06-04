# CLAUDE.md — 強制開場清單
# 這是唯一自動載入的規則文件。workflow.md 在步驟 5 主動讀取。

## ⛔ 每次對話開始，立刻依序執行（不可跳過，跳過 = Sensor Level 3）

```
1. Read D:\2026-06-04\.agent-role
2. Read D:\2026-06-04\docs\PROJECT_STATUS.md
3. Read D:\2026-06-04\docs\ERROR_LOG.md
4. Read D:\2026-06-04\docs\GAME_DESIGN.md  （若涉及遊戲功能）
5. Read D:\2026-06-04\workflow.md           （完整角色規則、hook 格式、SOP）
6. Read D:\2026-06-04\roles\<current-role>.md
```

## ⛔ 修完 BUG 或實作功能後（commit 前必做，缺任一 = 知識丟失）

| 必做 | 操作 |
|------|------|
| ✅ | `docs/ERROR_LOG.md` 新增 GAP-XXX 條目（症狀、根本原因、修復、防範規則） |
| ✅ | `docs/GAME_DESIGN.md` 若行為改變 → Designer 角色更新 |
| ✅ | `docs/PROJECT_STATUS.md` 更新日誌加一行 |

## ⛔ Godot 驗證：禁止 computer-use 存取遊戲 EXE

- `request_access` 只對 Windows 開始功能表已安裝 App 有效
- Godot EXE 不在開始功能表 → 永遠失敗，不要嘗試
- **正確方式**：GUT 自動化測試（首選）或 `mcp__godot__run_project` + `mcp__godot__get_debug_output`
