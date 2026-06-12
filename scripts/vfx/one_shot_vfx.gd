extends Node2D
## OneShotVFX — Self-configuring one-shot VFX script
## Each VFX scene exports its spritesheet parameters so they self-configure at runtime.
## No manual Inspector setup needed: set exports in the scene, play on ready.
##
## Usage: instantiate the scene, set global_position, optionally set flip_h on the sprite.
## The scene will play once and auto-free itself.

## Spritesheet configuration (set in each VFX scene's root node exports)
@export var texture_path: String = ""          ## e.g. "res://assets/vfxmix/fx/slash_01.png"
@export var frame_width: int  = 96             ## pixel width of one frame
@export var frame_height: int = 96             ## pixel height of one frame
@export var frame_count: int  = 16             ## total number of frames
@export var fps: float = 24.0                  ## animation speed
@export var vfx_scale: float = 0.45           ## scale relative to native pixel size

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if _sprite == null:
		push_error("[OneShotVFX] AnimatedSprite2D child not found")
		queue_free()
		return

	## Self-configure the SpriteFrames from exported parameters
	if texture_path != "" and frame_count > 0 and frame_width > 0:
		_build_sprite_frames()

	## Apply scale for proportion-correct sizing
	_sprite.scale = Vector2(vfx_scale, vfx_scale)

	## Connect animation completion and play
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play("default")

func _build_sprite_frames() -> void:
	var tex := load(texture_path) as Texture2D
	if tex == null:
		push_error("[OneShotVFX] Failed to load texture: " + texture_path)
		return

	var frames := SpriteFrames.new()
	frames.clear()
	frames.add_animation("default")
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", fps)

	for i: int in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("default", atlas)

	_sprite.sprite_frames = frames

func _on_animation_finished() -> void:
	queue_free()
