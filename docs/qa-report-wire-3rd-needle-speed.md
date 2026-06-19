# QA Report — GAP-025 第三針保留舊平台 + 鋼針速度2倍
> 日期：2026-06-20 | 角色：QA | 審查 commit：7f4d627 (DEV) + ce7b4fd (REVIEW)

---

## 驗收範圍

| 功能 | 描述 |
|------|------|
| GAP-025a | 第三根 wire 針不再觸發 rolling window，舊平台(a1↔a2)維持不變 |
| GAP-025b | 第三針到達後 `_platform_renderer` 獨立顯示金色平台線條 |
| GAP-025c | `flight_speed` 600.0 → 1200.0（兩倍速） |

---

## Sensor 掃描結果

執行：`.\scripts\sensor-scan.ps1`（v12 / 22 checks）

```
22/22 PASS
0/22 WARN
0/22 FAIL
```

→ **靜態掃描全通過**

---

## 靜態驗證（GDScript --check-only）

Godot v4.6.2 `--check-only` → **0 錯誤**（已包含在 Sensor Check 8/22）

---

## 邏輯驗證（人工審查）

### GAP-025a：第三針不觸發 rolling window

```gdscript
# needle_manager.gd
if get_wire_anchors().size() == 2:  # Only on 2nd wire anchor
    _try_create_platform()
```

✅ `size() == 2` 條件：3rd needle 到達後 `size() == 3`，`_try_create_platform()` 不執行
✅ 舊平台（anchor1↔anchor2）的 `_current_platform` 節點不受干擾

### GAP-025b：平台視覺獨立

```gdscript
# player.gd _on_wire_anchor_ready — 3rd needle 到達
func _on_wire_anchor_ready(anchor: Node) -> void:
    _wire_projectile = null
    _wire = anchor.wire as RefCounted
    _wire_anchor = anchor           # ← 僅更新擺錘，不碰 _platform_a/_platform_b
    _wire.setup(...)
```

✅ `_platform_a` / `_platform_b` 保留 anchor1/anchor2
✅ `_platform_renderer` 持續繪製 anchor1↔anchor2 金色線條
✅ `wire_renderer` 同時繪製 player↔anchor3 擺錘線條（Priority 2）

### GAP-025c：鋼針速度

```gdscript
@export var flight_speed: float = 1200.0
```

✅ 速度加倍；`_ray.target_position = Vector2(step * 1.2, 0)` 同步放大，碰撞精度維持

### 回收行為驗證

```gdscript
# needle_manager._remove_anchor — 回收 anchor3（擺錘，非平台端點）
if anchor == _platform_anchor_a or anchor == _platform_anchor_b:
    # anchor3 不是平台端點 → 此區塊跳過
    ...
```

✅ 回收第三針：平台不解散，`needle_retrieved` → player 清除 `_wire_anchor`，隨後 `wire_anchor_ready(anchor1)` → 玩家改從 anchor1 擺盪
✅ 回收平台端點：平台正確解散，`_platform_a/_b` 清除，`_platform_renderer.visible = false`

---

## 人工遊戲測試 Checklist（需在 Godot 中確認）

> ⚠️ 以下為執行時驗證，需手動在遊戲中確認：

- [ ] 射出第1根 wire 針 → 玩家從 anchor1 擺盪，黃色弧線
- [ ] 射出第2根 wire 針 → 平台建立，亮金色 anchor1↔anchor2，玩家站上
- [ ] 射出第3根 wire 針（RMB）→ 平台金線保持，玩家改從 anchor3 擺盪
- [ ] 回收第3根 → 平台仍在，玩家改從 anchor1 擺盪
- [ ] 回收第1根（平台端點）→ 平台解散，玩家從剩餘 anchor 擺盪
- [ ] Q 斷線 → 所有線條清除，重射可正常建立新平台
- [ ] 鋼針飛行速度明顯比之前快（主觀體感驗證）

---

## 結論

| 類型 | 結果 |
|------|------|
| Sensor 掃描 22/22 | ✅ PASS |
| --check-only 語法 | ✅ PASS |
| 邏輯人工審查 | ✅ PASS |
| 執行時遊戲測試 | ⏳ 待玩家在 Godot 中手動確認（見 checklist） |

**QA 決定：靜態驗收通過。執行時驗證需使用者在 Godot 中跑 checklist 確認後即可 merge。**
