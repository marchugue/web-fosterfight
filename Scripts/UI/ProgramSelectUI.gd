class_name ProgramSelectUI
extends Control

@export var versus_button_path: NodePath = "%VersusButton"
@export var cpu_button_path: NodePath = "%CpuButton"
@export var back_button_path: NodePath = "%BackButton"

func _ready() -> void:
	var versus_btn = get_node(versus_button_path) as Button
	versus_btn.pressed.connect(_on_versus_pressed)
	versus_btn.grab_focus()

	var back_btn = get_node(back_button_path) as Button
	back_btn.pressed.connect(_on_back_pressed)

	var cpu_btn = get_node(cpu_button_path) as Button
	if cpu_btn != null:
		cpu_btn.disabled = false
		cpu_btn.pressed.connect(_on_cpu_pressed)

func _on_versus_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_name_entry()

func _on_cpu_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_single_player()

func _on_back_pressed() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_main_menu()
