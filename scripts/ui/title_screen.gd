extends Control

@onready var host_btn: Button = $HostButton
@onready var join_btn: Button = $JoinButton
@onready var solo_btn: Button = $SoloButton
@onready var ip_input: LineEdit = $IPInput

const GAME_WORLD_SCENE := "res://scenes/level/game_world.tscn"

func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	solo_btn.pressed.connect(_on_solo_pressed)

	call_deferred("_setup_button_tween", host_btn)
	call_deferred("_setup_button_tween", join_btn)
	call_deferred("_setup_button_tween", solo_btn)

	## 監聽 NetworkManager 的 player_connected 信號
	## HOST 成功後切換到遊戲場景
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_connected.connect(_on_network_player_connected)

func _setup_button_tween(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func(): _animate_button(btn, Vector2(1.1, 1.1)))
	btn.mouse_exited.connect(func(): _animate_button(btn, Vector2(1.0, 1.0)))

func _animate_button(btn: Button, target_scale: Vector2) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target_scale, 0.4)

## ── 按鈕處理 ──────────────────────────────────────────────────
func _on_solo_pressed() -> void:
	## 單機模式：直接切換到遊戲場景（game_world 會自動偵測無網路參數並執行 _start_solo）
	print("[TitleScreen] 單機模式開始")
	get_tree().change_scene_to_file(GAME_WORLD_SCENE)

func _on_host_pressed() -> void:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.host_game()
		if err == OK:
			print("[TitleScreen] HOST 成功，切換到遊戲場景")
			get_tree().change_scene_to_file(GAME_WORLD_SCENE)
		else:
			push_error("[TitleScreen] HOST 失敗：%d" % err)

func _on_join_pressed() -> void:
	var ip := ip_input.text
	if not is_valid_ip(ip):
		push_warning("[TitleScreen] 無效 IP 地址")
		return
	if ip.is_empty():
		ip = "127.0.0.1"
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.join_game(ip)
		if err == OK:
			print("[TitleScreen] JOIN 中，等待連線...")
			## Client 等待 connected_to_server 信號後切換場景
			multiplayer.connected_to_server.connect(_on_client_connected, CONNECT_ONE_SHOT)
		else:
			push_error("[TitleScreen] JOIN 失敗：%d" % err)

func _on_client_connected() -> void:
	print("[TitleScreen] Client 連線成功，切換到遊戲場景")
	get_tree().change_scene_to_file(GAME_WORLD_SCENE)

func _on_network_player_connected(_peer_id: int, _info: Dictionary) -> void:
	## 已在 _on_host_pressed 中直接切換，此處備用
	pass

func is_valid_ip(ip: String) -> bool:
	if ip.is_empty():
		return true
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	for p: String in parts:
		if not p.is_valid_int():
			return false
		var v := p.to_int()
		if v < 0 or v > 255:
			return false
	return true
