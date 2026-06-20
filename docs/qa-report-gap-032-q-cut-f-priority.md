# QA Report — GAP-032 Q 斷線 / F 優先級回收

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.4、implementation_plan.md
> 驗證方式：`mcp__godot__run_project` + `get_debug_output`（依 workflow §F；遊戲 EXE 禁用 computer-use）

## 1. 自動化驗證

| 項目 | 結果 |
|------|------|
| `sensor-scan.ps1` | ✅ 21/21 PASS（Developer commit 自動執行） |
| Godot `--check-only` 語法 | ✅ 0 errors |
| run_project 載入（修復前） | ⚠️ WARNING：`needle_manager.gd:58` local var `is_connected` 遮蔽 `Object.is_connected()` |
| **修復**（`[DEV] fix` 646d117） | local var 改名 `is_player_wire` |
| run_project 載入（修復後） | ✅ **errors: [] / 無警告**，遊戲乾淨啟動 |

QA 於 run_project 階段攔截到靜態 `--check-only` 未報的執行期 shadowing 警告，已退回 Developer 修正並複驗通過。

## 2. 程式邏輯驗證（靜態追蹤）

- `try_retrieve(player_pos, connected_anchor=null)`：向後相容；相連錨點 `in_range` 不受半徑限制；其餘 `dist > retrieve_radius` 跳過；依 `_retrieve_priority` 取最小、同級取最近。✅
- `_retrieve_priority`：攻擊針 0 < wire/擺錘 1 < 平台端點 2。✅ 符合 GDD §2.4 優先級。
- `_cut_wire`：僅在 `_wire != null and _wire_anchor != null` 時清擺錘並隱藏 `wire_renderer`；不再清 `_platform_*`。✅ 平台不被 Q 影響。
- `_remove_anchor` 平台解散 + GAP-029 轉擺錘鏈未變動。✅

## 3. 手動驗證清單（互動輸入需玩家自行操作）

> 遊戲 EXE 無法用 computer-use 輸入按鍵，以下情境請於遊戲中實測：

| # | 操作 | 預期結果 |
|---|------|---------|
| 1 | 擺錘中按 **Q** | 線斷、針留在原地、可事後 F 回收；平台（若有）不受影響 |
| 2 | 已展開平台、無 active 擺錘時按 **Q** | 無任何作用（平台保留） |
| 3 | 旁邊同時有攻擊針與相連擺錘針，按 **F** | 先回收**攻擊針** |
| 4 | 無攻擊針、有 active 擺錘，按 **F**（即使離錨點很遠） | 回收**相連擺錘針**、線消失 |
| 5 | 靠近平台端點且無更高優先針，按 **F** | 回收該端點 → 平台解散 → 另一端轉為擺錘線 |
| 6 | 平台 + 第三針擺錘中，靠近平台端點按 **F** | 先回收**第三針**（優先級 1 高於平台 2），平台保留 |

## 4. 結論

- 自動化（sensor / check-only / 乾淨啟動）**全部 PASS**。
- 修復了 QA 發現的 shadowing 警告。
- 邏輯實作與 GDD §2.4 一致。
- 互動手感（情境 1–6）需玩家實測；如有偏差回報即可微調。
- **QA 通過**，無未解決 [GDD TODO]。
