class_name ComboMoveData
extends Resource

@export var move_name: String = "Command Move"
@export var input_sequence: String = "j+k"
@export var animation_key: String = "special"
@export var attack_stats: AttackData
@export var energy_cost: float = 0.0
@export var knockdown_meter_gain: int = 2
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 0.0
