class_name Projectile
extends Area2D

@export var speed: float = 600.0
@export var max_distance: float = 1400.0

var direction: int = 1
var attack_stats: AttackData
var target_hurtbox: Area2D
var owner_controller: CharacterController

var _distance_travelled: float = 0.0
var _has_hit: bool = false

func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var step = speed * delta * direction
	var pos = global_position
	pos.x += step
	global_position = pos
	_distance_travelled += absf(step)

	if _distance_travelled >= max_distance or pos.x < (Constants.Stage.WORLD_MIN_X - 100.0) or pos.x > (Constants.Stage.WORLD_MAX_X + 100.0):
		queue_free()
		return

	if target_hurtbox != null and attack_stats != null and overlaps_area(target_hurtbox):
		_has_hit = true
		if owner_controller != null:
			owner_controller.on_projectile_hit(self)
		var timer = get_tree().create_timer(0.05)
		timer.timeout.connect(queue_free)
