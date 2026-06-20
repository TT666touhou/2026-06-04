# QA Report — GAP-040 繩改回自然鐘擺 + 針速2400

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.3/9.3
> 採新驗證優先序（§F）：headless 自動化測試為主。

## 1. 主驗證 — Headless 測試

| 測試 | 結果 | 覆蓋 |
|------|------|------|
| `tests/test_rope_gap040.gd` | ✅ **ROPE40_TEST_PASS** | **無速度注入(自然)**：靜止玩家繃緊 → vel 仍 0；切向速度保留；朝外徑向消除；slack 不變；reel 夾 min；針數=5 |
| `tests/test_rope_gap037.gd` | ✅ **ROPE_TEST_PASS** | VerletRope 釘端/有限值 + reel |
| `sensor-scan.ps1` | ✅ 21/21 | |
| `--check-only` | ✅ 0 errors | |
| run_project 冒煙 | ✅ errors 空 | 載入無錯（含針速2400）|

→ **關鍵斷言**：靜止玩家在繃緊距離，`constrain` 後 `vel.length() ≈ 0` —— 證明**不再注入任何朝錨點的速度**（GAP-039 彈簧會注入 → 詭異上甩）。動量純由重力盪繩 = 自然。

## 2. 兩部分

- **A 繩改回自然鐘擺**：`wire_constraint` 移除彈簧 `apply()`/stiffness/damping/max_accel，改回 `constrain()`（夾位置 + 只消朝外徑向）。**零速度注入**。盪繩動量自然；收繩(縮 max_length)時角動量守恆自然加速擺盪。Verlet 視覺不變。
- **B 針速加快**：`flight_speed 1200→2400`。抗穿牆：step 40px、raycast 前探 48px > 16px 牆厚 → OK；`max_travel=2400` > 場景對角線。

## 3. 過程備註

- GAP-039 移除的彈簧 `apply()` 使 `test_rope_gap039.gd` 過時 → 以 `test_rope_gap040.gd`（斷言自然約束）取代。
- 過程中一次 `git add` 因不存在 pathspec 中斷導致代碼漏提，已補提（branch→commit→merge）；最終 main 代碼正確（constrain 在、flight_speed 2400）。

## 4. 手動驗證（玩家，主觀手感）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 帶線針盪繩 | 動量**自然**（重力盪繩），無詭異的「被往上甩」加速度 |
| 2 | 盪繩高點射第二針成平台 | 帶**自然盪繩動量**站上平台 |
| 3 | 射針 | 飛行明顯更快、俐落 |

## 5. 結論

- **「無速度注入＝自然」已 headless 數值斷言通過**；針速2400 載入正常。
- 手感（自然盪繩、針速）需玩家實測。
- **QA 通過**。
