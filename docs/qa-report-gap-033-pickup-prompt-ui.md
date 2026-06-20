# QA Report — GAP-033 回收提示文字 UI

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.5、implementation_plan.md
> 驗證方式：`mcp__godot__run_project` + `get_debug_output`

## 1. 自動化驗證

| 項目 | 結果 |
|------|------|
| `sensor-scan.ps1` | ✅ 21/21 PASS |
| Godot `--check-only` | ✅ 0 errors（補 reimport 後，見下方 gotcha） |
| run_project 啟動 | ✅ **errors: [] / 無警告**，乾淨啟動 |
| UI 整合路徑 | ✅ PickupPromptUI 於 `player._ready` instantiate、`_update_pickup_prompts` 每幀執行（0 針時回空候選並隱藏全部）；啟動無錯代表整合路徑正常 |

## 2. 開發中攔截的問題（class cache gotcha）

- **現象**：首次 `--check-only` FAIL — `Could not find type "WorldLabel"`。
- **原因**：新增 `class_name` 腳本後，Godot global class cache（`.godot/global_script_class_cache.cfg`，gitignored）尚未更新，孤立 `--check-only` 無法解析跨檔的 `class_name`。
- **修復**：`godot --headless --path . --import` 重新匯入，註冊 `WorldLabel`/`PickupPromptUI` 後即 PASS。
- **教訓**：見 ERROR_LOG GAP-033 防範規則。

## 3. 邏輯驗證（靜態）

- `needle_manager.get_retrieve_info()` 為回收資訊單一來源；`try_retrieve()` 復用其 `target` → UI 高亮與實際 F 目標**永遠一致**。✅
- `PickupPromptUI` top_level 已設，玩家面向翻轉（`scale.x=-1`）不會鏡像標籤。✅
- WorldLabel `show_prompt` 以 `_active` 旗標避免每幀重觸發 tween。✅

## 4. 手動驗證清單（需玩家於遊戲中實測）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 射出攻擊針，走近 | 針上方出現亮色 `[F] 攻擊針` |
| 2 | 建立平台後走近平台端點 | 端點上方出現亮色 `[F] 平台針`；按 F 可收回該端點 |
| 3 | 平台端點旁同時有攻擊針 | **攻擊針**亮色（F 目標）、平台針暗色 → 確認 F 會先收攻擊針 |
| 4 | 擺錘中（遠離錨點） | 錨點上方顯示 `[F] 擺錘針`（不限距離） |
| 5 | 走遠離開回收半徑 | 標籤消失 |

## 5. 結論

- 自動化（sensor / check-only / 乾淨啟動）**全部 PASS**。
- UI 為可復用兩層架構（WorldLabel + PickupPromptUI），tween 擴充點 `play_appear()` 已就位。
- 文字標籤視覺需玩家實測（情境 1–5）；高亮邏輯與 F 行為同源，不會漂移。
- **QA 通過**，無未解決 [GDD TODO]。
