extends Node

static var instance

var _db: SQLiteManager
var _players: PlayerRepository
var _matches: MatchRepository

func _ready() -> void:
	instance = self
	_db = SQLiteManager.new()
	_players = PlayerRepository.new(_db)
	_matches = MatchRepository.new(_db)

func record_match_result(winner_name: String, winner_combo: int, win_time_seconds: float, loser_name: String, loser_combo: int) -> void:
	var played_at = Time.get_datetime_string_from_system(true) + "Z"

	_players.upsert_after_match(winner_name, true, winner_combo, win_time_seconds, played_at)
	_matches.insert_match(winner_name, true, winner_combo, win_time_seconds, played_at)

	_players.upsert_after_match(loser_name, false, loser_combo, null, played_at)
	_matches.insert_match(loser_name, false, loser_combo, null, played_at)

func get_top_players_by_wins(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "Wins")

func get_top_players_by_combo(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "HighestCombo")

func get_top_players_by_fastest_win(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "FastestWinSeconds")
