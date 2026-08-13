class_name CooldownArcControl
extends Control

## progress: 1.0 = full cooldown (blocked), 0.0 = ready
var progress: float = 0.0
var arc_color: Color = Color(0.4, 0.8, 1.0, 0.85)

func _draw() -> void:
	if progress <= 0.02:
		return

	var center = size * 0.5
	var radius = minf(center.x, center.y) - 2.0
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	var steps: int = 40

	# Filled arc (fan polygon)
	var verts = PackedVector2Array()
	verts.append(center)
	for j in range(steps + 1):
		var a = start_angle + (end_angle - start_angle) * float(j) / float(steps)
		verts.append(center + Vector2(cos(a), sin(a)) * radius)

	var fill_color = arc_color
	fill_color.a = 0.45
	var cols = PackedColorArray()
	for _k in range(verts.size()):
		cols.append(fill_color)
	draw_polygon(verts, cols)

	# Outer arc outline
	draw_arc(center, radius, start_angle, end_angle, steps, arc_color, 3.0, true)

func _process(_delta: float) -> void:
	if progress > 0.0:
		queue_redraw()
