class_name AnimatedButtonComponent
extends Button

@export var animation_player_path: NodePath = "AnimationPlayer"
@export var sfx_hover: AudioStream
@export var sfx_press: AudioStream

var _player: AnimationPlayer

func _ready() -> void:
	focus_mode = FOCUS_ALL
	if not animation_player_path.is_empty():
		_player = get_node_or_null(animation_player_path) as AnimationPlayer

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(func(): _play_if_exists("unhover", "RESET"))
	button_down.connect(_on_button_down)
	pressed.connect(func(): _play_if_exists("activate"))

func _on_mouse_entered() -> void:
	_play_if_exists("hover")
	if sfx_hover != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(sfx_hover)

func _on_button_down() -> void:
	_play_if_exists("pressed")
	if sfx_press != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(sfx_press)

func _play_if_exists(anim_name: String, fallback: String = "") -> void:
	if _player == null:
		return

	if _player.has_animation(anim_name):
		_player.play(anim_name)
	elif not fallback.is_empty() and _player.has_animation(fallback):
		_player.play(fallback)
