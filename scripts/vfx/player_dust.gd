extends Node2D
## PlayerDust — 雙 GPU 粒子特效（BrickDebris + DustCloud）
## 架構：永久子節點，掛在 player1.tscn 下，由 player1.gd 呼叫 emit_*() 方法。
## Local Coords = OFF → 粒子以世界座標停留，不跟著 Player 移動。

@onready var _bricks: GPUParticles2D = $BrickDebris
@onready var _dust:   GPUParticles2D = $DustCloud

const _BRICK_TEX := preload("res://assets/vfxmix/particle/brick_gray.png")

# ── BrickDebris 參數 ──────────────────────────────────────────────
@export_group("BrickDebris")
## 每次爆發的粒子數（= brick_gray.png 幀數）
@export var brick_amount: int = 6
## 粒子壽命（秒）
@export_range(0.1, 2.0, 0.01) var brick_lifetime: float = 0.45
## 爆發集中度（0=分散，1=同時噴出）
@export_range(0.0, 1.0, 0.05) var brick_explosiveness: float = 0.90
## 初速最小值（px/s）
@export_range(10.0, 300.0, 5.0) var brick_vel_min: float = 60.0
## 初速最大值（px/s）
@export_range(10.0, 500.0, 5.0) var brick_vel_max: float = 130.0
## 角速最小值（度/s，碎片旋轉）
@export_range(-720.0, 0.0, 10.0) var brick_ang_min: float = -200.0
## 角速最大值（度/s）
@export_range(0.0, 720.0, 10.0) var brick_ang_max: float = 200.0
## 重力加速度（px/s²）
@export_range(0.0, 1000.0, 10.0) var brick_gravity: float = 300.0
## 磚塊紹素材大小 24×22px，玩家 16×16，讓磚塊變小有真實感
## 縮放範圍：0.15~0.35 = 实際 3.6~8.4px
@export_range(0.05, 1.0, 0.01) var brick_scale_min: float = 0.15
## 縮放最大値
@export_range(0.05, 2.0, 0.01) var brick_scale_max: float = 0.35
## 散射角度（度）
@export_range(0.0, 90.0, 1.0) var brick_spread: float = 30.0

# ── DustCloud 參數 ────────────────────────────────────────────────
@export_group("DustCloud")
## 粒子數
@export var dust_amount: int = 18
## 粒子壽命（秒）
@export_range(0.1, 2.0, 0.01) var dust_lifetime: float = 0.60
## 爆發集中度
@export_range(0.0, 1.0, 0.05) var dust_explosiveness: float = 0.90
## 初速最小値（px/s）
@export_range(5.0, 200.0, 5.0) var dust_vel_min: float = 25.0
## 初速最大値（px/s）
@export_range(5.0, 300.0, 5.0) var dust_vel_max: float = 60.0
## 重力加速度（px/s²）
@export_range(0.0, 500.0, 10.0) var dust_gravity: float = 120.0
## 縮放最小値（無貼圖 = 點粒子渲染大小）
@export_range(0.1, 5.0, 0.05) var dust_scale_min: float = 1.5
## 縮放最大値
@export_range(0.1, 5.0, 0.05) var dust_scale_max: float = 3.5
## 散射角度（度）
@export_range(0.0, 120.0, 1.0) var dust_spread: float = 55.0
## 灰塵顏色（固定）
@export var dust_color: Color = Color(0.667, 0.667, 0.667, 1.0)

# ── 內部 ─────────────────────────────────────────────────────────
var _brick_mat: ParticleProcessMaterial
var _dust_mat:  ParticleProcessMaterial
# 預先快取 6 個 AtlasTexture（每幀 24×22px）
var _brick_frames: Array[AtlasTexture] = []

# ═══════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_brick_frames()
	_setup_brick_debris()
	_setup_dust_cloud()

# ── 建立 6 個 AtlasTexture（對應 brick_gray.png 的 6 幀）────────────
func _build_brick_frames() -> void:
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas  = _BRICK_TEX
		at.region = Rect2(i * 24, 0, 24, 22)
		_brick_frames.append(at)

# ── 初始化 BrickDebris ──────────────────────────────────────────────
func _setup_brick_debris() -> void:
	_bricks.amount        = brick_amount
	_bricks.lifetime      = brick_lifetime
	_bricks.explosiveness = brick_explosiveness
	_bricks.one_shot      = true
	_bricks.local_coords  = false
	_bricks.emitting      = false
	_bricks.texture       = _brick_frames[0]  # 初始給第 0 幀（emit 時會隨機換）

	_brick_mat = ParticleProcessMaterial.new()
	_brick_mat.direction            = Vector3(0.0, -1.0, 0.0)
	_brick_mat.spread               = brick_spread
	_brick_mat.initial_velocity_min = brick_vel_min
	_brick_mat.initial_velocity_max = brick_vel_max
	_brick_mat.angular_velocity_min = brick_ang_min
	_brick_mat.angular_velocity_max = brick_ang_max
	_brick_mat.gravity              = Vector3(0.0, brick_gravity, 0.0)
	_brick_mat.scale_min            = brick_scale_min
	_brick_mat.scale_max            = brick_scale_max
	_bricks.process_material        = _brick_mat

# ── 初始化 DustCloud ────────────────────────────────────────────────
func _setup_dust_cloud() -> void:
	_dust.amount        = dust_amount
	_dust.lifetime      = dust_lifetime
	_dust.explosiveness = dust_explosiveness
	_dust.one_shot      = true
	_dust.local_coords  = false
	_dust.emitting      = false

	_dust_mat = ParticleProcessMaterial.new()
	_dust_mat.direction            = Vector3(0.0, -1.0, 0.0)
	_dust_mat.spread               = dust_spread
	_dust_mat.initial_velocity_min = dust_vel_min
	_dust_mat.initial_velocity_max = dust_vel_max
	_dust_mat.gravity              = Vector3(0.0, dust_gravity, 0.0)
	_dust_mat.scale_min            = dust_scale_min
	_dust_mat.scale_max            = dust_scale_max
	_dust_mat.color                = dust_color
	_dust.process_material         = _dust_mat

# ═══════════════════════════════════════════════════════════════════
# 公開 API
# ═══════════════════════════════════════════════════════════════════

## 磚塊碎片爆發（跳躍/翻滾/蹬牆 觸發）
## terrain_normal : 地形法線（地板=Vector2.UP，牆面=水平法線）
## launch_velocity: 觸發時的 velocity（用於計算反射方向）
## floor_color    : 地板顏色（由 _get_floor_color() 採樣）
func emit_bricks(terrain_normal: Vector2,
				 launch_velocity: Vector2,
				 floor_color: Color) -> void:
	# 計算反射方向：velocity 在地形法線方向上的反射
	var reflect := launch_velocity.bounce(terrain_normal).normalized()
	if reflect.length_squared() < 0.01:
		# fallback：直接沿法線反方向
		reflect = -terrain_normal if terrain_normal.length() > 0.01 else Vector2.DOWN

	_brick_mat.direction = Vector3(reflect.x, reflect.y, 0.0)

	# 隨機選一幀磚塊圖形
	_bricks.texture  = _brick_frames[randi() % _brick_frames.size()]
	# 套用地板顏色
	_bricks.modulate = floor_color
	_bricks.restart()

## 落地灰塵雲（落地且有水平速度時觸發）
## direction: 移動方向（1.0=向右，-1.0=向左）
func emit_dust(direction: float) -> void:
	# 粒子向上且略往反方向（從腳底向後飄起）
	var d := Vector3(-direction * 0.3, -1.0, 0.0).normalized()
	_dust_mat.direction = d
	_dust.restart()
