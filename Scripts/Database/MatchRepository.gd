class_name MatchRepository
extends RefCounted

var _db: SQLiteManager

func _init(db: SQLiteManager) -> void:
	_db = db

func insert_match(player_name: String, won: bool, combo_achieved: int, win_time_seconds, played_at_iso: String) -> void:
	var matches = _db.get_matches()
	matches.append({
		"player_name": player_name,
		"won": won,
		"combo_achieved": combo_achieved,
		"win_time_seconds": win_time_seconds,
		"played_at": played_at_iso
	})
	_db.save_db()

func get_recent_matches(player_name: String, limit: int = 10) -> Array:
	var matches = _db.get_matches()
	var filtered: Array = []
	for m in matches:
		if m.get("player_name") == player_name:
			filtered.append(m)

	filtered.reverse()
	if filtered.size() > limit:
		return filtered.slice(0, limit)
	return filtered
