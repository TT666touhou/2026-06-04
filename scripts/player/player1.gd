extends CharacterBody2D
## Player1 — 標準 2D 橫向移動控制器
## 操控（可在 Project Settings → Input Map 修改）：
##   move_left / move_right → 水平移動
##   jump                   → Space / W / ↑（跳躍 + Apex 二段跳）
##   roll                   → Shift（翻滾）

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數（全部可在 Inspector 即時調整）
# ═══════════════════════════════════════════════════════════════

# ── 移動 ────────────────────────────────────────────────────────
@export_group("Movement")
## 水平最大速度（px/s）
@export var speed: float = 200.0
## 重力加速度（px/s²）
@export var gravity: float = 980.0
## 地面制動加速度（px/s²）
@export var friction: float = 800.0
## 空中水平摩擦倍率（0=完全無摩擦，1=與地面相同）
@export_range(0.0, 1.0, 0.05) var air_friction_factor: float = 0.3

# ── 跳躍 ────────────────────────────────────────────────────────
@export_group("Jump")
## 第一跳初速（負=向上）
## 計算公式：height = v² / (2 × gravity)
## -161 @ gravity=180 → 高度 71.97px（中心）/ 底部約 64px
@export var jump_velocity: float = -420.0
## Coyote Time：踩空後仍可跳的寬限秒數
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12
## Jump Buffer：落地前提早按跳躍的容錯秒數
@export_range(0.0, 0.4, 0.01) var jump_buffer_time: float = 0.15

# ── 二段跳（Apex Jump）──────────────────────────────────────────
@export_group("Double Jump (Apex)")
## ℹ️ 二段跳機制說明：
##   上升期按跳躍 → buffer 保存，到達最高點自動觸發
##   下降期按跳躍 → 立即觸發（從較低位置，高度較低）
##   動能重置：velocity.y 恢復為 jump_velocity（與第一跳完全相同）
##   耐力消耗在觸發時才發生
## （無獨立 double_jump_velocity，二段跳高度 = 第一跳高度）

# ── 蹬牆跳 ──────────────────────────────────────────────────────
@export_group("Wall Jump")
## 蹬牆後向上的速度
@export var wall_jump_vertical: float = -380.0
## 蹬牆後離牆的水平速度
@export var wall_jump_horizontal: float = 180.0
## 蹬牆後水平方向鎖定時間（防止馬上頂回去）
@export_range(0.0, 0.5, 0.01) var wall_jump_lock_time: float = 0.2

# ── 翻滾 ────────────────────────────────────────────────────────
@export_group("Roll")
## 翻滾速度（px/s）
@export var roll_speed: float = 250.0
## 翻滾持續時間（秒）
@export_range(0.05, 0.5, 0.01) var roll_duration: float = 0.3
## 翻滾冷卻時間（秒）
@export_range(0.0, 1.0, 0.05) var roll_cooldown: float = 0.4
## 無敵幀持續時間（秒，≤ roll_duration）
@export_range(0.0, 0.4, 0.01) var roll_invincible_duration: float = 0.12

# ── 耐力系統 ────────────────────────────────────────────────────
@export_group("Stamina")
## 最大耐力格數
@export var max_stamina: float = 3.0
## 耐力恢復速度（格/秒）
@export_range(0.1, 3.0, 0.05) var stamina_recovery: float = 0.8

## 將玩家位置四捨五入到整數像素（修正 zoom 下的模糊問題）
@export var snap_position_to_pixel: bool = true

# ═══════════════════════════════════════════════════════════════
# 節點引用（_ready 時取得）
# ═══════════════════════════════════════════════════════════════
@onready var _stamina_ui: Node2D     = $StaminaBar
@onready var _dust_vfx:   Node2D     = $PlayerDust
@onready var _floor_cast: ShapeCast2D = $FloorCast

# ═══════════════════════════════════════════════════════════════
# 內部狀態
# ═══════════════════════════════════════════════════════════════

# ── 地面狀態 ────────────────────────────────────────────────────
var _was_on_floor: bool = false

# ── 跳躍 ────────────────────────────────────────────────────────
var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0

# ── Apex 二段跳 ──────────────────────────────────────────────────
var _can_double_jump:    bool = false  # 本次起跳後可否執行二段跳
var _apex_jump_buffered: bool = false  # 上升期是否已按跳躍（等待 apex 觸發）
var _was_ascending:      bool = false  # 上一幀是否在上升（Y 為負）

# ── 蹬牆跳 ──────────────────────────────────────────────────────
var _wall_lock_timer: float = 0.0

# ── 翻滾 ────────────────────────────────────────────────────────
var _is_rolling:    bool  = false
var _roll_timer:    float = 0.0
var _roll_cooldown: float = 0.0
var is_invincible:  bool  = false  # 供外部（攻擊判定）讀取

# ── 耐力 ────────────────────────────────────────────────────────
var _stamina: float = 3.0

# ── 翻滚朝向（供 roll 使用） ──────────────────────────────────────
var _facing: float = 1.0   # 1=右, -1=左

# ═══════════════════════════════════════════════════════════════
# 地板顏色快取將（每 0.1s 更新一次，減少 ShapeCast 像素讀取频率）
# ═══════════════════════════════════════════════════════════════
const _FLOOR_COLOR_INTERVAL: float = 0.1
var _cached_floor_ramp: GradientTexture1D
var _floor_color_timer: float = 0.0

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_cached_floor_ramp = _fallback_ramp()
	_stamina = max_stamina

# ═══════════════════════════════════════════════════════════════
# 物理更新主迴圈（標準順序）
# ═══════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	# 1. 重力
	_apply_gravity(delta)

	# 2. 耐力恢復
	_recover_stamina(delta)

	# 3. 跳躍（最優先，可覆蓋重力效果）
	_handle_jump(delta)

	# 4. 翻滾（覆蓋水平移動）
	_handle_roll(delta)

	# 5. 水平移動（翻滾中跳過）
	if not _is_rolling:
		_handle_horizontal(delta)

	# 6. 物理移動
	move_and_slide()

	# 6.5. VFX 更新
	_update_vfx(delta)

	# 7. 像素對齊（消除 float 座標在 zoom 下的模糊）
	if snap_position_to_pixel:
		position = position.round()

	# 8. UI
	_update_stamina_ui()

	# 9. 地面狀態記錄（供下一幀使用）
	_was_on_floor = is_on_floor()

# ═══════════════════════════════════════════════════════════════
# 重力
# ═══════════════════════════════════════════════════════════════
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# ═══════════════════════════════════════════════════════════════
# 跳躍系統（包含 Coyote、Jump Buffer、Apex 二段跳、蹬牆跳）
# ═══════════════════════════════════════════════════════════════
func _handle_jump(delta: float) -> void:
	var jump_pressed := Input.is_action_just_pressed("jump")
	var on_floor     := is_on_floor()
	var ascending    := velocity.y < 0.0   # 上升中（Y 負 = 向上）
	var descending   := velocity.y > 0.0   # 下降中（Y 正 = 向下）

	# ── 落地後重置所有跳躍狀態 ──────────────────────────────────
	if on_floor:
		_can_double_jump    = false
		_apex_jump_buffered = false
		_coyote_timer       = coyote_time
		_was_ascending      = false
		# Jump buffer 在落地時執行（見下方第 3 段）

	# ── Coyote Time 倒數（空中才倒數）──────────────────────────
	if not on_floor:
		_coyote_timer = max(0.0, _coyote_timer - delta)

	# ── Jump Buffer 記錄 ─────────────────────────────────────────
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time

	# ── 蹬牆跳（最高優先，高於普通跳和二段跳）─────────────────
	if jump_pressed and is_on_wall_only() and _has_stamina():
		_do_wall_jump()
		return

	# ── 普通跳（地面 + Coyote）─────────────────────────────────
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_do_normal_jump()
		return

	# ── 二段跳（Apex Detection）─────────────────────────────────
	if _can_double_jump and not on_floor:

		# 上升期：接受並 buffer 跳躍輸入（等待最高點自動觸發）
		if ascending and jump_pressed and _has_stamina():
			_apex_jump_buffered = true

		# Apex 偵測：上一幀在上升，本幀在下降 = 剛過最高點
		# → 若有 buffer，在此觸發（最佳時機，完整高度）
		if _was_ascending and descending and _apex_jump_buffered:
			_do_double_jump()
			return

		# 下降期直接按跳躍：立即觸發（從較低位置，總高度較低）
		if descending and jump_pressed and _has_stamina():
			_do_double_jump()
			return

	# ── 更新上升/下降記錄（供下一幀 Apex 偵測使用）────────────
	_was_ascending = ascending and not on_floor

# ── 跳躍動作子函式 ────────────────────────────────────────────
func _do_normal_jump() -> void:
	velocity.y          = jump_velocity
	_jump_buffer_timer  = 0.0
	_coyote_timer       = 0.0
	_can_double_jump    = true
	_apex_jump_buffered = false
	_was_ascending      = true
	# BurstDust：地面起跳（強制立即採樣目前地板顏色）
	if _was_on_floor:
		_dust_vfx.emit_burst(Vector2.UP, velocity, _update_floor_ramp_cache())

func _do_wall_jump() -> void:
	var normal       := get_wall_normal()
	velocity.y        = jump_velocity
	velocity.x        = sign(normal.x) * wall_jump_horizontal
	_wall_lock_timer  = wall_jump_lock_time
	_can_double_jump  = true
	_apex_jump_buffered = false
	_was_ascending    = true
	_jump_buffer_timer = 0.0
	_consume_stamina()
	# BurstDust：牆壁節屑，以牆壁法線做反射方向，並從擴大的 FloorCast 採樣牆壁顏色
	_dust_vfx.emit_burst(normal, velocity, _get_floor_ramp())

func _do_double_jump() -> void:
	# 動能重置：設回第一跳的初速（非疊加），確保二段跳高度 = 第一跳高度
	velocity.y          = jump_velocity
	_can_double_jump    = false
	_apex_jump_buffered = false
	_was_ascending      = true   # 二段跳後重新上升
	_consume_stamina()

# ═══════════════════════════════════════════════════════════════
# 水平移動
# ═══════════════════════════════════════════════════════════════
func _handle_horizontal(delta: float) -> void:
	# 蹬牆跳後鎖定水平方向一段時間
	if _wall_lock_timer > 0.0:
		_wall_lock_timer = max(0.0, _wall_lock_timer - delta)
		return

	var dir := Input.get_axis("move_left", "move_right")

	if dir != 0.0:
		_facing = sign(dir)
		velocity.x = dir * speed
	else:
		# 制動：地面全力煞車，空中摩擦較少
		var decel := friction if is_on_floor() else friction * air_friction_factor
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

# ═══════════════════════════════════════════════════════════════
# 翻滾
# ═══════════════════════════════════════════════════════════════
func _handle_roll(delta: float) -> void:
	# 冷卻倒數
	_roll_cooldown = max(0.0, _roll_cooldown - delta)

	if _is_rolling:
		_roll_timer -= delta
		# 無敵幀在翻滾前段生效
		is_invincible = _roll_timer > (roll_duration - roll_invincible_duration)
		# 翻滾期間鎖定水平速度
		velocity.x = _facing * roll_speed

		if _roll_timer <= 0.0:
			_is_rolling  = false
			is_invincible = false
	else:
		# 觸發翻滾：地面 + 有冷卻時間 + 有耐力
		if Input.is_action_just_pressed("roll") and is_on_floor() \
		   and _roll_cooldown <= 0.0 and _has_stamina():
			_is_rolling    = true
			_roll_timer    = roll_duration
			_roll_cooldown = roll_cooldown
			_consume_stamina()
			# BurstDust：翻滾起軌（強制立即採樣目前地板顏色）
			_dust_vfx.emit_burst(Vector2.UP, velocity, _update_floor_ramp_cache())

# ═══════════════════════════════════════════════════════════════
# 耐力系統
# ═══════════════════════════════════════════════════════════════
func _recover_stamina(delta: float) -> void:
	_stamina = minf(_stamina + stamina_recovery * delta, max_stamina)

func _has_stamina() -> bool:
	return _stamina >= 1.0

func _consume_stamina() -> void:
	if _stamina >= 1.0:
		_stamina -= 1.0
		# 通知 UI 閃爍
		if _stamina_ui != null:
			var slot := clampi(int(_stamina), 0, 2)
			_stamina_ui.trigger_flash(slot)

# ═══════════════════════════════════════════════════════════════
# 耐力 UI 更新
# ═══════════════════════════════════════════════════════════════
func _update_stamina_ui() -> void:
	if _stamina_ui != null:
		_stamina_ui.stamina = _stamina

# ═══════════════════════════════════════════════════════════════
# VFX 更新（對正 move_and_slide 後的狀態）
# ═══════════════════════════════════════════════════════════════
func _update_vfx(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── 地板顏色快取：地面且移動時每 0.1s 更新 ────────────────────
	if on_floor and abs(velocity.x) > trail_speed_threshold_ref():
		_floor_color_timer -= delta
		if _floor_color_timer <= 0.0:
			_cached_floor_ramp = _get_floor_ramp()
			_floor_color_timer  = _FLOOR_COLOR_INTERVAL

	# ── 幹跡煩塵：地面且移動時開啟 ─────────────────────────────────
	var moving_on_floor: bool = on_floor and abs(velocity.x) > trail_speed_threshold_ref()
	_dust_vfx.set_trail_active(moving_on_floor, _cached_floor_ramp, sign(velocity.x))

	# ── 落地偵測：上一幀在空中，本幀觸地 → BurstDust ─────────────────
	if not _was_on_floor and on_floor:
		# 在空中有水平速度 OR 垂直速度超過閾値 = 瞬間爆發（強制立即採樣目前地板顏色）
		if abs(velocity.x) > 10.0 or abs(velocity.y) > 80.0:
			_dust_vfx.emit_burst(Vector2.UP, velocity, _update_floor_ramp_cache())

## 輔助：取得 TrailDust 速度閾値（轉發至 PlayerDust export 參數）
func trail_speed_threshold_ref() -> float:
	var pd := _dust_vfx as Node
	if pd and pd.has_method("get"):
		var v = pd.get("trail_speed_threshold")
		if v != null: return float(v)
	return 20.0

# ═══════════════════════════════════════════════════════════════
# 地板顏色比例採樣（ShapeCast2D → TileMapLayer Atlas 多點取樣）
# ═══════════════════════════════════════════════════════════════
var _fallback_tex: GradientTexture1D
func _fallback_ramp() -> GradientTexture1D:
	if _fallback_tex != null:
		return _fallback_tex
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	grad.set_color(0, Color.DARK_GRAY)
	grad.set_color(1, Color.GRAY)
	_fallback_tex = GradientTexture1D.new()
	_fallback_tex.gradient = grad
	_fallback_tex.width = 16
	return _fallback_tex

func _update_floor_ramp_cache() -> GradientTexture1D:
	_cached_floor_ramp = _get_floor_ramp()
	_floor_color_timer = _FLOOR_COLOR_INTERVAL
	return _cached_floor_ramp

func _get_floor_ramp() -> GradientTexture1D:
	_floor_cast.force_shapecast_update()
	if not _floor_cast.is_colliding():
		return _fallback_ramp()
	for i in _floor_cast.get_collision_count():
		var col := _floor_cast.get_collider(i)
		if not col is TileMapLayer:
			continue
		var tilemap  := col as TileMapLayer
		var pt := _floor_cast.get_collision_point(i)
		var n  := _floor_cast.get_collision_normal(i)
		# 將採樣點往法線反方向（物體內部）推進 2 像素，徹底解決邊緣取樣到空磚塊的浮點數誤差
		pt -= n * 2.0
		var local_pt := tilemap.to_local(pt)
		var cell     := tilemap.local_to_map(local_pt)
		var src_id   := tilemap.get_cell_source_id(cell)
		if src_id < 0:
			continue
		var ts     := tilemap.tile_set
		var source := ts.get_source(src_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var atlas_c  := tilemap.get_cell_atlas_coords(cell)
		var tile_sz  := ts.tile_size
		# 磚塊在 Atlas 貼圖中的左上角（考慮 margins 與 separation）
		var origin   := source.margins + atlas_c * (tile_sz + source.separation)
		var img      := source.texture.get_image()
		if img == null:
			continue  # 貼圖影像無法讀取（VRAM壓縮）→ 賭下一個碰撞體
			
		# 4x4 取樣並統計頻率
		var colors := []
		for y in range(4):
			for x in range(4):
				var px = origin.x + int(tile_sz.x * (x + 0.5) / 4.0)
				var py = origin.y + int(tile_sz.y * (y + 0.5) / 4.0)
				var c = img.get_pixel(px, py)
				if c.a > 0.1:
					colors.append(c)
		
		if colors.is_empty():
			continue
			
		var freq := {}
		for c in colors:
			var hex = c.to_html(false)
			if not freq.has(hex):
				freq[hex] = {"color": c, "count": 0}
			freq[hex].count += 1
			
		var grad := Gradient.new()
		grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var offsets := PackedFloat32Array()
		var grad_colors := PackedColorArray()
		
		var curr_offset := 0.0
		for key in freq:
			var data = freq[key]
			offsets.append(curr_offset)
			grad_colors.append(data.color)
			curr_offset += float(data.count) / float(colors.size())
			
		grad.offsets = offsets
		grad.colors = grad_colors
		
		var tex := GradientTexture1D.new()
		tex.gradient = grad
		tex.width = 16
		return tex
		
	return _fallback_ramp()
