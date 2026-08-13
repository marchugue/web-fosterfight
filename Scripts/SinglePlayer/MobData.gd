class_name MobData
extends SinglePlayerEntityData

## Simplified Mob Data Resource for Quick & Easy Mob Configuration

@export_group("Mob Basics")
@export var mob_name: String = "Shadow Enemy":
	set(val):
		mob_name = val
		display_name = val
	get:
		return display_name if not display_name.is_empty() else mob_name

@export var mob_health: float = 500.0:
	set(val):
		mob_health = val
		max_health = val
	get:
		return max_health

@export var mob_speed: float = 200.0:
	set(val):
		mob_speed = val
		movement_speed = val
	get:
		return movement_speed

@export var mob_damage: float = 25.0:
	set(val):
		mob_damage = val
		attack_damage_multiplier = val / 25.0
	get:
		return attack_damage_multiplier * 25.0

@export_group("Mob Behavior & Visuals")
@export var mob_sprite_frames: SpriteFrames:
	set(val):
		mob_sprite_frames = val
		sprite_frames = val
	get:
		return sprite_frames

@export var is_flying_mob: bool = false:
	set(val):
		is_flying_mob = val
		is_flying = val
	get:
		return is_flying

@export var attack_reach: float = 80.0:
	set(val):
		attack_reach = val
		attack_range = val
	get:
		return attack_range

func _init() -> void:
	entity_type = EntityType.MOB
