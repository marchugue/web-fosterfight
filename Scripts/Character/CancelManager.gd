class_name CancelManager
extends Node

func can_cancel(
	current_attack: AttackData,
	hitbox_was_active: bool,
	has_connected: bool,
	requested_input: CharacterCombat.AttackInput
) -> bool:
	if current_attack == null:
		return false

	if not current_attack.can_cancel_after_hit:
		return false

	var is_light_string = current_attack.light_attack_string_cancel and requested_input == CharacterCombat.AttackInput.ATTACK1

	if not has_connected and not is_light_string:
		return false

	if not hitbox_was_active and not is_light_string:
		return false

	return is_move_allowed(current_attack, requested_input)

func can_jump_cancel(current_attack: AttackData, hitbox_was_active: bool, has_connected: bool) -> bool:
	if current_attack == null or not current_attack.can_cancel_after_hit:
		return false

	return has_connected and hitbox_was_active

static func is_move_allowed(current_attack: AttackData, requested_input: CharacterCombat.AttackInput) -> bool:
	if current_attack.light_attack_string_cancel and requested_input == CharacterCombat.AttackInput.ATTACK1:
		return true

	return current_attack.is_cancel_target_allowed(int(requested_input))

func reset_for_new_round() -> void:
	pass
