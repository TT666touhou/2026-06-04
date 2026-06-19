# Review Log — GAP-025 第三針保留舊平台 + 鋼針速度2倍
> 日期：2026-06-20 | 角色：Reviewer | 審查 commit：7f4d627

---

## 審查範圍

| 功能 | 描述 |
|------|------|
| 3rd needle platform 保留 | 第三根 wire 針不再觸發 rolling window，舊平台維持 |
| 平台視覺獨立 | `_platform_renderer` 與擺錘 `wire_renderer` 分離，各自更新 |
| 鋼針速度 | `flight_speed` 600.0 → 1200.0 |

---

## needle_manager.gd 審查

### [1] `_on_embedded` size==2 條件

```gdscript
if get_wire_anchors().size() == 2:  # Only create platform on 2nd wire anchor; 3rd+ keeps old platform
    _try_create_platform()
```

✅ **正確**。第三根 wire 針嵌入後 `size()==3`，條件不成立，舊平台不受干擾。
✅ **Q 斷線 + 重射場景**：回收至剩1根後再射，size 回到2，平台正確重建。

### [2] `_try_create_platform` — 用 `wire_anchors[0]` 和 `[1]` 而非 rolling window

```gdscript
var a1: Node = wire_anchors[0]
var a2: Node = wire_anchors[1]
```

✅ **正確**。永遠是前兩根 wire 針建立平台，不再 shift。
⚠️ **潛在限制**：若第一根 wire 針被回收（`_remove_anchor(anchor1)`），平台解散，`remaining[0]` = anchor2 被作為新擺錘 anchor，但第三根 anchor3 不會自動成為新平台。此行為在當前設計下是可接受的（邊界案例，超出本次 spec）。

### [3] `_platform_anchor_a / _platform_anchor_b` 追蹤

```gdscript
var _platform_anchor_a: Node = null
var _platform_anchor_b: Node = null
```

✅ **正確**。`_remove_anchor` 現在只在「被回收的 anchor 是平台端點之一」時才解散平台，防止回收 pendulum anchor 時誤毀平台。

### [4] `_remove_anchor` 新邏輯

```gdscript
if anchor == _platform_anchor_a or anchor == _platform_anchor_b:
    if is_instance_valid(_current_platform):
        _current_platform.call("dissolve")
    _current_platform = null
    _platform_anchor_a = null
    _platform_anchor_b = null
```

✅ **正確**。`is_instance_valid` 保護防懸空指標。
✅ 三個狀態變數一起清除，不留殘留。

---

## player.gd 審查

### [5] `_wire_anchor2` 移除 → `_platform_a / _platform_b`

舊架構：`_wire_anchor` 和 `_wire_anchor2` 同時用於「平台端點」和「擺錘錨點」，導致兩者強耦合。
新架構：職責分離 ✅

| 變數 | 職責 |
|------|------|
| `_wire_anchor` | 當前擺錘錨點（物理 + 視覺） |
| `_platform_a / _platform_b` | 平台端點（視覺 + 回收追蹤），與擺錘無關 |

### [6] `_platform_renderer` 動態建立

```gdscript
_platform_renderer = Line2D.new()
_platform_renderer.top_level = true
_platform_renderer.visible = false
_platform_renderer.width = 3.0
_platform_renderer.default_color = Color(1.0, 0.92, 0.5, 1.0)
add_child(_platform_renderer)
```

✅ `top_level = true` 確保 Line2D 不受 player transform 影響（世界座標繪製）。
✅ 初始 visible=false，避免閃爍。

### [7] `_on_wire_anchor_ready` 不再清除平台狀態

```gdscript
func _on_wire_anchor_ready(anchor: Node) -> void:
    _wire_projectile = null
    _wire = anchor.wire as RefCounted
    _wire_anchor = anchor
    _wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position) + wire_slack)
```

✅ **關鍵修正**：第三針到達後只更新 `_wire_anchor`，不再清除 `_platform_a / _platform_b`，平台金色線條保持顯示。

### [8] `_on_needle_retrieved` 細粒度清除

```gdscript
func _on_needle_retrieved(anchor: Node) -> void:
    if anchor == _wire_anchor:
        _wire = null
        _wire_anchor = null
    if anchor == _platform_a or anchor == _platform_b:
        _platform_a = null
        _platform_b = null
        _platform_slack = 0.0
        if _platform_renderer != null:
            _platform_renderer.visible = false
```

✅ 擺錘回收 ≠ 平台清除，兩者獨立。
✅ 平台端點回收後立即隱藏 renderer（不等下一幀）。

### [9] `_on_platform_created` 清除 `_wire_anchor`

```gdscript
func _on_platform_created(a1: Node, a2: Node) -> void:
    _wire = null
    _wire_anchor = null
    ...
```

✅ 平台建立時玩家進入「站上平台」模式，`_wire` 和 `_wire_anchor` 正確清空，不留殘餘的擺錘約束。

### [10] `_draw_catenary_line(renderer, from, to, slack)` 重構

```gdscript
func _draw_catenary_line(renderer: Line2D, from: Vector2, to: Vector2, slack: float) -> void:
```

✅ 接受 `renderer` 參數，platform 和 pendulum 共用同一條 catenary 數學，不重複代碼。
✅ 所有舊的 `_draw_catenary(...)` 呼叫已更新為 `_draw_catenary_line(wire_renderer, ...)` 或 `_draw_catenary_line(_platform_renderer, ...)`。

### [11] `_update_wire_renderer` 渲染層次

```
Platform renderer（獨立更新）：_platform_a ↔ _platform_b 亮金色 3px
Priority 1：anchor + 飛行針 → 延伸線（75% alpha 1.5px）
Priority 2：擺錘 → 張力自適應（1.5-3px）
Priority 3：純飛行 → 暗金細線（60% alpha 1px）
```

✅ Platform 和 wire_renderer 完全獨立，可同時顯示（第三針到達後：金色平台 + 黃色擺錘同時可見）。

---

## needle_projectile.gd 審查

```gdscript
@export var flight_speed: float = 1200.0
```

✅ `@export` 保留，允許在 Godot Inspector 覆寫（測試方便）。
✅ 物理計算使用 `step = flight_speed * delta`，速度加倍不影響碰撞精度（RayCast2D `target_position = step * 1.2` 同步）。

---

## 風險評估

| 風險 | 等級 | 說明 |
|------|------|------|
| anchor 懸空指標 | 低 | `is_instance_valid` 保護已到位 |
| 平台解散信號時序 | 低 | Godot 信號同步，`needle_retrieved` 先於 `wire_anchor_ready` |
| 舊 `_wire_anchor2` 引用殘留 | 無 | grep 確認已全部清除 |
| `_platform_renderer` null 保護 | 低 | `_cut_wire` 和 `_on_needle_retrieved` 均有 `!= null` 判斷 |

---

## 結論

**REVIEW PASS** — 邏輯清晰，職責分離正確，無已知副作用。可進入 QA。
