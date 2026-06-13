extends Node2D
## StaminaBar — 耐力環形 UI
## 以 draw_arc() 繪製 3 段弧形，跟隨角色在世界空間中移動（非 CanvasLayer）
## 顏色全部取自 VfxMix palette.pal（34 色色票），不使用色票外顏色
##
## ═══ 角度系統說明 ═══
## Godot 的角度 0° = 右方（3點鐘），順時針為正（螢幕座標 Y 向下）
## 90°  = 下方（6點鐘）
## 180° = 左方（9點鐘）
## 270° = 上方（12點鐘）

# ── 弧形位置與角度（最常需要調整的參數）────────────────────────
@export_group("弧形角度")
## 弧形起始角度（度）
## 推薦值：90=正下方起始 / 120=右下方4點鐘起始 / 45=右下方偏右起始
## 弧形會從此角度開始，往 arc_span_deg 方向延伸
@export_range(0.0, 360.0, 1.0) var arc_start_deg: float = 120.0
## 弧形總涵蓋範圍（度）
## 推薦值：90=四分之一圓 / 180=半圓 / 120=三分之一圓
@export_range(10.0, 360.0, 1.0) var arc_span_deg: float = 90.0
## 段間間隔（度）：每段弧之間的空白，0=無間隙
@export_range(0.0, 20.0, 0.5) var arc_gap_deg: float = 4.0

# ── 弧形大小（控制圓的大小與粗細）──────────────────────────────
@export_group("弧形大小")
## 弧形半徑（遊戲像素，顯示時 × cam_zoom 倍）
## 推薦值：8~16（遊戲像素）= 顯示 32~64px（zoom=4）
@export_range(4.0, 64.0, 1.0) var arc_radius: float = 10.0
## 弧形線條寬度（遊戲像素）
## 推薦值：1~3，太粗會擋住角色
@export_range(0.5, 8.0, 0.5) var arc_width: float = 1.5
## 繪製精細度（每段弧用幾個頂點構成）
## 推薦值：8~16（像素藝術不需要太高，太高反而更糊）
@export_range(4, 64, 1) var arc_points: int = 8

# ── VfxMix 色票顏色（禁止使用色票外顏色）────────────────────────
@export_group("顏色（VfxMix 色票）")
## 滿格顏色 — Near White（色票 #34）
@export var color_full    : Color = Color(0.949, 0.976, 0.973, 1.0)   # #F2F9F8
## 恢復中格背景色 — Warm Gray（色票 #23）
@export var color_recover : Color = Color(0.592, 0.549, 0.557, 0.6)   # #978C8E 60%
## 空格顏色 — Dark Charcoal（色票 #1）
@export var color_empty   : Color = Color(0.212, 0.196, 0.196, 0.8)   # #363232 80%
## 消耗閃爍色 — Warm Yellow（色票 #18）
@export var color_flash   : Color = Color(0.933, 0.812, 0.353, 1.0)   # #EECF5A
## 耐力不足警告色 — Bright Red（色票 #11）
@export var color_warning : Color = Color(0.898, 0.361, 0.361, 0.8)   # #E55C5C 80%

# ── 閃爍動畫 ────────────────────────────────────────────────────
@export_group("動畫")
## 消耗閃爍持續時間（秒）：消耗耐力後的金黃閃爍動畫長度
@export_range(0.0, 1.0, 0.01) var flash_duration: float = 0.15

# ── UI 偏移（調整弧形相對於角色中心的位置）──────────────────────
@export_group("位置偏移")
## UI 中心相對於角色中心的偏移（遊戲像素）
## 範例：Vector2(4, 4) = 往右下各 4px
@export var center_offset: Vector2 = Vector2(0.0, 0.0)

# ── 內部狀態 ────────────────────────────────────────────────────
## 來自 player1.gd 的耐力值（0.0 ~ 3.0），由 parent 每幀更新
var stamina: float = 3.0
## 每格的閃爍計時器倒數，> 0 表示正在閃爍
var _flash_timers: Array[float] = [0.0, 0.0, 0.0]

# ── 初始化 ──────────────────────────────────────────────────────
func _ready() -> void:
	z_index = 1

# ── 每幀更新 ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	for i in 3:
		if _flash_timers[i] > 0.0:
			_flash_timers[i] = max(0.0, _flash_timers[i] - delta)
	queue_redraw()

## 由 player1.gd 呼叫：消耗耐力時觸發指定格的閃爍
func trigger_flash(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < 3:
		_flash_timers[slot_index] = flash_duration

# ── 繪製弧形 ────────────────────────────────────────────────────
func _draw() -> void:
	var full_slots   : int   = floori(stamina)
	var partial_fill : float = fmod(stamina, 1.0)
	var is_critical  : bool  = stamina < 1.0

	# 每段弧的角度寬度（總 span 扣掉所有間隔後均分 3 段）
	var usable_span : float = arc_span_deg - arc_gap_deg * 2.0
	var slot_span   : float = usable_span / 3.0

	for i in 3:
		var start_deg : float = arc_start_deg + float(i) * (slot_span + arc_gap_deg)
		var end_deg   : float = start_deg + slot_span

		var col: Color

		if _flash_timers[i] > 0.0:
			var t : float = _flash_timers[i] / flash_duration
			col = color_flash.lerp(color_empty, 1.0 - t)
		elif i < full_slots:
			col = color_full
		elif i == full_slots and partial_fill > 0.01:
			# 恢復中格：先畫暗色背景，再疊加進度
			_draw_segment(start_deg, end_deg, color_recover)
			var fill_end : float = start_deg + slot_span * partial_fill
			_draw_segment(start_deg, fill_end, color_full)
			continue
		else:
			col = color_warning if is_critical else color_empty

		_draw_segment(start_deg, end_deg, col)

## 繪製單段弧（antialiased=false 確保像素銳利，不模糊）
func _draw_segment(from_deg: float, to_deg: float, col: Color) -> void:
	if to_deg <= from_deg:
		return
	draw_arc(
		center_offset,          # 中心點（加上偏移）
		arc_radius,             # 半徑
		deg_to_rad(from_deg),   # 起始角（弧度）
		deg_to_rad(to_deg),     # 結束角（弧度）
		arc_points,             # 精細度
		col,                    # 顏色
		arc_width,              # 線寬
		false                   # ← antialiased = FALSE，像素藝術必須關閉，否則模糊
	)
