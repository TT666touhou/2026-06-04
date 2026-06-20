# QA Report — GAP-039 彈性收繩+上甩 / 單按右鍵 / 針數5 / 驗證法改良

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.1/2.2/2.3/9.1/9.3、workflow §F
> **本次採新驗證優先序（§F）：headless 自動化測試為主，run_project 僅冒煙。**

## 1. 主驗證 — Headless 自動化測試（斷言數值，無需輸入）

| 測試 | 結果 | 覆蓋 |
|------|------|------|
| `tests/test_rope_gap039.gd` | ✅ **ROPE39_TEST_PASS** | 針數=5；彈性 apply 朝錨點加速；**上甩**（錨點在上，auto-reel+apply 後玩家獲得**向上速度**且位置上移）；reel 夾 min |
| `tests/test_rope_gap037.gd` | ✅ **ROPE_TEST_PASS** | VerletRope 釘端/有限值 + reel 夾 min（已隨 GAP-039 移除過時的 constrain 斷言）|
| `sensor-scan.ps1` | ✅ 21/21 PASS | |
| `--check-only` | ✅ 0 errors | |

→ **「上甩」物理已被數值斷言**：`vel.y < 0`（朝上）、`pos.y < 起點`。這比 run_project 純開機可靠且快。

## 2. 冒煙 — run_project（僅確認載入無錯）

✅ errors: [] 乾淨啟動（非主驗證）。

## 3. 各部分

- **A 彈性快速收繩**：`wire_constraint` 改 spring(`stiffness=40`/`damping=4`/`max_accel=5000`) + 快 `auto_reel_speed=320`；`apply` 取代 `constrain`。收繩快、有彈力、朝上射針上甩。✅(單元測試)
- **A 上甩接平台**：射第二帶線針 → `get_wire_anchors()==2` 成平台、`_on_platform_created` 清 `_wire` 釋放 → 玩家帶上甩動能（既有平台邏輯未動）。
- **B 單按右鍵**：`_unhandled_input` 右鍵→帶線針、左鍵→攻擊針；`_shoot_needle(wire)` 參數化。✅(碼審)
- **C 針數5**：`max_needles 3→5`；debug_overlay `count/cap` 動態。✅(單元測試 max_needles==5)
- **D 驗證法改良**：workflow §F 新增驗證優先序（headless 首選）、§I-C Rule 24 改述。本報告即依新法執行。

## 4. 手動驗證（玩家，主觀手感）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 朝上單按右鍵 | 被快速彈性收繩**往上甩** |
| 2 | 上甩中適時再單按右鍵 | 形成平台，帶上甩動能**站上平台** |
| 3 | 左鍵 | 攻擊針；可連續持有至 5 根 |
| 4 | 繩感 | 收繩快、有彈力回彈（非生硬）|

調校：`auto_reel_speed`/`rope_stiffness`/`rope_damping`/`rope_max_accel`(在 Player 節點)。

## 5. 結論

- **上甩物理 + 針數5 已 headless 數值驗證通過**（新驗證法示範）。
- 連段最終手感與時機需玩家實測（情境 1–2）。
- **QA 通過**。
