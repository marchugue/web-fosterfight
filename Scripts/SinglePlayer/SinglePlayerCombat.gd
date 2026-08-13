class_name SinglePlayerCombat
extends CharacterCombat

var _standalone_mode: bool = false
var _standalone_owner: Node2D
var _standalone_damage_multiplier: float = 1.0
var _standalone_attack: Resource
var _lock_target: Node2D
var _fired_spawn_frames: Array[int] = []
var _beam_vfx_spawned: bool = false

func enable_standalone_mode(caster: Node2D, sprite: AnimatedSprite2D, hitbox: Area2D, p_damage_multiplier: float = 1.0) -> void:
	_standalone_mode = true
	_standalone_owner = caster
	_standalone_damage_multiplier = p_damage_multiplier
	set_sprite(sprite)
	set_hitbox(hitbox)

func set_lock_target(target: Node2D) -> void:
	_lock_target = target if is_instance_valid(target) else null

func start_standalone_attack(atk_data: Resource, facing: int, resolved_anim: String = "") -> void:
	if atk_data == null:
		return
	if not _standalone_mode:
		push_warning("SinglePlayerCombat: start_standalone_attack called before enable_standalone_mode")
		return

	_facing = facing
	_standalone_attack = atk_data
	_current_attack_data = atk_data if atk_data is AttackData else null
	is_attacking = true
	is_hitbox_active = false
	has_connected = false
	_swing_sfx_fired = false
	_hit_targets_this_swing.clear()
	_fired_spawn_frames.clear()
	_beam_vfx_spawned = false

	if _current_attack_data != null:
		apply_hitbox_transform(_current_attack_data)
	set_hitbox_active(false)

	var anim_key = resolved_anim
	if anim_key.is_empty():
		anim_key = SinglePlayerAttackHelper.get_animation_name(atk_data, 1)

	attack_started.emit(anim_key)
	var sfx = atk_data.sfx if atk_data is SinglePlayerAttackData else null
	if sfx == null and atk_data is AttackData and atk_data.sfx_on_start != null:
		sfx = atk_data.sfx_on_start
	if sfx != null:
		attack_start_sfx.emit(sfx)

	var safe_timeout = SinglePlayerAttackHelper.compute_attack_duration(atk_data, 1.0) * 1.5 + 1.0
	get_tree().create_timer(safe_timeout).timeout.connect(func():
		if is_attacking:
			_on_animation_finished()
	, CONNECT_ONE_SHOT)

func check_hit(opponent_hurtbox: Area2D) -> void:
	if _standalone_mode:
		_standalone_check_hit(opponent_hurtbox)
		return
	super.check_hit(opponent_hurtbox)

func _standalone_check_hit(opponent_hurtbox: Area2D) -> void:
	var atk_data = _get_active_attack()
	if not is_attacking or atk_data == null or opponent_hurtbox == null:
		return

	var target_id = opponent_hurtbox.get_instance_id()
	if target_id in _hit_targets_this_swing:
		return

	var entity = opponent_hurtbox.get_parent()
	if entity == null or not (entity.has_method("take_damage") or entity.has_method("apply_damage")):
		if is_instance_valid(opponent_hurtbox.owner) and (opponent_hurtbox.owner.has_method("take_damage") or opponent_hurtbox.owner.has_method("apply_damage")):
			entity = opponent_hurtbox.owner
	if entity == _standalone_owner or entity == null or not is_instance_valid(entity):
		return

	if _hitbox != null and not _hitbox.overlaps_area(opponent_hurtbox):
		if atk_data is SinglePlayerAttackData and (atk_data as SinglePlayerAttackData).delivery_type == SinglePlayerAttackData.DeliveryType.BEAM:
			var beam_origin = _get_beam_hit_origin()
			if not _is_hurtbox_in_beam(opponent_hurtbox, atk_data as SinglePlayerAttackData, beam_origin):
				return
		else:
			var dist = _standalone_owner.global_position.distance_to(opponent_hurtbox.global_position)
			var check_range = SinglePlayerAttackHelper.get_melee_range(atk_data) + 30.0
			if dist > check_range:
				return

	_hit_targets_this_swing.append(target_id)
	has_connected = true
	SinglePlayerAttackHelper.apply_damage_to_entity(entity, SinglePlayerAttackHelper.get_damage(atk_data, _standalone_damage_multiplier))

func _on_sprite_frame_changed() -> void:
	if not is_attacking or _get_active_attack() == null or _sprite == null:
		return
	var frame = _sprite.frame
	var atk_data = _get_active_attack()

	if atk_data is SinglePlayerAttackData and (atk_data as SinglePlayerAttackData).delivery_type == SinglePlayerAttackData.DeliveryType.BEAM:
		_process_special_attack_frame(frame)
		if SinglePlayerAttackHelper.is_hit_frame(atk_data, frame):
			if not _swing_sfx_fired:
				_swing_sfx_fired = true
				var sfx = atk_data.sfx
				if sfx != null:
					attack_swing.emit(sfx)
			_apply_beam_hits(atk_data as SinglePlayerAttackData)
		set_hitbox_active(false)
		return

	# Process VFX spawning for special attacks
	_process_special_attack_frame(frame)

	# Hitbox activation via hit_frames
	var should_be_active = SinglePlayerAttackHelper.is_hit_frame(atk_data, frame)
	if should_be_active:
		if not _swing_sfx_fired:
			_swing_sfx_fired = true
			var sfx = atk_data.sfx if atk_data is SinglePlayerAttackData else null
			if sfx != null:
				attack_swing.emit(sfx)
		# Scan and damage all mob hurtboxes in range
		for hb in get_tree().get_nodes_in_group("hurtboxes"):
			if hb is Area2D:
				check_hit(hb as Area2D)

	set_hitbox_active(should_be_active)

func _process_special_attack_frame(frame: int) -> void:
	var atk_data = _get_active_attack()
	if atk_data == null or not (atk_data is SinglePlayerAttackData):
		return

	var sp_atk := atk_data as SinglePlayerAttackData
	if not sp_atk.is_vfx_spawn_frame(frame) or frame in _fired_spawn_frames:
		return

	var parent_node = get_parent() as Node2D
	var marker_name = sp_atk.get_spawn_marker_name()
	var cfg = sp_atk.vfx_config
	var origin_pos = SinglePlayerAttackHelper.resolve_spawn_position(parent_node, marker_name, cfg)

	match sp_atk.delivery_type:
		SinglePlayerAttackData.DeliveryType.PROJECTILE:
			# Close-range melee check on close_range_frames
			if sp_atk.is_close_range_frame(frame):
				for hurtbox in get_tree().get_nodes_in_group("hurtboxes"):
					if hurtbox is Area2D:
						var entity = hurtbox.get_parent()
						if entity == null or not (entity.has_method("take_damage") or entity.has_method("apply_damage")):
							if is_instance_valid(hurtbox.owner) and (hurtbox.owner.has_method("take_damage") or hurtbox.owner.has_method("apply_damage")):
								entity = hurtbox.owner
						if entity != parent_node and entity != null:
							var dist = origin_pos.distance_to(hurtbox.global_position)
							if dist <= SinglePlayerAttackHelper.get_close_range(atk_data):
								check_hit(hurtbox as Area2D)

			_fired_spawn_frames.append(frame)
			_spawn_projectile(origin_pos, sp_atk)

		SinglePlayerAttackData.DeliveryType.AOE:
			_fired_spawn_frames.append(frame)
			_spawn_aoe(origin_pos, sp_atk)

		SinglePlayerAttackData.DeliveryType.BEAM:
			_fire_beam(origin_pos, sp_atk, frame)

func _spawn_projectile(origin: Vector2, atk_data: SinglePlayerAttackData) -> void:
	var cfg = atk_data.vfx_config
	var speed = atk_data.projectile_speed
	var inst = SinglePlayerAttackHelper.spawn_vfx_from_config(get_tree(), cfg, origin, _facing, {"speed": speed})
	if inst != null:
		if "damage" in inst:
			inst.set("damage", SinglePlayerAttackHelper.get_damage(atk_data, _standalone_damage_multiplier))
		if "caster_node" in inst:
			inst.set("caster_node", _standalone_owner)
		# Pass lock target for homing arrows
		if "lock_target" in inst and _lock_target != null and is_instance_valid(_lock_target):
			inst.set("lock_target", _lock_target)
		# Fallback tween for non-scene VFX (sprite_frames / texture only)
		if not (cfg != null and cfg.vfx_scene != null):
			var travel := 600.0
			var tw = inst.create_tween()
			tw.tween_property(inst, "global_position:x", inst.global_position.x + (_facing * travel), 0.6)
			tw.parallel().tween_property(inst, "modulate:a", 0.0, 0.6)
			tw.tween_callback(inst.queue_free)
	projectile_spawn_requested.emit()

func _spawn_aoe(origin: Vector2, atk_data: SinglePlayerAttackData) -> void:
	var spell_radius = atk_data.aoe_radius
	var parent_node = get_parent() as Node2D
	var cfg = atk_data.vfx_config
	var target_pos := _resolve_aoe_target_pos(origin, atk_data)

	for hb in get_tree().get_nodes_in_group("hurtboxes"):
		if hb is Area2D and hb.owner != parent_node and is_instance_valid(hb.owner):
			if hb.global_position.distance_to(target_pos) <= spell_radius:
				check_hit(hb as Area2D)

	var vfx_scale := maxf(0.1, atk_data.aoe_vfx_scale)
	var spawn_pos = target_pos
	if cfg != null:
		spawn_pos += Vector2(_facing * cfg.offset.x, cfg.offset.y)
	var inst = SinglePlayerAttackHelper.spawn_vfx_from_config(get_tree(), cfg, spawn_pos, _facing)
	if inst != null:
		inst.scale = Vector2(vfx_scale * signf(float(_facing)), vfx_scale)
		if inst is AnimatedSprite2D:
			(inst as AnimatedSprite2D).animation_finished.connect(inst.queue_free)
		elif cfg != null and cfg.vfx_scene == null:
			var tw = inst.create_tween()
			tw.tween_property(inst, "modulate:a", 0.0, 0.45)
			tw.tween_callback(inst.queue_free)
	else:
		var spell_vfx = Line2D.new()
		spell_vfx.width = spell_radius * 2.0 * vfx_scale
		spell_vfx.default_color = cfg.tint if cfg != null else Color(0.6, 0.2, 1.0, 0.8)
		spell_vfx.position = target_pos
		get_tree().get_root().add_child(spell_vfx)
		var tween = spell_vfx.create_tween()
		tween.tween_property(spell_vfx, "modulate:a", 0.0, 0.4)
		tween.tween_callback(spell_vfx.queue_free)

func _resolve_aoe_target_pos(origin: Vector2, atk_data: SinglePlayerAttackData) -> Vector2:
	if atk_data.aoe_targets_player_position:
		return origin

	if atk_data.aoe_targets_enemies:
		var caster = get_parent() as Node2D
		if atk_data.aoe_prioritize_clusters and caster != null:
			var cluster_pos = SinglePlayerAttackHelper.find_best_aoe_cluster_target(
				caster, get_tree(), atk_data.aoe_radius
			)
			if cluster_pos is Vector2:
				return cluster_pos

		if _lock_target != null and is_instance_valid(_lock_target):
			return _lock_target.global_position

		if caster != null:
			var nearest = SinglePlayerAttackHelper.find_nearest_mob(caster, get_tree())
			if nearest != null:
				return nearest.global_position

	return origin + Vector2(_facing * atk_data.aoe_cast_distance, 0)

func _fire_beam(origin: Vector2, atk_data: SinglePlayerAttackData, frame: int) -> void:
	var cfg = atk_data.vfx_config
	var bl = _resolve_beam_length(atk_data)
	var laser_end = Vector2(origin.x + (_facing * bl), origin.y)

	if not _beam_vfx_spawned:
		_beam_vfx_spawned = true
		_fired_spawn_frames.append(frame)
		var inst = SinglePlayerAttackHelper.spawn_vfx_from_config(get_tree(), cfg, origin, _facing, {"laser_range": bl})
		if inst != null:
			var parent_node = get_parent() as Node2D
			if parent_node != null:
				inst.reparent(parent_node)
				inst.global_position = origin

		if inst == null:
			var laser_vfx = Line2D.new()
			laser_vfx.width = 12.0
			laser_vfx.default_color = cfg.tint if cfg != null else Color(0.2, 0.8, 1.0, 0.9)
			laser_vfx.add_point(origin)
			laser_vfx.add_point(laser_end)
			get_tree().get_root().add_child(laser_vfx)
			var tween = laser_vfx.create_tween()
			tween.tween_property(laser_vfx, "modulate:a", 0.0, 0.25)
			tween.tween_callback(laser_vfx.queue_free)

func _apply_beam_hits(atk_data: SinglePlayerAttackData) -> void:
	var origin := _get_beam_hit_origin()
	for hb in get_tree().get_nodes_in_group("hurtboxes"):
		if hb is Area2D and _is_hurtbox_in_beam(hb as Area2D, atk_data, origin):
			check_hit(hb as Area2D)

func _get_beam_hit_origin() -> Vector2:
	if _standalone_owner != null and is_instance_valid(_standalone_owner):
		return _standalone_owner.global_position
	var parent_node = get_parent() as Node2D
	if parent_node != null:
		return parent_node.global_position
	return Vector2.ZERO

func _resolve_beam_length(atk_data: SinglePlayerAttackData) -> float:
	var configured := SinglePlayerAttackHelper.get_beam_length(atk_data)
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_reach := maxf(viewport_size.x, viewport_size.y) * 2.5
	return maxf(configured, screen_reach)

func _is_hurtbox_in_beam(hurtbox: Area2D, atk_data: SinglePlayerAttackData, origin: Vector2) -> bool:
	if hurtbox == null or not is_instance_valid(hurtbox):
		return false
	var parent_node = get_parent()
	if hurtbox.owner == parent_node:
		return false

	var beam_length := _resolve_beam_length(atk_data)
	var beam_height := SinglePlayerAttackHelper.get_beam_hit_height(atk_data)
	var pos := hurtbox.global_position
	var forward_delta := pos.x - origin.x

	if _facing > 0:
		if forward_delta < 0.0 or forward_delta > beam_length:
			return false
	else:
		if forward_delta > 0.0 or forward_delta < -beam_length:
			return false

	return absf(pos.y - origin.y) <= beam_height

func _on_animation_finished() -> void:
	if not is_attacking:
		return
	set_hitbox_active(false)
	is_attacking = false
	is_hitbox_active = false
	_standalone_attack = null
	_current_attack_data = null
	_lock_target = null
	_fired_spawn_frames.clear()
	_beam_vfx_spawned = false
	has_connected = false
	apply_hitbox_transform(null)
	attack_ended.emit()

func _get_active_attack() -> Resource:
	if _standalone_attack != null:
		return _standalone_attack
	return _current_attack_data
