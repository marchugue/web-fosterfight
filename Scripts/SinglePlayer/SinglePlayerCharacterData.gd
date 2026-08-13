class_name SinglePlayerCharacterData
extends Resource

@export_group("Identity")
@export var character_id: String = "sp_hero_01"
@export var display_name: String = "Single-Player Hero"
@export var character_portrait: Texture2D

@export_group("Base Stats")
@export var max_health: float = 1000.0
@export var move_speed: float = 230.0
@export var jump_force: float = 520.0
@export var attack_damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.5

@export_group("Visuals")
@export var sprite_frames: SpriteFrames

@export_group("Attack Data Slots")
@export var attack1_data: SinglePlayerAttackData
@export var attack2_data: SinglePlayerAttackData
@export var attack3_data: SinglePlayerAttackData
@export var special_attack_data: SinglePlayerAttackData

func get_attack_slot(slot: int) -> SinglePlayerAttackData:
	match slot:
		1: return attack1_data
		2: return attack2_data
		3: return attack3_data
		4: return special_attack_data
		_: return attack1_data
