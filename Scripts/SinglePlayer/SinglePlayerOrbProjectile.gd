class_name SinglePlayerOrbProjectile
extends Area2D

@export var speed: float = 450.0
@export var damage: float = 30.0
@export var max_range: float = 1200.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var _travelled_distance: float = 0.0
var _has_exploded: bool = false
var source_mob: Node
var _intended_target: Node

func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_hit_something)
	area_entered.connect(_on_area_entered)

func launch(start_pos: Vector2, target_dir: Vector2, base_damage: float, mob_owner: Node = null, intended_target: Node = null) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	damage = base_damage
	source_mob = mob_owner
	_intended_target = intended_target
	if direction != Vector2.ZERO:
		rotation = direction.angle()

	if _sprite == null:
		_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if _sprite != null:
		var mob_frames: SpriteFrames = null
		if mob_owner != null:
			if "sprite_frames" in mob_owner and mob_owner.sprite_frames != null:
				mob_frames = mob_owner.sprite_frames
			elif mob_owner.get_node_or_null("Sprite") != null:
				var mob_anim = mob_owner.get_node_or_null("Sprite") as AnimatedSprite2D
				if mob_anim != null:
					mob_frames = mob_anim.sprite_frames

		if mob_frames != null and mob_frames.has_animation("moving"):
			_sprite.sprite_frames = mob_frames

		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("moving"):
			_sprite.play("moving")

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	var move_vec = direction * speed * delta
	global_position += move_vec
	_travelled_distance += move_vec.length()

	if _travelled_distance >= max_range:
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if _has_exploded or not is_instance_valid(area):
		return
	if not area.is_in_group("hurtboxes"):
		return

	var target_entity = area.get_parent()
	if target_entity == null or not (target_entity.has_method("take_damage") or target_entity.has_method("apply_damage")):
		if is_instance_valid(area.owner) and (area.owner.has_method("take_damage") or area.owner.has_method("apply_damage")):
			target_entity = area.owner

	if _is_valid_damage_target(target_entity):
		SinglePlayerAttackHelper.apply_damage_to_entity(target_entity, damage)
		_explode()

func _on_hit_something(body: Node) -> void:
	if _has_exploded:
		return
	if body == source_mob or (source_mob != null and body.is_ancestor_of(source_mob)):
		return
	if body.is_in_group("mobs"):
		return
	if _is_valid_damage_target(body):
		SinglePlayerAttackHelper.apply_damage_to_entity(body, damage)
		_explode()

func _is_valid_damage_target(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity == source_mob or entity.is_in_group("mobs"):
		return false
	if _intended_target != null and is_instance_valid(_intended_target):
		return entity == _intended_target
	return entity.is_in_group("players")

func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	speed = 0.0

	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("explode"):
		_sprite.play("explode")
		if not _sprite.animation_finished.is_connected(queue_free):
			_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
		get_tree().create_timer(0.6).timeout.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()
