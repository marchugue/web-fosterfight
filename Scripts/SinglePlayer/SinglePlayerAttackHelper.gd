class_name SinglePlayerAttackHelper
extends RefCounted

## Shared utilities for resolving attack data, animations, timing, and VFX spawning.
## Works exclusively with SinglePlayerAttackData resources.

enum DeliveryType {
	MELEE,
	PROJECTILE,
	BEAM,
	AOE,
}


# ── Delivery Type ────────────────────────────────────────────────────────────

static func get_delivery_type(atk_data: Resource) -> DeliveryType:
	if atk_data is SinglePlayerAttackData:
		return atk_data.delivery_type as DeliveryType
	return DeliveryType.MELEE

static func is_ranged_or_special(atk_data: Resource) -> bool:
	return get_delivery_type(atk_data) != DeliveryType.MELEE

static func is_special_attack(atk_data: Resource) -> bool:
	return is_ranged_or_special(atk_data)


# ── Damage & Speed ───────────────────────────────────────────────────────────

static func get_damage(atk_data: Resource, multiplier: float = 1.0) -> float:
	if atk_data != null and "damage" in atk_data:
		return float(atk_data.damage) * multiplier
	return multiplier

static func get_attack_speed(atk_data: Resource, base_speed: float = 1.0) -> float:
	var speed = base_speed
	if atk_data != null and "attack_speed" in atk_data and float(atk_data.attack_speed) > 0.0:
		speed *= float(atk_data.attack_speed)
	return maxf(0.1, speed)


# ── Animation ────────────────────────────────────────────────────────────────

static func get_animation_name(atk_data: Resource, slot: int, char_data: CharacterData = null) -> String:
	if atk_data is SinglePlayerAttackData and not atk_data.character_animation.is_empty():
		return atk_data.character_animation
	if atk_data != null and "sprite_animation_name" in atk_data:
		var anim = str(atk_data.sprite_animation_name)
		if not anim.is_empty():
			return anim
	if char_data != null:
		return char_data.get_animation_name("attack%d" % slot)
	return "attack_%d" % slot

static func get_character_sprite_frames(atk_data: Resource) -> SpriteFrames:
	if atk_data is SinglePlayerAttackData:
		return atk_data.character_sprite_frames
	if atk_data != null and "custom_sprite_frames" in atk_data:
		return atk_data.custom_sprite_frames
	return null

static func resolve_animation_on_sprite(sprite: AnimatedSprite2D, anim_name: String, char_data: CharacterData = null) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	var resolved = anim_name
	if char_data != null:
		resolved = char_data.get_animation_name(anim_name)
	if sprite.sprite_frames.has_animation(resolved):
		return resolved
	var fallbacks: Array[String] = [
		anim_name,
		"death" if anim_name == "dead" else "dead",
		anim_name.replace("_0", "_"),
		"attack_%d" % _extract_slot_from_anim(anim_name),
		"close_attack",
		"attack",
		"attack_1",
		"idle",
	]
	for fb in fallbacks:
		if fb.is_empty():
			continue
		var resolved_fb = fb
		if char_data != null:
			resolved_fb = char_data.get_animation_name(fb)
		if sprite.sprite_frames.has_animation(resolved_fb):
			return resolved_fb
	if anim_name == "walk":
		for alias in ["walk_forward", "walking", "run"]:
			if sprite.sprite_frames.has_animation(alias):
				return alias
	if anim_name == "idle" and sprite.sprite_frames.has_animation("stand"):
		return "stand"
	return ""

static func _extract_slot_from_anim(anim_name: String) -> int:
	for i in range(1, 4):
		if anim_name.contains(str(i)):
			return i
	return 1

static func get_locomotion_animation(sprite: AnimatedSprite2D, anim_name: String, char_data: CharacterData = null) -> String:
	return resolve_animation_on_sprite(sprite, anim_name, char_data)


# ── Frame Queries ────────────────────────────────────────────────────────────

static func is_vfx_spawn_frame(atk_data: Resource, frame: int) -> bool:
	if atk_data is SinglePlayerAttackData:
		return atk_data.is_vfx_spawn_frame(frame)
	return false

static func is_hit_frame(atk_data: Resource, frame: int) -> bool:
	if atk_data is SinglePlayerAttackData:
		return atk_data.is_hit_frame(frame)
	if atk_data != null and "hitbox_start_frame" in atk_data:
		var start = int(atk_data.hitbox_start_frame)
		var dur = int(atk_data.hitbox_duration) if "hitbox_duration" in atk_data else 2
		return frame >= start and frame < (start + dur)
	return false

static func is_hitbox_active_on_frame(atk_data: Resource, frame: int) -> bool:
	return is_hit_frame(atk_data, frame)

static func is_close_range_frame(atk_data: Resource, frame: int) -> bool:
	if atk_data is SinglePlayerAttackData:
		return atk_data.is_close_range_frame(frame)
	return false

# Legacy aliases kept for MobController compatibility
static func is_arrow_spawn_frame(atk_data: Resource, frame: int) -> bool:
	return is_vfx_spawn_frame(atk_data, frame)

static func is_spell_spawn_frame(atk_data: Resource, frame: int) -> bool:
	return is_vfx_spawn_frame(atk_data, frame)

static func is_beam_spawn_frame(atk_data: Resource, frame: int) -> bool:
	return is_vfx_spawn_frame(atk_data, frame)

static func is_beam_active_frame(atk_data: Resource, frame: int) -> bool:
	return is_hit_frame(atk_data, frame)


# ── Range & Delivery Params ──────────────────────────────────────────────────

static func get_melee_range(atk_data: Resource, fallback: float = 90.0) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.melee_range
	return fallback

static func get_close_range(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.close_range_melee
	return 120.0

static func get_projectile_speed(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.projectile_speed
	return 800.0

static func get_beam_length(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.beam_length
	return 800.0

static func get_beam_hit_height(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.beam_hit_height
	return 40.0

static func get_aoe_radius(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.aoe_radius
	return 70.0

static func get_aoe_cast_distance(atk_data: Resource) -> float:
	if atk_data is SinglePlayerAttackData:
		return atk_data.aoe_cast_distance
	return 200.0

static func aoe_targets_enemies(atk_data: Resource) -> bool:
	if atk_data is SinglePlayerAttackData:
		return atk_data.aoe_targets_enemies
	return true


# ── Timing ───────────────────────────────────────────────────────────────────

static func compute_attack_duration(atk_data: Resource, attack_speed: float) -> float:
	var effective_speed = get_attack_speed(atk_data, attack_speed)
	if atk_data is SinglePlayerAttackData:
		var sf = atk_data.character_sprite_frames
		var anim = atk_data.character_animation
		if sf != null and sf.has_animation(anim):
			var count = sf.get_frame_count(anim)
			var fps = sf.get_animation_speed(anim)
			if fps > 0.0:
				return float(count) / (fps * effective_speed)
		var total_frames = atk_data.get_total_frames()
		return float(total_frames) / (10.0 * effective_speed)
	elif atk_data != null and "hitbox_start_frame" in atk_data:
		var start = int(atk_data.hitbox_start_frame)
		var dur = int(atk_data.hitbox_duration) if "hitbox_duration" in atk_data else 2
		var total_frames = start + dur + 8
		return float(total_frames) / (10.0 * effective_speed)
	return 1.5 / effective_speed


# ── VFX ──────────────────────────────────────────────────────────────────────

static func get_effect_vfx(atk_data: Resource) -> SinglePlayerVfxConfig:
	if atk_data is SinglePlayerAttackData:
		return atk_data.vfx_config
	return null

static func get_swing_vfx(atk_data: Resource) -> SinglePlayerVfxConfig:
	# Swing VFX is only used for melee — same config in the new system
	if atk_data is SinglePlayerAttackData and atk_data.delivery_type == SinglePlayerAttackData.DeliveryType.MELEE:
		return atk_data.vfx_config
	return null

static func resolve_spawn_position(caster: Node2D, marker_name: String, cfg: SinglePlayerVfxConfig = null) -> Vector2:
	if caster == null:
		return Vector2.ZERO

	var sprite = caster.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = caster.find_child("Sprite", true, false) as AnimatedSprite2D

	var is_flipped := false
	if sprite != null and sprite.flip_h:
		is_flipped = true

	if not marker_name.is_empty():
		var marker = _find_marker(caster, marker_name)
		if marker != null:
			if is_flipped and sprite != null:
				# Mirror local marker offset relative to sprite when flip_h is active
				var local_pos = marker.position
				var mirrored_local = Vector2(-local_pos.x, local_pos.y)
				return sprite.to_global(mirrored_local)
			else:
				return marker.global_position

	# Fallback: use offset from caster position
	var facing = -1 if is_flipped else 1
	if cfg != null:
		return caster.global_position + Vector2(facing * cfg.offset.x, cfg.offset.y)
	return caster.global_position

static func _find_marker(caster: Node2D, marker_name: String) -> Node2D:
	var marker = caster.get_node_or_null(marker_name) as Node2D
	if marker != null:
		return marker
	var sprite = caster.get_node_or_null("Sprite") as Node2D
	if sprite != null:
		marker = sprite.get_node_or_null(marker_name) as Node2D
		if marker != null:
			return marker
	return caster.find_child(marker_name, true, false) as Node2D

static func spawn_vfx_from_config(tree: SceneTree, cfg: SinglePlayerVfxConfig, world_pos: Vector2, facing: int, extra_props: Dictionary = {}) -> Node2D:
	if cfg == null or not cfg.has_visual():
		return null

	if cfg.vfx_scene != null:
		var inst = cfg.vfx_scene.instantiate() as Node2D
		if inst == null:
			return null
		inst.global_position = world_pos
		for key in extra_props:
			if key in inst:
				inst.set(key, extra_props[key])
		if "direction" in inst:
			inst.set("direction", facing)
		if "facing" in inst:
			inst.set("facing", facing)
		if "animation_name" in inst and not cfg.animation_name.is_empty():
			inst.set("animation_name", cfg.animation_name)
		tree.get_root().add_child(inst)
		return inst

	if cfg.sprite_frames != null:
		var anim_spr := AnimatedSprite2D.new()
		anim_spr.sprite_frames = cfg.sprite_frames
		anim_spr.global_position = world_pos
		anim_spr.scale = Vector2(facing, 1.0)
		anim_spr.modulate = cfg.tint
		var anim = cfg.animation_name if cfg.sprite_frames.has_animation(cfg.animation_name) else "default"
		anim_spr.play(anim)
		tree.get_root().add_child(anim_spr)
		return anim_spr

	if cfg.texture != null:
		var spr := Sprite2D.new()
		spr.texture = cfg.texture
		spr.global_position = world_pos + Vector2(facing * cfg.offset.x, cfg.offset.y)
		spr.scale = Vector2(facing, 1.0)
		spr.modulate = cfg.tint
		tree.get_root().add_child(spr)
		return spr

	return null


# ── Audio ────────────────────────────────────────────────────────────────────

static func play_attack_sfx(atk_data: Resource, audio_player: AudioStreamPlayer2D) -> void:
	if atk_data == null or audio_player == null:
		return
	if atk_data is SinglePlayerAttackData and atk_data.sfx != null:
		audio_player.stream = atk_data.sfx
		audio_player.play()
		return
	if "sound_effect" in atk_data and atk_data.sound_effect != null:
		audio_player.stream = atk_data.sound_effect
		audio_player.play()


# ── Entity Damage ────────────────────────────────────────────────────────────

static func apply_damage_to_entity(entity: Node, amount: float) -> void:
	if entity == null or not is_instance_valid(entity) or amount <= 0.0:
		return
	if entity.has_method("take_damage"):
		entity.take_damage(amount)
	elif entity.has_method("apply_damage"):
		entity.apply_damage(amount)
	elif entity.has_node("CharacterHealth"):
		var hp_node = entity.get_node("CharacterHealth")
		if hp_node.has_method("apply_damage"):
			hp_node.apply_damage(amount)
		elif hp_node.has_method("take_damage"):
			hp_node.take_damage(amount)

static func supports_combat_runtime(atk_data: Resource) -> bool:
	return atk_data is SinglePlayerAttackData


# ── Mob Targeting ────────────────────────────────────────────────────────────

static func find_nearest_mob(from_node: Node2D, tree: SceneTree, max_range: float = 700.0) -> Node2D:
	if from_node == null or tree == null:
		return null

	var best_mob: Node2D = null
	var best_dist := max_range

	for node in tree.get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or node == from_node or not (node is Node2D):
			continue
		if "is_knocked_out" in node and node.is_knocked_out:
			continue

		var mob := node as Node2D
		var dist = from_node.global_position.distance_to(mob.global_position)
		if dist <= best_dist:
			best_dist = dist
			best_mob = mob

	return best_mob

static func get_denser_enemy_facing(from_node: Node2D, tree: SceneTree, max_range: float = 700.0) -> int:
	if from_node == null or tree == null:
		return 0

	var left_count := 0
	var right_count := 0
	var my_pos = from_node.global_position

	for hurtbox in tree.get_nodes_in_group("hurtboxes"):
		if hurtbox is Area2D:
			var entity = hurtbox.get_parent()
			if entity == null or not (entity.has_method("take_damage") or entity.has_method("apply_damage")):
				if is_instance_valid(hurtbox.owner) and (hurtbox.owner.has_method("take_damage") or hurtbox.owner.has_method("apply_damage")):
					entity = hurtbox.owner
			if entity == from_node or entity == null:
				continue
			if "is_knocked_out" in entity and entity.is_knocked_out:
				continue
			var dist = my_pos.distance_to(hurtbox.global_position)
			if dist <= max_range:
				if hurtbox.global_position.x < my_pos.x:
					left_count += 1
				else:
					right_count += 1

	if left_count > right_count:
		return -1
	elif right_count > left_count:
		return 1
	return 0

static func find_best_aoe_cluster_target(from_node: Node2D, tree: SceneTree, radius: float, max_range: float = 1200.0) -> Variant:
	if from_node == null or tree == null or radius <= 0.0:
		return null

	var mob_positions: Array[Vector2] = []
	for node in tree.get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if "is_knocked_out" in node and node.is_knocked_out:
			continue
		var mob_pos := (node as Node2D).global_position
		if from_node.global_position.distance_to(mob_pos) <= max_range:
			mob_positions.append(mob_pos)

	if mob_positions.is_empty():
		return null

	var best_pos: Vector2 = mob_positions[0]
	var best_score := -INF

	for candidate in mob_positions:
		var in_cluster: Array[Vector2] = []
		for other in mob_positions:
			if candidate.distance_to(other) <= radius:
				in_cluster.append(other)

		var count := in_cluster.size()
		if count <= 0:
			continue

		var tightness_bonus := 0.0
		if count > 1:
			for i in range(count):
				for j in range(i + 1, count):
					tightness_bonus += 1.0 / (1.0 + in_cluster[i].distance_to(in_cluster[j]))

		var score := float(count) * 1000.0 + tightness_bonus
		if score > best_score:
			best_score = score
			best_pos = candidate

	return best_pos

static func get_facing_toward(from_pos: Vector2, target_pos: Vector2) -> int:
	if absf(target_pos.x - from_pos.x) < 4.0:
		return 1 if from_pos.x <= target_pos.x else -1
	return 1 if target_pos.x > from_pos.x else -1

static func get_locked_hurtbox(mob: Node2D) -> Area2D:
	if mob == null or not is_instance_valid(mob):
		return null
	return mob.get_node_or_null("Hurtbox") as Area2D

static func apply_facing_to_sprite(facing: int, sprite: AnimatedSprite2D) -> void:
	if sprite != null:
		sprite.flip_h = facing < 0
