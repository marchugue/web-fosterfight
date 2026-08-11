class_name CharacterData
extends Resource

@export var display_name: String = "Unnamed Program"
@export var id: String = "unnamed"
@export var portrait: Texture2D
@export_file("*.tscn") var scene_path: String = ""
@export var scene: PackedScene

func get_character_scene() -> PackedScene:
	if scene != null:
		return scene

	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene

	if not id.is_empty():
		var regex = RegEx.new()
		regex.compile("\\d+")
		var result = regex.search(id)
		if result != null:
			var num = result.get_string()
			var convention_path = "res://Scenes/Components/characters/Character%s.tscn" % num
			if ResourceLoader.exists(convention_path):
				return load(convention_path) as PackedScene

	return null

@export_group("Stats")
@export var max_health: float = 1000.0
@export var move_speed: float = 220.0
@export var jump_force: float = 520.0

@export_group("Attacks")
@export var attack1_data: AttackData
@export var attack2_data: AttackData
@export var attack3_data: AttackData

@export_group("Audio")
@export var sfx_hurt: AudioStream
@export var sfx_ko: AudioStream

@export_group("Animation")
@export var frames: SpriteFrames
@export var animation_names: Dictionary = {
	"idle": "idle",
	"walk": "walk",
	"jump": "jump",
	"run": "run",
	"attack1": "attack1",
	"attack2": "attack2",
	"attack3": "attack3",
	"attack1_1": "attack1",
	"attack1_2": "attack2",
	"attack1_3": "attack3",
	"hurt": "hurt",
	"dead": "dead",
}

@export_group("Command Combos")
@export var command_combos: ComboMoveSet

func get_animation_name(key: String) -> String:
	if animation_names.has(key):
		return str(animation_names[key])

	match key:
		"attack1_1": return get_animation_name("attack1")
		"attack1_2": return get_animation_name("attack2")
		"attack1_3": return get_animation_name("attack3")
		_: return key

func get_attack_data(slot: int) -> AttackData:
	var data: AttackData = null
	match slot:
		1: data = attack1_data
		2: data = attack2_data
		3: data = attack3_data

	if data == null:
		push_warning("Character '%s' slot %d: no attack data yet" % [display_name, slot])
	return data

func has_attack_data() -> bool:
	if attack1_data == null and attack2_data == null and attack3_data == null:
		push_warning("Character '%s': no attack data yet" % display_name)
		return false
	return true
