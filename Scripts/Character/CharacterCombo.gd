class_name CharacterCombo
extends Node

signal combo_changed(count: int)
signal combo_ended(final_count: int)

var current_combo: int = 0
var current_gravity_scale: float = 1.0

var next_hitstun_multiplier: float:
	get:
		if current_combo <= 0:
			return 1.0
		return pow(Constants.Combat.HITSTUN_DETERIORATION_BASE, current_combo)

func register_hit() -> void:
	current_combo += 1
	_recalculate_gravity_scale()
	combo_changed.emit(current_combo)

func end_combo() -> void:
	var final_count = current_combo
	current_combo = 0
	current_gravity_scale = 1.0

	if final_count > 0:
		combo_ended.emit(final_count)
	combo_changed.emit(current_combo)

func _recalculate_gravity_scale() -> void:
	var raw = 1.0 + Constants.Combat.GRAVITY_SCALE_PER_COMBO_HIT * (current_combo - 1)
	current_gravity_scale = minf(raw, Constants.Combat.MAX_COMBO_GRAVITY_SCALE)

func reset_for_new_round() -> void:
	current_combo = 0
	current_gravity_scale = 1.0
	combo_changed.emit(current_combo)
