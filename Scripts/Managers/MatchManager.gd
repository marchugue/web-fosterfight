class_name MatchManager
extends Node

signal rounds_score_changed(player_one_wins: int, player_two_wins: int)
signal match_ended(winner: CharacterController)

@export var player_one_path: NodePath = ""
@export var player_two_path: NodePath = ""
@export var round_manager_path: NodePath = ""
@export var rounds_to_win_match: int = Constants.Match.ROUNDS_TO_WIN_MATCH

var _player_one: CharacterController
var _player_two: CharacterController
var _round_manager: RoundManager

var player_one_rounds_won: int = 0
var player_two_rounds_won: int = 0

var _player_one_highest_combo: int = 0
var _player_two_highest_combo: int = 0
var _match_elapsed_seconds: float = 0.0
var _match_active: bool = false
var _rounds_played: int = 0

func _ready() -> void:
	process_priority = -100
	_initialize_match.call_deferred()

func _initialize_match() -> void:
	if not player_one_path.is_empty() and has_node(player_one_path):
		_player_one = get_node(player_one_path) as CharacterController
	if not player_two_path.is_empty() and has_node(player_two_path):
		_player_two = get_node(player_two_path) as CharacterController
	if not round_manager_path.is_empty() and has_node(round_manager_path):
		_round_manager = get_node(round_manager_path) as RoundManager

	if GameManager.instance != null and GameManager.instance.selected_player_one_character != null and _player_one != null:
		_player_one = _replace_or_init_character(GameManager.instance.selected_player_one_character, _player_one, false)

	if _player_two != null and GameManager.instance != null and GameManager.instance.selected_player_two_character != null:
		_player_two = _replace_or_init_character(GameManager.instance.selected_player_two_character, _player_two, true)

	if _player_one != null and _player_two != null:
		_player_one.set_opponent(_player_two)
		_player_two.set_opponent(_player_one)

	var camera = get_node_or_null("../BattleCamera") as BattleCamera
	if camera != null and _player_one != null:
		camera.update_fighter_references(_player_one, _player_two)

	var ui = get_node_or_null("../UI/BattleUI") as BattleUI
	if ui != null and _player_one != null:
		ui.update_fighter_references(_player_one, _player_two)

	if _player_one != null:
		_player_one.combo.combo_ended.connect(func(combo): _player_one_highest_combo = maxi(_player_one_highest_combo, combo))
	if _player_two != null:
		_player_two.combo.combo_ended.connect(func(combo): _player_two_highest_combo = maxi(_player_two_highest_combo, combo))

	if _round_manager != null and _player_one != null:
		_round_manager.setup(_player_one, _player_two)
		_round_manager.round_ended.connect(_on_round_ended)

	_start_next_round()

func _replace_or_init_character(p_data: CharacterData, existing_node: CharacterController, is_player_two: bool) -> CharacterController:
	var char_scene = p_data.get_character_scene()
	if char_scene != null:
		var parent = existing_node.get_parent()
		var pos = existing_node.global_position
		var scl = existing_node.scale
		var node_name = existing_node.name
		var child_idx = existing_node.get_index()
		var p1_tex = existing_node.player1_indicator_texture
		var p2_tex = existing_node.player2_indicator_texture

		parent.remove_child(existing_node)
		existing_node.queue_free()

		var new_char = char_scene.instantiate() as CharacterController
		new_char.name = node_name
		new_char.scale = scl
		new_char.is_player_two = is_player_two
		new_char.player1_indicator_texture = p1_tex
		new_char.player2_indicator_texture = p2_tex

		parent.add_child(new_char)
		parent.move_child(new_char, child_idx)
		new_char.global_position = pos

		new_char.initialize_from_data(p_data)
		return new_char
	else:
		existing_node.is_player_two = is_player_two
		existing_node.initialize_from_data(p_data)
		return existing_node

func _process(delta: float) -> void:
	if _match_active:
		_match_elapsed_seconds += delta

func _physics_process(_delta: float) -> void:
	if _player_one != null and _player_two != null:
		CharacterController.separate_fighters(_player_one, _player_two)

func _start_next_round() -> void:
	_match_active = true
	_rounds_played += 1

	if AudioManager.instance != null and AudioManager.instance.battle_bgm != null:
		AudioManager.instance.fade_in_music(AudioManager.instance.battle_bgm, 1.5)

	_round_manager.prepare_round()
	_round_manager.play_intro_sequence(_rounds_played, player_one_rounds_won, player_two_rounds_won)

func _on_round_ended(winner: CharacterController, _was_timeout: bool) -> void:
	_match_active = false

	if winner == _player_one:
		player_one_rounds_won += 1
	elif winner == _player_two:
		player_two_rounds_won += 1

	rounds_score_changed.emit(player_one_rounds_won, player_two_rounds_won)

	if AudioManager.instance != null:
		AudioManager.instance.fade_out_music(1.2)

	if player_one_rounds_won >= rounds_to_win_match:
		_end_match(_player_one, _player_two)
	elif player_two_rounds_won >= rounds_to_win_match:
		_end_match(_player_two, _player_one)
	elif _rounds_played >= Constants.Match.MAX_ROUNDS_IN_MATCH:
		var tiebreak_winner = _player_one if player_one_rounds_won >= player_two_rounds_won else _player_two
		var tiebreak_loser = _player_two if tiebreak_winner == _player_one else _player_one
		_end_match(tiebreak_winner, tiebreak_loser)
	else:
		var timer = get_tree().create_timer(Constants.Match.ROUND_END_DELAY_SECONDS)
		timer.timeout.connect(_start_next_round)

func _end_match(winner: CharacterController, loser: CharacterController) -> void:
	var winner_combo = _player_one_highest_combo if winner == _player_one else _player_two_highest_combo
	var loser_combo = _player_one_highest_combo if loser == _player_one else _player_two_highest_combo

	var p1_custom_name = GameManager.instance.player_one_name if GameManager.instance != null and not GameManager.instance.player_one_name.strip_edges().is_empty() else (winner.data.display_name if winner.data != null else "Player 1")
	var p2_custom_name = GameManager.instance.player_two_name if GameManager.instance != null and not GameManager.instance.player_two_name.strip_edges().is_empty() else (loser.data.display_name if loser.data != null else "Player 2")

	var winner_name = p1_custom_name if winner == _player_one else p2_custom_name
	var loser_name = p1_custom_name if loser == _player_one else p2_custom_name

	if winner_name == loser_name:
		var p1_suffix = " (P1)" if winner == _player_one else " (P2)"
		var p2_suffix = " (P1)" if loser == _player_one else " (P2)"
		winner_name += p1_suffix
		loser_name += p2_suffix

	var snapshot = MatchResultSnapshot.new()
	snapshot.winner_name = winner_name
	snapshot.loser_name = loser_name
	snapshot.winner_character = winner.data
	snapshot.winner_rounds_won = player_one_rounds_won if winner == _player_one else player_two_rounds_won
	snapshot.loser_rounds_won = player_one_rounds_won if loser == _player_one else player_two_rounds_won
	snapshot.winner_highest_combo = winner_combo
	snapshot.loser_highest_combo = loser_combo
	snapshot.match_duration_seconds = _match_elapsed_seconds

	if GameManager.instance != null:
		GameManager.instance.set_last_match_result(snapshot)

	if LeaderboardManager.instance != null:
		LeaderboardManager.instance.record_match_result(winner_name, winner_combo, _match_elapsed_seconds, loser_name, loser_combo)

	if AudioManager.instance != null:
		AudioManager.instance.play_match_win_sfx()

	match_ended.emit(winner)

	var timer = get_tree().create_timer(Constants.Match.ROUND_END_DELAY_SECONDS)
	timer.timeout.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_result())
