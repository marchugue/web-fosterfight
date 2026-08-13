class_name CharacterCombat
extends Node

signal attack_started(animation_key: String)
signal attack_hit(target_hurtbox: Node2D, damage: float, knockback: float, hit_stun: float, energy_gained: float, direction: int, attack_input: int)
signal attack_ended
signal attack_swing(sfx: AudioStream)
signal attack_start_sfx(sfx: AudioStream)
signal projectile_spawn_requested

enum AttackInput {
	ATTACK1,
	ATTACK2,
	ATTACK3,
	COMMAND
}

@export_group("Attack Data")
@export var attack1_data: AttackData
@export var attack2_data: AttackData
@export var attack3_data: AttackData
@export var damage_multiplier: float = 1.0

class HitboxTransformData extends RefCounted:
	var area_position: Vector2 = Vector2.ZERO
	var area_scale: Vector2 = Vector2.ONE
	var shape_position: Vector2 = Vector2.ZERO
	var shape_scale: Vector2 = Vector2.ONE
	var is_valid: bool = false

var _hitbox: Area2D
var _hitbox_shape: CollisionShape2D
var _base_hitbox_transform: HitboxTransformData = HitboxTransformData.new()
var _sprite: AnimatedSprite2D

var is_attacking: bool = false
var is_hitbox_active: bool = false
var has_connected: bool = false

var current_attack_data: AttackData:
	get: return _current_attack_data

var current_input: AttackInput:
	get: return _current_input

var current_command_move: ComboMoveData:
	get: return _current_command_move

var _owner_data: CharacterData
var _character_id: String = ""
var _current_input: AttackInput = AttackInput.ATTACK1
var _current_attack_data: AttackData
var _current_command_move: ComboMoveData
var _facing: int = 1
var _swing_sfx_fired: bool = false
var _hit_targets_this_swing: Array[int] = []

var _cooldown1: float = 0.0
var _cooldown2: float = 0.0
var _cooldown3: float = 0.0

var _light_attack_step: int = 1

func _ready() -> void:
	set_hitbox_active(false)

func set_hitbox(hitbox: Area2D) -> void:
	_hitbox = hitbox
	_hitbox_shape = _hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _hitbox_shape == null and _hitbox.get_child_count() > 0:
		_hitbox_shape = _hitbox.get_child(0) as CollisionShape2D

	_base_hitbox_transform = HitboxTransformData.new()
	_base_hitbox_transform.area_position = _hitbox.position
	_base_hitbox_transform.area_scale = _hitbox.scale
	_base_hitbox_transform.shape_position = _hitbox_shape.position if _hitbox_shape != null else Vector2.ZERO
	_base_hitbox_transform.shape_scale = _hitbox_shape.scale if _hitbox_shape != null else Vector2.ONE
	_base_hitbox_transform.is_valid = true

	apply_hitbox_transform(_current_attack_data)
	set_hitbox_active(false)

func set_sprite(sprite_node: AnimatedSprite2D) -> void:
	if _sprite != null:
		_sprite.frame_changed.disconnect(_on_sprite_frame_changed)
		_sprite.animation_finished.disconnect(_on_animation_finished)
	_sprite = sprite_node
	if _sprite != null:
		_sprite.frame_changed.connect(_on_sprite_frame_changed)
		_sprite.animation_finished.connect(_on_animation_finished)

func initialize(data: CharacterData) -> void:
	_owner_data = data
	_character_id = data.id if data.id != null else ""
	if data.attack1_data != null: attack1_data = data.attack1_data
	if data.attack2_data != null: attack2_data = data.attack2_data
	if data.attack3_data != null: attack3_data = data.attack3_data

	if attack1_data == null and attack2_data == null and attack3_data == null:
		push_warning("CharacterCombat: Character '%s' has no attack data yet" % data.display_name)

func set_facing(facing: int) -> void:
	if facing == _facing and _hitbox != null:
		return
	_facing = facing
	apply_hitbox_transform(_current_attack_data)

func get_cooldown_remaining(input: AttackInput) -> float:
	match input:
		AttackInput.ATTACK1: return _cooldown1
		AttackInput.ATTACK2: return _cooldown2
		AttackInput.ATTACK3: return _cooldown3
		_: return 0.0

func is_on_cooldown(input: AttackInput) -> bool:
	return get_cooldown_remaining(input) > 0.0

func try_start_attack(input: AttackInput, energy: CharacterEnergy) -> bool:
	if is_attacking or _owner_data == null:
		return false

	if is_on_cooldown(input):
		return false

	var atk_data = _resolve_attack_data(input)
	if atk_data == null:
		push_warning("CharacterCombat: Cannot perform attack %s: no attack data yet" % input)
		return false

	if not _character_id.is_empty() and not atk_data.is_valid_for_character(_character_id):
		push_warning("CharacterCombat: Attack '%s' is restricted to character '%s'." % [atk_data.attack_name, atk_data.character_id])
		return false

	if atk_data.energy_cost > 0.0 and not energy.try_spend(atk_data.energy_cost):
		return false

	_begin_attack(input, atk_data)
	return true

func try_start_command_move(move: ComboMoveData, energy: CharacterEnergy) -> bool:
	if is_attacking or _owner_data == null or move.attack_stats == null:
		return false

	if not _character_id.is_empty() and not move.attack_stats.is_valid_for_character(_character_id):
		push_warning("CharacterCombat: Command move '%s' is restricted." % move.move_name)
		return false

	var energy_cost = move.energy_cost if move.energy_cost > 0.0 else move.attack_stats.energy_cost
	if energy_cost > 0.0 and not energy.try_spend(energy_cost):
		return false

	_current_command_move = move
	_begin_attack(AttackInput.COMMAND, move.attack_stats, move.animation_key)
	return true

func try_cancel_into(input: AttackInput, energy: CharacterEnergy, cancel_mgr: CancelManager) -> bool:
	if not is_attacking or _current_attack_data == null or _owner_data == null:
		return false

	if not cancel_mgr.can_cancel(_current_attack_data, is_hitbox_active, has_connected, input):
		return false

	if is_on_cooldown(input):
		return false

	var new_atk_data = _resolve_attack_data(input, true)
	if new_atk_data == null:
		push_warning("CharacterCombat: Cannot cancel into %s: no attack data yet" % input)
		return false

	if not _character_id.is_empty() and not new_atk_data.is_valid_for_character(_character_id):
		return false

	if new_atk_data.energy_cost > 0.0 and not energy.try_spend(new_atk_data.energy_cost):
		return false

	set_hitbox_active(false)
	_begin_attack(input, new_atk_data)
	return true

func _begin_attack(input: AttackInput, atk_data: AttackData, animation_key: String = "") -> void:
	if input != AttackInput.COMMAND:
		_current_command_move = null

	if input == AttackInput.ATTACK1:
		if is_attacking and _current_input == AttackInput.ATTACK1:
			_light_attack_step = mini(_light_attack_step + 1, 3)
		else:
			_light_attack_step = 1
	else:
		_light_attack_step = 1

	_current_input = input
	_current_attack_data = atk_data
	is_attacking = true
	is_hitbox_active = false
	has_connected = false
	_swing_sfx_fired = false
	_hit_targets_this_swing.clear()

	apply_hitbox_transform(atk_data)
	set_hitbox_active(false)

	var anim_key = animation_key
	if anim_key.is_empty():
		if not atk_data.sprite_animation_name.is_empty() and atk_data.sprite_animation_name != "Default (Auto)":
			anim_key = atk_data.sprite_animation_name
		else:
			anim_key = _animation_key_for(input, _light_attack_step)

	attack_started.emit(anim_key)
	if atk_data.sfx_on_start != null:
		attack_start_sfx.emit(atk_data.sfx_on_start)

	# Safety fallback timer to prevent character freeze if animation signal is missed
	var safe_timeout = (float(atk_data.hitbox_duration + 5) / 10.0) / maxf(0.1, atk_data.attack_speed) + 0.35
	get_tree().create_timer(safe_timeout).timeout.connect(func():
		if is_attacking:
			_on_animation_finished()
	, CONNECT_ONE_SHOT)

func _on_sprite_frame_changed() -> void:
	if not is_attacking or _current_attack_data == null or _sprite == null:
		return

	var frame = _sprite.frame
	var should_be_active = _current_attack_data.is_hitbox_active_on_frame(frame)

	_process_special_attack_frame(frame)

	if should_be_active and not is_hitbox_active:
		if not _swing_sfx_fired:
			_swing_sfx_fired = true
			if _current_command_move != null and _current_command_move.projectile_scene != null:
				projectile_spawn_requested.emit()
			else:
				attack_swing.emit(_current_attack_data.sfx_on_swing)

	set_hitbox_active(should_be_active)

func _process_special_attack_frame(_frame: int) -> void:
	# Base 2-Player arcade combat does not execute single-player mob/special frame logic.
	# SinglePlayerCombat extends this class to process Bow, Spell, and Laser attacks.
	pass

func _on_animation_finished() -> void:
	if not is_attacking or _current_attack_data == null:
		return

	set_hitbox_active(false)
	_set_cooldown(_current_input, _current_attack_data.cooldown)

	_light_attack_step = 1
	is_attacking = false
	is_hitbox_active = false
	_current_attack_data = null
	_current_command_move = null
	apply_hitbox_transform(null)
	attack_ended.emit()

func _physics_process(delta: float) -> void:
	if _cooldown1 > 0.0: _cooldown1 = maxf(0.0, _cooldown1 - delta)
	if _cooldown2 > 0.0: _cooldown2 = maxf(0.0, _cooldown2 - delta)
	if _cooldown3 > 0.0: _cooldown3 = maxf(0.0, _cooldown3 - delta)

func _set_cooldown(input: AttackInput, duration: float) -> void:
	match input:
		AttackInput.ATTACK1: _cooldown1 = duration
		AttackInput.ATTACK2: _cooldown2 = duration
		AttackInput.ATTACK3: _cooldown3 = duration

func check_hit(opponent_hurtbox: Area2D) -> void:
	if not is_attacking or not is_hitbox_active or _hitbox == null or _current_attack_data == null or _owner_data == null:
		return

	var target_id = opponent_hurtbox.get_instance_id()
	if target_id in _hit_targets_this_swing:
		return

	if not _hitbox.overlaps_area(opponent_hurtbox):
		return

	_hit_targets_this_swing.append(target_id)
	has_connected = true

	attack_hit.emit(
		opponent_hurtbox,
		_current_attack_data.damage * damage_multiplier,
		_current_attack_data.knockback,
		_current_attack_data.hitstun,
		_current_attack_data.energy_gained_on_hit,
		_facing,
		int(_current_input)
	)

func _resolve_attack_data(input: AttackInput, is_cancel: bool = false) -> AttackData:
	var base_data: AttackData = null
	match input:
		AttackInput.ATTACK1: base_data = attack1_data
		AttackInput.ATTACK2: base_data = attack2_data
		AttackInput.ATTACK3: base_data = attack3_data

	if base_data == null:
		return null

	if input == AttackInput.ATTACK1 and base_data.string_steps.size() > 0:
		var target_step = mini(_light_attack_step + 1, 3) if (is_cancel and _current_input == AttackInput.ATTACK1) else (1 if is_cancel else _light_attack_step)
		var step_idx = clampi(target_step - 1, 0, base_data.string_steps.size() - 1)
		var step_data = base_data.string_steps[step_idx]
		if step_data != null:
			return step_data

	return base_data

static func _animation_key_for(input: AttackInput, light_step: int = 1) -> String:
	match input:
		AttackInput.ATTACK1: return "attack1_%d" % light_step
		AttackInput.ATTACK2: return "attack2"
		AttackInput.ATTACK3: return "attack3"
		AttackInput.COMMAND: return "attack1"
		_: return "idle"

func set_hitbox_active(active: bool) -> void:
	is_hitbox_active = active
	if _hitbox != null:
		_hitbox.monitoring = active

func apply_hitbox_transform(atk_data: AttackData = null) -> void:
	if _hitbox == null or not _base_hitbox_transform.is_valid:
		return

	var offset = atk_data.hitbox_offset if atk_data != null else Vector2.ZERO
	var scale_mult = atk_data.hitbox_scale_multiplier if atk_data != null else Vector2.ONE
	var facing_mult = float(_facing)

	var base_area_pos = _base_hitbox_transform.area_position
	_hitbox.position = Vector2((base_area_pos.x + offset.x) * facing_mult, base_area_pos.y + offset.y)
	_hitbox.scale = _base_hitbox_transform.area_scale * scale_mult

	if _hitbox_shape != null:
		var base_shape_pos = _base_hitbox_transform.shape_position
		_hitbox_shape.position = Vector2(base_shape_pos.x * facing_mult, base_shape_pos.y)
		_hitbox_shape.scale = _base_hitbox_transform.shape_scale

func mark_connected() -> void:
	has_connected = true

func cancel_attack() -> void:
	is_attacking = false
	is_hitbox_active = false
	_current_attack_data = null
	_current_command_move = null
	has_connected = false
	_light_attack_step = 1
	_swing_sfx_fired = false
	apply_hitbox_transform(null)
	set_hitbox_active(false)

func reset_cooldowns() -> void:
	_cooldown1 = 0.0
	_cooldown2 = 0.0
	_cooldown3 = 0.0
