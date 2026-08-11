class_name CharacterController
extends CharacterBody2D

signal round_loss(loser: CharacterController)

@export var data: CharacterData
@export var is_player_two: bool = false

@export var movement_path: NodePath = "CharacterMovement"
@export var combat_path: NodePath = "CharacterCombat"
@export var animation_path: NodePath = "CharacterAnimation"
@export var health_path: NodePath = "CharacterHealth"
@export var energy_path: NodePath = "CharacterEnergy"
@export var combo_path: NodePath = "CharacterCombo"
@export var command_combo_path: NodePath = "CommandComboSystem"
@export var cancel_manager_path: NodePath = "CancelManager"
@export var hurtbox_path: NodePath = "Hurtbox"
@export var player_indicator_path: NodePath = "PlayerIndicator"
@export var player1_indicator_texture: Texture2D
@export var player2_indicator_texture: Texture2D

var movement: CharacterMovement
var combat: CharacterCombat
var anim: CharacterAnimation
var health: CharacterHealth
var energy: CharacterEnergy
var combo: CharacterCombo
var command_combos: CommandComboSystem
var cancel_mgr: CancelManager
var hurtbox: Area2D
var player_indicator: TextureRect

var input_locked: bool = false
var is_blocking: bool = false

var is_invulnerable: bool:
	get: return _standup_remaining > 0.0

var hit_stun_frames_remaining: int:
	get: return _hit_stun_frames

var _opponent: CharacterController
var _hit_stun_frames: int = 0
var _standup_remaining: float = 0.0
var _knocked_down: bool = false
var _airborne_knockdown: bool = false
var _knockdown_meter: float = 0.0
var _knockdown_meter_window_remaining: float = 0.0
var _match_over: bool = false
var _is_stunned: bool = false
var _body_shape: CollisionShape2D

var _combo_gravity_scale: float = 1.0
var _dash_phasing_active: bool = false

var _buffered_attack_input = null
var _buffered_attack_frames: int = 0

func _ready() -> void:
	_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	movement = get_node(movement_path) as CharacterMovement
	combat = get_node(combat_path) as CharacterCombat
	anim = get_node(animation_path) as CharacterAnimation
	health = get_node(health_path) as CharacterHealth
	energy = get_node(energy_path) as CharacterEnergy
	combo = get_node(combo_path) as CharacterCombo
	command_combos = get_node(command_combo_path) as CommandComboSystem
	cancel_mgr = get_node_or_null(cancel_manager_path) as CancelManager
	if cancel_mgr == null:
		cancel_mgr = CancelManager.new()
		add_child(cancel_mgr)

	hurtbox = get_node_or_null(hurtbox_path) as Area2D
	player_indicator = get_node_or_null(player_indicator_path) as TextureRect

	if player_indicator != null:
		player_indicator.texture = player2_indicator_texture if is_player_two else player1_indicator_texture

	if data != null:
		initialize_from_data(data)

	combat.attack_hit.connect(_on_own_attack_hit)
	combat.attack_started.connect(_on_own_attack_started)
	combat.attack_swing.connect(_on_own_attack_swing)
	combat.attack_start_sfx.connect(_on_own_attack_swing)
	combat.projectile_spawn_requested.connect(_on_projectile_spawn_requested)
	health.knocked_out.connect(_on_knocked_out)
	movement.facing_changed.connect(func(dir): anim.set_facing(dir))
	movement.dash_ended.connect(func(): anim.set_facing(movement.facing_direction))

	var hitbox = get_node_or_null("Hitbox") as Area2D
	if hitbox != null:
		combat.set_hitbox(hitbox)

	var sprite_node = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite_node != null:
		combat.set_sprite(sprite_node)

func initialize_from_data(p_data: CharacterData) -> void:
	data = p_data
	if movement != null: movement.initialize(data)
	if combat != null: combat.initialize(data)
	if anim != null: anim.initialize(data)
	if health != null: health.initialize(data.max_health)
	if energy != null: energy.initialize(Constants.Combat.MAX_ENERGY)
	if command_combos != null: command_combos.load_for_character(data)
	if player_indicator != null:
		player_indicator.texture = player2_indicator_texture if is_player_two else player1_indicator_texture
	if is_player_two and movement != null:
		movement.set_facing(-1)

func set_opponent(opponent: CharacterController) -> void:
	_opponent = opponent
	_update_facing_toward_opponent()

func reset_for_new_round() -> void:
	_update_facing_toward_opponent()
	health.reset_for_new_round()
	energy.reset_for_new_round()
	combo.reset_for_new_round()
	command_combos.reset_for_new_round()
	movement.reset_for_new_round()
	if cancel_mgr != null: cancel_mgr.reset_for_new_round()
	combat.cancel_attack()
	combat.reset_cooldowns()
	_hit_stun_frames = 0
	_standup_remaining = 0.0
	_knocked_down = false
	_airborne_knockdown = false
	_knockdown_meter = 0.0
	_knockdown_meter_window_remaining = 0.0
	_combo_gravity_scale = 1.0
	_match_over = false
	if _is_stunned:
		_is_stunned = false
		anim.unfreeze_animation()

	if _dash_phasing_active:
		_dash_phasing_active = false
		collision_layer = Constants.Physics.PLAYER_LAYER
		collision_mask = Constants.Physics.PLAYER_COLLISION_MASK
		if _body_shape != null: _body_shape.disabled = false
		if _opponent != null: remove_collision_exception_with(_opponent)

	if hurtbox != null: hurtbox.monitorable = true
	anim.play_state(CharacterAnimation.CharacterState.IDLE)

func play_intro_pose() -> void:
	anim.play_state(CharacterAnimation.CharacterState.ATTACK1)

func play_intro_idle() -> void:
	anim.play_state(CharacterAnimation.CharacterState.IDLE)

func _physics_process(delta: float) -> void:
	if _match_over:
		return

	_tick_hit_reaction_timers(delta)

	var in_hitstun = _hit_stun_frames > 0
	var locked = input_locked or in_hitstun or _standup_remaining > 0.0
	var input = FrameInput.none() if input_locked else (InputHelper.read_player_two() if is_player_two else InputHelper.read_player_one())

	_update_facing_toward_opponent()

	is_blocking = input.crouch_held and is_truly_on_floor() and not combat.is_attacking and _hit_stun_frames <= 0 and _standup_remaining <= 0.0 and not _knocked_down and not input_locked

	velocity = movement.compute_velocity(velocity, delta, input, is_truly_on_floor(), locked or combat.is_attacking or is_blocking, _is_flying_knockdown())

	if in_hitstun and not is_truly_on_floor() and _combo_gravity_scale > 1.0:
		var extra_gravity = Constants.Physics.DEFAULT_GRAVITY * (_combo_gravity_scale - 1.0) * delta
		velocity.y = minf(velocity.y + extra_gravity, Constants.Physics.MAX_FALL_SPEED)

	_update_dash_phasing()
	move_and_slide()

	if _opponent != null:
		separate_fighters(self, _opponent)

	if _airborne_knockdown and is_truly_on_floor():
		_airborne_knockdown = false

	clamp_to_stage_bounds()
	combat.set_facing(movement.facing_direction)

	command_combos.update_buffer(delta)

	if not input_locked and not in_hitstun and _standup_remaining <= 0.0:
		_try_process_attack_input(input)

	_update_animation_state(input)

	if combat.is_attacking and _opponent != null and _opponent.hurtbox != null:
		combat.check_hit(_opponent.hurtbox)

func _tick_hit_reaction_timers(dt: float) -> void:
	_tick_knockdown_meter(dt)

	if _hit_stun_frames > 0:
		var prev = _hit_stun_frames
		_hit_stun_frames -= 1
		if _hit_stun_frames <= 0 and prev > 0:
			_on_hitstun_expired()
	elif _knocked_down and is_on_floor():
		_knocked_down = false
		_airborne_knockdown = false
		_start_standup()

	if _standup_remaining > 0.0:
		_standup_remaining -= dt
		if _standup_remaining <= 0.0:
			_end_standup()

func _on_hitstun_expired() -> void:
	_combo_gravity_scale = 1.0
	if _is_stunned:
		_is_stunned = false
		anim.unfreeze_animation()

	if _opponent != null:
		_opponent.combo.end_combo()

func _tick_knockdown_meter(dt: float) -> void:
	if _knockdown_meter_window_remaining <= 0.0:
		return

	_knockdown_meter_window_remaining -= dt
	if _knockdown_meter_window_remaining <= 0.0:
		_knockdown_meter = 0.0

func _start_standup() -> void:
	_standup_remaining = Constants.Combat.STANDUP_SECONDS
	if hurtbox != null:
		hurtbox.monitorable = false
	anim.play_state(CharacterAnimation.CharacterState.HURT)

func _end_standup() -> void:
	_standup_remaining = 0.0
	_knockdown_meter = 0.0
	_knockdown_meter_window_remaining = 0.0
	if hurtbox != null:
		hurtbox.monitorable = true

func _is_flying_knockdown() -> bool:
	return _airborne_knockdown or (_knocked_down and not is_on_floor())

func _update_facing_toward_opponent() -> void:
	if _opponent == null:
		return
	var desired = 1 if _opponent.global_position.x >= global_position.x else -1
	movement.set_facing(desired)

func clamp_to_stage_bounds() -> void:
	var pos = global_position
	var clamped_x = clampf(pos.x, Constants.Stage.MIN_X, Constants.Stage.MAX_X)
	if clamped_x != pos.x:
		pos.x = clamped_x
		global_position = pos
		velocity.x = 0.0
	else:
		global_position = pos

func _update_dash_phasing() -> void:
	if movement.is_dashing:
		if not _dash_phasing_active:
			_dash_phasing_active = true
			collision_layer = 0
			collision_mask = Constants.Physics.GROUND_COLLISION_MASK
			if _body_shape != null: _body_shape.disabled = true
			if _opponent != null: add_collision_exception_with(_opponent)
	else:
		if _dash_phasing_active:
			_dash_phasing_active = false
			collision_layer = Constants.Physics.PLAYER_LAYER
			collision_mask = Constants.Physics.PLAYER_COLLISION_MASK
			if _body_shape != null: _body_shape.disabled = false
			if _opponent != null:
				remove_collision_exception_with(_opponent)
				separate_fighters(self, _opponent)

func is_truly_on_floor() -> bool:
	if not is_on_floor():
		return false
	if _opponent == null:
		return true

	var count = get_slide_collision_count()
	for i in range(count):
		var col = get_slide_collision(i)
		if col.get_collider() == _opponent:
			if col.get_normal().y < -0.5:
				return false
	return true

static func separate_fighters(a: CharacterController, b: CharacterController) -> void:
	if a.movement.is_dashing or b.movement.is_dashing:
		return

	var min_sep = Constants.Physics.PLAYER_PUSH_SEPARATION
	var dx = b.global_position.x - a.global_position.x
	var abs_dx = absf(dx)

	if abs_dx >= min_sep:
		return

	var overlap = min_sep - abs_dx
	var dy = b.global_position.y - a.global_position.y
	var is_vertical_stack = absf(dy) > 4.0

	var sign_val: int = 1
	if abs_dx > 0.01:
		sign_val = 1 if dx > 0 else -1
	else:
		sign_val = a.movement.facing_direction if a.movement.facing_direction != 0 else 1

	var a_dist = minf(a.global_position.x - Constants.Stage.MIN_X, Constants.Stage.MAX_X - a.global_position.x)
	var b_dist = minf(b.global_position.x - Constants.Stage.MIN_X, Constants.Stage.MAX_X - b.global_position.x)

	var a_cornered = a_dist <= Constants.Physics.CORNER_MARGIN
	var b_cornered = b_dist <= Constants.Physics.CORNER_MARGIN

	var push_a: float = 0.0
	var push_b: float = 0.0
	if a_cornered and not b_cornered:
		push_a = 0.0
		push_b = overlap
	elif b_cornered and not a_cornered:
		push_a = overlap
		push_b = 0.0
	else:
		push_a = overlap * 0.5
		push_b = overlap * 0.5

	if is_vertical_stack:
		var top = b if dy < 0 else a
		var top_sign = sign_val if top == b else -sign_val
		var desired_slide_x = top_sign * 200.0
		if signf(top.velocity.x) != top_sign or absf(top.velocity.x) < 150.0:
			top.velocity.x = desired_slide_x

	a.global_position = Vector2(a.global_position.x - push_a * sign_val, a.global_position.y)
	b.global_position = Vector2(b.global_position.x + push_b * sign_val, b.global_position.y)

	a.clamp_to_stage_bounds()
	b.clamp_to_stage_bounds()

func _try_process_attack_input(input: FrameInput) -> void:
	if input.attack1: _buffered_attack_input = CharacterCombat.AttackInput.ATTACK1; _buffered_attack_frames = 12
	elif input.attack2: _buffered_attack_input = CharacterCombat.AttackInput.ATTACK2; _buffered_attack_frames = 12
	elif input.attack3: _buffered_attack_input = CharacterCombat.AttackInput.ATTACK3; _buffered_attack_frames = 12

	if _buffered_attack_frames > 0 and _buffered_attack_input != null:
		var target_input = _buffered_attack_input

		if combat.is_attacking:
			if cancel_mgr != null and combat.try_cancel_into(target_input, energy, cancel_mgr):
				_buffered_attack_input = null
				_buffered_attack_frames = 0
				return

			if input.jump_pressed and cancel_mgr != null and cancel_mgr.can_jump_cancel(combat.current_attack_data, combat.is_hitbox_active, combat.has_connected):
				combat.cancel_attack()
				_buffered_attack_input = null
				_buffered_attack_frames = 0
				return
		else:
			if command_combos.try_execute(input, combat, energy):
				_buffered_attack_input = null
				_buffered_attack_frames = 0
				return

			if command_combos.try_release_expired_buffer(combat, energy):
				_buffered_attack_input = null
				_buffered_attack_frames = 0
				return

			if combat.try_start_attack(target_input, energy):
				_buffered_attack_input = null
				_buffered_attack_frames = 0
				return

		_buffered_attack_frames -= 1
		if _buffered_attack_frames <= 0:
			_buffered_attack_input = null

func _update_animation_state(input: FrameInput) -> void:
	if health.is_knocked_out:
		anim.play_state(CharacterAnimation.CharacterState.KO)
		return

	if combat.is_attacking or _hit_stun_frames > 0 or _knocked_down or _standup_remaining > 0.0:
		return

	if not is_on_floor():
		if movement.is_dashing:
			anim.play_state(CharacterAnimation.CharacterState.RUN)
			anim.set_facing(-movement.facing_direction if movement.is_back_dash else movement.facing_direction)
		else:
			anim.play_state(CharacterAnimation.CharacterState.JUMP)
	elif movement.is_dashing:
		anim.play_state(CharacterAnimation.CharacterState.RUN)
		anim.set_facing(-movement.facing_direction if movement.is_back_dash else movement.facing_direction)
	elif is_blocking:
		anim.play_state(CharacterAnimation.CharacterState.BLOCK)
	elif absf(velocity.x) > 5.0:
		anim.play_state(CharacterAnimation.CharacterState.WALK)
	else:
		anim.play_state(CharacterAnimation.CharacterState.IDLE)

func _on_own_attack_started(animation_key: String) -> void:
	var atk_data = combat.current_attack_data
	var speed_scale = atk_data.attack_speed if atk_data != null else 1.0
	var custom_frames = atk_data.custom_sprite_frames if atk_data != null else null
	if anim.try_play_animation_key(animation_key, speed_scale, custom_frames):
		return

	var state = CharacterAnimation.CharacterState.IDLE
	match animation_key:
		"attack1": state = CharacterAnimation.CharacterState.ATTACK1
		"attack2": state = CharacterAnimation.CharacterState.ATTACK2
		"attack3": state = CharacterAnimation.CharacterState.ATTACK3

	anim.set_speed_scale(speed_scale)
	anim.play_state(state)

func _on_own_attack_swing(sfx: AudioStream) -> void:
	if sfx != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(sfx)

func _on_own_attack_hit(target_hurtbox: Node2D, damage: float, knockback: float, hit_stun: float, energy_gained: float, direction: int, attack_input: int) -> void:
	energy.add_energy(energy_gained)
	var deterioration = combo.next_hitstun_multiplier
	combo.register_hit()

	var target = target_hurtbox.get_parent() as CharacterController
	if target != null:
		var deteriorated_hitstun = hit_stun * deterioration
		var hitstun_frames = maxi(roundi(deteriorated_hitstun * 60.0), Constants.Combat.MIN_HITSTUN_FRAMES)
		var gravity_scale = combo.current_gravity_scale
		var launch_force = combat.current_attack_data.launch_force if combat.current_attack_data != null else Vector2.ZERO
		var hit_effect = combat.current_attack_data.effect if combat.current_attack_data != null else AttackData.HitEffect.NORMAL
		var knockdown_meter_gain = combat.current_command_move.knockdown_meter_gain if combat.current_command_move != null else 0

		target.receive_hit(damage, knockback, hitstun_frames, direction, attack_input as CharacterCombat.AttackInput, launch_force, gravity_scale, hit_effect, knockdown_meter_gain)

func _on_projectile_spawn_requested() -> void:
	var move = combat.current_command_move
	if move == null or move.projectile_scene == null or move.attack_stats == null or _opponent == null:
		return

	var proj = move.projectile_scene.instantiate() as Projectile
	proj.direction = movement.facing_direction
	proj.attack_stats = move.attack_stats
	proj.target_hurtbox = _opponent.hurtbox
	proj.owner_controller = self
	if move.projectile_speed > 0.0:
		proj.speed = move.projectile_speed

	var spawn_offset_x = 50.0 * movement.facing_direction
	proj.global_position = Vector2(global_position.x + spawn_offset_x, global_position.y - 5.0)

	get_tree().current_scene.add_child(proj)

func on_projectile_hit(proj: Projectile) -> void:
	if proj.attack_stats == null or _opponent == null:
		return

	var stats = proj.attack_stats
	energy.add_energy(stats.energy_gained_on_hit)

	var deterioration = combo.next_hitstun_multiplier
	combo.register_hit()

	var deteriorated_hitstun = stats.hitstun * deterioration
	var hitstun_frames = maxi(roundi(deteriorated_hitstun * 60.0), Constants.Combat.MIN_HITSTUN_FRAMES)

	var gravity_scale = combo.current_gravity_scale
	var launch_force = stats.launch_force
	var hit_effect = stats.effect
	var knockdown_meter_gain = combat.current_command_move.knockdown_meter_gain if combat.current_command_move != null else 0

	combat.mark_connected()

	_opponent.receive_hit(stats.damage, stats.knockback, hitstun_frames, proj.direction, CharacterCombat.AttackInput.COMMAND, launch_force, gravity_scale, hit_effect, knockdown_meter_gain)

func receive_hit(
	damage: float, knockback: float, hitstun_frames: int,
	attacker_facing: int, attack_input: CharacterCombat.AttackInput,
	launch_force: Vector2, combo_gravity_scale: float,
	hit_effect: AttackData.HitEffect = AttackData.HitEffect.NORMAL,
	knockdown_meter_gain: int = 0
) -> void:
	if health.is_knocked_out or is_invulnerable:
		return

	var current_input = InputHelper.read_player_two() if is_player_two else InputHelper.read_player_one()
	var is_holding_block_now = is_truly_on_floor() and current_input.crouch_held
	var is_blocking_hit = is_blocking or (is_holding_block_now and not combat.is_attacking and _hit_stun_frames <= 0 and _standup_remaining <= 0.0 and not _knocked_down)

	if is_blocking_hit:
		var chip_damage = damage * Constants.Combat.BLOCK_DAMAGE_MULTIPLIER
		health.apply_damage(chip_damage)
		energy.add_energy(Constants.Combat.ENERGY_PER_HIT_TAKEN)

		if data != null and data.sfx_hurt != null and not health.is_knocked_out:
			if AudioManager.instance != null: AudioManager.instance.play_sfx(data.sfx_hurt)

		var block_knockback = maxf(knockback * Constants.Combat.BLOCK_KNOCKBACK_MULTIPLIER, Constants.Combat.MIN_HURT_KNOCKBACK)
		velocity = Vector2(block_knockback * attacker_facing, velocity.y)
		_hit_stun_frames = roundi(Constants.Combat.BLOCK_STUN_SECONDS * 60.0)

		if not health.is_knocked_out:
			anim.play_state(CharacterAnimation.CharacterState.BLOCK)
		return

	health.apply_damage(damage)
	energy.add_energy(Constants.Combat.ENERGY_PER_HIT_TAKEN)

	if data != null and data.sfx_hurt != null and not health.is_knocked_out:
		if AudioManager.instance != null: AudioManager.instance.play_sfx(data.sfx_hurt)

	_combo_gravity_scale = combo_gravity_scale

	var is_knockdown = false
	if hit_effect == AttackData.HitEffect.NORMAL:
		var meter_gain = knockdown_meter_gain if knockdown_meter_gain > 0 else (
			Constants.Combat.KNOCKDOWN_METER_LIGHT_GAIN if (attack_input == CharacterCombat.AttackInput.ATTACK1 or attack_input == CharacterCombat.AttackInput.ATTACK2) else Constants.Combat.KNOCKDOWN_METER_HEAVY_GAIN
		)

		_knockdown_meter += meter_gain
		_knockdown_meter_window_remaining = Constants.Combat.KNOCKDOWN_METER_WINDOW_SECONDS

		is_knockdown = _knockdown_meter >= Constants.Combat.KNOCKDOWN_METER_MAX
		if is_knockdown:
			_knockdown_meter = 0.0
			_knockdown_meter_window_remaining = 0.0

	var hit_anim = CharacterAnimation.CharacterState.HURT

	match hit_effect:
		AttackData.HitEffect.AIRBORNE:
			_apply_airborne_hit(launch_force, knockback, hitstun_frames, attacker_facing)
			hit_anim = CharacterAnimation.CharacterState.HURT
		AttackData.HitEffect.STUN:
			_apply_stun_hit(hitstun_frames)
			hit_anim = CharacterAnimation.CharacterState.HURT
		AttackData.HitEffect.CRUMPLE:
			_apply_crumple_hit(hitstun_frames, attacker_facing)
			hit_anim = CharacterAnimation.CharacterState.KO
		AttackData.HitEffect.WALL_BOUNCE:
			_apply_wall_bounce_hit(launch_force, knockback, hitstun_frames, attacker_facing)
			hit_anim = CharacterAnimation.CharacterState.KO
		_:
			_apply_normal_hit(knockback, hitstun_frames, attacker_facing, launch_force, is_knockdown)
			hit_anim = CharacterAnimation.CharacterState.KO if is_knockdown else CharacterAnimation.CharacterState.HURT

	if combat.is_attacking:
		combat.cancel_attack()

	if not health.is_knocked_out:
		anim.play_state(hit_anim)
		if _is_stunned:
			anim.freeze_animation()

func _apply_normal_hit(knockback: float, hitstun_frames: int, attacker_facing: int, launch_force: Vector2, is_knockdown: bool) -> void:
	var min_kb = Constants.Combat.KNOCKDOWN_KNOCKBACK if is_knockdown else Constants.Combat.MIN_HURT_KNOCKBACK
	var applied_kb = maxf(knockback, min_kb)

	if is_knockdown:
		velocity = Vector2(applied_kb * attacker_facing, Constants.Combat.KNOCKDOWN_LAUNCH_VELOCITY)
		_hit_stun_frames = roundi(Constants.Combat.KNOCKDOWN_STUN_SECONDS * 60.0)
		_knocked_down = true
		_airborne_knockdown = true
	else:
		if launch_force != Vector2.ZERO:
			velocity = Vector2(launch_force.x * attacker_facing, launch_force.y)
		else:
			velocity = Vector2(applied_kb * attacker_facing, velocity.y)
		_hit_stun_frames = hitstun_frames

func _apply_airborne_hit(launch_force: Vector2, knockback: float, hitstun_frames: int, attacker_facing: int) -> void:
	if launch_force != Vector2.ZERO:
		velocity = Vector2(launch_force.x * attacker_facing, launch_force.y)
	else:
		velocity = Vector2(maxf(knockback, Constants.Combat.MIN_HURT_KNOCKBACK) * attacker_facing, Constants.Combat.KNOCKDOWN_LAUNCH_VELOCITY)

	_hit_stun_frames = hitstun_frames
	_knocked_down = true
	_airborne_knockdown = true

func _apply_stun_hit(hitstun_frames: int) -> void:
	velocity = Vector2(0.0, velocity.y)
	_hit_stun_frames = roundi(hitstun_frames * Constants.Combat.STUN_HITSTUN_MULTIPLIER)
	_is_stunned = true

func _apply_crumple_hit(hitstun_frames: int, _attacker_facing: int) -> void:
	velocity = Vector2(0.0, 20.0)
	_combo_gravity_scale = Constants.Combat.CRUMPLE_GRAVITY_SCALE
	_hit_stun_frames = hitstun_frames
	_knocked_down = true
	_airborne_knockdown = not is_on_floor()

func _apply_wall_bounce_hit(launch_force: Vector2, knockback: float, hitstun_frames: int, attacker_facing: int) -> void:
	var dist_left = global_position.x - Constants.Stage.MIN_X
	var dist_right = Constants.Stage.MAX_X - global_position.x
	var min_dist = minf(dist_left, dist_right)

	if min_dist <= Constants.Combat.WALL_BOUNCE_PROXIMITY:
		var bounce_dir = 1 if dist_left < dist_right else -1
		var bounce_speed = maxf(knockback, Constants.Combat.MIN_HURT_KNOCKBACK)
		velocity = Vector2(bounce_speed * bounce_dir * absf(Constants.Combat.WALL_BOUNCE_VELOCITY_MULTIPLIER), Constants.Combat.WALL_BOUNCE_LAUNCH_Y)
		_hit_stun_frames = hitstun_frames
		_knocked_down = true
		_airborne_knockdown = true
	else:
		_apply_airborne_hit(launch_force, knockback, hitstun_frames, attacker_facing)

func _on_knocked_out() -> void:
	_match_over = true
	if data != null and data.sfx_ko != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(data.sfx_ko)
	anim.play_state(CharacterAnimation.CharacterState.KO)
	round_loss.emit(self)
