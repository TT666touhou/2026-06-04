# CLAUDE.md — 強制開場
# 每次對話第一個動作：執行下方指令

## ⛔ SESSION START — 第一個動作（不可跳過）

```powershell
powershell -NoProfile -File "D:\2026-06-04\scripts\session-start.ps1"
```

執行後閱讀輸出，然後：
- `Read D:\2026-06-04\workflow.md` — 完整角色規則
- `Read D:\2026-06-04\roles\<role>.md` — 當前角色職責

---

## ⛔ 修完 BUG 或實作功能後（commit 前，缺任一 = 知識丟失）

| ✅ | `docs/ERROR_LOG.md` 新增 GAP-XXX 條目 |
| ✅ | `docs/GAME_DESIGN.md` 行為改變 → Designer 角色更新 |
| ✅ | `docs/PROJECT_STATUS.md` 更新日誌加一行 |

---

## ⛔ Godot 驗證：禁止 computer-use 存取遊戲 EXE

Godot EXE 不在 Start Menu → `request_access` 永遠失敗，不要嘗試。
正確方式：GUT 測試 或 `mcp__godot__run_project` + `mcp__godot__get_debug_output`
