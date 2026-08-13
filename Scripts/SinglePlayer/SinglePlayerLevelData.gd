class_name SinglePlayerLevelData
extends Resource

@export_group("Identity")
@export var level_id: String = "level1"
@export var level_name: String = "Battle Arena"

@export_group("Wave Entities")
@export var assigned_mob: SinglePlayerEntityData
@export var assigned_mobs: Array[SinglePlayerEntityData] = []
@export var assigned_boss: SinglePlayerEntityData

@export_group("Wave Mechanics")
@export var wave_1_count: int = 2
@export var wave_2_count: int = 3
@export var wave_3_count: int = 3
@export var wave_4_count: int = 4

@export var wave_2_stat_multiplier: float = 1.2
@export var wave_3_stat_multiplier: float = 1.35
@export var wave_4_stat_multiplier: float = 1.5

@export var spawn_positions: Array[Vector2] = [
	Vector2(600, 440),
	Vector2(1450, 270),
	Vector2(2400, 440),
	Vector2(800, 220),
	Vector2(1800, 220),
	Vector2(500, 520),
	Vector2(2600, 520)
]

@export_group("Scene References")
@export var mob_scene: PackedScene = preload("res://Scenes/single_player/SinglePlayerMob2.tscn")
@export var flying_mob_scene: PackedScene = preload("res://Scenes/single_player/SinglePlayerMob1.tscn")
@export var boss_scene: PackedScene = preload("res://Scenes/single_player/SinglePlayerBoss.tscn")
@export var next_level_scene_path: String = ""
