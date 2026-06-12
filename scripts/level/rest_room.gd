extends Node2D
## RestRoom — 休息房間控制器
## 玩家進入回復 1 HP + 提示訊息
## 踩上 RestArea 觸發器後進入下一間房

signal heal_triggered

@onready var _heal_area: Area2D = $HealArea
@onready var _exit_area: Area2D = $ExitArea
@onready var _heal_label: Label = $HealLabel

var _healed: bool = false

func _ready() -> void:
	if _heal_area:
		_heal_area.body_entered.connect(_on_heal_area_entered)
	if _exit_area:
		_exit_area.body_entered.connect(_on_exit_area_entered)
	if _heal_label:
		_heal_label.text = "踏上回復台以回復 1 HP"

func _on_heal_area_entered(body: Node) -> void:
	if _healed:
		return
	if not body.is_in_group("Players"):
		return
	_healed = true
	## 治療所有玩家 1 HP
	var players := get_tree().get_nodes_in_group("Players")
	for player: Node in players:
		if player.has_method("heal"):
			player.heal(1)
		elif player.get("hp") != null:
			player.hp = min(player.hp + 1, player.get("max_hp") if player.get("max_hp") != null else 5)
	heal_triggered.emit()
	if _heal_label:
		_heal_label.text = "✨ HP +1 已回復！繼續前進..."
	print("[RestRoom] 玩家回復 1 HP")

func _on_exit_area_entered(body: Node) -> void:
	if not body.is_in_group("Players"):
		return
	## 呼叫 GameWorld 載入下一間房
	var gw: Node = get_tree().get_root().get_node_or_null("GameWorld")
	if gw and gw.has_method("load_next_room"):
		gw.load_next_room()
