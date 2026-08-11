class_name ComboInputParser
extends RefCounted

static func try_parse_token(raw: String) -> Dictionary:
	# Returns { "success": bool, "token": ComboInputToken.Type }
	if raw.strip_edges().is_empty():
		return { "success": false, "token": ComboInputToken.Type.ATTACK1 }

	var normalized = raw.strip_edges().to_lower()
	match normalized:
		"a1", "4", "j", "attack1", "attack_1":
			return { "success": true, "token": ComboInputToken.Type.ATTACK1 }
		"a2", "5", "k", "attack2", "attack_2":
			return { "success": true, "token": ComboInputToken.Type.ATTACK2 }
		"a3", "6", "l", "attack3", "attack_3":
			return { "success": true, "token": ComboInputToken.Type.ATTACK3 }
		_:
			return { "success": false, "token": ComboInputToken.Type.ATTACK1 }

static func parse_sequence(sequence: String) -> Array[Array]:
	var steps: Array[Array] = []
	if sequence.strip_edges().is_empty():
		return steps

	var normalized = sequence.strip_edges().to_lower()
	var step_parts = normalized.split(">", false)

	for step_part in step_parts:
		var raw_tokens = step_part.strip_edges().replace(",", "+").split("+", false)
		var tokens: Array[ComboInputToken.Type] = []

		for t_part in raw_tokens:
			var res = try_parse_token(t_part)
			if res.success:
				tokens.append(res.token)

		if not tokens.is_empty():
			steps.append(tokens)

	return steps

static func matches_step(input: FrameInput, step_tokens: Array[ComboInputToken.Type]) -> bool:
	if step_tokens.is_empty():
		return false

	for token in step_tokens:
		if not is_just_pressed(input, token):
			return false

	return true

static func has_any_attack_just_pressed(input: FrameInput) -> bool:
	return input.attack1 or input.attack2 or input.attack3

static func is_just_pressed(input: FrameInput, token: ComboInputToken.Type) -> bool:
	match token:
		ComboInputToken.Type.ATTACK1: return input.attack1
		ComboInputToken.Type.ATTACK2: return input.attack2
		ComboInputToken.Type.ATTACK3: return input.attack3
		_: return false

static func token_to_attack_input(token: ComboInputToken.Type) -> CharacterCombat.AttackInput:
	match token:
		ComboInputToken.Type.ATTACK1: return CharacterCombat.AttackInput.ATTACK1
		ComboInputToken.Type.ATTACK2: return CharacterCombat.AttackInput.ATTACK2
		ComboInputToken.Type.ATTACK3: return CharacterCombat.AttackInput.ATTACK3
		_: return CharacterCombat.AttackInput.ATTACK1
