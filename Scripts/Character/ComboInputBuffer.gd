class_name ComboInputBuffer
extends RefCounted

class Entry extends RefCounted:
	var token: ComboInputToken.Type
	var age: float = 0.0

var _entries: Array[Entry] = []

func clear() -> void:
	_entries.clear()

func record(input: FrameInput) -> void:
	if input.attack1: _add(ComboInputToken.Type.ATTACK1)
	if input.attack2: _add(ComboInputToken.Type.ATTACK2)
	if input.attack3: _add(ComboInputToken.Type.ATTACK3)

func _add(token: ComboInputToken.Type) -> void:
	var e = Entry.new()
	e.token = token
	e.age = 0.0
	_entries.append(e)

func tick(delta: float, max_age: float) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		_entries[i].age += delta
		if _entries[i].age > max_age:
			_entries.remove_at(i)

func contains_all_within_window(required: Array[ComboInputToken.Type], window_seconds: float) -> bool:
	if required.is_empty():
		return false

	var min_age: float = 999999.0
	var max_age: float = -999999.0

	for token in required:
		var idx = _find_newest_entry_index(token)
		if idx < 0:
			return false

		var age = _entries[idx].age
		min_age = minf(min_age, age)
		max_age = maxf(max_age, age)

	return max_age <= window_seconds and (max_age - min_age) <= window_seconds

func consume(tokens: Array[ComboInputToken.Type]) -> void:
	for token in tokens:
		_remove_newest(token)

func try_take_expired(window_seconds: float) -> Dictionary:
	# Returns { "success": bool, "token": ComboInputToken.Type }
	var oldest_index: int = -1
	var oldest_age: float = -1.0

	for i in range(_entries.size()):
		if _entries[i].age >= window_seconds and _entries[i].age > oldest_age:
			oldest_age = _entries[i].age
			oldest_index = i

	if oldest_index < 0:
		return { "success": false, "token": ComboInputToken.Type.ATTACK1 }

	var tok = _entries[oldest_index].token
	_entries.remove_at(oldest_index)
	return { "success": true, "token": tok }

func _find_newest_entry_index(token: ComboInputToken.Type) -> int:
	var newest_index: int = -1
	var newest_age: float = 999999.0

	for i in range(_entries.size()):
		if _entries[i].token != token:
			continue
		if _entries[i].age < newest_age:
			newest_age = _entries[i].age
			newest_index = i

	return newest_index

func _remove_newest(token: ComboInputToken.Type) -> void:
	var index = _find_newest_entry_index(token)
	if index >= 0:
		_entries.remove_at(index)
