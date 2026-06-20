# QA Report — GAP-041 大幅簡化（移除平台/Q/E/F + 右鍵按住盪繩）

> 日期：2026-06-20 | 角色：QA | 對應：GDD §2.2/2.3/2.4/2.5/9.1
> 驗證優先序（§F）：headless 測試為主，run_project 冒煙。

## 1. 主驗證 — Headless 測試

| 測試 | 結果 | 覆蓋 |
|------|------|------|
| `tests/test_rope_gap041.gd` | ✅ **NM41_TEST_PASS** | `max_needles==5`；**攻擊針靠近自動回收**（近的被收、遠的留、發出 `needle_retrieved`）；`release_wire()` 空呼叫安全 |
| `tests/test_rope_gap040.gd` | ✅ **ROPE40_TEST_PASS** | 自然鐘擺約束無速度注入（不變）|
| `tests/test_rope_gap037.gd` | ✅ **ROPE_TEST_PASS** | VerletRope + reel |
| `sensor-scan.ps1` | ✅ 21/21 | |
| `--check-only` | ✅ 0 errors | |
| run_project 冒煙 | ✅ errors 空 | Player.tscn 移除 WirePlatform ext_resource 後**載入正常** |

## 2. 簡化內容

- **移除**：鋼索平台（`wire_platform.gd`、`WirePlatform.tscn`、`_try_create_platform`、平台 sag/drop-through、S 穿透）、Q 斷線、E 收繩、F 回收/優先級系統、回收提示 UI（player 不再實例化）。
- **盪繩改右鍵按住**：右鍵 pressed → 發射帶線針抓鉤 + 自動收繩 + 自然鐘擺盪繩；右鍵 released → `release_wire()` 斷繩且該針回收；飛行途中放開以 `_wire_held` 守住、亦取消回收。
- **攻擊針自動回收**：每幀 `needle_manager.auto_retrieve_attack(global_position)`，攻擊針在 `retrieve_radius=60` 內自動回收（無需 F）。
- **保留**：移動慣性、jump buffer/coyote/可變跳、Verlet 繩視覺、自然鐘擺約束、瞄準翻面。
- **淨減 193 行**（127 insert / 320 delete）。

## 3. 邊界（碼審）

- `release_wire` 冪等（`is_instance_valid` 守護）→ 「鬆開」與「飛行中嵌入後 `_wire_held=false`」雙路徑不會重複 free。
- `_start_grapple` 已有 wire/proj 時不重射。

## 4. 手動驗證（玩家）

| # | 操作 | 預期 |
|---|------|------|
| 1 | 右鍵**按住** | 發射抓鉤、命中後被自動收繩拉近、可盪繩 |
| 2 | 盪繩中**鬆開**右鍵 | 立即斷繩，該帶線針**回收**（持有數量回復）|
| 3 | 左鍵射攻擊針後走近 | 自動回收（無需按鍵）|
| 4 | 試 Q/E/F/S | 無作用（功能已移除）|

## 5. 結論

- 簡化後**核心邏輯 headless 驗證通過**（自動回收、release、約束、Verlet）。
- 場景移除平台引用後載入正常。
- 盪繩手感（右鍵按住/鬆開）需玩家實測。
- **QA 通過**。
