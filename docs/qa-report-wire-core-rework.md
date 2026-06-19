# QA Report — Wire Core Rework (GAP-022/023/024)
> 日期：2026-06-20 | 角色：QA | 審查 commit：241d4ed

---

## 驗收範圍

| Bug | 描述 |
|-----|------|
| GAP-022 | E 鍵彈簧感（velocity 累加 → winch position 收縮） |
| GAP-023 | 第三針無法牽線（早返阻斷 + rolling window 修復） |
| GAP-024 | 第二針飛行途中線段綁在兩端（應顯示 anchor1→飛行針） |

---

## Sensor 掃描結果

執行：`.\scripts\sensor-scan.ps1`（v12 / 22 checks）

```
21/22 PASS
1/22 WARN：GAP-014 GUT addon 未安裝（tests/.gdignore 保護，不阻斷）
0/22 FAIL
```

→ **靜態掃描通過**

---

## 靜態驗證（GDScript --check-only）

Godot v4.6.2 `--check-only` → **0 錯誤**

已驗證文件：
- `scripts/player.gd` — winch、renderer 優先順序
- `scripts/needle_manager.gd` — rolling window

---

## 邏輯驗證（人工審查）

### GAP-022：E 鍵 winch

```gdscript
# 修復後
_wire.reel_in(reel_speed, delta)
var to_anchor: Vector2 = _wire.anchor_pos - global_position
var dist: float = to_anchor.length()
if dist > _wire.max_length and dist > 0.0:
    position += (to_anchor / dist) * (dist - _wire.max_length)
```

- ✅ `dist > max_length` 守衛：繩子已夠短時不移動 player
- ✅ position 直接收縮（winch）而非 velocity 累加（spring）
- ✅ `reel_in()` 同步縮短 `max_length`，兩者一致

### GAP-023：第三針牽線

信號順序（Godot 同步信號）：
1. `wire_anchor_ready(anchor3)` → player 設 `_wire_anchor=anchor3, _wire_anchor2=null`
2. `platform_created(anchor2, anchor3)` → player 設 `_wire_anchor=anchor2, _wire_anchor2=anchor3`

- ✅ 無競爭條件
- ✅ `get_wire_anchors().size() < 2` 守衛，針不足時不建平台
- ✅ 回收一端後 `remaining[0]` 重建連線（剩1根時正確）

### GAP-024：第二針飛行顯示

```
P1: platform（anchor1↔anchor2）     → 優先級最高，飛行時也保持
P2: anchor + 飛行針（anchor1→proj） ← 新增，解決 GAP-024
P3: 擺錘（player↔anchor1）
P4: 僅飛行（player→proj）
```

- ✅ 條件互斥，不會雙重繪製
- ✅ `is_instance_valid` 保護避免懸空指標
- ✅ GDD §2.3 已更新對應設計文件

---

## 人工遊戲測試（需 QA 在 Godot 中執行）

> ⚠️ 以下為必要的執行時驗證，需人工在遊戲中確認：

- [ ] 射出第一根 wire 針 → 鐘擺 catenary 顯示正確（黃色弧線）
- [ ] 按 E 收線 → player 被拉近，無振盪（winch 感，非彈簧感）
- [ ] 射出第二根 wire 針（飛行中）→ 線從 anchor1 延伸至飛行針尖
- [ ] 第二根落點 → 平台建立，線切換為亮金色 anchor1↔anchor2
- [ ] 射出第三根 wire 針 → 可成功牽線，平台移位至 anchor2↔anchor3
- [ ] Q 斷線後再射 → 狀態完全重置，無殘留

---

## 結論

| 類型 | 結果 |
|------|------|
| 靜態掃描 | ✅ PASS（21/22，1 WARN 為舊有 GAP-014） |
| --check-only 語法 | ✅ PASS |
| 邏輯人工審查 | ✅ PASS |
| 執行時遊戲測試 | ⚠️ 待玩家手動確認 |

**QA 決定：靜態驗收通過。執行時驗證需使用者在 Godot 中執行上表清單。**
