class_name DashTrail
extends Node

@export var sprite_path: NodePath = "../Sprite"
@export var movement_path: NodePath = "../CharacterMovement"

var _sprite: AnimatedSprite2D
var _movement: CharacterMovement
var _spawn_timer: float = 0.0
var _trail_active_remaining: float = 0.0

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_movement = get_node_or_null(movement_path) as CharacterMovement

	if _movement != null:
		_movement.dash_started.connect(func(_dir):
			_spawn_timer = 0.0
			_trail_active_remaining = Constants.Movement.DASH_DURATION_SECONDS + Constants.Movement.DASH_TRAIL_POST_SECONDS
			_spawn_ghost()
		)
		_movement.dash_ended.connect(func():
			_trail_active_remaining = Constants.Movement.DASH_TRAIL_POST_SECONDS
		)

func _process(delta: float) -> void:
	if _sprite == null or _movement == null:
		return

	if _trail_active_remaining > 0.0:
		_trail_active_remaining -= delta

	var spawning = _movement.is_dashing or _trail_active_remaining > 0.0
	if not spawning:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	_spawn_timer = Constants.Movement.DASH_TRAIL_SPAWN_INTERVAL
	_spawn_ghost()

func _spawn_ghost() -> void:
	if _sprite.sprite_frames == null:
		return

	var anim = _sprite.animation
	if not _sprite.sprite_frames.has_animation(anim):
		return

	var texture = _sprite.sprite_frames.get_frame_texture(anim, _sprite.frame)
	if texture == null:
		return

	var ghost = Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = _sprite.flip_h
	ghost.scale = _sprite.scale * 1.06
	ghost.modulate = Color(0.45, 0.92, 1.0, Constants.Movement.DASH_TRAIL_START_ALPHA)
	ghost.z_index = _sprite.z_index - 1

	var spawn_parent = get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else get_tree().current_scene
	spawn_parent.add_child(ghost)
	ghost.global_transform = _sprite.global_transform

	var tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, Constants.Movement.DASH_TRAIL_FADE_SECONDS)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate", Color(0.2, 0.55, 1.0, 0.0), Constants.Movement.DASH_TRAIL_FADE_SECONDS)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", ghost.scale * 0.88, Constants.Movement.DASH_TRAIL_FADE_SECONDS)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(ghost.queue_free)
