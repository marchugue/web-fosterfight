class_name ArrowVFX
extends Node2D

@export var speed: float = 800.0
@export var direction: int = 1
@export var lifetime: float = 1.5

@export var sprite_frames: SpriteFrames
@export var animation_name: String = "arrow"
@export var texture: Texture2D

## Auto-lock target — set by SinglePlayerCombat before adding to tree.
var lock_target: Node2D
## How strongly the arrow homes toward the target (0 = straight, 1 = instant).
var homing_strength: float = 6.0
var damage: float = 40.0
var caster_node: Node2D

var _timer: float = 0.0
var _velocity: Vector2
var _has_hit: bool = false

func _ready() -> void:
	# Set initial velocity in facing direction
	_velocity = Vector2(float(direction) * speed, 0.0)
	scale.x = float(direction)

	# If we have a lock target, aim initial velocity toward it
	if lock_target != null and is_instance_valid(lock_target):
		var to_target = lock_target.global_position - global_position
		if to_target.length() > 10.0:
			_velocity = to_target.normalized() * speed
			# Rotate arrow sprite to match flight direction
			rotation = _velocity.angle()
			# Flip handling: if going left, we need to adjust
			if direction < 0:
				scale.x = -1.0

	# Play the arrow animation
	var anim_spr = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_spr != null:
		if sprite_frames != null:
			anim_spr.sprite_frames = sprite_frames
		var sf = anim_spr.sprite_frames
		if sf != null:
			var anim = animation_name if not animation_name.is_empty() and sf.has_animation(animation_name) else "arrow"
			if not sf.has_animation(anim):
				anim = "default"
			anim_spr.play(anim)

	var spr = get_node_or_null("Sprite2D") as Sprite2D
	if spr != null and texture != null:
		spr.texture = texture

func _process(delta: float) -> void:
	if _has_hit:
		return

	# Homing: steer toward lock target if still alive
	if lock_target != null and is_instance_valid(lock_target):
		var to_target = lock_target.global_position - global_position
		var dist = to_target.length()
		if dist > 5.0:
			var desired = to_target.normalized() * speed
			_velocity = _velocity.lerp(desired, homing_strength * delta)
			rotation = _velocity.angle()
			if direction < 0:
				scale.x = -1.0

	global_position += _velocity * delta
	_timer += delta

	_check_mob_hit()

	if _timer >= lifetime:
		queue_free()

func _check_mob_hit() -> void:
	if _has_hit:
		return
	var hurtboxes = get_tree().get_nodes_in_group("hurtboxes")
	for hb in hurtboxes:
		if not is_instance_valid(hb) or not (hb is Area2D):
			continue

		var entity = hb.owner if is_instance_valid(hb.owner) else hb.get_parent()
		if entity == caster_node or entity == null or not is_instance_valid(entity):
			continue

		# Dynamically compute hurtbox collision radius considering shape & global scale
		var hit_radius: float = 45.0
		var shape_node = hb.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var shape_center = hb.global_position

		if shape_node != null:
			shape_center = shape_node.global_position
			if shape_node.shape != null:
				var gs = shape_node.global_scale
				if shape_node.shape is RectangleShape2D:
					var sz = (shape_node.shape as RectangleShape2D).size
					hit_radius = maxf(sz.x * absf(gs.x), sz.y * absf(gs.y)) * 0.7 + 15.0
				elif shape_node.shape is CapsuleShape2D:
					var cap = shape_node.shape as CapsuleShape2D
					hit_radius = maxf(cap.radius * absf(gs.x), cap.height * absf(gs.y)) * 0.7 + 15.0
				elif shape_node.shape is CircleShape2D:
					hit_radius = (shape_node.shape as CircleShape2D).radius * maxf(absf(gs.x), absf(gs.y)) + 15.0

		var hit_dist = global_position.distance_to(shape_center)
		if hit_dist <= hit_radius:
			_has_hit = true
			SinglePlayerAttackHelper.apply_damage_to_entity(entity, damage)
			_spawn_landed_effect_on_mob(entity, global_position)
			queue_free()
			break

func _spawn_landed_effect_on_mob(mob_entity: Node, hit_pos: Vector2) -> void:
	var archer_frames = load("res://Assets/Animations/singlecharacter/archer.tres") as SpriteFrames
	if archer_frames == null or not archer_frames.has_animation("arrow_landed"):
		return

	var landed_spr = AnimatedSprite2D.new()
	landed_spr.sprite_frames = archer_frames
	landed_spr.play("arrow_landed")

	# Attach landed_spr directly to mob node so it moves together with the mob
	mob_entity.add_child(landed_spr)

	if mob_entity is Node2D:
		landed_spr.global_position = hit_pos
		landed_spr.rotation = rotation

	landed_spr.animation_finished.connect(landed_spr.queue_free, CONNECT_ONE_SHOT)
