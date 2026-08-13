class_name SinglePlayerMobController
extends CharacterBody2D

signal mob_died
signal mob_health_changed(current: float, max_health: float)

@export_group("Entity Data")
var _entity_data: SinglePlayerEntityData

@export var entity_data: SinglePlayerEntityData:
	get:
		return _entity_data
	set(val):
		_entity_data = val
		if is_node_ready() and _entity_data != null:
			_apply_entity_data(_entity_data)

@export_group("Mob Attributes")
@export var mob_health: float = 600.0
@export var mob_attack_damage: float = 1.0
@export var mob_movement_speed: float = 160.0
@export var mob_attack_speed: float = 1.0
@export var is_flying: bool = false

@export_group("Mob AI")
@export var detection_range: float = 800.0
@export var attack_range: float = 90.0
@export var attack_interval: float = 1.2
@export var primary_attack: Resource
@export var secondary_attack: Resource

var current_health: float = 600.0
var is_knocked_out: bool = false
var facing_direction: int = 1
var is_attacking: bool = false

var _ai_timer: float = 0.0
var _hover_offset_y: float = 0.0
var _target: Node2D
var _sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _hitbox: Area2D
var _collision_shape: CollisionShape2D
var _base_sprite_frames: SpriteFrames
var _current_attack_res: Resource = null
var _attack_hit_processed: bool = false
var _processed_hit_frames: Array[int] = []
var _hit_entities_this_attack: Array[Node] = []
var _player_aoe_scheduled: bool = false
var _initial_hitbox_pos_x: float = 0.0
var _initial_hurtbox_pos_x: float = 0.0
var _initial_collision_pos_x: float = 0.0

func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	_hurtbox = get_node_or_null("Hurtbox") as Area2D
	_hitbox = get_node_or_null("Hitbox") as Area2D
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if _hitbox != null:
		_initial_hitbox_pos_x = _hitbox.position.x
		if not _hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			_hitbox.area_entered.connect(_on_hitbox_area_entered)
		_hitbox.monitoring = false

	if _hurtbox != null:
		_initial_hurtbox_pos_x = _hurtbox.position.x

	if _collision_shape != null:
		_initial_collision_pos_x = _collision_shape.position.x

	if _sprite != null:
		if _sprite.sprite_frames != null:
			_base_sprite_frames = _sprite.sprite_frames
		_sprite.frame_changed.connect(_on_sprite_frame_changed)

	if _entity_data != null:
		_apply_entity_data(_entity_data)
	else:
		push_warning("SinglePlayerMobController: No entity_data — using export defaults for testing.")
		current_health = mob_health
		mob_health_changed.emit(current_health, mob_health)

	add_to_group("mobs")
	if _hurtbox != null:
		_hurtbox.add_to_group("hurtboxes")

	_load_default_attacks()
	_play_animation("idle")

func initialize_from_entity_data(data_res: SinglePlayerEntityData, stat_multiplier: float = 1.0) -> void:
	if data_res == null:
		return
	_entity_data = data_res
	_apply_entity_data(data_res, stat_multiplier)

func _apply_entity_data(data_res: SinglePlayerEntityData, stat_multiplier: float = 1.0) -> void:
	if data_res == null:
		return
	mob_health = data_res.max_health * stat_multiplier
	current_health = mob_health
	mob_attack_damage = data_res.attack_damage_multiplier * stat_multiplier
	mob_attack_speed = data_res.attack_speed_multiplier * (1.0 + (stat_multiplier - 1.0) * 0.5)
	mob_movement_speed = data_res.movement_speed * (1.0 + (stat_multiplier - 1.0) * 0.2)
	is_flying = data_res.is_flying
	attack_range = data_res.attack_range
	if data_res.sprite_frames != null and _sprite != null:
		_sprite.sprite_frames = data_res.sprite_frames
		_base_sprite_frames = data_res.sprite_frames
	if not data_res.attacks.is_empty():
		primary_attack = data_res.attacks[0]
		if data_res.attacks.size() > 1:
			secondary_attack = data_res.attacks[1]
	mob_health_changed.emit(current_health, mob_health)

func _load_default_attacks() -> void:
	if primary_attack == null and ResourceLoader.exists("res://Resources/Attacks/single_player/level1/sp_mob_slash.tres"):
		primary_attack = load("res://Resources/Attacks/single_player/level1/sp_mob_slash.tres")
	if primary_attack == null and ResourceLoader.exists("res://Resources/Attacks/mob/mob_swipe.tres"):
		primary_attack = load("res://Resources/Attacks/mob/mob_swipe.tres") as AttackData
	if secondary_attack == null and ResourceLoader.exists("res://Resources/Attacks/mob/mob_tackle.tres"):
		secondary_attack = load("res://Resources/Attacks/mob/mob_tackle.tres") as AttackData

func _physics_process(delta: float) -> void:
	if is_knocked_out:
		return

	_find_player_target()
	if _target == null:
		_play_animation("idle")
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_ai_timer += delta
	var dist_vec = _target.global_position - global_position
	var dist = dist_vec.length()

	if dist <= detection_range:
		facing_direction = 1 if dist_vec.x > 0 else -1
		_update_facing()

		if is_flying:
			_hover_offset_y += delta * 2.0
			var target_y = _target.global_position.y - 40.0 + sin(_hover_offset_y) * 20.0
			var y_diff = target_y - global_position.y
			var move_dir = Vector2(sign(dist_vec.x) if absf(dist_vec.x) > _get_effective_attack_range() * 0.7 else 0.0, sign(y_diff) if absf(y_diff) > 20.0 else 0.0)
			velocity = move_dir * mob_movement_speed
			velocity.x = clampf(velocity.x, -600.0, 600.0)
			velocity.y = clampf(velocity.y, -600.0, 600.0)
			move_and_slide()
			if not is_attacking:
				_play_animation("walk" if velocity.length() > 5.0 else "idle")
		else:
			if not is_on_floor():
				velocity.y += 980.0 * delta
			else:
				velocity.y = 0.0

			if dist > _get_effective_attack_range() * 0.8 and not is_attacking:
				velocity.x = float(facing_direction) * mob_movement_speed
				_play_animation("walk")
			else:
				velocity.x = 0.0
				if not is_attacking:
					_play_animation("idle")

			velocity.x = clampf(velocity.x, -600.0, 600.0)
			velocity.y = clampf(velocity.y, -1200.0, 1200.0)
			move_and_slide()

		if _get_target_distance() <= _get_effective_attack_range() and _ai_timer >= (attack_interval / maxf(0.1, mob_attack_speed)):
			_ai_timer = 0.0
			perform_attack()

func perform_attack() -> void:
	if is_attacking or is_knocked_out:
		return

	var atk: SinglePlayerAttackData = null

	if _entity_data != null and not _entity_data.attacks.is_empty():
		if _entity_data.attacks.size() == 1:
			atk = _entity_data.attacks[0]
		else:
			# Smart distance-based selection for hybrid melee & ranged/cast mobs
			var dist = global_position.distance_to(_target.global_position) if (_target != null and is_instance_valid(_target)) else 0.0
			var melee_atks: Array[SinglePlayerAttackData] = []
			var ranged_atks: Array[SinglePlayerAttackData] = []

			for a in _entity_data.attacks:
				if a != null:
					if a.delivery_type == SinglePlayerAttackData.DeliveryType.AOE and a.aoe_targets_player_position:
						ranged_atks.append(a)
					elif a.delivery_type == SinglePlayerAttackData.DeliveryType.PROJECTILE or a.melee_range > 200.0:
						ranged_atks.append(a)
					else:
						melee_atks.append(a)

			if dist <= _get_effective_attack_range() * 0.8 and not melee_atks.is_empty():
				atk = melee_atks.pick_random()
			elif dist > _get_effective_attack_range() * 0.8 and not ranged_atks.is_empty():
				atk = ranged_atks.pick_random()
			else:
				atk = _entity_data.attacks.pick_random()
	else:
		atk = primary_attack
		if secondary_attack != null and randf() > 0.5:
			atk = secondary_attack

	if atk == null:
		return

	is_attacking = true
	_current_attack_res = atk
	_attack_hit_processed = false
	_processed_hit_frames.clear()
	_hit_entities_this_attack.clear()
	_player_aoe_scheduled = false
	_set_hitbox_active(false)
	var slot := 1
	if _entity_data != null and not _entity_data.attacks.is_empty():
		slot = _entity_data.attacks.find(atk) + 1

	_play_attack_animation(slot, atk)

	var duration = _compute_attack_duration(atk, slot)
	get_tree().create_timer(duration).timeout.connect(func():
		_set_hitbox_active(false)
		if not _attack_hit_processed:
			_check_attack_hit(atk)
		is_attacking = false
		_current_attack_res = null
		_restore_base_sprite_frames()
		_play_animation("idle")
	, CONNECT_ONE_SHOT)

func _execute_combo_sequence(combo_list: Array[SinglePlayerAttackData]) -> void:
	is_attacking = true
	_perform_combo_step(combo_list, 0)

func _perform_combo_step(combo_list: Array[SinglePlayerAttackData], step_idx: int) -> void:
	if is_knocked_out or step_idx >= combo_list.size():
		is_attacking = false
		_ai_timer = 0.0
		_restore_base_sprite_frames()
		_play_animation("idle")
		return

	var atk = combo_list[step_idx]
	if atk == null:
		_perform_combo_step(combo_list, step_idx + 1)
		return

	_current_attack_res = atk
	_attack_hit_processed = false
	_processed_hit_frames.clear()
	_hit_entities_this_attack.clear()
	_player_aoe_scheduled = false
	_set_hitbox_active(false)

	if _target != null and is_instance_valid(_target):
		facing_direction = 1 if (_target.global_position.x - global_position.x) > 0 else -1
		_update_facing()

	_play_attack_animation(step_idx + 1, atk)

	var duration = _compute_attack_duration(atk, step_idx + 1)
	get_tree().create_timer(duration).timeout.connect(func():
		_set_hitbox_active(false)
		if not is_knocked_out:
			if not _attack_hit_processed:
				_check_attack_hit(atk)
			_perform_combo_step(combo_list, step_idx + 1)
		else:
			is_attacking = false
	, CONNECT_ONE_SHOT)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_attacking or _current_attack_res == null or not is_instance_valid(area):
		return

	var entity = _resolve_hurtbox_entity(area)
	if entity == self or entity == null or not is_instance_valid(entity):
		return
	if entity.is_in_group("mobs"):
		return

	if _hit_entities_this_attack.has(entity):
		return

	_hit_entities_this_attack.append(entity)
	var dmg = SinglePlayerAttackHelper.get_damage(_current_attack_res, mob_attack_damage)
	SinglePlayerAttackHelper.apply_damage_to_entity(entity, dmg)
	_attack_hit_processed = true

func _compute_attack_duration(atk: Resource, slot: int) -> float:
	if _sprite != null and _sprite.sprite_frames != null and atk != null:
		var anim = SinglePlayerAttackHelper.resolve_animation_on_sprite(
			_sprite, SinglePlayerAttackHelper.get_animation_name(atk, slot)
		)
		if not anim.is_empty():
			var count = _sprite.sprite_frames.get_frame_count(anim)
			var fps = _sprite.sprite_frames.get_animation_speed(anim)
			var speed = SinglePlayerAttackHelper.get_attack_speed(atk, mob_attack_speed)
			if fps > 0.0 and count > 0:
				return float(count) / (fps * speed)
	return SinglePlayerAttackHelper.compute_attack_duration(atk, mob_attack_speed)

func _set_hitbox_active(active: bool) -> void:
	if _hitbox != null:
		_hitbox.monitoring = active

func _update_facing() -> void:
	if _sprite != null:
		_sprite.flip_h = (facing_direction < 0)

	var dir = float(facing_direction)

	if _hitbox != null:
		_hitbox.position.x = absf(_initial_hitbox_pos_x) * dir if _initial_hitbox_pos_x != 0.0 else 0.0

	if _hurtbox != null:
		_hurtbox.position.x = _initial_hurtbox_pos_x * dir

	if _collision_shape != null:
		_collision_shape.position.x = _initial_collision_pos_x * dir

func _on_sprite_frame_changed() -> void:
	if not is_attacking or _current_attack_res == null or _sprite == null:
		return

	var frame = _sprite.frame
	if _current_attack_res is SinglePlayerAttackData:
		var sp_atk = _current_attack_res as SinglePlayerAttackData
		if sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.AOE and sp_atk.aoe_targets_player_position:
			if sp_atk.is_vfx_spawn_frame(frame) and frame not in _processed_hit_frames:
				_processed_hit_frames.append(frame)
				_schedule_player_position_aoe(sp_atk)
				_attack_hit_processed = true
			_set_hitbox_active(false)
			return

		var act_frame := sp_atk.get_activation_frame()
		if frame == act_frame and frame not in _processed_hit_frames:
			_show_melee_activation_indicator(sp_atk)

		if sp_atk.is_hit_frame(frame) and frame not in _processed_hit_frames:
			_processed_hit_frames.append(frame)
			_set_hitbox_active(true)
			if _check_attack_hit(sp_atk):
				_attack_hit_processed = true
		elif not sp_atk.is_hit_frame(frame) and _processed_hit_frames.size() > 0:
			_set_hitbox_active(false)
		return

	if _attack_hit_processed:
		return

	var spawn_frame := 2
	if "vfx_spawn_frames" in _current_attack_res and not _current_attack_res.vfx_spawn_frames.is_empty():
		spawn_frame = _current_attack_res.vfx_spawn_frames[0]
	elif "hitbox_start_frame" in _current_attack_res:
		spawn_frame = int(_current_attack_res.hitbox_start_frame)

	if frame >= spawn_frame:
		_set_hitbox_active(true)
		if _check_attack_hit(_current_attack_res):
			_attack_hit_processed = true

func _show_melee_activation_indicator(sp_atk: SinglePlayerAttackData) -> void:
	if _sprite != null:
		var tw = _sprite.create_tween()
		tw.tween_property(_sprite, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.06)
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.14)
	var dir := float(facing_direction)
	var reach := _get_effective_attack_range(sp_atk)
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(dir * reach, -10), Vector2(0, 2)
	])
	spark.color = Color(1.0, 0.25, 0.15, 0.75)
	spark.position = global_position + Vector2(0, -10)
	var parent := get_tree().current_scene if get_tree() != null else get_parent()
	if parent != null:
		parent.add_child(spark)
		var tw2 := spark.create_tween()
		tw2.tween_property(spark, "modulate:a", 0.0, 0.18)
		tw2.tween_callback(spark.queue_free)

func _play_attack_animation(slot: int, atk_data: Resource) -> void:
	if _sprite == null:
		return

	if atk_data != null and "custom_sprite_frames" in atk_data and atk_data.custom_sprite_frames != null:
		_sprite.sprite_frames = atk_data.custom_sprite_frames

	var target_anim = SinglePlayerAttackHelper.get_animation_name(atk_data, slot)
	var resolved = SinglePlayerAttackHelper.resolve_animation_on_sprite(_sprite, target_anim)
	if not resolved.is_empty():
		_sprite.play(resolved)

func _check_attack_hit(atk: Resource) -> bool:
	var dmg = SinglePlayerAttackHelper.get_damage(atk, mob_attack_damage)
	var reach = _get_effective_attack_range(atk)

	var is_proj = false
	if atk is SinglePlayerAttackData and (atk as SinglePlayerAttackData).delivery_type == SinglePlayerAttackData.DeliveryType.PROJECTILE:
		is_proj = true
	elif reach > 200.0:
		is_proj = true

	if is_proj:
		_spawn_mob_projectile(atk, dmg)
		return true

	if atk is SinglePlayerAttackData:
		var sp_atk := atk as SinglePlayerAttackData
		if sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.AOE and sp_atk.aoe_targets_player_position:
			if not _player_aoe_scheduled:
				_schedule_player_position_aoe(sp_atk)
			return true

	var targets = get_tree().get_nodes_in_group("hurtboxes")
	var hit_entities: Array[Node] = []
	var hit_margin: float = maxf(reach * 0.45, 80.0)

	for hb in targets:
		if not is_instance_valid(hb) or not (hb is Area2D):
			continue

		var entity = _resolve_hurtbox_entity(hb as Area2D)
		if entity == self or entity == null or not is_instance_valid(entity) or hit_entities.has(entity):
			continue
		if entity.is_in_group("mobs"):
			continue
		if _hit_entities_this_attack.has(entity):
			continue

		var is_hit = false
		if _hitbox != null and is_instance_valid(_hitbox) and _hitbox.overlaps_area(hb):
			is_hit = true
		else:
			var dist = _hitbox.global_position.distance_to((hb as Area2D).global_position) if _hitbox != null else global_position.distance_to((hb as Area2D).global_position)
			if dist <= hit_margin:
				is_hit = true

		if is_hit:
			hit_entities.append(entity)
			_hit_entities_this_attack.append(entity)
			SinglePlayerAttackHelper.apply_damage_to_entity(entity, dmg)

	if _target != null and is_instance_valid(_target) and not hit_entities.has(_target) and not _target.is_in_group("mobs") and not _hit_entities_this_attack.has(_target):
		if _get_target_distance() <= hit_margin:
			_hit_entities_this_attack.append(_target)
			SinglePlayerAttackHelper.apply_damage_to_entity(_target, dmg)
			return true

	return not hit_entities.is_empty()

func _resolve_hurtbox_entity(hb: Area2D) -> Node:
	var entity = hb.get_parent()
	if entity != null and (entity.has_method("take_damage") or entity.has_method("apply_damage")):
		return entity
	if is_instance_valid(hb.owner) and (hb.owner.has_method("take_damage") or hb.owner.has_method("apply_damage")):
		return hb.owner
	return entity

func _get_effective_attack_range(atk: Resource = null) -> float:
	var base_range: float = attack_range
	if atk is SinglePlayerAttackData:
		base_range = maxf(base_range, (atk as SinglePlayerAttackData).melee_range)
	return base_range * maxf(1.0, absf(scale.x))

func _get_target_distance() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return global_position.distance_to(_target.global_position)

func _get_horizontal_dir_toward_target(from_pos: Vector2) -> Vector2:
	if _target != null and is_instance_valid(_target):
		var dx := _target.global_position.x - from_pos.x
		if absf(dx) > 0.01:
			return Vector2(signf(dx), 0.0)
	return Vector2(float(facing_direction), 0.0)

func _spawn_mob_projectile(_atk: Resource, dmg: float) -> void:
	var proj_scene = load("res://Scenes/Components/vfx/SinglePlayerOrbProjectile.tscn") as PackedScene
	if proj_scene == null:
		return
	var proj_inst = proj_scene.instantiate()

	if _target != null and is_instance_valid(_target):
		facing_direction = 1 if _target.global_position.x > global_position.x else -1
		_update_facing()

	var spawn_y = -45.0
	if scale.y > 0.0:
		spawn_y = -40.0 * (1.0 / scale.y)
	var spawn_pos = global_position + Vector2(float(facing_direction) * 35.0, spawn_y)
	var target_dir = _get_horizontal_dir_toward_target(spawn_pos)

	if get_tree() != null and get_tree().current_scene != null:
		get_tree().current_scene.add_child(proj_inst)
	elif get_parent() != null:
		get_parent().add_child(proj_inst)

	if proj_inst.has_method("launch"):
		proj_inst.call("launch", spawn_pos, target_dir, dmg, self, _target)

func _schedule_player_position_aoe(atk: SinglePlayerAttackData) -> void:
	if _player_aoe_scheduled or _target == null or not is_instance_valid(_target):
		return
	_player_aoe_scheduled = true

	var impact_pos := _target.global_position
	var radius := atk.aoe_radius
	var delay := maxf(0.2, atk.aoe_impact_delay)
	var dmg := SinglePlayerAttackHelper.get_damage(atk, mob_attack_damage)

	_spawn_aoe_telegraph(impact_pos, radius, delay)

	get_tree().create_timer(delay).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_resolve_player_position_aoe_hit(impact_pos, radius, dmg, atk)
	, CONNECT_ONE_SHOT)

func _spawn_aoe_telegraph(world_pos: Vector2, radius: float, duration: float) -> void:
	var telegraph := AoeTelegraph.new()
	telegraph.radius = radius
	telegraph.duration = duration
	telegraph.global_position = world_pos
	var parent := get_tree().current_scene if get_tree() != null else get_parent()
	if parent != null:
		parent.add_child(telegraph)

func _resolve_player_position_aoe_hit(center: Vector2, radius: float, dmg: float, atk: SinglePlayerAttackData) -> void:
	if atk.vfx_config != null:
		SinglePlayerAttackHelper.spawn_vfx_from_config(get_tree(), atk.vfx_config, center, 1)

	for hb in get_tree().get_nodes_in_group("hurtboxes"):
		if not is_instance_valid(hb) or not (hb is Area2D):
			continue
		var entity = _resolve_hurtbox_entity(hb as Area2D)
		if entity == null or not is_instance_valid(entity) or entity.is_in_group("mobs"):
			continue
		if entity.is_in_group("players") and "is_dashing" in entity and entity.is_dashing:
			continue
		if (hb as Area2D).global_position.distance_to(center) <= radius * 1.05:
			SinglePlayerAttackHelper.apply_damage_to_entity(entity, dmg)

func _is_attack_uninterruptable() -> bool:
	if not is_attacking or _current_attack_res == null:
		return false
	if _current_attack_res is SinglePlayerAttackData:
		var sp_atk := _current_attack_res as SinglePlayerAttackData
		return sp_atk.is_uninterruptable or sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.PROJECTILE or sp_atk.delivery_type == SinglePlayerAttackData.DeliveryType.AOE
	return false

func take_damage(amount: float) -> void:
	if is_knocked_out:
		return

	current_health -= amount
	mob_health_changed.emit(maxf(0.0, current_health), mob_health)
	if current_health <= 0.0:
		current_health = 0.0
		is_knocked_out = true
		is_attacking = false
		_current_attack_res = null
		_set_hitbox_active(false)
		_play_animation("death")
		mob_died.emit()
		get_tree().create_timer(1.2).timeout.connect(queue_free, CONNECT_ONE_SHOT)
	elif not _is_attack_uninterruptable():
		_play_animation("hurt")

func _play_animation(anim_name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return

	var resolved = SinglePlayerAttackHelper.get_locomotion_animation(_sprite, anim_name)
	if resolved.is_empty():
		return
	_sprite.play(resolved)

func _restore_base_sprite_frames() -> void:
	if _sprite == null:
		return
	var restore_frames = _base_sprite_frames
	if restore_frames == null and _entity_data != null:
		restore_frames = _entity_data.sprite_frames
	if restore_frames != null and _sprite.sprite_frames != restore_frames:
		_sprite.sprite_frames = restore_frames

func _find_player_target() -> void:
	var best_target: Node2D = null
	var best_dist := INF

	for node in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if "is_knocked_out" in node and node.is_knocked_out:
			continue

		var player := node as Node2D
		var dist = global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = player

	_target = best_target
