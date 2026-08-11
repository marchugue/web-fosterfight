class_name ResultUI
extends Control

@export var winner_label_path: NodePath = "%WinnerLabel"
@export var rounds_won_label_path: NodePath = "%RoundsWonLabel"
@export var combo_label_path: NodePath = "%ComboLabel"
@export var winner_idle_preview_path: NodePath = "%WinnerIdlePreview"
@export var play_again_button_path: NodePath = "%PlayAgainButton"
@export var main_menu_button_path: NodePath = "%MainMenuButton"
@export var leaderboard_button_path: NodePath = "%LeaderboardButton"

func _ready() -> void:
	var result = GameManager.instance.last_match_result if GameManager.instance != null else null

	var winner_label = get_node(winner_label_path) as Label
	var rounds_label = get_node(rounds_won_label_path) as Label
	var combo_label = get_node(combo_label_path) as Label
	var winner_anim = get_node_or_null(winner_idle_preview_path) as AnimatedSprite2D

	if result != null:
		winner_label.text = "%s Wins!" % result.winner_name
		rounds_label.text = "Rounds: %d - %d" % [result.winner_rounds_won, result.loser_rounds_won]
		combo_label.text = "Highest Combo: %d (%s)" % [result.winner_highest_combo, result.winner_name]
	else:
		winner_label.text = "No match data"
		rounds_label.text = ""
		combo_label.text = ""

	var winner_data: CharacterData = null
	if result != null and result.winner_character != null:
		winner_data = result.winner_character
	elif GameManager.instance != null and GameManager.instance.selected_player_one_character != null:
		winner_data = GameManager.instance.selected_player_one_character
	else:
		winner_data = load("res://Resources/Characters/character1.tres") as CharacterData

	if winner_data != null and winner_anim != null and winner_data.frames != null:
		winner_anim.stop()
		winner_anim.sprite_frames = winner_data.frames
		var idle_anim = winner_data.get_animation_name("idle")
		var anim_to_play = idle_anim if winner_data.frames.has_animation(idle_anim) else ("idle" if winner_data.frames.has_animation("idle") else "")
		if not anim_to_play.is_empty():
			winner_anim.play(anim_to_play)

	var play_again = get_node(play_again_button_path) as Button
	play_again.pressed.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_character_select())

	var main_menu = get_node(main_menu_button_path) as Button
	main_menu.pressed.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_main_menu())

	var leaderboard = get_node(leaderboard_button_path) as Button
	leaderboard.pressed.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_leaderboard())

	if AudioManager.instance != null:
		AudioManager.instance.play_menu_music()
