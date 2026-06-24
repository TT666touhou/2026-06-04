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

## ⛔ 場景內容保護規則（2026-06-24 硬性規則）

> **絕對禁止** 在沒有用戶明確要求的情況下修改以下內容：
> - 場景中的平台位置/數量（不得新增或刪除平台）
> - 世界尺寸（Ground/Ceiling/WallLeft/WallRight 的 shape size 和 position）
> - 任何 StaticBody2D 的幾何形狀
>
> **判斷標準**：用戶要求「加鏡頭」≠ 許可「改世界大小或加平台」。
> 有疑問時**先問**，不要假設用戶同意。

---

## ⛔ 修完 BUG 或實作功能後（commit 前，缺任一 = 知識丟失）

| ✅ | `docs/ERROR_LOG.md` 新增 GAP-XXX 條目 |
| ✅ | `docs/GAME_DESIGN.md` 行為改變 → Designer 角色更新 |
| ✅ | `docs/PROJECT_STATUS.md` 更新日誌加一行 |

---

## ⛔ Godot 驗證：禁止 computer-use 存取遊戲 EXE

Godot EXE 不在 Start Menu → `request_access` 永遠失敗，不要嘗試。
正確方式：GUT 測試 或 `mcp__godot__run_project` + `mcp__godot__get_debug_output`
