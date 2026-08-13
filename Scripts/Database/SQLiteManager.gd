class_name SQLiteManager
extends RefCounted

const SAVE_PATH = "user://leaderboard_db.json"

var _data: Dictionary = {
	"players": {},
	"matches": []
}

func _init(_db_path: String = Constants.Database.LEADERBOARD_DB_PATH) -> void:
	load_db()

func load_db() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_str) == OK and json.data is Dictionary:
				_data = json.data
				if not _data.has("players"): _data["players"] = {}
				if not _data.has("matches"): _data["matches"] = []

func save_db() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		var json_str = JSON.stringify(_data, "\t")
		file.store_string(json_str)
		file.close()

func get_players() -> Dictionary:
	return _data["players"]

func get_matches() -> Array:
	return _data["matches"]
