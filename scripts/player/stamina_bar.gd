extends Node2D
## StaminaBar — 耐力環形 UI
## 以 draw_arc() 繪製 3 段弧形，跟隨角色在世界空間中移動（非 CanvasLayer）
## 顏色全部取自 VfxMix palette.pal（34 色色票），不使用色票外顏色

# ── 弧形外觀參數 ────────────────────────────────────────────────
## 弧形半徑（遊戲像素）
@export var arc_radius  : float = 12.0
## 弧形線條寬度（遊戲像素）
@export var arc_width   : float = 2.0
## 弧形起始角度（4 點鐘方向 = 120°，以 Godot 的 x 軸右為 0° 計算）
@export var arc_start_deg: float = 115.0
## 弧形涵蓋範圍（度）
@export var arc_span_deg : float = 180.0
## 段間間隔（度）
@export var arc_gap_deg  : float = 6.0
## 弧形繪製精細度（點數越多越圓滑）
@export var arc_points   : int   = 32

# ── VfxMix 色票顏色（palette.pal 索引對應，禁止更改為色票外顏色） ──
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

# ── 閃爍動畫計時器（每格獨立） ─────────────────────────────────
## 消耗閃爍持續時間（秒）
@export var flash_duration: float = 0.15

# ── 內部狀態 ────────────────────────────────────────────────────
## 來自 player1.gd 的耐力值（0.0 ~ 3.0），由 parent 每幀更新
var stamina: float = 3.0
## 每格的閃爍計時器倒數，> 0 表示正在閃爍
var _flash_timers: Array[float] = [0.0, 0.0, 0.0]

# ── 初始化 ──────────────────────────────────────────────────────
func _ready() -> void:
	# 確保在 Player 節點前繪製（或後，依需求）
	z_index = 1

# ── 每幀更新：觸發閃爍 + 觸發重繪 ─────────────────────────────
func _process(delta: float) -> void:
	# 倒數各格閃爍計時器
	for i in 3:
		if _flash_timers[i] > 0.0:
			_flash_timers[i] = max(0.0, _flash_timers[i] - delta)
	queue_redraw()

## 由 player1.gd 呼叫：消耗了第幾格時觸發閃爍
## slot_index 為消耗掉的最高格（0=第一格，1=第二格，2=第三格）
func trigger_flash(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < 3:
		_flash_timers[slot_index] = flash_duration

# ── 繪製弧形 ────────────────────────────────────────────────────
func _draw() -> void:
	var full_slots   : int   = floori(stamina)              # 完整亮起的格數（0-3）
	var partial_fill : float = fmod(stamina, 1.0)           # 恢復中的格的進度（0.0-1.0）
	var is_critical  : bool  = stamina < 1.0               # 耐力不足警告

	# 每格的弧度計算
	# arc_span_deg 分成 3 段，段間留 arc_gap_deg
	var slot_span := (arc_span_deg - arc_gap_deg * 2.0) / 3.0  # 每段的度數

	for i in 3:
		var start_deg := arc_start_deg + i * (slot_span + arc_gap_deg)
		var end_deg   := start_deg + slot_span

		# 決定此格的顏色
		var col: Color
		if _flash_timers[i] > 0.0:
			# 閃爍中：從 color_flash 淡出到消耗後顏色
			var t := _flash_timers[i] / flash_duration  # 1.0 → 0.0
			col = color_flash.lerp(color_empty, 1.0 - t)
		elif i < full_slots:
			# 完整亮起
			col = color_full
		elif i == full_slots and partial_fill > 0.01:
			# 恢復中的格：顯示恢復進度
			# 先畫暗色背景
			_draw_arc_segment(start_deg, end_deg, color_recover)
			# 再畫進度填充（按 partial_fill 比例縮短弧形）
			var fill_end_deg: float = start_deg + slot_span * partial_fill
			_draw_arc_segment(start_deg, fill_end_deg, color_full)
			continue
		else:
			# 空格
			col = color_empty if not is_critical else color_warning

		_draw_arc_segment(start_deg, end_deg, col)

## 繪製單段弧形（from_deg → to_deg，角度以度為單位）
func _draw_arc_segment(from_deg: float, to_deg: float, col: Color) -> void:
	if to_deg <= from_deg:
		return
	var from_rad := deg_to_rad(from_deg)
	var to_rad   := deg_to_rad(to_deg)
	draw_arc(Vector2.ZERO, arc_radius, from_rad, to_rad, arc_points, col, arc_width, true)
