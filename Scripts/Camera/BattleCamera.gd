class_name BattleCamera
extends Camera2D

@export var player_one_path: NodePath = ""
@export var player_two_path: NodePath = ""
@export var round_manager_path: NodePath = ""
@export var match_manager_path: NodePath = ""

@export_group("Target Lock")
@export var single_player_mode: bool = false
@export var lock_on_player_one: bool = false
@export var follow_vertical: bool = false

var _player_one: Node2D
var _player_two: Node2D
var _ko_focus: Node2D
var _round_win_focus: Node2D
var _intro_focus: Node2D
var _ko_active: bool = false
var _round_win_active: bool = false
var _intro_active: bool = false
var _intro_fight_pulse: bool = false
var _intro_is_match_opening: bool = false
var _current_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	if not player_one_path.is_empty():
		_player_one = get_node_or_null(player_one_path) as Node2D
	if not player_two_path.is_empty():
		_player_two = get_node_or_null(player_two_path) as Node2D

	position_smoothing_enabled = false
	global_position = Vector2(Constants.Stage.DEFAULT_CENTER_X, Constants.Camera.DEFAULT_Y)
	_current_zoom = Vector2.ONE
	zoom = _current_zoom

	if not round_manager_path.is_empty():
		var round_mgr = get_node_or_null(round_manager_path) as RoundManager
		if round_mgr != null:
			round_mgr.knockout.connect(_on_knockout)
			round_mgr.round_intro_started.connect(_on_round_intro_started)
			round_mgr.round_intro_player_focus.connect(_on_round_intro_player_focus)
			round_mgr.round_intro_fight.connect(_on_round_intro_fight)
			round_mgr.round_started.connect(_on_round_started)
			round_mgr.round_ended.connect(_on_round_ended)

	if not match_manager_path.is_empty():
		var match_mgr = get_node_or_null(match_manager_path) as MatchManager
		if match_mgr != null:
			match_mgr.match_ended.connect(_on_match_ended)

func update_fighter_references(player_one: Node2D, player_two: Node2D) -> void:
	_player_one = player_one
	_player_two = player_two

func _process(delta: float) -> void:
	if _player_one == null:
		return

	if _ko_active and _ko_focus != null:
		_update_focus_camera(_ko_focus, Constants.Camera.KO_ZOOM, delta * 1.6)
	elif _round_win_active and _round_win_focus != null:
		_update_focus_camera(_round_win_focus, Constants.Camera.WINNER_ZOOM, delta * 1.2)
	elif _intro_active:
		_update_intro_camera(delta)
	else:
		_update_normal_camera(delta)

func _on_knockout(loser: Node2D, winner: Node2D) -> void:
	_ko_focus = loser
	_ko_active = true
	_round_win_active = false
	_round_win_focus = winner
	_intro_active = false
	_intro_focus = null

func _on_round_ended(winner: Node2D, _was_timeout: bool) -> void:
	_ko_active = false
	_ko_focus = null
	if winner != null:
		_round_win_active = true
		_round_win_focus = winner

func _on_match_ended(winner: Node2D) -> void:
	_round_win_active = true
	_round_win_focus = winner

func _on_round_intro_started(round_number: int, _p1_wins: int, _p2_wins: int) -> void:
	_ko_active = false
	_ko_focus = null
	_round_win_active = false
	_round_win_focus = null
	_intro_is_match_opening = round_number <= 1
	_intro_active = _intro_is_match_opening
	_intro_fight_pulse = false

func _on_round_intro_player_focus(player: Node2D, _display_name: String, _player_num: int) -> void:
	_intro_focus = player
	_intro_fight_pulse = false

func _on_round_intro_fight() -> void:
	_intro_fight_pulse = true
	_intro_focus = null

func _on_round_started() -> void:
	_ko_active = false
	_ko_focus = null
	_round_win_active = false
	_round_win_focus = null
	_intro_active = false
	_intro_focus = null
	_intro_fight_pulse = false

func _update_intro_camera(dt: float) -> void:
	if _intro_fight_pulse:
		var midpoint = _player_one.global_position.x if _player_two == null else (_player_one.global_position.x + _player_two.global_position.x) * 0.5
		_apply_smoothed_camera(midpoint, Constants.Camera.DEFAULT_Y, Constants.Camera.MAX_ZOOM, dt * 2.0)
		return

	if _intro_focus == null:
		_update_intro_character_camera(_player_one, dt)
		return

	_update_intro_character_camera(_intro_focus, dt)

func _update_intro_character_camera(focus: Node2D, dt: float) -> void:
	var target_zoom = Constants.Camera.INTRO_FULL_BODY_ZOOM
	var half_view_x = (Constants.Camera.VIEWPORT_WIDTH * 0.5) / target_zoom
	var target_x = clampf(focus.global_position.x, Constants.Stage.WORLD_MIN_X + half_view_x, Constants.Stage.WORLD_MAX_X - half_view_x)
	var target_y = focus.global_position.y - Constants.Camera.INTRO_VERTICAL_OFFSET

	_apply_smoothed_camera(target_x, target_y, target_zoom, dt * 1.4)

func _update_normal_camera(dt: float) -> void:
	if _player_one == null or not is_instance_valid(_player_one):
		return

	var target_x: float
	if single_player_mode or lock_on_player_one or _player_two == null or not is_instance_valid(_player_two):
		target_x = _player_one.global_position.x
	else:
		var p1x = _player_one.global_position.x
		var p2x = _player_two.global_position.x
		var left_x = minf(p1x, p2x)
		var right_x = maxf(p1x, p2x)
		target_x = (left_x + right_x) * 0.5

	var target_y = Constants.Camera.DEFAULT_Y
	if follow_vertical:
		target_y = _player_one.global_position.y - 30.0

	var target_zoom = Constants.Camera.MAX_ZOOM
	var half_view = (Constants.Camera.VIEWPORT_WIDTH * 0.5) / target_zoom

	var world_min_cam = Constants.Stage.WORLD_MIN_X + half_view
	var world_max_cam = Constants.Stage.WORLD_MAX_X - half_view
	target_x = clampf(target_x, world_min_cam, world_max_cam)

	_apply_smoothed_camera(target_x, target_y, target_zoom, dt)

func _update_focus_camera(focus: CharacterController, target_zoom: float, dt: float) -> void:
	var half_view = (Constants.Camera.VIEWPORT_WIDTH * 0.5) / target_zoom
	var target_x = clampf(focus.global_position.x, Constants.Stage.WORLD_MIN_X + half_view, Constants.Stage.WORLD_MAX_X - half_view)

	_apply_smoothed_camera(target_x, Constants.Camera.DEFAULT_Y, target_zoom, dt)

func _apply_smoothed_camera(target_x: float, target_y: float, target_zoom: float, dt: float) -> void:
	var t = 1.0 - exp(-Constants.Camera.PAN_SMOOTH_SPEED * dt)
	global_position = Vector2(
		lerpf(global_position.x, target_x, t),
		lerpf(global_position.y, target_y, t)
	)
	_current_zoom = _current_zoom.lerp(Vector2(target_zoom, target_zoom), t)
	zoom = _current_zoom
