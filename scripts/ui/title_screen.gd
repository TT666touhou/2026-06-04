extends Control

@onready var host_btn = $HostButton
@onready var join_btn = $JoinButton
@onready var ip_input = $IPInput

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	# Wait one frame so size is calculated if inside a container
	call_deferred("_setup_button_tween", host_btn)
	call_deferred("_setup_button_tween", join_btn)

func _setup_button_tween(btn: Button):
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func(): _animate_button(btn, Vector2(1.1, 1.1)))
	btn.mouse_exited.connect(func(): _animate_button(btn, Vector2(1.0, 1.0)))

func _animate_button(btn: Button, target_scale: Vector2):
	var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target_scale, 0.4)

func _on_host_pressed():
	NetworkManager.host_game()

func _on_join_pressed():
	var ip = ip_input.text
	if not is_valid_ip(ip):
		return # Optionally show error
	if ip.is_empty(): ip = "127.0.0.1"
	NetworkManager.join_game(ip)

func is_valid_ip(ip: String) -> bool:
	if ip.is_empty(): return true
	var parts = ip.split(".")
	if parts.size() != 4: return false
	for p in parts:
		if not p.is_valid_int(): return false
		var v = p.to_int()
		if v < 0 or v > 255: return false
	return true
