class_name MainMenuUI
extends Control

@export var start_button_path: NodePath = "%StartButton"
@export var leaderboard_button_path: NodePath = "%LeaderboardButton"
@export var exit_button_path: NodePath = "%ExitButton"

func _ready() -> void:
	var start = get_node_or_null(start_button_path) as BaseButton
	var leaderboard = get_node_or_null(leaderboard_button_path) as BaseButton
	var exit = get_node_or_null(exit_button_path) as BaseButton

	if start != null: start.pressed.connect(_on_start_pressed)
	if leaderboard != null: leaderboard.pressed.connect(_on_leaderboard_pressed)
	if exit != null: exit.pressed.connect(_on_exit_pressed)

	if start != null:
		start.grab_focus()

	if AudioManager.instance != null:
		AudioManager.instance.play_menu_music()

func _on_start_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_program_select()

func _on_leaderboard_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_leaderboard()

func _on_exit_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.quit_game()
