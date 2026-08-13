class_name CharacterMovement
extends Node

signal facing_changed(direction: int)
signal jumped
signal dash_started(direction: int)
signal dash_ended

var move_speed: float = 300.0

var speed: float:
	get: return move_speed
	set(val): move_speed = val

var jump_force: float = 520.0
var facing_direction: int = 1

var is_dashing: bool:
	get: return _dash_time_remaining > 0.0

var is_back_dash: bool:
	get: return is_dashing and _dash_direction != facing_direction

var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction: int = 1
var _air_dash_used: bool = false
var _is_air_dash: bool = false
var _post_dash_timer: float = 0.0
var _was_on_floor: bool = false

var _last_left_tap_ms: int = 0
var _last_right_tap_ms: int = 0

func initialize(data: CharacterData) -> void:
	move_speed = data.move_speed
	jump_force = data.jump_force

func compute_velocity(p_velocity: Vector2, delta: float, input: FrameInput, is_on_floor: bool, movement_locked: bool, flying_knockdown: bool = false) -> Vector2:
	var dt = delta
	var velocity = p_velocity

	if is_on_floor:
		_air_dash_used = false

	var just_landed = is_on_floor and not _was_on_floor
	if just_landed:
		velocity.x *= Constants.Physics.LANDING_MOMENTUM_KEEP
	_was_on_floor = is_on_floor

	if not is_on_floor:
		var grav_scale: float
		var abs_vel_y = absf(velocity.y)

		if velocity.y < 0.0 and abs_vel_y > Constants.Physics.APEX_THRESHOLD:
			grav_scale = Constants.Physics.RISING_GRAVITY_SCALE
		elif abs_vel_y <= Constants.Physics.APEX_THRESHOLD:
			grav_scale = Constants.Physics.APEX_GRAVITY_SCALE
		elif velocity.y > Constants.Physics.LATE_FALL_THRESHOLD:
			grav_scale = Constants.Physics.LATE_FALL_GRAVITY_SCALE
		else:
			grav_scale = Constants.Physics.FALL_GRAVITY_SCALE

		velocity.y = minf(velocity.y + Constants.Physics.DEFAULT_GRAVITY * grav_scale * dt, Constants.Physics.MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_tick_dash_timers(dt)
	_tick_post_dash_timer(dt)

	if movement_locked:
		if not flying_knockdown:
			velocity.x = move_toward(velocity.x, 0.0, Constants.Physics.KNOCKBACK_FRICTION * dt)
		return velocity

	_try_detect_dash(input, is_on_floor)

	if is_dashing:
		var dash_spd = Constants.Movement.AIR_DASH_SPEED if _is_air_dash else Constants.Movement.DASH_SPEED
		if _dash_time_remaining >= Constants.Movement.DASH_DURATION_SECONDS - dt * 1.5:
			dash_spd *= Constants.Movement.DASH_BURST_MULTIPLIER

		velocity.x = _dash_direction * dash_spd
		if _is_air_dash:
			velocity.y = 0.0
		return velocity

	if is_on_floor:
		if absf(input.horizontal) > 0.01:
			var reversing = velocity.x != 0.0 and signf(input.horizontal) != signf(velocity.x)
			var accel = Constants.Physics.TURNAROUND_BOOST if reversing else Constants.Physics.GROUND_ACCEL
			velocity.x = move_toward(velocity.x, input.horizontal * move_speed, accel * dt)
		else:
			var friction = Constants.Movement.POST_DASH_FRICTION if _post_dash_timer > 0.0 else Constants.Physics.GROUND_FRICTION
			velocity.x = move_toward(velocity.x, 0.0, friction * dt)
	else:
		if absf(input.horizontal) > 0.01:
			velocity.x = move_toward(velocity.x, input.horizontal * move_speed, Constants.Physics.AIR_ACCEL * dt)
		else:
			velocity.x = move_toward(velocity.x, 0.0, Constants.Physics.AIR_FRICTION * dt)

	if is_on_floor and input.jump_pressed:
		velocity.y = -jump_force
		jumped.emit()

	return velocity

func _tick_dash_timers(dt: float) -> void:
	var was_dashing = is_dashing

	if _dash_time_remaining > 0.0:
		_dash_time_remaining -= dt
		if _dash_time_remaining <= 0.0:
			_dash_time_remaining = 0.0
			_post_dash_timer = Constants.Movement.POST_DASH_DURATION

	if _dash_cooldown_remaining > 0.0:
		_dash_cooldown_remaining -= dt

	if was_dashing and not is_dashing:
		dash_ended.emit()

func _tick_post_dash_timer(dt: float) -> void:
	if _post_dash_timer > 0.0:
		_post_dash_timer -= dt
		if _post_dash_timer < 0.0:
			_post_dash_timer = 0.0

func _try_detect_dash(input: FrameInput, is_on_floor: bool) -> void:
	if is_dashing or _dash_cooldown_remaining > 0.0:
		return
	if not is_on_floor and _air_dash_used:
		return

	var now = Time.get_ticks_msec()
	var window_ms = Constants.Movement.DASH_TAP_WINDOW_SECONDS * 1000.0

	if input.move_right_just_pressed:
		var double_tapped = float(now - _last_right_tap_ms) <= window_ms
		_last_right_tap_ms = now
		if double_tapped:
			_start_dash(1, is_on_floor)
			return

	if input.move_left_just_pressed:
		var double_tapped = float(now - _last_left_tap_ms) <= window_ms
		_last_left_tap_ms = now
		if double_tapped:
			_start_dash(-1, is_on_floor)

func _start_dash(direction: int, is_on_floor: bool) -> void:
	_dash_direction = direction
	_is_air_dash = not is_on_floor
	_dash_time_remaining = Constants.Movement.DASH_DURATION_SECONDS
	_dash_cooldown_remaining = Constants.Movement.DASH_COOLDOWN_SECONDS
	_post_dash_timer = 0.0
	if _is_air_dash:
		_air_dash_used = true
	dash_started.emit(direction)

func set_facing(direction: int) -> void:
	if direction != 0:
		facing_direction = 1 if direction > 0 else -1
		facing_changed.emit(facing_direction)

func cancel_dash() -> void:
	_dash_time_remaining = 0.0

func move(dir_val: float) -> void:
	if dir_val != 0.0:
		set_facing(1 if dir_val > 0.0 else -1)

func stop() -> void:
	pass

func reset_for_new_round() -> void:
	_dash_time_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	_post_dash_timer = 0.0
	_was_on_floor = false
	_last_left_tap_ms = 0
	_last_right_tap_ms = 0
	_air_dash_used = false
	_is_air_dash = false
