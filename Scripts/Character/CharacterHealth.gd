class_name CharacterHealth
extends Node

signal health_changed(current: float, max_val: float)
signal knocked_out

var max_health: float = 1000.0
var current_health: float = 1000.0

var is_knocked_out: bool:
	get: return current_health <= 0.0

func initialize(p_max_health: float) -> void:
	max_health = p_max_health
	current_health = p_max_health
	health_changed.emit(current_health, max_health)

func apply_damage(amount: float) -> void:
	if is_knocked_out or amount <= 0.0:
		return

	current_health = Extensions.clamp_positive(current_health - amount, max_health)
	health_changed.emit(current_health, max_health)

	if is_knocked_out:
		knocked_out.emit()

func reset_for_new_round() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
