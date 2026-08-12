extends Node

signal settings_changed

static var instance

var settings: GameSettingsData = GameSettingsData.new()

var player_one_name: String = "Player 1"
var player_two_name: String = "Player 2"

var selected_player_one_character: CharacterData
var selected_player_two_character: CharacterData

var last_match_result: MatchResultSnapshot

func set_last_match_result(result: MatchResultSnapshot) -> void:
	last_match_result = result

func set_player_names(p1: String, p2: String) -> void:
	player_one_name = "Player 1" if p1.strip_edges().is_empty() else p1.strip_edges()
	player_two_name = "Player 2" if p2.strip_edges().is_empty() else p2.strip_edges()

func _ready() -> void:
	instance = self
	load_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F11 or (event.alt_pressed and event.keycode == KEY_ENTER):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var win = get_window()
	if win != null:
		if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
		else:
			win.mode = Window.MODE_FULLSCREEN

func load_settings() -> void:
	const PATH = "res://Resources/Config/GameSettings.tres"
	if ResourceLoader.exists(PATH):
		var loaded = load(PATH) as GameSettingsData
		if loaded != null:
			settings = loaded
	settings_changed.emit()

func save_settings() -> void:
	const PATH = "res://Resources/Config/GameSettings.tres"
	if settings != null:
		ResourceSaver.save(settings, PATH)

func set_selected_characters(player_one: CharacterData, player_two: CharacterData) -> void:
	selected_player_one_character = player_one
	selected_player_two_character = player_two

func go_to_main_menu() -> void: change_scene(Constants.Scenes.MAIN_MENU)
func go_to_program_select() -> void: change_scene(Constants.Scenes.PROGRAM_SELECT)
func go_to_name_entry() -> void: change_scene(Constants.Scenes.NAME_ENTRY)
func go_to_character_select() -> void: change_scene(Constants.Scenes.CHARACTER_SELECT)
func go_to_battle() -> void: change_scene(Constants.Scenes.BATTLE)
func go_to_result() -> void: change_scene(Constants.Scenes.RESULT)
func go_to_leaderboard() -> void: change_scene(Constants.Scenes.LEADERBOARD)

func change_scene(path: String) -> void:
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameManager: failed to change scene to '%s' (%d)." % [path, error])

func quit_game() -> void:
	get_tree().quit()
