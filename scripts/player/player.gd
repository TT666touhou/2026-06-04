extends CharacterBody2D
## Player1 — 標準 2D 橫向移動控制器
## 操控（可在 Project Settings → Input Map 修改）：
##   move_left / move_right → 水平移動
##   jump                   → Space / W / ↑（跳躍 + Apex 二段跳）
##   roll                   → Shift（翻滾）

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數（全部可在 Inspector 即時調整）
# ═══════════════════════════════════════════════════════════════

# ── 多玩家輸入前綴 ──────────────────────────────────────────────
@export_group("Multiplayer")
## 輸入動作前綴："" = 使用預設(單機), "p1_" / "p2_" / "p3_" / "p4_" = 多玩家
@export var player_prefix: String = ""

# ── 移動 ────────────────────────────────────────────────────────
@export_group("Movement")
## 水平最大速度（px/s）
@export var speed: float = 100.0
## 地面啟動與轉向加速度（px/s²）
@export var acceleration: float = 800.0
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
@export var jump_velocity: float = -297.0
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
@export var wall_jump_vertical: float = -268.7
## 蹬牆後離牆的水平速度
@export var wall_jump_horizontal: float = 90.0
## 蹬牆後水平方向鎖定時間（防止馬上頂回去）
@export_range(0.0, 0.5, 0.01) var wall_jump_lock_time: float = 0.2

# ── 翻滾 ────────────────────────────────────────────────────────
@export_group("Roll")
## 翻滾速度（px/s）
@export var roll_speed: float = 125.0
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

# ── 視覺傾斜 (Visual Sway) ────────────────────────────────────────────────
@export_group("Visual Sway")
## 彈簧系統：頻率（反應速度，越大越快）
@export var sway_frequency: float = 4.0
## 彈簧系統：阻尼（<1 會有回彈與 overshoot，越低越 Q 彈）
@export var sway_damping: float = 0.35
## 彈簧系統：初始反應力度
@export var sway_response: float = 1.2
## 最大傾斜角度（度）
@export var sway_max_angle: float = 25.0

# ── 戰鬥系統 ────────────────────────────────────────────────────
@export_group("Combat")
## 近戰傷害
@export var melee_damage: int = 1
## 近戰攻擊範圍（向前）px
@export var melee_range: float = 28.0
## 近戰攻擊張數（秒）
@export_range(0.1, 1.0, 0.05) var melee_duration: float = 0.25
## 近戰冷卻時間（秒）
@export_range(0.1, 2.0, 0.05) var melee_cooldown: float = 0.45
## 遠程子彈傷害
@export var bullet_damage: int = 1
## 遠程子彈速度（px/s）
@export var bullet_speed: float = 280.0
## 遠程冷卻時間（秒）
@export_range(0.1, 2.0, 0.05) var ranged_cooldown: float = 0.6
## 遠程子彈場景（由 GameWorld 動態注入）
@export var bullet_scene: PackedScene
## 近戰片斬特效（左鍵攻擊觸發）
@export var melee_slash_scene: PackedScene
## 遠程發射火花特效（右鍵攻擊觸發）
@export var muzzle_flash_scene: PackedScene

# ═══════════════════════════════════════════════════════════════
# 節點引用（_ready 時取得）
# ═══════════════════════════════════════════════════════════════
@onready var _stamina_ui: Node2D      = $StaminaBar
@onready var _dust_vfx:   Node2D      = $PlayerDust
@onready var _floor_cast: ShapeCast2D = $FloorCast
@onready var _visual_pivot: Node2D    = $VisualPivot
@onready var appearance: TileMapLayer = $VisualPivot/Appearance

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

# ── 生命與無敵幀 ──────────────────────────────────────────────────
signal health_changed(new_health: int)
signal died

@export_group("Health")
@export var max_health: int = 3
@export var i_frame_duration: float = 1.5

var current_health: int = 3
var _i_frame_timer: float = 0.0


# ── 視覺傾斜 (Sway) 變數 ──────────────────────────────────────────
var _sway_y: float = 0.0
var _sway_yd: float = 0.0
var _sway_xp: float = 0.0

# ═══════════════════════════════════════════════════════════════
# 地板顏色快取將（每 0.1s 更新一次，減少 ShapeCast 像素讀取频率）
# ═══════════════════════════════════════════════════════════════
const _FLOOR_COLOR_INTERVAL: float = 0.1
var _cached_floor_ramp: GradientTexture1D
var _floor_color_timer: float = 0.0
var _atlas_cache: Dictionary = {}

var _skin_index: int = 0

# ── 戰鬥狀態 ────────────────────────────────────────────────
var _melee_timer: float = 0.0      # > 0 表示攻擊張數中
var _melee_cooldown_timer: float = 0.0
var _ranged_cooldown_timer: float = 0.0
var _is_attacking: bool = false    # 近戰攻擊張數中
var _attack_hold_timer: float = 0.0 # 按住攻擊鍵的時間
## 供 DebugBridge/Overlay 讀取
var attack_state: String = "IDLE"  # "IDLE" | "MELEE" | "RANGED"

# ═══════════════════════════════════════════════════════════════
# Multiplayer Authority
# ═══════════════════════════════════════════════════════════════
func _enter_tree() -> void:
	# 設定 multiplayer authority：節點名稱必須是 peer_id 字串
	# 例如：節點名稱 "1" → 由 peer 1 控制
	if multiplayer.has_multiplayer_peer() and name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _is_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true # 離線/測試時預設本機控制
	return is_multiplayer_authority()

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_cached_floor_ramp = _fallback_ramp()
	_stamina = max_stamina
	
	## Debug 整合：加入 Players group，讓 DebugBridge 自動追蹤
	add_to_group("Players")
	print("[Player] 初始化完成 — name:", name, " prefix:'", player_prefix, "'")
	
	# Multiplayer Synchronizer 設定（在 _enter_tree 之後執行，authority 已設定）
	var sync := MultiplayerSynchronizer.new()
	var rep := SceneReplicationConfig.new()
	
	rep.add_property(NodePath(".:position"))
	rep.property_set_spawn(NodePath(".:position"), true)
	rep.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	
	rep.add_property(NodePath(".:velocity"))
	rep.property_set_spawn(NodePath(".:velocity"), true)
	rep.property_set_replication_mode(NodePath(".:velocity"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	
	rep.add_property(NodePath(".:_facing"))
	rep.property_set_spawn(NodePath(".:_facing"), true)
	rep.property_set_replication_mode(NodePath(".:_facing"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	
	sync.replication_config = rep
	add_child(sync)
	# 注意：Camera 由 MultiplayerCamera 場景節點統一管理，不在 player 內建立

## 設定玩家皮膚 tile（基礎外觀切換）
func set_skin(index: int) -> void:
	_skin_index = index
	if appearance:
		appearance.set_cell(Vector2i(0, 0), 0, Vector2i(28 + index, 0))

## 設定玩家顏色（依 VfxMix 34色調色盤區分玩家）
## skin_index: 0=暖橙, 1=冷藍, 2=綠, 3=紫
func apply_player_color(skin_index: int) -> void:
	const PLAYER_COLORS: Array[Color] = [
		Color("#FF8C42"),  # P1 暖橙
		Color("#4CC9F0"),  # P2 冷藍
		Color("#5DA16E"),  # P3 綠
		Color("#9D5789"),  # P4 紫
	]
	var col := PLAYER_COLORS[skin_index % PLAYER_COLORS.size()]
	if _visual_pivot:
		_visual_pivot.modulate = col


# ═══════════════════════════════════════════════════════════════
# 物理更新主迴圈（標準順序）
# ═══════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	# 6.5. VFX 更新 (Visual effects should run on all clients)
	_update_vfx(delta)

	# 6.6. 視覺傾斜 (Visual Sway should run on all clients)
	_update_sway(delta)
	
	if not _is_authority():
		return
		
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

	# 7. 像素對齊（消除 float 座標在 zoom 下的模糊）
	if snap_position_to_pixel:
		position = position.round()

	# 8. UI
	_update_stamina_ui()

	# 8.5. 無敵幀與閃爍
	_handle_invincibility(delta)

	# 9. 攻擊冷卻計時
	_melee_timer = maxf(0.0, _melee_timer - delta)
	_melee_cooldown_timer = maxf(0.0, _melee_cooldown_timer - delta)
	_ranged_cooldown_timer = maxf(0.0, _ranged_cooldown_timer - delta)
	if _is_attacking and _melee_timer <= 0.0:
		_is_attacking = false
		attack_state = "IDLE"

	# 10. 戰鬥輸入
	_handle_attack(delta)

	# 11. 地面狀態記錄（供下一幀使用）
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
	var jump_pressed := Input.is_action_just_pressed(player_prefix + "jump")
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
	
	# Jump buffer 觸發（落地後）
	if on_floor and _jump_buffer_timer > 0.0:
		_do_normal_jump()
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

	var dir := Input.get_axis(player_prefix + "move_left", player_prefix + "move_right")

	if dir != 0.0:
		_facing = sign(dir)
		var accel := acceleration if is_on_floor() else acceleration * air_friction_factor
		velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
	else:
		# 制動：地面全力煞車，空中摩擦較少
		var decel := friction if is_on_floor() else friction * air_friction_factor
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

# ═══════════════════════════════════════════════════════════════
# 視覺傾斜 (Visual Sway)
# ═══════════════════════════════════════════════════════════════
func _update_sway(delta: float) -> void:
	if not _visual_pivot:
		return
	
	# ── 左右翻轉（依據 _facing 翻轉 scale.x）────────────────────────
	# TileMapLayer 不支援 flip_h，改用 scale.x 翻轉整個 VisualPivot
	# scale.x = 1 → 右（預設），scale.x = -1 → 左
	var target_scale_x := _facing  # 1.0 或 -1.0
	if _visual_pivot.scale.x != target_scale_x:
		_visual_pivot.scale.x = target_scale_x
		
	# 計算目標角度：向右移動 (vel.x > 0) -> 逆時針傾斜 (角度為負)
	# 放大幅度，讓最大速度下的傾斜角度變成 8 度，使動態更明顯
	var target_deg = -velocity.x * (8.0 / speed)
	target_deg = clampf(target_deg, -sway_max_angle, sway_max_angle)
	var target_rad = deg_to_rad(target_deg)
	
	# Second Order Dynamics 計算
	var f = maxf(0.01, sway_frequency)
	var z = maxf(0.01, sway_damping)
	var r = sway_response
	
	var k1 = z / (PI * f)
	var k2 = 1.0 / pow(2 * PI * f, 2)
	var k3 = r * z / (2 * PI * f)
	
	_sway_yd += delta * (target_rad + k3 * (target_rad - _sway_xp) / delta - _sway_y - k1 * _sway_yd) / k2
	_sway_y += delta * _sway_yd
	_sway_xp = target_rad
	
	# 傾斜方向需要跟著 scale.x 翻轉（否則左向時傾斜反向）
	_visual_pivot.rotation = _sway_y * _facing

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
		if Input.is_action_just_pressed(player_prefix + "roll") and is_on_floor() \
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
		# move_and_slide 會把 y 速度歸零，所以這裡只要偵測到剛觸地就觸發
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
	var contact_points: Array[Vector2] = []
	var contact_normals: Array[Vector2] = []
	
	# 1. 優先使用真實的物理碰撞點 (包含 move_and_slide 觸發的蹬牆跳、落地等)
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		contact_points.append(col.get_position())
		contact_normals.append(col.get_normal())
		
	# 2. 補充使用 FloorCast 確保隨時能抓到地板 (例如在地上跑但 y 軸沒有擠壓碰撞時)
	_floor_cast.force_shapecast_update()
	for i in _floor_cast.get_collision_count():
		contact_points.append(_floor_cast.get_collision_point(i))
		contact_normals.append(_floor_cast.get_collision_normal(i))
		
	if contact_points.is_empty():
		print("[VFX DUST] 沒有任何物理碰撞或探測點。使用預設灰塵。")
		return _fallback_ramp()

	# 獲取場景中所有的 TileMapLayer (包含 Ground, Decor 等)
	var tilemaps := get_tree().current_scene.find_children("*", "TileMapLayer", true, false)
	if tilemaps.is_empty():
		return _fallback_ramp()

	var collected_colors: Array[Color] = []

	for i in range(contact_points.size()):
		var pt := contact_points[i]
		var n  := contact_normals[i]
		# 物理內推，確保進入實體內部
		var base_pt = pt - n * 2.0
		
		# 十字探測法 (Cross Probe) - 徹底解決切線邊界與浮點數誤差
		# 同時也是「以碰撞點為中心的多點採樣」
		var probe_offsets = [
			Vector2.ZERO,
			Vector2(2, 0), Vector2(-2, 0),
			Vector2(0, 2), Vector2(0, -2)
		]
		
		for offset in probe_offsets:
			var probe_pt = base_pt + offset
			
			for tm_node in tilemaps:
				var tm := tm_node as TileMapLayer
				if not tm.visible: continue
				
				# 圖層白名單過濾：只允許包含特定名稱的圖層進行採樣
				var lname = tm.name.to_upper()
				if not ("BLOCK" in lname or "WORLD" in lname or "CEIL" in lname or "DECOR" in lname):
					continue
					
				var local_pt := tm.to_local(probe_pt)
				var cell     := tm.local_to_map(local_pt)
				
				var src_id := tm.get_cell_source_id(cell)
				if src_id < 0:
					continue
					
				var ts := tm.tile_set
				if not ts: continue
				var source := ts.get_source(src_id) as TileSetAtlasSource
				if not source or not source.texture: continue
				
				var tex := source.texture
				var img: Image
				if _atlas_cache.has(tex):
					img = _atlas_cache[tex]
				else:
					img = tex.get_image()
					if img:
						_atlas_cache[tex] = img
						
				if not img: continue
				
				var atlas_c  := tm.get_cell_atlas_coords(cell)
				# 網路建議的最佳實踐：直接向 TileSetAtlasSource 獲取該磁磚真正的 Rect2i
				# 註：第二個參數是 animation frame 而非 alternative_tile，因此不需要傳入 alternative_tile！
				var region: Rect2i = source.get_tile_texture_region(atlas_c)
				
				# 算出碰撞點相對於「該格子中心」的偏移量
				var cell_center_local = tm.map_to_local(cell)
				var offset_from_center = local_pt - cell_center_local
				
				# 在 Atlas 上的實際中心像素座標 (加上偏移)
				var atlas_center = Vector2(region.position) + Vector2(region.size) / 2.0
				var center_px = int(atlas_center.x + offset_from_center.x)
				var center_py = int(atlas_center.y + offset_from_center.y)
				
				var valid_pixels: Array[Color] = []
				
				# 1. 優先：精準接觸點採樣 (3x3 範圍)
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var px = center_px + dx
						var py = center_py + dy
						if px >= region.position.x and px < region.end.x and py >= region.position.y and py < region.end.y:
							if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
								var c := img.get_pixel(px, py)
								if c.a > 0.8 and c.get_luminance() < 0.98:
									c.a = 1.0 # 強制不透明
									valid_pixels.append(c)
				
				# 2. 穩定性防呆機制：如果精準採樣失敗 (例如戳到透明邊緣、或是發生翻轉導致座標錯位)
				# 則立刻在「該磁磚的有效區域」內隨機取樣，保證絕對不會回傳空陣列而變成預設白底灰塵！
				if valid_pixels.is_empty():
					for s in range(5):
						var rx = randi_range(region.position.x, region.end.x - 1)
						var ry = randi_range(region.position.y, region.end.y - 1)
						if rx >= 0 and rx < img.get_width() and ry >= 0 and ry < img.get_height():
							var c := img.get_pixel(rx, ry)
							# 放寬條件，只要有顏色就好
							if c.a > 0.1:
								c.a = 1.0
								valid_pixels.append(c)
										
				collected_colors.append_array(valid_pixels)

	if collected_colors.is_empty():
		print("[VFX DUST] 迴圈結束，沒有任何 TileMapLayer 的碰撞點成功採樣，使用預設灰塵。")
		return _fallback_ramp()

	# 混合並產生漸層
	collected_colors.shuffle()
	var display_colors: Array[Color] = []
	for i in range(min(3, collected_colors.size())):
		display_colors.append(collected_colors[i])
		
	if display_colors.size() == 1:
		display_colors.append(display_colors[0].darkened(0.2))
		
	display_colors.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var grad_colors := PackedColorArray()
	var step = 1.0 / display_colors.size()
	
	for i in range(display_colors.size()):
		offsets.append(i * step)
		grad_colors.append(display_colors[i])
		
	grad.offsets = offsets
	grad.colors = grad_colors
	
	var out_tex := GradientTexture1D.new()
	out_tex.gradient = grad
	out_tex.width = 16
	print("[VFX DUST] 全局十字探測成功！混合了 ", display_colors.size(), " 種顏色。")
	return out_tex

# ═══════════════════════════════════════════════════════════════
# 戰鬥與受擊邏輯
# ═══════════════════════════════════════════════════════════════
func take_damage(amount: int) -> void:
	if _i_frame_timer > 0.0 or _is_rolling or is_invincible:
		return
		
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health)
	
	if current_health <= 0:
		die()
	else:
		_i_frame_timer = i_frame_duration
		print("[Player] Took damage! HP remaining: ", current_health)

func die() -> void:
	print("[Player] Died!")
	## 發出死亡信號，由 GameWorld 決定重生或 Game Over
	## 不在這裡直接 reload（避免多人模式衝突）
	died.emit()
	## 隱藏玩家但不銷毀（等待 GameWorld 決策）
	visible = false
	set_physics_process(false)

## 回復指定 HP（由休息房呼叫）
func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health)
	print("[Player] Healed! HP now: ", current_health)

func _handle_invincibility(delta: float) -> void:
	if _i_frame_timer > 0.0:
		_i_frame_timer = maxf(0.0, _i_frame_timer - delta)
		# 閃爍特效：以 70ms 為間隔切換半透明 (0.4) 與不透明 (1.0)
		var blink_freq := 0.07
		var is_blink_visible := fmod(_i_frame_timer, blink_freq * 2.0) < blink_freq
		if _visual_pivot:
			_visual_pivot.modulate.a = 0.4 if is_blink_visible else 1.0
	else:
		if _visual_pivot and _visual_pivot.modulate.a != 1.0:
			_visual_pivot.modulate.a = 1.0

# ═══════════════════════════════════════════════════════════════
# 戰鬥系統（攻擊輸入處理）
# 設計決策 [CONFIRMED 2026-06-12]:
#   左鍵 (LMB) = 近戰攻擊（即時觸發，短範圍矩形揄描）
#   右鍵 (RMB) = 遠程攻擊（即時觸發，發射子彈）
# ═══════════════════════════════════════════════════════════════
func _handle_attack(_delta: float) -> void:
	## 翻滚中禁止攻擊
	if _is_rolling:
		return

	var melee_action  := player_prefix + "melee"
	var ranged_action := player_prefix + "ranged"

	## 近戰：左鍵 just_pressed（骜防御： action 不存在則跳過）
	if InputMap.has_action(melee_action) and Input.is_action_just_pressed(melee_action):
		if _melee_cooldown_timer <= 0.0 and not _is_attacking:
			_perform_melee_attack()
			_is_attacking = true
			_melee_timer = melee_duration
			_melee_cooldown_timer = melee_cooldown
			attack_state = "MELEE"

	## 遠程：右鍵 just_pressed
	if InputMap.has_action(ranged_action) and Input.is_action_just_pressed(ranged_action):
		if _ranged_cooldown_timer <= 0.0:
			_fire_bullet()
			_ranged_cooldown_timer = ranged_cooldown
			attack_state = "RANGED"

	## 攻擊張數結束重置
	if _is_attacking and _melee_timer <= 0.0:
		_is_attacking = false
		attack_state = "IDLE"

func _perform_melee_attack() -> void:
	## 用 ShapeCast2D 掃描前方扇形區域（即時查詢，不依賴固定 Hitbox 節點）
	var space := get_world_2d().direct_space_state
	var shape  := RectangleShape2D.new()
	shape.size = Vector2(melee_range, 24.0)

	## 攻擊方向跟隨 _facing（-1 = 左，1 = 右）
	var offset := Vector2(_facing * (melee_range * 0.5 + 4.0), 0.0)
	var hit_transform := global_transform
	hit_transform.origin += offset

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = hit_transform
	## 只打中 Layer 4（Enemies）
	query.collision_mask = 8

	var results := space.intersect_shape(query, 8)
	for r: Dictionary in results:
		var body: Node = r.get("collider")
		if body and body != self and body.has_method("take_damage"):
			body.take_damage(melee_damage)
			print("[Player] 近戰命中：", body.name, " 傷害：", melee_damage)

	## 視覺回餌：短暫縮放 VisualPivot 模擬攻擊動態
	if _visual_pivot:
		var tw := create_tween()
		var scale_dir := Vector2(1.3 * _facing, 0.85)
		tw.tween_property(_visual_pivot, "scale", scale_dir, 0.08)
		tw.tween_property(_visual_pivot, "scale", Vector2.ONE, 0.12)

	## 近戰片斬 VFX
	var vfx_pos := global_position + Vector2(_facing * 12.0, -4.0)
	_spawn_vfx(melee_slash_scene, vfx_pos, _facing < 0.0)

## ── 8方向射擊方向計算 ────────────────────────────────────────────
## 依據目前按下的 WASD 鍵決定射擊方向（8個方向）
## 水平：move_left / move_right
## 垂直：move_up (W) / move_down (S)
## 無輸入時：沿 _facing 水平射擊
func _get_aim_direction() -> Vector2:
	var h := Input.get_axis(player_prefix + "move_left", player_prefix + "move_right")
	var v_up   := Input.is_action_pressed(player_prefix + "move_up")   if InputMap.has_action(player_prefix + "move_up")   else false
	var v_down := Input.is_action_pressed(player_prefix + "move_down") if InputMap.has_action(player_prefix + "move_down") else false
	var v := 0.0
	if v_up:   v = -1.0
	if v_down: v =  1.0
	
	# 更新朝向（水平輸入時才更新，確保近戰方向與移動方向一致）
	if h != 0.0:
		_facing = sign(h)
	
	# 構建方向向量並標準化（對角線自動變為 0.707）
	var dir := Vector2(h, v)
	if dir.length_squared() < 0.01:
		# 無方向輸入 → 沿朝向水平射擊
		return Vector2(_facing, 0.0)
	return dir.normalized()

func _fire_bullet() -> void:
	## 從 GameWorld 的 Players 父節點取得子彈場景引用
	if bullet_scene == null:
		## 嘗試從 GameWorld 找 bullet_scene
		var gw := get_node_or_null("/root")
		if gw == null:
			push_warning("[Player] bullet_scene 未設定，無法發射")
			return

	var b_scene := bullet_scene
	if b_scene == null:
		## fallback：動態載入（正確路徑 player_bullet.tscn）
		b_scene = load("res://scenes/player/player_bullet.tscn") as PackedScene
		if b_scene == null:
			push_warning("[Player] 找不到 player_bullet.tscn，無法發射")
			return

	## ── 8方向彈道：根據 WASD 輸入決定方向 ──────────────────────────
	var aim_dir := _get_aim_direction()

	var bullet: Node2D = b_scene.instantiate()
	## 繼承玩家顏色（tint）
	if _visual_pivot:
		bullet.modulate = _visual_pivot.modulate

	## 設定子彈初始位置（從玩家中心偏移 8px 向發射方向）
	var spawn_pos := global_position + aim_dir * 8.0 + Vector2(0.0, -4.0)
	bullet.global_position = spawn_pos

	if bullet.has_method("setup"):
		bullet.setup(aim_dir, bullet_speed, bullet_damage, "Players")
	elif bullet.get("direction") != null:
		bullet.set("direction", aim_dir)
		if bullet.get("speed") != null:
			bullet.set("speed", bullet_speed)

	## 加入到 Players 的父節點（同一個 World 空間）
	var parent := get_parent()
	if parent:
		parent.add_child(bullet)
	print("[Player] 發射子彈 8方向：", aim_dir)

	## 遠程發射 VFX（位置跟 spawn_pos 相同；flip_h 依水平朝向，旋轉依射擊角度）
	_spawn_vfx_aimed(muzzle_flash_scene, spawn_pos, aim_dir)


# ═══════════════════════════════════════════════════════════════
# VFX 輔助函式
# ═══════════════════════════════════════════════════════════════
func _spawn_vfx(vfx_scene: PackedScene, pos: Vector2, flip_h: bool = false) -> void:
	if vfx_scene == null:
		return
	var vfx := vfx_scene.instantiate() as Node2D
	if vfx == null:
		return
	vfx.global_position = pos
	if flip_h:
		var spr := vfx.get_node_or_null("AnimatedSprite2D")
		if spr:
			spr.flip_h = true
	var parent := get_parent()
	if parent:
		parent.call_deferred("add_child", vfx)

## 8方向 VFX：根據射擊方向旋轉特效，並依水平分量決定 flip_h
func _spawn_vfx_aimed(vfx_scene: PackedScene, pos: Vector2, aim_dir: Vector2) -> void:
	if vfx_scene == null:
		return
	var vfx := vfx_scene.instantiate() as Node2D
	if vfx == null:
		return
	vfx.global_position = pos
	## 旋轉整個 VFX 節點以對齊射擊方向（0 = 右，PI = 左，等）
	vfx.rotation = aim_dir.angle()
	var parent := get_parent()
	if parent:
		parent.call_deferred("add_child", vfx)
