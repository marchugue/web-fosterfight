class_name CharacterEnergy
extends Node

signal energy_changed(current: float, max_val: float)

var max_energy: float = Constants.Combat.MAX_ENERGY
var current_energy: float = 0.0

func initialize(p_max_energy: float = Constants.Combat.MAX_ENERGY) -> void:
	max_energy = p_max_energy
	current_energy = 0.0
	energy_changed.emit(current_energy, max_energy)

func add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	current_energy = Extensions.clamp_positive(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)

func has_enough(cost: float) -> bool:
	return current_energy >= cost

func try_spend(cost: float) -> bool:
	if not has_enough(cost):
		return false

	current_energy = Extensions.clamp_positive(current_energy - cost, max_energy)
	energy_changed.emit(current_energy, max_energy)
	return true

func reset_for_new_round() -> void:
	current_energy = 0.0
	energy_changed.emit(current_energy, max_energy)
