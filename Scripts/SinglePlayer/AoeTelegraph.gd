class_name AoeTelegraph
extends Node2D

@export var radius: float = 80.0
@export var duration: float = 0.75
@export var fill_color: Color = Color(1.0, 0.28, 0.12, 0.28)
@export var ring_color: Color = Color(1.0, 0.55, 0.2, 0.85)

func _ready() -> void:
	z_index = 15
	queue_redraw()
	modulate.a = 0.2
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.95, duration * 0.35)
	tween.tween_property(self, "modulate:a", 0.55, duration * 0.65)
	get_tree().create_timer(duration).timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, ring_color, 3.0, true)
