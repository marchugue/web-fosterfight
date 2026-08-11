class_name NameEntryUI
extends Control

@export var p1_name_input_path: NodePath = "%P1NameInput"
@export var p2_name_input_path: NodePath = "%P2NameInput"
@export var confirm_button_path: NodePath = "%ConfirmButton"
@export var back_button_path: NodePath = "%BackButton"

var _p1_name_input: LineEdit
var _p2_name_input: LineEdit

func _ready() -> void:
	_p1_name_input = get_node(p1_name_input_path) as LineEdit
	_p2_name_input = get_node(p2_name_input_path) as LineEdit

	if GameManager.instance != null:
		_p1_name_input.text = GameManager.instance.player_one_name
		_p2_name_input.text = GameManager.instance.player_two_name

	var confirm_btn = get_node_or_null(confirm_button_path) as BaseButton
	if confirm_btn != null:
		confirm_btn.pressed.connect(_on_confirm)

	var back_btn = get_node_or_null(back_button_path) as BaseButton
	if back_btn != null:
		back_btn.pressed.connect(_on_back)

	_p1_name_input.text_submitted.connect(func(_text): _on_confirm())
	_p2_name_input.text_submitted.connect(func(_text): _on_confirm())

	_p1_name_input.grab_focus()

	if AudioManager.instance != null:
		AudioManager.instance.play_menu_music()

func _on_confirm() -> void:
	var p1 = "Player 1" if _p1_name_input.text.strip_edges().is_empty() else _p1_name_input.text.strip_edges()
	var p2 = "Player 2" if _p2_name_input.text.strip_edges().is_empty() else _p2_name_input.text.strip_edges()

	if GameManager.instance != null:
		GameManager.instance.set_player_names(p1, p2)
		GameManager.instance.go_to_character_select()

func _on_back() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_program_select()
