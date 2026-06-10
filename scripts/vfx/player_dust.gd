extends Node2D
## PlayerDust — 方塊煙塵特效系統（TrailDust + BurstDust）
## ──────────────────────────────────────────────────────────
## TrailDust : 地面移動時連續噴出各種大小的方塊，留在軌跡上
## BurstDust : 跳躍 / 蹬牆 / 衝刺 / 墜落 觸發大型爆發方塊
## ──────────────────────────────────────────────────────────
## 顏色：ShapeCast2D 採樣地板像素（由 set_trail_active / emit_burst 傳入）
## Local Coords = OFF → 粒子以世界座標停留，不跟著 Player 移動

@onready var _trail: GPUParticles2D = $TrailDust
@onready var _burst: GPUParticles2D = $BurstDust

# ── 內部 ────────────────────────────────────────────────────
var _trail_mat: ParticleProcessMaterial
var _burst_mat:  ParticleProcessMaterial
var _trail_active: bool = false   # 目前是否正在發射
var _scale_curve_tex: CurveTexture

# ═══════════════════════════════════════════════════════════
# EXPORT 參數（Inspector 即時調整）
# ═══════════════════════════════════════════════════════════

# ── TrailDust ────────────────────────────────────────────────
@export_group("TrailDust")
## 粒子池大小（決定同時存在的最大粒子數）
@export var trail_amount: int = 15
## 粒子壽命（秒）—— 越長軌跡越長
@export_range(0.2, 2.0, 0.01) var trail_lifetime: float = 0.35
## 粒子初速最小值（px/s）
@export_range(0.0, 100.0, 1.0) var trail_vel_min: float = 10.0
## 粒子初速最大值（px/s）
@export_range(0.0, 200.0, 1.0) var trail_vel_max: float = 30.0
## 重力（px/s²，讓方塊緩緩落下）
@export_range(0.0, 400.0, 5.0) var trail_gravity: float = 150.0
## 最小方塊縮放（以 1x1 像素為基礎，1.0 = 1px）
@export_range(1.0, 4.0, 0.5) var trail_scale_min: float = 2.0
## 最大方塊縮放
@export_range(1.0, 6.0, 0.5) var trail_scale_max: float = 4.0
## 散射角度（度）
@export_range(0.0, 120.0, 1.0) var trail_spread: float = 45.0
## 移動速度閾值（速度超過此值才發射軌跡）
@export_range(0.0, 100.0, 5.0) var trail_speed_threshold: float = 20.0

# ── BurstDust ────────────────────────────────────────────────
@export_group("BurstDust")
## 爆發粒子數
@export var burst_amount: int = 20
## 粒子壽命（秒）
@export_range(0.2, 2.5, 0.01) var burst_lifetime: float = 0.5
## 爆發集中度（0=分散，1=同時）
@export_range(0.0, 1.0, 0.05) var burst_explosiveness: float = 0.88
## 粒子初速最小值（px/s）
@export_range(5.0, 400.0, 5.0) var burst_vel_min: float = 50.0
## 粒子初速最大值（px/s）
@export_range(5.0, 600.0, 5.0) var burst_vel_max: float = 120.0
## 重力（px/s²）
@export_range(0.0, 600.0, 10.0) var burst_gravity: float = 400.0
## 最小方塊縮放（比 Trail 更大）
@export_range(1.0, 6.0, 0.5) var burst_scale_min: float = 1.0
## 最大方塊縮放
@export_range(2.0, 12.0, 0.5) var burst_scale_max: float = 4.0
## 散射角度（度）
@export_range(0.0, 120.0, 1.0) var burst_spread: float = 60.0



# ═══════════════════════════════════════════════════════════
func _ready() -> void:
	# 將特效節點向下偏移 6 像素，接近腳底但不會陷入地板
	position = Vector2(0, 6)
	# 提高 z_index 確保絕對不會被地圖或背景遮擋
	z_index = 100
	
	# 建立隨壽命縮小的曲線
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_scale_curve_tex = CurveTexture.new()
	_scale_curve_tex.curve = curve

	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_setup_trail(tex)
	_setup_burst(tex)

# ── 初始化 TrailDust ─────────────────────────────────────────
func _setup_trail(tex: Texture2D) -> void:
	_trail.texture      = tex
	_trail.amount       = trail_amount
	_trail.lifetime     = trail_lifetime
	_trail.one_shot     = false
	_trail.local_coords = false
	_trail.emitting     = false

	_trail_mat = ParticleProcessMaterial.new()
	_trail_mat.direction            = Vector3(0.0, -1.0, 0.0)
	_trail_mat.spread               = trail_spread
	_trail_mat.initial_velocity_min = trail_vel_min
	_trail_mat.initial_velocity_max = trail_vel_max
	_trail_mat.gravity              = Vector3(0.0, trail_gravity, 0.0)
	_trail_mat.scale_min            = trail_scale_min
	_trail_mat.scale_max            = trail_scale_max
	_trail_mat.scale_curve          = _scale_curve_tex
	_trail.process_material         = _trail_mat

# ── 初始化 BurstDust ─────────────────────────────────────────
func _setup_burst(tex: Texture2D) -> void:
	_burst.texture        = tex
	_burst.amount         = burst_amount
	_burst.lifetime       = burst_lifetime
	_burst.explosiveness  = burst_explosiveness
	_burst.one_shot       = true
	_burst.local_coords   = false
	_burst.emitting       = false

	_burst_mat = ParticleProcessMaterial.new()
	_burst_mat.direction            = Vector3(0.0, -1.0, 0.0)
	_burst_mat.spread               = burst_spread
	_burst_mat.initial_velocity_min = burst_vel_min
	_burst_mat.initial_velocity_max = burst_vel_max
	_burst_mat.gravity              = Vector3(0.0, burst_gravity, 0.0)
	_burst_mat.scale_min            = burst_scale_min
	_burst_mat.scale_max            = burst_scale_max
	_burst_mat.scale_curve          = _scale_curve_tex
	_burst.process_material         = _burst_mat

# ═══════════════════════════════════════════════════════════
# 公開 API
# ═══════════════════════════════════════════════════════════

## 開啟/關閉軌跡塵（每幀由 player1.gd 呼叫）
## active      : 是否在移動
## floor_color : 地板採樣顏色（由 _get_floor_color() 傳入）
## move_dir    : 移動方向（1=右，-1=左），用於讓方塊往後飄
func set_trail_active(active: bool,
					  color_ramp: GradientTexture1D = null,
					  move_dir: float = 0.0) -> void:
	# 根據移動方向調整軌跡粒子的噴出方向（更貼近地面 + 往後踢）
	if active and move_dir != 0.0:
		var d := Vector3(-move_dir * 0.8, -1.0, 0.0).normalized()
		_trail_mat.direction = d

	if color_ramp:
		_trail_mat.color_initial_ramp = color_ramp
		_trail.modulate = Color.WHITE # 重置 node 的 modulate，避免雙重染色

	# 僅在狀態改變時修改 emitting（避免每幀重設）
	if active != _trail_active:
		_trail_active  = active
		_trail.emitting = active

## 大型爆發（跳躍 / 蹬牆 / 衝刺 / 墜落 觸發）
## terrain_normal : 地形法線（地板=Vector2.UP，牆面=水平法線）
## launch_velocity: 觸發時的 velocity（用於計算反射方向）
## floor_color    : 地板 / 牆壁 顏色
func emit_burst(terrain_normal: Vector2,
				launch_velocity: Vector2,
				color_ramp: GradientTexture1D = null) -> void:
	# 計算粒子爆發主方向（velocity 在地形法線的反射）
	var dir := _calc_burst_direction(terrain_normal, launch_velocity)
	_burst_mat.direction = dir
	
	if color_ramp:
		_burst_mat.color_initial_ramp = color_ramp
		_burst.modulate = Color.WHITE
		
	_burst.restart()

# ── 輔助：計算爆發方向 ───────────────────────────────────────
func _calc_burst_direction(normal: Vector2, vel: Vector2) -> Vector3:
	# 取消反射邏輯，改為永遠沿著法線往外噴（從牆壁噴出、從地板往上噴）
	var dir := normal.normalized()
	
	# 根據玩家的水平速度，稍微加一點反向的後座力
	if abs(vel.x) > 1.0:
		dir.x -= sign(vel.x) * 0.6
		
	dir = dir.normalized()
	return Vector3(dir.x, dir.y, 0.0)
