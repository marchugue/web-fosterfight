class_name StandaloneSinglePlayerCharacterController
extends CharacterBody2D

signal health_changed(current: float, max_health: float)
signal character_died
signal attack_slot_used(slot: int, cooldown_duration: float)

@export_group("SinglePlayer Character Data")
var _sp_character_data: SinglePlayerCharacterData

@export var sp_character_data: SinglePlayerCharacterData:
	get:
		return _sp_character_data
	set(val):
		_sp_character_data = val
		if is_node_ready() and _sp_character_data != null:
			_apply_sp_character_data(_sp_character_data)

@export_group("Entity Data")
var _entity_data: SinglePlayerEntityData

@export var entity_data: SinglePlayerEntityData:
	get:
		return _entity_data
	set(val):
		_entity_data = val
		if is_node_ready() and _entity_data != null:
			_apply_entity_data(_entity_data)

@export_group("Character Data")
var _character_data: CharacterData

@export var character_data: CharacterData:
	get:
		return _character_data
	set(val):
		_character_data = val
		if is_node_ready() and _character_data != null:
			_apply_character_data(_character_data)

var data: CharacterData:
	get: return _character_data
	set(val): character_data = val

@export_group("Single-Player Stats Override")
@export var mob_max_health: float = 1000.0
@export var attack_damage: float = 1.0
@export var attack_speed: float = 1.5
@export var movement_speed: float = 240.0
@export var jump_force: float = 520.0
@export var is_flying: bool = false
@export var level_scene_mob: PackedScene

@export_group("AI Options")
@export var is_ai_controlled: bool = false
@export var ai_attack_range: float = 80.0
@export var ai_aggression_interval: float = 1.2

@export_group("Targeting Options")
@export var auto_lock_mobs: bool = true
@export var auto_lock_on_attack: bool = true
@export var auto_lock_when_idle: bool = true
@export var auto_lock_range: float = 700.0

@export_group("Input Buffer & Mobility")
@export var input_buffer_time: float = 0.35
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.25
@export var max_jumps: int = 2

var _buffered_slot: int = 0
var _buffered_timer: float = 0.0
var is_dashing: bool = false
var _dash_timer: float = 0.0
var jump_count: int = 0
var _last_right_tap_ms: int = 0
var _last_left_tap_ms: int = 0

var current_health: float = 1000.0
var facing_direction: int = 1
var is_attacking: bool = false

# Skill unlock state — skills 2 and 3 are locked until awarded via chest reward
var skill2_unlocked: bool = false
var skill3_unlocked: bool = false
var is_knocked_out: bool = false

var _ai_timer: float = 0.0
var _current_attack_data: Resource = null
var _base_sprite_frames: SpriteFrames
var _locked_mob: Node2D

var _sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _hitbox: Area2D
var _opponent: Node2D
var _audio_player: AudioStreamPlayer2D
var _combat: SinglePlayerCombat

func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	_hurtbox = get_node_or_null("Hurtbox") as Area2D
	_hitbox = get_node_or_null("Hitbox") as Area2D
	_combat = get_node_or_null("CharacterCombat") as SinglePlayerCombat
	_audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer2D
	if _audio_player == null:
		_audio_player = AudioStreamPlayer2D.new()
		add_child(_audio_player)

	if _sprite != null and _sprite.sprite_frames != null:
		_base_sprite_frames = _sprite.sprite_frames

	add_to_group("players")
	if _hurtbox != null:
		_hurtbox.add_to_group("hurtboxes")

	_initialize_from_available_data()
	_setup_combat_node()
	_play_animation("idle")

func _initialize_from_available_data() -> void:
	if _sp_character_data != null:
		_apply_sp_character_data(_sp_character_data)
		return
	if _entity_data != null:
		_apply_entity_data(_entity_data)
		return
	if _character_data != null:
		_apply_character_data(_character_data)
		return

	const SP_HERO_RES = "res://Resources/SinglePlayer/sp_hero_archer.tres"
	const SP_RES = "res://Resources/Characters/SinglePlayerCharacter.tres"
	if ResourceLoader.exists(SP_HERO_RES):
		initialize_from_sp_character_data(load(SP_HERO_RES) as SinglePlayerCharacterData)
	elif ResourceLoader.exists(SP_RES):
		initialize_from_data(load(SP_RES) as CharacterData)
	else:
		push_warning("SinglePlayerCharacterController: No character data assigned — using export defaults for testing.")
		current_health = mob_max_health
		health_changed.emit(current_health, mob_max_health)

func _setup_combat_node() -> void:
	if _combat == null:
		return
	_combat.enable_standalone_mode(self, _sprite, _hitbox, attack_damage)
	if not _combat.attack_ended.is_connected(_on_combat_attack_ended):
		_combat.attack_ended.connect(_on_combat_attack_ended)
	if not _combat.attack_start_sfx.is_connected(_on_combat_start_sfx):
		_combat.attack_start_sfx.connect(_on_combat_start_sfx)

func initialize_from_sp_character_data(sp_data: SinglePlayerCharacterData) -> void:
	if sp_data == null:
		return
	_sp_character_data = sp_data
	_apply_sp_character_data(sp_data)

func _apply_sp_character_data(sp_data: SinglePlayerCharacterData) -> void:
	if sp_data == null:
		return
	mob_max_health = sp_data.max_health
	current_health = sp_data.max_health
	movement_speed = sp_data.move_speed
	jump_force = sp_data.jump_force
	attack_damage = sp_data.attack_damage_multiplier
	attack_speed = sp_data.attack_speed_multiplier
	if sp_data.sprite_frames != null and _sprite != null:
		_sprite.sprite_frames = sp_data.sprite_frames
		_base_sprite_frames = sp_data.sprite_frames
	health_changed.emit(current_health, mob_max_health)
	_setup_combat_node()

func initialize_from_entity_data(e_data: SinglePlayerEntityData) -> void:
	if e_data == null:
		return
	_entity_data = e_data
	_apply_entity_data(e_data)

func _apply_entity_data(e_data: SinglePlayerEntityData) -> void:
	if e_data == null:
		return
	mob_max_health = e_data.max_health
	current_health = e_data.max_health
	attack_damage = e_data.attack_damage_multiplier
	attack_speed = e_data.attack_speed_multiplier
	movement_speed = e_data.movement_speed
	jump_force = e_data.jump_force
	is_flying = e_data.is_flying
	ai_attack_range = e_data.attack_range
	if e_data.level_scene != null:
		level_scene_mob = e_data.level_scene
	if e_data.sprite_frames != null and _sprite != null:
		_sprite.sprite_frames = e_data.sprite_frames
		_base_sprite_frames = e_data.sprite_frames
	health_changed.emit(current_health, mob_max_health)
	_setup_combat_node()

func initialize_from_data(p_data: CharacterData) -> void:
	if p_data == null:
		return
	_character_data = p_data
	_apply_character_data(p_data)

func _apply_character_data(p_data: CharacterData) -> void:
	if p_data == null:
		return
	if p_data.max_health > 0.0:
		mob_max_health = p_data.max_health
		current_health = mob_max_health
	if p_data.move_speed > 0.0:
		movement_speed = p_data.move_speed
	if p_data.jump_force > 0.0:
		jump_force = p_data.jump_force

	if _sprite != null and p_data.frames != null:
		_sprite.stop()
		_sprite.sprite_frames = p_data.frames
		_base_sprite_frames = p_data.frames

	health_changed.emit(current_health, mob_max_health)
	_setup_combat_node()

func _physics_process(delta: float) -> void:
	if is_knocked_out:
		return

	if _buffered_timer > 0.0:
		_buffered_timer -= delta
		if _buffered_timer <= 0.0:
			_buffered_slot = 0

	if not is_ai_controlled:
		_handle_attack_input()

	if auto_lock_mobs and not is_ai_controlled and not is_dashing:
		_update_mob_lock()

	if is_ai_controlled and _opponent != null:
		_process_ai_behavior(delta)

	if is_flying:
		_process_flying_physics(delta)
	else:
		_process_ground_physics(delta)

func _process_ground_physics(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dash_timer = 0.0
			is_dashing = false

	if is_on_floor():
		jump_count = 0
		velocity.y = 0.0
	else:
		velocity.y += 980.0 * delta

	if not is_attacking and not is_dashing:
		if (InputMap.has_action("dash") and Input.is_action_just_pressed("dash")) or Input.is_key_pressed(KEY_SHIFT) or _check_double_tap():
			_start_dash()

	if is_dashing:
		velocity.x = facing_direction * dash_speed
		velocity.y = 0.0
		_play_locomotion("dash")
		move_and_slide()
		return

	var move_x: float = 0.0
	if not is_attacking:
		if is_ai_controlled and _opponent != null:
			var dist_x = _opponent.global_position.x - global_position.x
			if absf(dist_x) > ai_attack_range:
				move_x = signf(dist_x)
		else:
			if Input.is_action_pressed("move_right"):
				move_x += 1.0
			if Input.is_action_pressed("move_left"):
				move_x -= 1.0

		if Input.is_action_just_pressed("jump") and (is_on_floor() or jump_count < max_jumps):
			velocity.y = -jump_force
			jump_count += 1
			_play_locomotion("jump")

	if move_x != 0.0 and not is_attacking:
		facing_direction = 1 if move_x > 0 else -1
		if _sprite != null:
			_sprite.flip_h = (facing_direction < 0)
		velocity.x = move_x * movement_speed
	else:
		velocity.x = 0.0
		if auto_lock_mobs and auto_lock_when_idle and not is_attacking and not is_ai_controlled:
			_face_locked_mob(false)

	# Locomotion animation selection:
	if not is_attacking:
		if is_on_floor():
			if move_x != 0.0:
				_play_locomotion("walk")
			else:
				_play_locomotion("idle")
		else:
			# Airborne (whether moving horizontally or not): always use jump animation!
			_play_locomotion("jump")

	move_and_slide()

func _check_double_tap() -> bool:
	var now = Time.get_ticks_msec()
	if Input.is_action_just_pressed("move_right"):
		if (now - _last_right_tap_ms) <= 250:
			_last_right_tap_ms = 0
			facing_direction = 1
			return true
		_last_right_tap_ms = now
	if Input.is_action_just_pressed("move_left"):
		if (now - _last_left_tap_ms) <= 250:
			_last_left_tap_ms = 0
			facing_direction = -1
			return true
		_last_left_tap_ms = now
	return false

func _start_dash() -> void:
	is_dashing = true
	_dash_timer = dash_duration
	if _sprite != null:
		_sprite.flip_h = (facing_direction < 0)
	_play_locomotion("dash")

func _has_animation(anim_name: String) -> bool:
	if _sprite != null and _sprite.sprite_frames != null:
		return _sprite.sprite_frames.has_animation(anim_name)
	return false

func _play_locomotion(anim_name: String) -> void:
	if is_attacking and anim_name != "dead":
		return
	if is_dashing and anim_name != "dash" and anim_name != "dead":
		return
	_play_animation(anim_name)

func _process_flying_physics(delta: float) -> void:
	var target_vel = Vector2.ZERO
	if not is_attacking:
		if Input.is_action_pressed("move_right"): target_vel.x += movement_speed
		if Input.is_action_pressed("move_left"): target_vel.x -= movement_speed
		if Input.is_action_pressed("ui_up") or Input.is_action_pressed("jump"): target_vel.y -= movement_speed
		if Input.is_action_pressed("ui_down") or Input.is_action_pressed("crouch"): target_vel.y += movement_speed

	if target_vel.x != 0.0:
		facing_direction = 1 if target_vel.x > 0 else -1
		if _sprite != null:
			_sprite.flip_h = (facing_direction < 0)
	elif auto_lock_mobs and auto_lock_when_idle and not is_attacking:
		_face_locked_mob(false)

	velocity = velocity.move_toward(target_vel, 1800.0 * delta)
	move_and_slide()

	if not is_attacking:
		_play_locomotion("walk" if velocity.length() > 5.0 else "idle")

func _handle_attack_input() -> void:
	var pressed_slot: int = 0
	if Input.is_action_just_pressed("attack1") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		pressed_slot = 1
	elif Input.is_action_just_pressed("attack2"):
		pressed_slot = 2
	elif Input.is_action_just_pressed("attack3"):
		pressed_slot = 3
	elif InputMap.has_action("special") and Input.is_action_just_pressed("special"):
		pressed_slot = 4

	if pressed_slot > 0:
		if is_attacking:
			_buffered_slot = pressed_slot
			_buffered_timer = input_buffer_time
		else:
			execute_attack_slot(pressed_slot)

func execute_attack_slot(slot: int) -> void:
	if is_attacking or is_knocked_out:
		return

	var atk_data = _resolve_attack_data(slot)
	if atk_data == null:
		return

	# Auto-lock & Density Targeting:
	var should_lock = auto_lock_on_attack
	if atk_data is SinglePlayerAttackData:
		var sp_atk = atk_data as SinglePlayerAttackData
		should_lock = sp_atk.auto_lock_on_attack
		if sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.BEAM:
			var density_dir = SinglePlayerAttackHelper.get_denser_enemy_facing(self, get_tree(), auto_lock_range)
			if density_dir != 0:
				facing_direction = density_dir
				SinglePlayerAttackHelper.apply_facing_to_sprite(facing_direction, _sprite)
			should_lock = false
		elif sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.AOE and sp_atk.aoe_prioritize_clusters:
			var cluster_pos = SinglePlayerAttackHelper.find_best_aoe_cluster_target(
				self, get_tree(), sp_atk.aoe_radius, auto_lock_range
			)
			if cluster_pos is Vector2:
				facing_direction = SinglePlayerAttackHelper.get_facing_toward(global_position, cluster_pos)
				SinglePlayerAttackHelper.apply_facing_to_sprite(facing_direction, _sprite)
			should_lock = false

	if auto_lock_mobs and should_lock:
		_update_mob_lock()
		_face_locked_mob(true)

	_current_attack_data = atk_data
	is_attacking = true

	# Notify HUD for cooldown display
	var _cd: float = SinglePlayerAttackHelper.compute_attack_duration(atk_data, attack_speed)
	if atk_data is SinglePlayerAttackData:
		var _sp = atk_data as SinglePlayerAttackData
		if "cooldown" in _sp and _sp.cooldown > 0.0:
			_cd = _sp.cooldown
	attack_slot_used.emit(slot, _cd)

	SinglePlayerAttackHelper.play_attack_sfx(atk_data, _audio_player)

	var resolved_anim = _play_attack_animation(slot, atk_data)

	if _combat != null and SinglePlayerAttackHelper.supports_combat_runtime(atk_data):
		_combat._standalone_damage_multiplier = attack_damage
		_combat.set_lock_target(_locked_mob)
		_combat.start_standalone_attack(atk_data, facing_direction, resolved_anim)
		if _sprite != null and not resolved_anim.is_empty():
			var spd = SinglePlayerAttackHelper.get_attack_speed(atk_data, attack_speed)
			_sprite.play(resolved_anim, spd)
		return

	var duration = SinglePlayerAttackHelper.compute_attack_duration(atk_data, attack_speed)
	_spawn_swing_vfx(atk_data)

	get_tree().create_timer(duration).timeout.connect(func():
		_finish_attack(atk_data)
	, CONNECT_ONE_SHOT)

func _resolve_attack_data(slot: int) -> Resource:
	# Skill 2 and 3 are locked until unlocked via chest reward
	if slot == 2 and not skill2_unlocked:
		return null
	if slot == 3 and not skill3_unlocked:
		return null

	if sp_character_data != null:
		var sp_atk = sp_character_data.get_attack_slot(slot)
		if sp_atk != null:
			return sp_atk
	if entity_data != null:
		var entity_atk = entity_data.get_attack_data(slot)
		if entity_atk != null:
			return entity_atk
	if _character_data != null:
		var char_atk = _character_data.get_attack_data(slot)
		if char_atk != null:
			return char_atk
	return null

func apply_booster(card_id: String, value: float) -> void:
	match card_id:
		"atk_dmg", "atk_dmg_big":
			attack_damage += value
		"atk_spd":
			attack_speed += value
			if _combat != null:
				_combat._standalone_damage_multiplier = attack_damage
		"health":
			mob_max_health += value
			current_health = minf(current_health + value, mob_max_health)
			health_changed.emit(current_health, mob_max_health)
		"skill2":
			skill2_unlocked = true
		"skill3":
			skill3_unlocked = true

func _get_closest_mob_distance() -> float:
	var closest: float = 999999.0
	var mobs = get_tree().get_nodes_in_group("mobs")
	for m in mobs:
		if is_instance_valid(m) and m is Node2D:
			if m.has_method("is_dead") and m.is_dead():
				continue
			var d = global_position.distance_to(m.global_position)
			if d < closest:
				closest = d
	return closest

func _play_attack_animation(slot: int, atk_data: Resource) -> String:
	if _sprite == null:
		return ""

	var frames = SinglePlayerAttackHelper.get_character_sprite_frames(atk_data)
	if frames != null:
		_sprite.stop()
		_sprite.sprite_frames = frames

	var target_anim = SinglePlayerAttackHelper.get_animation_name(atk_data, slot, _character_data)

	# Dynamic melee switch for Skill 1: Use close_attack animation when mob is in close range (<= 120px)
	if slot == 1 and _sprite.sprite_frames != null:
		if _sprite.sprite_frames.has_animation("close_attack"):
			var dist = _get_closest_mob_distance()
			if dist <= 120.0:
				target_anim = "close_attack"

	var resolved = SinglePlayerAttackHelper.resolve_animation_on_sprite(_sprite, target_anim, _character_data)

	var spd = SinglePlayerAttackHelper.get_attack_speed(atk_data, attack_speed)
	if not resolved.is_empty():
		_sprite.play(resolved, spd)
		return resolved

	return target_anim

func _play_animation(anim_name: String) -> void:
	if is_attacking and anim_name != "dead":
		return
	if _sprite == null or _sprite.sprite_frames == null:
		return

	var resolved = SinglePlayerAttackHelper.get_locomotion_animation(_sprite, anim_name, _character_data)
	if resolved.is_empty():
		return
	_sprite.play(resolved, 1.0)

func _finish_attack(_atk_data: Resource) -> void:
	is_attacking = false
	_current_attack_data = null
	_restore_base_sprite_frames()

	if _check_buffered_attack():
		return

	_play_animation("idle")

func _on_combat_attack_ended() -> void:
	is_attacking = false
	_current_attack_data = null
	_restore_base_sprite_frames()

	if _check_buffered_attack():
		return

	_play_animation("idle")

func _check_buffered_attack() -> bool:
	if _buffered_slot > 0 and _buffered_timer > 0.0:
		var slot = _buffered_slot
		_buffered_slot = 0
		_buffered_timer = 0.0
		call_deferred("execute_attack_slot", slot)
		return true
	return false

func _on_combat_start_sfx(sfx: AudioStream) -> void:
	if _audio_player != null and sfx != null:
		_audio_player.stream = sfx
		_audio_player.play()

func _restore_base_sprite_frames() -> void:
	if _sprite == null:
		return
	_sprite.speed_scale = 1.0
	var restore_frames = _base_sprite_frames
	if restore_frames == null and sp_character_data != null:
		restore_frames = sp_character_data.sprite_frames
	if restore_frames == null and _character_data != null:
		restore_frames = _character_data.frames
	if restore_frames != null and _sprite.sprite_frames != restore_frames:
		_sprite.sprite_frames = restore_frames

func _spawn_swing_vfx(atk_data: Resource) -> void:
	var cfg = SinglePlayerAttackHelper.get_swing_vfx(atk_data)
	if cfg == null:
		return
	var marker_name = ""
	if atk_data is SinglePlayerAttackData:
		marker_name = atk_data.get_spawn_marker_name()
	var base_pos = SinglePlayerAttackHelper.resolve_spawn_position(self, marker_name, cfg)
	var inst = SinglePlayerAttackHelper.spawn_vfx_from_config(get_tree(), cfg, base_pos, facing_direction)
	if inst != null and cfg.attach_to_caster:
		if inst.get_parent() != self:
			inst.reparent(self)

func take_damage(amount: float) -> void:
	if is_knocked_out or amount <= 0.0 or is_dashing:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, mob_max_health)

	if current_health <= 0.0:
		is_knocked_out = true
		_play_animation("dead")
		character_died.emit()
	else:
		if not _is_uninterruptable_attack():
			_play_animation("hurt")

func _is_uninterruptable_attack() -> bool:
	if is_attacking:
		return true
	if _current_attack_data != null and _current_attack_data is SinglePlayerAttackData:
		var sp = _current_attack_data as SinglePlayerAttackData
		return sp.is_uninterruptable
	return false

func get_locked_mob() -> Node2D:
	return _locked_mob

func _update_mob_lock() -> void:
	_locked_mob = SinglePlayerAttackHelper.find_nearest_mob(self, get_tree(), auto_lock_range)

func _face_locked_mob(force: bool) -> void:
	if _locked_mob == null or not is_instance_valid(_locked_mob):
		return
	if "is_knocked_out" in _locked_mob and _locked_mob.is_knocked_out:
		_locked_mob = null
		return

	var new_facing = SinglePlayerAttackHelper.get_facing_toward(global_position, _locked_mob.global_position)
	if force or new_facing != facing_direction:
		facing_direction = new_facing
		SinglePlayerAttackHelper.apply_facing_to_sprite(facing_direction, _sprite)

func _process_ai_behavior(delta: float) -> void:
	_ai_timer += delta
	if _opponent == null:
		return

	var dist = global_position.distance_to(_opponent.global_position)
	if dist <= ai_attack_range and _ai_timer >= ai_aggression_interval:
		_ai_timer = 0.0
		execute_attack_slot(1)
