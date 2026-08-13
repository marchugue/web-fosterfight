class_name CancelManager
extends Node

func can_cancel(
	_current_attack: AttackData,
	_hitbox_was_active: bool,
	_has_connected: bool,
	_requested_input: CharacterCombat.AttackInput
) -> bool:
	# Attacks cannot be cancelled mid-animation
	return false

func can_jump_cancel(_current_attack: AttackData, _hitbox_was_active: bool, _has_connected: bool) -> bool:
	# Attacks cannot be jump-cancelled mid-animation
	return false

static func is_move_allowed(_current_attack: AttackData, _requested_input: CharacterCombat.AttackInput) -> bool:
	return false

func reset_for_new_round() -> void:
	pass
