extends Area2D
class_name RoomPortal
## RoomPortal — 房間洞口觸發節點（Hollow Knight 走廊風格）
##
## 架構：
##   玩家走進走廊深處（Area2D觸發區）→ call_deferred → ScreenFader.fade_out
##   → faded_out signal → call_deferred → GameWorld換場
##   → _finish_portal_room_load → 玩家從對應 door_id 的 SpawnMarker 出現
##
## ⚠️ ERR-001/007：body_entered 內部絕對不可直接修改場景樹
## ⚠️ ERR-006：此 .gd 必須在引用它的 .tscn 建立之前存在

## 本洞口的識別 ID（必須與對應房間的 target_door_id 一致）
@export var door_id: String = "right"

## 目標房間的 .tscn 路徑（Inspector 可直接用文件對話框選擇；空字串 = 交由 DungeonGenerator 決定下一間）
@export_file("*.tscn") var target_room_path: String = ""

## 目標房間中對應的 door_id（玩家從那個洞口出現）
@export var target_door_id: String = "left"

## Fade 持續時間
@export var fade_duration: float = 0.4

## 內部狀態
var _players_in_zone: Array[Node2D] = []
var _triggered: bool = false  ## 防重複觸發守衛

func _ready() -> void:
	## 只偵測 Layer 2（Players）
	collision_mask = 2
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[RoomPortal] 初始化完成：door_id=%s → target=%s [%s]" % [
		door_id, target_door_id, target_room_path if not target_room_path.is_empty() else "DungeonGen"
	])

func _on_body_entered(body: Node2D) -> void:
	## 只處理玩家（有 take_damage 方法的節點）
	if not body.has_method("take_damage"):
		return
	if not body in _players_in_zone:
		_players_in_zone.append(body)
		_check_trigger()

func _on_body_exited(body: Node2D) -> void:
	if body in _players_in_zone:
		_players_in_zone.erase(body)

func _check_trigger() -> void:
	if _triggered:
		return
	## 非 Server 端不觸發（多人模式下由 Server 控制）
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	## 取得需要的玩家數（多人時需要全部進入）
	var nm := get_node_or_null("/root/NetworkManager")
	var needed: int = 1
	if nm and nm.get("connected_players") != null:
		needed = (nm.connected_players as Dictionary).size()
	if needed <= 0:
		needed = 1
	## 全部玩家都在洞口才觸發
	if _players_in_zone.size() >= needed:
		_triggered = true
		## ⚠️ ERR-001/007 三層 deferred 架構第一層：
		## 跳出 body_entered callback 的物理 flush 環境
		call_deferred("_do_trigger")

func _do_trigger() -> void:
	## 第二層：已在安全的 deferred 環境
	print("[RoomPortal] 觸發：%s → %s" % [door_id, target_door_id])
	var game_world := get_tree().get_root().get_node_or_null("GameWorld")
	if game_world == null:
		## F6 獨立模式：沒有 GameWorld 屬於預期行為，降為 warning 不阻礙測試
		push_warning("[RoomPortal] F6 standalone mode: GameWorld not found, portal transition disabled.")
		return
	if not game_world.has_method("load_next_room_portal"):
		push_error("[RoomPortal] GameWorld 沒有 load_next_room_portal 方法！")
		return
	game_world.load_next_room_portal(door_id, target_door_id, target_room_path, fade_duration)
