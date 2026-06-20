# QA Report — GAP-042 盪繩收繩穿過平台修復

> 日期：2026-06-20 | 角色：QA | 類型：碰撞 bug 修復

## 1. 根因

`player._apply_wire` 用 `global_position = r["pos"]` **直接設定位置（瞬移）**套用繩約束的位置夾鉗。直接設 `global_position` 會**繞過 CharacterBody2D 的碰撞**，所以玩家被往牆上錨點收繩時會**穿過中間的平台**。

## 2. 修復

改為 `move_and_collide(r["pos"] - global_position)`：以碰撞感知的方式移動，遇牆/平台會**停住**。

## 3. 驗證（暫時插樁 + run_project，實機真值）

暫時自動朝正上方發射抓鉤並 hold，於 `_apply_wire` 記錄 `move_and_collide` 回傳的碰撞：
```
[grapple] blocked by Platform_C at player_y=436.0   (× 1044 幀)
```
- 玩家被收繩往上拉時，**被 Platform_C 擋住卡在 y≈436**（平台位置），**未穿過** → 正是用戶回報的情境，已修復。
- 舊版（瞬移）會穿過 Platform_C；新版 move_and_collide **每幀回報被該平台擋住**。
- 插樁已還原。

| 項目 | 結果 |
|------|------|
| `--check-only` | ✅ 0 errors |
| `sensor-scan.ps1` | ✅ 21/21 |
| 實機插樁 | ✅ **blocked by Platform_C**（卡住，未穿過）|
| 既有 headless 測試 | gap037/040/041 不受影響 |

## 4. 影響面

- 盪繩時的**收繩位置修正**與**擺盪**（move_and_slide）皆碰撞感知，玩家會被牆/平台擋住（卡住），可沿邊滑動。
- 不影響攻擊針/自動回收/Verlet 視覺/移動跳躍。

## 5. 手動驗證（玩家）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 勾到牆壁、被收繩往上 | 路徑上的平台會**擋住**玩家（卡住），不再穿過 |
| 2 | 盪繩撞到平台 | 被擋住、可沿邊滑 |

## 6. 結論

- 根因（直接設 global_position 繞過碰撞）明確；修復用 move_and_collide。
- **實機插樁證明玩家被 Platform_C 擋住**（卡住），未穿過。
- **QA 通過**。
