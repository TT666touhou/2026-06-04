class_name EnemyStats
extends Resource
## 敵人數值設定資源

@export_group("Stats")
## 最大生命值
@export var max_health: int = 10
## 移動速度
@export var speed: float = 50.0
## 每次攻擊造成的傷害值 [GDD §4.3]
@export var attack_damage: int = 5
