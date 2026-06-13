extends Area2D
## 玩家子彈（遠程攻擊）
## 通過 setup() 設定方向、速度、傷害，並指定要忽略的群組（不打自己人）

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: int = 1
var _ignore_group: String = "Players"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 2 秒後自動清除（防止記憶體洩漏）
	get_tree().create_timer(2.0).timeout.connect(queue_free)

## 初始化子彈（由 player.gd 的 _fire_bullet() 呼叫）
func setup(dir: Vector2, spd: float, dmg: int, ignore_group: String = "Players") -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	_ignore_group = ignore_group

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	## 朝移動方向旋轉（視覺效果）
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	## 忽略自己群組（不打自己人）
	if _ignore_group != "" and body.is_in_group(_ignore_group):
		return
	## 打中有 take_damage 方法的實體（敵人）
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("[PlayerBullet] 命中：", body.name, " 傷害：", damage)
		queue_free()
		return
	## 打中靜態碰撞（地形牆壁）→ 消除
	if body is StaticBody2D or body is TileMapLayer:
		queue_free()
