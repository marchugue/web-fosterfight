class_name Extensions
extends RefCounted

static func clamp_positive(value: float, max_val: float) -> float:
	return clampf(value, 0.0, max_val)

static func is_between(value: float, min_val: float, max_val: float) -> bool:
	return value >= min_val and value <= max_val

static func to_facing_direction(horizontal: float, current_facing: int) -> int:
	if horizontal > 0.1:
		return 1
	if horizontal < -0.1:
		return -1
	return current_facing

static func to_timer_label(seconds: float) -> String:
	var whole: int = int(ceil(maxf(seconds, 0.0)))
	return str(whole)

static func get_node_or_warn(parent: Node, path: NodePath) -> Node:
	var node = parent.get_node_or_null(path)
	if node == null:
		push_warning("[%s] Expected node at '%s' but found none." % [parent.name, path])
	return node
