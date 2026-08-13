class_name StandaloneSinglePlayerPlayerController
extends StandaloneSinglePlayerCharacterController

@export var movement_speed_override: float = 0.0
@export var health_override: float = 0.0

func _ready() -> void:
	is_ai_controlled = false
	super._ready()

	if movement_speed_override > 0.0:
		movement_speed = movement_speed_override
	if health_override > 0.0:
		mob_max_health = health_override
		current_health = health_override
		health_changed.emit(current_health, mob_max_health)
