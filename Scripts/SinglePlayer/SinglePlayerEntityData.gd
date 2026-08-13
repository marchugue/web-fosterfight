class_name SinglePlayerEntityData
extends Resource

enum EntityType {
	PLAYER,
	MOB,
	BOSS
}

@export_group("Identity & Type")
@export var display_name: String = "Single-Player Entity"
@export var entity_type: EntityType = EntityType.MOB

var is_boss: bool:
	get:
		return entity_type == EntityType.BOSS or "boss" in display_name.to_lower()

@export_group("Stats & Combat")
@export var max_health: float = 1000.0
@export var attack_damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0
@export var movement_speed: float = 200.0
@export var jump_force: float = 520.0
@export var is_flying: bool = false
@export var attack_range: float = 80.0

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var scale_multiplier: float = 1.0

@export_group("Level & Progression")
@export var level_scene: PackedScene
@export var next_level_scene: PackedScene

@export_group("Attacks & Abilities")
@export var attacks: Array[SinglePlayerAttackData] = []

@export_group("Boss Properties")
@export var enrage_health_threshold: float = 0.5

func get_attack_data(slot: int) -> SinglePlayerAttackData:
	if attacks.is_empty():
		return null
	var idx = clampi(slot - 1, 0, attacks.size() - 1)
	return attacks[idx]
