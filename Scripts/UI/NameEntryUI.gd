class_name NameEntryUI
extends Control

@export var p1_name_input_path: NodePath = "%P1NameInput"
@export var p2_name_input_path: NodePath = "%P2NameInput"
@export var confirm_button_path: NodePath = "%ConfirmButton"
@export var back_button_path: NodePath = "%BackButton"

var _p1_name_input: LineEdit
var _p2_name_input: LineEdit

func _ready() -> void:
	_p1_name_input = get_node_or_null(p1_name_input_path) as LineEdit
	_p2_name_input = get_node_or_null(p2_name_input_path) as LineEdit

	var is_sp = (GameManager.instance != null and GameManager.instance.is_single_player_mode)

	if is_sp:
		var title_lbl = get_node_or_null("Title") as Label
		if title_lbl != null:
			title_lbl.text = "ENTER HERO NAME"

		var p1_label = get_node_or_null("MainPanel/TextureRect2/P1Label") as Label
		if p1_label != null:
			p1_label.text = "HERO NAME"

		if _p1_name_input != null:
			_p1_name_input.placeholder_text = "Enter Hero Name..."

		var p2_container = get_node_or_null("MainPanel/TextureRect3") as Control
		if p2_container != null:
			p2_container.visible = false

		var p1_container = get_node_or_null("MainPanel/TextureRect2") as Control
		if p1_container != null:
			p1_container.position.y = 135.0

	if GameManager.instance != null:
		if _p1_name_input != null:
			_p1_name_input.text = GameManager.instance.player_one_name
		if not is_sp and _p2_name_input != null:
			_p2_name_input.text = GameManager.instance.player_two_name

	var confirm_btn = get_node_or_null(confirm_button_path) as BaseButton
	if confirm_btn != null:
		confirm_btn.pressed.connect(_on_confirm)

	var back_btn = get_node_or_null(back_button_path) as BaseButton
	if back_btn != null:
		back_btn.pressed.connect(_on_back)

	if _p1_name_input != null:
		_p1_name_input.text_submitted.connect(func(_text): _on_confirm())
	if not is_sp and _p2_name_input != null:
		_p2_name_input.text_submitted.connect(func(_text): _on_confirm())

	if _p1_name_input != null:
		_p1_name_input.grab_focus()

	if AudioManager.instance != null:
		AudioManager.instance.play_menu_music()

func _on_confirm() -> void:
	var p1_text = _p1_name_input.text.strip_edges() if _p1_name_input != null else ""
	var p1 = "Player 1" if p1_text.is_empty() else p1_text

	if GameManager.instance != null:
		if GameManager.instance.is_single_player_mode:
			GameManager.instance.set_player_names(p1, "CPU")
			GameManager.instance.go_to_single_player()
		else:
			var p2_text = _p2_name_input.text.strip_edges() if _p2_name_input != null else ""
			var p2 = "Player 2" if p2_text.is_empty() else p2_text
			GameManager.instance.set_player_names(p1, p2)
			GameManager.instance.go_to_character_select()

func _on_back() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_program_select()
