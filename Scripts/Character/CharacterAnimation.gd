class_name CharacterAnimation
extends Node

signal animation_finished(animation_key: String)

enum CharacterState {
	IDLE,
	WALK,
	JUMP,
	RUN,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	HURT,
	KO,
	BLOCK
}

@export var sprite_path: NodePath = ""

var _sprite: AnimatedSprite2D
var _data: CharacterData
var _current_state: CharacterState = CharacterState.IDLE
var _locked_until_finished: bool = false
var _facing_direction: int = 1

var sprite: AnimatedSprite2D:
	get: return _sprite

func _ready() -> void:
	if not sprite_path.is_empty():
		_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	if _sprite == null and get_parent() != null:
		_sprite = get_parent().get_node_or_null("Sprite") as AnimatedSprite2D

	if _sprite != null:
		if not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			_sprite.animation_finished.connect(_on_sprite_animation_finished)

func initialize(data: CharacterData) -> void:
	_data = data
	if _sprite != null and data.frames != null:
		_sprite.stop()
		_sprite.sprite_frames = data.frames
		_sprite.flip_h = _facing_direction < 0
		_locked_until_finished = false
		play_state(CharacterState.IDLE)

func set_facing(direction: int) -> void:
	if direction != 0:
		_facing_direction = 1 if direction > 0 else -1
	if _sprite != null:
		_sprite.flip_h = (_facing_direction < 0)

func set_speed_scale(speed_scale: float) -> void:
	if _sprite != null:
		_sprite.speed_scale = maxf(0.1, speed_scale)

func freeze_animation() -> void:
	if _sprite != null:
		_sprite.pause()

func unfreeze_animation() -> void:
	if _sprite != null:
		_sprite.play()

func try_play_animation_key(key: String, speed_scale: float = 1.0, custom_frames: SpriteFrames = null) -> bool:
	if _sprite == null or _data == null or _sprite.sprite_frames == null:
		return false

	_apply_sprite_frames(custom_frames)

	var raw_name = _data.get_animation_name(key)
	var resolved = _resolve_existing_animation_name(raw_name)

	if resolved.is_empty() and custom_frames != null:
		_apply_sprite_frames(null)
		resolved = _resolve_existing_animation_name(raw_name)

	if resolved.is_empty():
		return false

	_locked_until_finished = true
	_current_state = CharacterState.ATTACK1
	_sprite.speed_scale = maxf(0.1, speed_scale)

	# Ensure non-looping so animation_finished signal fires
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(resolved):
		_sprite.sprite_frames.set_animation_loop_mode(resolved, SpriteFrames.LOOP_NONE)

	_sprite.play(resolved)

	# Safety fallback timer in case signal is missed
	var frame_count = _sprite.sprite_frames.get_frame_count(resolved) if _sprite.sprite_frames.has_animation(resolved) else 4
	var fps = _sprite.sprite_frames.get_animation_speed(resolved) if _sprite.sprite_frames.has_animation(resolved) else 10.0
	var expected_duration = (float(frame_count) / maxf(1.0, fps)) / maxf(0.1, speed_scale) + 0.15

	get_tree().create_timer(expected_duration).timeout.connect(func():
		if _locked_until_finished and _current_state == CharacterState.ATTACK1:
			_on_sprite_animation_finished()
	, CONNECT_ONE_SHOT)

	return true

func play_state(state: CharacterState) -> void:
	if _sprite == null or _data == null or _sprite.sprite_frames == null:
		return

	var can_break_lock = state == CharacterState.KO or state == CharacterState.HURT
	if _locked_until_finished and not can_break_lock:
		return

	if state == _current_state and _is_looping_state(state):
		return

	var is_attack_state = state == CharacterState.ATTACK1 or state == CharacterState.ATTACK2 or state == CharacterState.ATTACK3
	if not is_attack_state:
		_apply_sprite_frames(null)

	_current_state = state
	_locked_until_finished = not _is_looping_state(state)
	if _is_looping_state(state):
		_sprite.speed_scale = 1.0

	var key = _state_to_animation_key(state)
	var raw_name = _data.get_animation_name(key)
	var resolved = _resolve_existing_animation_name(raw_name)
	if not resolved.is_empty():
		if (state == CharacterState.BLOCK or is_attack_state) and _sprite.sprite_frames != null:
			_sprite.sprite_frames.set_animation_loop_mode(resolved, SpriteFrames.LOOP_NONE)
		_sprite.play(resolved)

func _apply_sprite_frames(custom_frames: SpriteFrames) -> void:
	if _sprite == null or _data == null or _data.frames == null:
		return

	var target = custom_frames if custom_frames != null else _data.frames
	if _sprite.sprite_frames != target:
		_sprite.stop()
		_sprite.sprite_frames = target

func _resolve_existing_animation_name(p_name: String) -> String:
	if p_name.strip_edges().is_empty() or _sprite == null or _sprite.sprite_frames == null:
		return ""

	if _sprite.sprite_frames.has_animation(p_name):
		return p_name

	if p_name == "walk":
		for candidate in ["walk_forward", "walking", "walk_backward"]:
			if _sprite.sprite_frames.has_animation(candidate):
				return candidate

	var alt_name = ""
	if "_" in p_name:
		alt_name = p_name.replace("_", "")
	elif p_name.begins_with("attack") and p_name.length() > 6:
		alt_name = p_name.insert(6, "_")
	else:
		alt_name = p_name

	if _sprite.sprite_frames.has_animation(alt_name):
		return alt_name

	return ""

func _on_sprite_animation_finished() -> void:
	_locked_until_finished = false
	if _sprite != null:
		_sprite.speed_scale = 1.0

	if _current_state == CharacterState.BLOCK:
		if _sprite != null and _sprite.sprite_frames != null and not _sprite.animation.is_empty():
			var frame_count = _sprite.sprite_frames.get_frame_count(_sprite.animation)
			if frame_count > 0:
				_sprite.frame = frame_count - 1
			_sprite.pause()
		return

	animation_finished.emit(_state_to_animation_key(_current_state))
	if _current_state != CharacterState.KO:
		play_state(CharacterState.IDLE)

static func _is_looping_state(state: CharacterState) -> bool:
	return state in [CharacterState.IDLE, CharacterState.WALK, CharacterState.JUMP, CharacterState.RUN, CharacterState.BLOCK]

static func _state_to_animation_key(state: CharacterState) -> String:
	match state:
		CharacterState.IDLE: return "idle"
		CharacterState.WALK: return "walk"
		CharacterState.JUMP: return "jump"
		CharacterState.RUN: return "run"
		CharacterState.ATTACK1: return "attack1"
		CharacterState.ATTACK2: return "attack2"
		CharacterState.ATTACK3: return "attack3"
		CharacterState.HURT: return "hurt"
		CharacterState.KO: return "dead"
		CharacterState.BLOCK: return "shield"
		_: return "idle"
