# QA Report — GAP-034 統一回收距離 + 彈性繩物理

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.3/2.4/2.5、implementation_plan.md
> 驗證方式：`mcp__godot__run_project` + `get_debug_output`

## 1. 自動化驗證

| 項目 | 結果 |
|------|------|
| `sensor-scan.ps1` | ✅ 21/21 PASS |
| Godot `--check-only` | ✅ 0 errors |
| run_project 啟動 | ✅ **errors: [] / 無警告**，乾淨啟動 |
| 新程式路徑 | ✅ `_apply_movement`/`_apply_gravity` 每幀執行，乾淨啟動代表無 runtime 錯誤 |

## 2. 修正內容驗證（靜態）

- **回收半徑**：`retrieve_radius` 30→60。根因確認：Player collision 32×64、中心在原點 → 腳在 +32px；30px 半徑量自中心，腳邊針恆 >30px 故撿不到。60px 已涵蓋。✅
- **統一距離**：`get_retrieve_info` 距離過濾改 `dist > retrieve_radius: continue`，移除擺錘針例外 → 所有針一律需夠近。✅ UI（GAP-033）同源，標籤同步。
- **彈性繩**：`WireConstraint.apply()` 改 spring-damper；taut 時 `velocity += dir*(stiffness*stretch*delta)` + 沿繩阻尼；slack 時純自由落。`max_length` 介面保留 → renderer/debug 不受影響。✅
- **保留動量**：繩上時 `velocity.x` 改為 `+= dir*swing_accel*delta` + `move_toward(.,0,air_drag*delta)`，不再硬覆寫 → 擺盪動量保留。✅

## 3. 手動驗證清單（需玩家於遊戲中實測）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 走近落在平台/地面的針 | 出現 `[F] 平台針` 且 **F 可成功撿起**（半徑修正）|
| 2 | 盪繩中（遠離錨點）按 F | **無法**撿起遠處擺錘針（需先盪近或 Q 斷線走過去）|
| 3 | 射帶線針後從高處落下 | 繩繃緊時**彈性拉伸**再回彈（不再生硬截斷），呈鐘擺擺盪 |
| 4 | 盪繩過程左右輸入 | 可 pump 擺盪、保留動量（不再被輸入瞬間歸零）|
| 5 | 按住 E 收線 | 繩長縮短、玩家被**彈性拉近**（繩子感）|

## 4. 手感調校（@export，玩家可在 Player 節點即時調）

| 參數 | 預設 | 作用 |
|------|------|------|
| `rope_stiffness` | 80 | 彈簧硬度（大=拉伸少更硬、小=更彈）|
| `rope_damping` | 9 | 沿繩阻尼（大=少彈跳更快收斂）|
| `swing_accel` | 500 | 空中左右控制力 |
| `swing_air_drag` | 60 | 擺盪空氣阻力（0=不衰減）|
| `retrieve_radius`(NeedleManager) | 60 | 回收半徑 |

## 5. 結論

- 自動化全 PASS、乾淨啟動。
- 撿針半徑與統一距離為確定性修正（靜態可證）。
- 繩子彈性/擺盪手感屬主觀，需玩家實測（情境 3–5）；已開放 4 個 @export 供即時微調。
- **QA 通過**，無未解決 [GDD TODO]。
