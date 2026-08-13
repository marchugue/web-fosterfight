class_name CommandComboSystem
extends Node

signal command_combo_started(move_name: String)

var _moves: Array[ComboMoveData] = []
var _tracked_moves: Array[ComboMoveData] = []
var _progress: Dictionary = {} # ComboMoveData -> int
var _buffer: ComboInputBuffer = ComboInputBuffer.new()
var _sequence_time_remaining: float = 0.0

static var input_buffer_seconds: float:
	get: return Constants.Combat.COMMAND_COMBO_INPUT_BUFFER_SECONDS

func load_for_character(data: CharacterData) -> void:
	_moves.clear()
	_tracked_moves.clear()
	_progress.clear()
	_buffer.clear()
	_sequence_time_remaining = 0.0

	if data.command_combos != null:
		_add_moves_from_set(data.command_combos)

	_load_moves_from_folder("res://Resources/Combos/%s" % data.id)
	_load_moves_from_folder("res://Resources/Combos/Shared")

	for move in _moves:
		var steps = ComboInputParser.parse_sequence(move.input_sequence)
		if steps.size() > 1:
			_tracked_moves.append(move)
			_progress[move] = 0

func reset_for_new_round() -> void:
	for move in _tracked_moves:
		_progress[move] = 0

	_buffer.clear()
	_sequence_time_remaining = 0.0

func update_buffer(delta: float) -> void:
	_buffer.tick(delta, input_buffer_seconds)
	_tick_sequence_timer(delta)

func try_execute(input: FrameInput, combat: CharacterCombat, energy: CharacterEnergy) -> bool:
	if combat.is_attacking:
		return false

	if ComboInputParser.has_any_attack_just_pressed(input):
		_buffer.record(input)
	else:
		return false

	var simultaneous_move = _find_simultaneous_move(input)
	if simultaneous_move != null:
		return _start_move(simultaneous_move, combat, energy)

	var seq_res = _advance_sequential_moves(input)
	var sequential_move = seq_res.completed
	var made_progress = seq_res.made_progress

	if sequential_move != null:
		return _start_move(sequential_move, combat, energy)

	if made_progress or _has_pending_simultaneous_chord(input):
		return true

	return false

func try_release_expired_buffer(combat: CharacterCombat, energy: CharacterEnergy) -> bool:
	if combat.is_attacking:
		return false

	var res = _buffer.try_take_expired(input_buffer_seconds)
	if not res.success:
		return false

	return combat.try_start_attack(ComboInputParser.token_to_attack_input(res.token), energy)

func _start_move(move: ComboMoveData, combat: CharacterCombat, energy: CharacterEnergy) -> bool:
	if not combat.try_start_command_move(move, energy):
		return false

	var steps = ComboInputParser.parse_sequence(move.input_sequence)
	if steps.size() == 1:
		_buffer.consume(steps[0])
	else:
		_buffer.clear()

	_reset_sequential_progress()
	command_combo_started.emit(move.move_name)
	return true

func _find_simultaneous_move(input: FrameInput) -> ComboMoveData:
	for move in _moves:
		var steps = ComboInputParser.parse_sequence(move.input_sequence)
		if steps.size() != 1 or steps[0].size() <= 1:
			continue

		if ComboInputParser.matches_step(input, steps[0]) or _buffer.contains_all_within_window(steps[0], input_buffer_seconds):
			return move

	return null

func _has_pending_simultaneous_chord(input: FrameInput) -> bool:
	for move in _moves:
		var steps = ComboInputParser.parse_sequence(move.input_sequence)
		if steps.size() != 1 or steps[0].size() <= 1:
			continue

		if _buffer.contains_all_within_window(steps[0], input_buffer_seconds):
			continue

		for token in steps[0]:
			if ComboInputParser.is_just_pressed(input, token):
				return true

	return false

func _advance_sequential_moves(input: FrameInput) -> Dictionary:
	# Returns { "completed": ComboMoveData, "made_progress": bool }
	var completed_move: ComboMoveData = null
	var made_progress = false

	for move in _tracked_moves:
		var steps = ComboInputParser.parse_sequence(move.input_sequence)
		var index: int = _progress.get(move, 0)

		if index >= steps.size():
			_progress[move] = 0
			index = 0

		if not ComboInputParser.matches_step(input, steps[index]):
			_progress[move] = 0
			continue

		index += 1
		_progress[move] = index
		_sequence_time_remaining = Constants.Combat.COMMAND_COMBO_SEQUENCE_SECONDS
		made_progress = true

		if index >= steps.size():
			completed_move = move
			_progress[move] = 0

	return { "completed": completed_move, "made_progress": made_progress }

func _tick_sequence_timer(delta: float) -> void:
	if _sequence_time_remaining <= 0.0:
		return

	_sequence_time_remaining -= delta
	if _sequence_time_remaining <= 0.0:
		_reset_sequential_progress()

func _reset_sequential_progress() -> void:
	for move in _tracked_moves:
		_progress[move] = 0
	_sequence_time_remaining = 0.0

func _add_moves_from_set(move_set: ComboMoveSet) -> void:
	for move in move_set.moves:
		if move != null and not _moves.has(move):
			_moves.append(move)

func _load_moves_from_folder(folder_path: String) -> void:
	var dir = DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while not entry.is_empty():
		var clean_entry = entry
		if clean_entry.ends_with(".remap"):
			clean_entry = clean_entry.trim_suffix(".remap")
		if clean_entry.ends_with(".import"):
			entry = dir.get_next()
			continue
		if not dir.current_is_dir() and clean_entry.ends_with(".tres"):
			var res = load("%s/%s" % [folder_path, clean_entry])
			if res is ComboMoveData and not _moves.has(res):
				_moves.append(res)
			elif res is ComboMoveSet:
				_add_moves_from_set(res)
		entry = dir.get_next()
	dir.list_dir_end()
