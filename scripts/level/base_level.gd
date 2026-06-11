extends Node2D
## BaseLevel — 所有房間的基礎腳本
## 負責：玩家生成、HUD、鏡頭、Banner、GameOver/Victory 監控

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## 在 Inspector 設定此房間的名稱
@export var room_name: String = "ROOM"
## 此房間是否是 Boss 房間
@export var is_boss_room: bool = false
## 通關後前往的下一個場景路徑
@export var next_room_path: String = ""

var _hud: Node = null
var _banner: Node = null
var _offscreen: Node = null
var _camera: Camera2D = null
var _start_time: float = 0.0

@onready var player_spawns: Node2D = $PlayerSpawns
@onready var cam_root: Node2D = $CameraRoot

func _ready() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	
	_spawn_players()
	_setup_camera()
	_setup_hud()
	_setup_banner()
	_setup_offscreen_indicator()
	_connect_game_signals()
	
	# 顯示房間名稱橫幅
	await get_tree().process_frame
	if _banner and _banner.has_method("show_banner"):
		_banner.show_banner(room_name)
	
	# 監聽 NetworkManager all_players_died
	if NetworkManager.has_signal("all_players_died"):
		NetworkManager.all_players_died.connect(_on_all_players_died)

func _spawn_players() -> void:
	var spawn_positions: Array[Vector2] = []
	
	# 收集所有生成點
	if player_spawns:
		for child in player_spawns.get_children():
			if child is Node2D:
				spawn_positions.append(child.global_position)
	
	if spawn_positions.is_empty():
		spawn_positions.append(Vector2(0, -50))
	
	# 根據連線狀態決定要生成幾個玩家
	var player_count := 1
	if multiplayer.has_multiplayer_peer():
		player_count = NetworkManager.connected_players.size()
	
	for i in range(player_count):
		var player := PLAYER_SCENE.instantiate()
		player.name = "Player%d" % (i + 1)
		player.player_id = i + 1
		
		var spawn_pos := spawn_positions[i % spawn_positions.size()]
		player.global_position = spawn_pos
		
		# 設定皮膚
		add_child(player)
		if player.has_method("set_skin"):
			player.set_skin(i)
		
		# 連接死亡信號
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

func _setup_camera() -> void:
	# 嘗試使用場景中的 MultiplayerCamera
	var existing_cam := get_node_or_null("CameraRoot/MultiplayerCamera")
	if existing_cam:
		_camera = existing_cam
		existing_cam.add_to_group("MainCamera")
		return
	
	# 動態建立
	var cam_script := load("res://scripts/camera/multiplayer_camera.gd")
	var cam := Camera2D.new()
	cam.name = "MultiplayerCamera"
	cam.set_script(cam_script)
	
	# 套用邊界（如果場景有 Marker2D）
	var lim_top := get_node_or_null("CamLimitTop")
	var lim_bottom := get_node_or_null("CamLimitBottom")
	var lim_left := get_node_or_null("CamLimitLeft")
	var lim_right := get_node_or_null("CamLimitRight")
	
	if lim_top:
		cam.set("limit_top_path", cam.get_path_to(lim_top))
	if lim_bottom:
		cam.set("limit_bottom_path", cam.get_path_to(lim_bottom))
	if lim_left:
		cam.set("limit_left_path", cam.get_path_to(lim_left))
	if lim_right:
		cam.set("limit_right_path", cam.get_path_to(lim_right))
	
	add_child(cam)
	cam.add_to_group("MainCamera")
	_camera = cam

func _setup_hud() -> void:
	var hud_scene_path := "res://scenes/ui/hud.tscn"
	if ResourceLoader.exists(hud_scene_path):
		_hud = load(hud_scene_path).instantiate()
	else:
		# 直接使用 script 建立（不依賴 .tscn）
		var hud_script := load("res://scripts/ui/hud.gd")
		_hud = CanvasLayer.new()
		_hud.set_script(hud_script)
	add_child(_hud)

func _setup_banner() -> void:
	var banner_scene_path := "res://scenes/ui/room_banner.tscn"
	if ResourceLoader.exists(banner_scene_path):
		_banner = load(banner_scene_path).instantiate()
	else:
		var banner_script := load("res://scripts/ui/room_banner.gd")
		_banner = CanvasLayer.new()
		_banner.set_script(banner_script)
		
		var panel := PanelContainer.new()
		panel.name = "BannerPanel"
		panel.anchor_left = 0.1
		panel.anchor_right = 0.9
		panel.anchor_top = 0.35
		panel.anchor_bottom = 0.55
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.85)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 1, 1, 0.8)
		panel.add_theme_stylebox_override("panel", style)
		
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		panel.add_child(lbl)
		_banner.add_child(panel)
	add_child(_banner)

func _setup_offscreen_indicator() -> void:
	var osi_script := load("res://scripts/ui/offscreen_indicator.gd")
	_offscreen = CanvasLayer.new()
	_offscreen.set_script(osi_script)
	add_child(_offscreen)

func _connect_game_signals() -> void:
	pass

func _on_player_died(_player_node: Node) -> void:
	## 單機模式下：檢查是否所有玩家都死亡
	if multiplayer.has_multiplayer_peer():
		return  # 連線模式由 NetworkManager 處理
	
	var alive := get_tree().get_nodes_in_group("Players")
	if alive.is_empty():
		_trigger_game_over()

func _on_all_players_died() -> void:
	_trigger_game_over()

func _trigger_game_over() -> void:
	print("[BaseLevel] Game Over!")
	await get_tree().create_timer(1.5).timeout
	var go_path := "res://scenes/ui/game_over.tscn"
	if ResourceLoader.exists(go_path):
		get_tree().change_scene_to_file(go_path)
	else:
		get_tree().reload_current_scene()

func trigger_victory() -> void:
	print("[BaseLevel] Victory!")
	NetworkManager.change_game_state("victory")
	var elapsed := Time.get_ticks_msec() / 1000.0 - _start_time
	await get_tree().create_timer(2.0).timeout
	var v_path := "res://scenes/ui/victory.tscn"
	if ResourceLoader.exists(v_path):
		var victory_scene: Node = load(v_path).instantiate()
		if victory_scene.has_method("set_clear_time"):
			victory_scene.set_clear_time(elapsed)
		get_tree().root.add_child(victory_scene)
		queue_free()
	else:
		get_tree().reload_current_scene()
