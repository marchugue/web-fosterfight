class_name TimerComponent
extends Control

@export var label_path: NodePath = "%TimeLabel"

var _label: Label

func _ready() -> void:
	if not label_path.is_empty():
		_label = get_node_or_null(label_path) as Label

func set_time(remaining_seconds: float) -> void:
	if _label != null:
		_label.text = Extensions.to_timer_label(remaining_seconds)
