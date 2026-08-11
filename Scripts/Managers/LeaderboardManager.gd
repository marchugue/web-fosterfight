extends Node

signal leaderboard_data_ready(records: Array, is_online: bool)

static var instance: Node

var is_online_mode: bool = true

var _db: SQLiteManager
var _players: PlayerRepository
var _matches: MatchRepository
var _cloud_client: CloudDatabaseClient

func _ready() -> void:
	instance = self
	_db = SQLiteManager.new()
	_players = PlayerRepository.new(_db)
	_matches = MatchRepository.new(_db)

	_cloud_client = CloudDatabaseClient.new()
	_cloud_client.name = "CloudDatabaseClient"
	_cloud_client.leaderboard_fetched.connect(_on_cloud_leaderboard_fetched)
	add_child(_cloud_client)

func record_match_result(winner_name: String, winner_combo: int, win_time_seconds: float, loser_name: String, loser_combo: int) -> void:
	var played_at = Time.get_datetime_string_from_system(true) + "Z"

	# Always save to local offline JSON database
	_players.upsert_after_match(winner_name, true, winner_combo, win_time_seconds, played_at)
	_matches.insert_match(winner_name, true, winner_combo, win_time_seconds, played_at)

	_players.upsert_after_match(loser_name, false, loser_combo, null, played_at)
	_matches.insert_match(loser_name, false, loser_combo, null, played_at)

	# Also post to Cloud DB
	if _cloud_client != null:
		_cloud_client.record_match(winner_name, winner_combo, win_time_seconds, loser_name, loser_combo)

func request_leaderboard(mode_name: String = "Wins", limit: int = 50, use_online: bool = true) -> void:
	is_online_mode = use_online
	if is_online_mode and _cloud_client != null:
		_cloud_client.fetch_top_players(mode_name, limit)
	else:
		var local_records = _players.get_top_players(limit, mode_name)
		leaderboard_data_ready.emit(local_records, false)

func get_top_players_by_wins(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "Wins")

func get_top_players_by_combo(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "HighestCombo")

func get_top_players_by_fastest_win(limit: int = 10) -> Array:
	return _players.get_top_players(limit, "FastestWinSeconds")

func _on_cloud_leaderboard_fetched(records: Array, is_online: bool) -> void:
	if is_online and not records.is_empty():
		leaderboard_data_ready.emit(records, true)
	else:
		# Fallback to local offline records if cloud request returned empty or failed
		var local_records = _players.get_top_players(50, "Wins")
		leaderboard_data_ready.emit(local_records, false)
