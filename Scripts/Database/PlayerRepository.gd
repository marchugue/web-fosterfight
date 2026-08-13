class_name PlayerRepository
extends RefCounted

var _db: SQLiteManager

func _init(db: SQLiteManager) -> void:
	_db = db

func upsert_after_match(player_name: String, won: bool, combo_achieved: int, win_time_seconds, played_at_iso: String) -> void:
	var players = _db.get_players()

	if not players.has(player_name):
		players[player_name] = {
			"player_name": player_name,
			"wins": 0,
			"losses": 0,
			"matches_played": 0,
			"highest_combo": 0,
			"fastest_win_seconds": null,
			"sp_fastest_win_seconds": null,
			"last_played_date": null
		}

	var rec = players[player_name]
	if won:
		rec["wins"] = int(rec["wins"]) + 1
	else:
		rec["losses"] = int(rec["losses"]) + 1

	rec["matches_played"] = int(rec["matches_played"]) + 1
	rec["highest_combo"] = maxi(int(rec.get("highest_combo", 0)), combo_achieved)

	if win_time_seconds != null:
		var w_time = float(win_time_seconds)
		if rec.get("fastest_win_seconds") == null or w_time < float(rec["fastest_win_seconds"]):
			rec["fastest_win_seconds"] = w_time

	rec["last_played_date"] = played_at_iso
	_db.save_db()

func upsert_sp_clear(player_name: String, clear_time_seconds: float, played_at_iso: String) -> void:
	var players = _db.get_players()

	if not players.has(player_name):
		players[player_name] = {
			"player_name": player_name,
			"wins": 0,
			"losses": 0,
			"matches_played": 0,
			"highest_combo": 0,
			"fastest_win_seconds": null,
			"sp_fastest_win_seconds": null,
			"last_played_date": null
		}

	var rec = players[player_name]
	var cur_sp = rec.get("sp_fastest_win_seconds", null)
	if cur_sp == null or clear_time_seconds < float(cur_sp):
		rec["sp_fastest_win_seconds"] = clear_time_seconds

	rec["last_played_date"] = played_at_iso
	_db.save_db()

func get_top_players(limit: int = 10, order_by_column: String = "Wins") -> Array:
	var players = _db.get_players()
	var list: Array = []
	for name_key in players:
		list.append(players[name_key])

	match order_by_column:
		"Wins":
			list.sort_custom(func(a, b): return int(a.get("wins", 0)) > int(b.get("wins", 0)))
		"HighestCombo":
			list.sort_custom(func(a, b): return int(a.get("highest_combo", 0)) > int(b.get("highest_combo", 0)))
		"FastestWinSeconds":
			list.sort_custom(func(a, b):
				var a_sec = a.get("fastest_win_seconds")
				var b_sec = b.get("fastest_win_seconds")
				if a_sec == null and b_sec == null: return false
				if a_sec == null: return false
				if b_sec == null: return true
				return float(a_sec) < float(b_sec)
			)
		"SPFastestWinSeconds":
			list.sort_custom(func(a, b):
				var a_sec = a.get("sp_fastest_win_seconds")
				var b_sec = b.get("sp_fastest_win_seconds")
				if a_sec == null and b_sec == null: return false
				if a_sec == null: return false
				if b_sec == null: return true
				return float(a_sec) < float(b_sec)
			)
		_:
			list.sort_custom(func(a, b): return int(a.get("wins", 0)) > int(b.get("wins", 0)))

	if list.size() > limit:
		return list.slice(0, limit)
	return list
