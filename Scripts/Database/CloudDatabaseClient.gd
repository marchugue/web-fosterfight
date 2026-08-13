class_name CloudDatabaseClient
extends Node

signal leaderboard_fetched(records: Array, is_online: bool)
signal match_recorded(success: bool)

const DEFAULT_SERVER_URL = "https://web-fosterfight.vercel.app"

var _http_fetch: HTTPRequest
var _http_post: HTTPRequest

func _ready() -> void:
	_http_fetch = HTTPRequest.new()
	_http_fetch.timeout = 5.0
	_http_fetch.request_completed.connect(_on_fetch_completed)
	add_child(_http_fetch)

	_http_post = HTTPRequest.new()
	_http_post.timeout = 5.0
	_http_post.request_completed.connect(_on_post_completed)
	add_child(_http_post)

func fetch_top_players(mode: String = "Wins", limit: int = 50) -> void:
	var base_url = _get_base_url()
	var url = "%s/api/leaderboard?mode=%s&limit=%d" % [base_url, mode, limit]
	var headers = ["Content-Type: application/json"]
	var err = _http_fetch.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		leaderboard_fetched.emit([], false)

func record_match(winner_name: String, winner_combo: int, win_time_seconds: float, loser_name: String, loser_combo: int) -> void:
	var base_url = _get_base_url()
	var url = "%s/api/match" % base_url
	var headers = ["Content-Type: application/json"]
	var payload = {
		"winner_name": winner_name,
		"winner_combo": winner_combo,
		"win_time_seconds": win_time_seconds,
		"loser_name": loser_name,
		"loser_combo": loser_combo
	}
	var json_str = JSON.stringify(payload)
	var err = _http_post.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		match_recorded.emit(false)

func record_sp_clear(player_name: String, sp_clear_time_seconds: float) -> void:
	var base_url = _get_base_url()
	var url = "%s/api/match" % base_url
	var headers = ["Content-Type: application/json"]
	var payload = {
		"player_name": player_name,
		"is_singleplayer": true,
		"sp_clear_time_seconds": sp_clear_time_seconds
	}
	var json_str = JSON.stringify(payload)
	var err = _http_post.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		match_recorded.emit(false)

func _get_base_url() -> String:
	if OS.has_feature("web"):
		return ""
	return DEFAULT_SERVER_URL

func _on_fetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		leaderboard_fetched.emit([], false)
		return

	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK or not (json.data is Dictionary):
		leaderboard_fetched.emit([], false)
		return

	var dict = json.data as Dictionary
	var online = dict.get("online", false)
	var records = dict.get("records", [])
	leaderboard_fetched.emit(records if records is Array else [], online)

func _on_post_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		match_recorded.emit(true)
	else:
		match_recorded.emit(false)
