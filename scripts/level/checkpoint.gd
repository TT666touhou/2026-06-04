extends Area2D
class_name Checkpoint
## Checkpoint — 存檔/傳送點（Elden Ring 風格的「賜福」）
## 放入任何 Room 場景即可使用。
##
## 功能（現階段）：
##   - 玩家靠近並按 F 鍵激活
##   - 激活後成為 F6 debug spawn 點
##   - 激活狀態為 Session-local（重啟遊戲重置）
##
## Inspector 設定：
##   entry_direction  — F6 無此 Checkpoint 時 Walk-in 進場方向（"right"/"left"/"up"/"down"）
##   checkpoint_id    — 可選 ID（未來存檔系統用）
##
## Group: "Checkpoints"（room_base.gd 用此 group 偵測）

## 玩家激活此 Checkpoint 時發送
signal player_activated(checkpoint: Checkpoint)

# ── Export 屬性（Inspector 設定）──────────────────────────────────────────────
@export_group("Checkpoint Config")
## F6 spawn 無 Checkpoint 時，Walk-in 進場方向（玩家走入的方向）
## "right" = 從左側門走入（面朝右）
## "left"  = 從右側門走入（面朝左）
@export var entry_direction: String = "right"
## 可選識別 ID（未來存檔系統用）
@export var checkpoint_id: String = ""

# ── 子節點 refs ──────────────────────────────────────────────────────────────
## 玩家 F6 spawn 時的生成位置（激活後在此生成）
@onready var _spawn_marker: Marker2D = get_node_or_null("SpawnMarker") as Marker2D
## 激活視覺效果節點（AnimatedSprite2D）
@onready var _vfx: AnimatedSprite2D = get_node_or_null("ActivationVFX") as AnimatedSprite2D
## 互動提示標籤（Label2D）
@onready var _hint: Node = get_node_or_null("InteractHint")

# ── 狀態 ────────────────────────────────────────────────────────────────────
var _activated: bool = false
## 玩家是否在互動範圍內
var _player_in_range: bool = false
## 範圍內的玩家節點（用於 F 鍵提示）
var _player_ref: Node = null

func _ready() -> void:
	add_to_group("Checkpoints")

	## 連接 Area2D 信號
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	## 初始視覺：未激活狀態
	_update_vfx(false)
	_set_hint_visible(false)

	if _spawn_marker == null:
		push_warning("[Checkpoint] 缺少 SpawnMarker 子節點: %s" % name)

	print("[Checkpoint] Ready: %s (entry_direction=%s)" % [name, entry_direction])

func _process(_delta: float) -> void:
	## 玩家在範圍內且未激活 → 偵測 F 鍵
	if _player_in_range and not _activated:
		if Input.is_action_just_pressed("ui_interact"):
			activate()

# ── 公開 API ─────────────────────────────────────────────────────────────────

## 回傳此 Checkpoint 是否已激活
func is_activated() -> bool:
	return _activated

## 激活此 Checkpoint
func activate() -> void:
	if _activated:
		return
	_activated = true
	_update_vfx(true)
	_set_hint_visible(false)
	player_activated.emit(self)
	print("[Checkpoint] Activated: %s" % name)

## 回傳 F6 spawn 時的生成位置
func get_spawn_position() -> Vector2:
	if _spawn_marker != null:
		return _spawn_marker.global_position
	## 回退到自身位置
	return global_position

## 回傳進場方向字串（"right"/"left"/"up"/"down"）
func get_entry_direction() -> String:
	return entry_direction

## 將方向字串轉為 Vector2（供 room_base.gd 呼叫）
func get_entry_vector() -> Vector2:
	match entry_direction:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		"down":  return Vector2.DOWN
	push_warning("[Checkpoint] 未知的 entry_direction: %s，回退為 RIGHT" % entry_direction)
	return Vector2.RIGHT

# ── 私有：Area2D 信號處理 ─────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	_player_in_range = true
	_player_ref = body
	if not _activated:
		_set_hint_visible(true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	_player_in_range = false
	if _player_ref == body:
		_player_ref = null
	_set_hint_visible(false)

# ── 私有：視覺控制 ────────────────────────────────────────────────────────────

func _update_vfx(is_active: bool) -> void:
	if _vfx == null:
		return
	if is_active:
		## 激活態：播放發光動畫（或切換顏色）
		if _vfx.sprite_frames != null and _vfx.sprite_frames.has_animation("activated"):
			_vfx.play("activated")
		else:
			## 無動畫資源：改用 modulate 顏色標示激活
			_vfx.modulate = Color(1.2, 1.0, 0.3, 1.0)  ## 金黃色發光
			_vfx.show()
	else:
		## 未激活態：暗淡待機
		if _vfx.sprite_frames != null and _vfx.sprite_frames.has_animation("idle"):
			_vfx.play("idle")
		else:
			_vfx.modulate = Color(0.4, 0.4, 0.4, 0.8)  ## 灰暗
			_vfx.show()

func _set_hint_visible(visible: bool) -> void:
	if _hint == null:
		return
	if _hint is CanvasItem:
		(_hint as CanvasItem).visible = visible
