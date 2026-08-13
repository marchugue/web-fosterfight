class_name RoundManager
extends Node

signal round_timer_tick(remaining_seconds: float)
signal round_intro_started(round_number: int, player_one_wins: int, player_two_wins: int)
signal round_intro_player_focus(player: CharacterController, display_name: String, player_number: int)
signal round_intro_fight
signal round_started
signal knockout(loser: CharacterController, winner: CharacterController)
signal round_ended(winner: CharacterController, was_timeout: bool)

@export var round_time_seconds: float = Constants.Match.ROUND_TIME_SECONDS

var _player_one: CharacterController
var _player_two: CharacterController
var _time_remaining: float = 0.0
var _round_active: bool = false
var _intro_running: bool = false

func setup(player_one: CharacterController, player_two: CharacterController) -> void:
	_player_one = player_one
	_player_two = player_two

	if _player_one != null: _player_one.round_loss.connect(_on_fighter_knocked_out)
	if _player_two != null: _player_two.round_loss.connect(_on_fighter_knocked_out)

func prepare_round() -> void:
	_time_remaining = round_time_seconds
	_round_active = false
	_intro_running = false

	if _player_one != null: _player_one.reset_for_new_round()
	if _player_two != null: _player_two.reset_for_new_round()

	if _player_one != null:
		_player_one.global_position = Vector2(Constants.Stage.PLAYER_ONE_SPAWN_X, Constants.Stage.SPAWN_Y)
		_player_one.velocity = Vector2.ZERO

	if _player_two != null:
		_player_two.global_position = Vector2(Constants.Stage.PLAYER_TWO_SPAWN_X, Constants.Stage.SPAWN_Y)
		_player_two.velocity = Vector2.ZERO

	set_input_locked(true)

func play_intro_sequence(round_number: int, player_one_wins: int, player_two_wins: int) -> void:
	if _player_one == null or _intro_running:
		return

	_intro_running = true
	round_intro_started.emit(round_number, player_one_wins, player_two_wins)

	if _player_two == null or round_number > 1:
		_play_round_overlay_only()
	else:
		_play_match_intro_sequence()

func _play_match_intro_sequence() -> void:
	if AudioManager.instance != null: AudioManager.instance.play_round_intro_sfx()
	_focus_intro_player(_player_one, 1)

	var p1_timer = get_tree().create_timer(Constants.Match.INTRO_PLAYER_FOCUS_SECONDS)
	p1_timer.timeout.connect(func():
		if AudioManager.instance != null: AudioManager.instance.play_round_intro_sfx()
		_focus_intro_player(_player_two, 2)

		var p2_timer = get_tree().create_timer(Constants.Match.INTRO_PLAYER_FOCUS_SECONDS)
		p2_timer.timeout.connect(func():
			if AudioManager.instance != null: AudioManager.instance.play_fight_sfx()
			round_intro_fight.emit()
			_player_one.play_intro_idle()
			_player_two.play_intro_idle()

			var fight_timer = get_tree().create_timer(Constants.Match.INTRO_FIGHT_CALL_SECONDS)
			fight_timer.timeout.connect(_finish_intro)
		)
	)

func _play_round_overlay_only() -> void:
	if AudioManager.instance != null: AudioManager.instance.play_round_intro_sfx()
	var timer = get_tree().create_timer(Constants.Match.ROUND_OVERLAY_SECONDS)
	timer.timeout.connect(_finish_intro)

func _finish_intro() -> void:
	_intro_running = false
	begin_round()

func begin_round() -> void:
	Engine.time_scale = 1.0
	set_input_locked(false)
	_round_active = true
	round_started.emit()

func stop_round() -> void:
	Engine.time_scale = 1.0
	_round_active = false
	_intro_running = false
	set_input_locked(true)

func _process(delta: float) -> void:
	if not _round_active:
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	round_timer_tick.emit(_time_remaining)

	if _time_remaining <= 0.0:
		_resolve_timeout()

func _focus_intro_player(player: CharacterController, player_number: int) -> void:
	if _player_one == null or _player_two == null:
		return

	_player_one.play_intro_idle()
	_player_two.play_intro_idle()
	player.play_intro_pose()

	var display_name = player.data.display_name if player.data != null else "Player %d" % player_number
	round_intro_player_focus.emit(player, display_name, player_number)

func _on_fighter_knocked_out(loser: CharacterController) -> void:
	if not _round_active:
		return

	_round_active = false
	var winner = _player_two if loser == _player_one else _player_one
	set_input_locked(true)

	if AudioManager.instance != null:
		AudioManager.instance.play_ko_sfx()
		AudioManager.instance.fade_out_music(1.8)

	Engine.time_scale = 0.08
	var freeze_timer = get_tree().create_timer(0.20, true, false, true)
	freeze_timer.timeout.connect(func(): Engine.time_scale = 1.0)

	knockout.emit(loser, winner)

	var timer = get_tree().create_timer(Constants.Match.KO_PAUSE_SECONDS)
	timer.timeout.connect(func(): round_ended.emit(winner, false))

func _resolve_timeout() -> void:
	_round_active = false
	set_input_locked(true)

	if _player_one == null or _player_two == null:
		round_ended.emit(null, true)
		return

	var p1_hp = _player_one.health.current_health
	var p2_hp = _player_two.health.current_health

	var winner: CharacterController = null
	if p1_hp > p2_hp:
		winner = _player_one
	elif p2_hp > p1_hp:
		winner = _player_two
	else:
		winner = null

	round_ended.emit(winner, true)

func set_input_locked(locked: bool) -> void:
	if _player_one != null: _player_one.input_locked = locked
	if _player_two != null: _player_two.input_locked = locked
