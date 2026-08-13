class_name SinglePlayerLevelManager
extends Node

signal wave_changed(wave_num: int, is_boss: bool)
signal level_cleared

@export_group("Level Configuration")
@export var level_data: SinglePlayerLevelData

@export_group("Node References")
@export var player_path: NodePath = "../P1"
@export var camera_path: NodePath = "../BattleCamera"
@export var ui_path: NodePath = "../UI/SinglePlayerWaveHUD"

@export_group("Spawn Tuning")
## Base mob scale — tuned to match the player (~7× scene scale × ~0.32 sprite scale ≈ 2.2).
@export var spawned_mob_scale: float = 2.2
@export var max_concurrent_mobs: int = 5

@export_group("Debug")
## TEMP: After clearing this wave, jump straight to the boss (skips later mob waves). 0 = normal.
@export var debug_skip_to_boss_after_wave: int = 0

var _player: Node
var _camera: BattleCamera
var _ui: Node
var _level_cleared: bool = false

var current_wave: int = 0
var total_waves: int = 7
var active_mobs: Array[Node] = []

var _spawn_queue: Array[SinglePlayerEntityData] = []
var _current_wave_stat_mult: float = 1.0
var _spawn_check_timer: float = 0.0
var _is_transitioning_wave: bool = false

func _ready() -> void:
	call_deferred("_setup_level")

func _process(delta: float) -> void:
	if _level_cleared or current_wave <= 0:
		return

	_spawn_check_timer += delta
	if _spawn_check_timer < 0.35:
		return
	_spawn_check_timer = 0.0

	_purge_active_mobs()
	if not _spawn_queue.is_empty() and active_mobs.size() < max_concurrent_mobs:
		_process_spawn_queue()
	_check_wave_complete()

func _setup_level() -> void:
	if not player_path.is_empty() and has_node(player_path):
		_player = get_node(player_path)
	elif has_node("../P1"):
		_player = get_node("../P1")
	elif has_node("../SinglePlayerCharacter"):
		_player = get_node("../SinglePlayerCharacter")
	else:
		var p_nodes = get_tree().get_nodes_in_group("players")
		if not p_nodes.is_empty():
			_player = p_nodes[0]

	if _player != null and _player.has_signal("character_died"):
		_player.connect("character_died", _on_player_died)

	if not camera_path.is_empty() and has_node(camera_path):
		_camera = get_node(camera_path) as BattleCamera

	_resolve_ui()

	if level_data == null:
		_create_fallback_level_data()

	_cleanup_preplaced_mobs()

	if _ui != null and _player != null and _ui.has_method("update_fighter_references"):
		_ui.call("update_fighter_references", _player, null)

	# Wire attack cooldown signal → HUD
	if _player != null and _player.has_signal("attack_slot_used") and _ui != null:
		if not _player.is_connected("attack_slot_used", _on_player_attack_slot_used):
			_player.connect("attack_slot_used", _on_player_attack_slot_used)

	_start_wave(1)

func _on_player_attack_slot_used(slot: int, cooldown_duration: float) -> void:
	if _ui != null and _ui.has_method("notify_attack_used"):
		_ui.call("notify_attack_used", slot, cooldown_duration)

func _resolve_ui() -> void:
	_ui = null
	if not ui_path.is_empty() and has_node(ui_path):
		_ui = get_node(ui_path)
	elif has_node("../UI/SinglePlayerWaveHUD"):
		_ui = get_node("../UI/SinglePlayerWaveHUD")
	elif has_node("../UI/BattleUI"):
		_ui = get_node("../UI/BattleUI")

	if _ui == null:
		push_warning("SinglePlayerLevelManager: Wave HUD not found — add SinglePlayerWaveHUD under UI/")

func _create_fallback_level_data() -> void:
	if ResourceLoader.exists("res://Resources/SinglePlayer/level1_data.tres"):
		level_data = load("res://Resources/SinglePlayer/level1_data.tres") as SinglePlayerLevelData
	else:
		level_data = SinglePlayerLevelData.new()
		level_data.level_id = "level1"
		level_data.level_name = "Battle Arena"
		if ResourceLoader.exists("res://Resources/SinglePlayer/mob_level1_goblin.tres"):
			level_data.assigned_mob = load("res://Resources/SinglePlayer/mob_level1_goblin.tres")
		if ResourceLoader.exists("res://Resources/SinglePlayer/boss_level1_golem.tres"):
			level_data.assigned_boss = load("res://Resources/SinglePlayer/boss_level1_golem.tres")

func _cleanup_preplaced_mobs() -> void:
	if has_node("../Mob"):
		get_node("../Mob").queue_free()
	if has_node("../BossMob"):
		get_node("../BossMob").queue_free()

func _start_wave(wave_num: int) -> void:
	if _level_cleared:
		return

	_is_transitioning_wave = false
	current_wave = wave_num
	active_mobs.clear()
	_spawn_queue.clear()
	var is_boss_wave = (current_wave == total_waves)

	wave_changed.emit(current_wave, is_boss_wave)

	if _ui != null and _ui.has_method("show_wave_banner"):
		if is_boss_wave:
			var boss_name = "GOLEM BOSS"
			if level_data != null and level_data.assigned_boss != null:
				boss_name = level_data.assigned_boss.display_name.to_upper()
			_ui.call("show_wave_banner", current_wave, true, "FINAL WAVE: %s!" % boss_name)
		else:
			_ui.call("show_wave_banner", current_wave, false, "WAVE %d / %d" % [current_wave, total_waves - 1])

	var parent_scene = get_parent()

	if is_boss_wave:
		var boss_scene = level_data.boss_scene if (level_data != null and level_data.boss_scene != null) else load("res://Scenes/single_player/SinglePlayerBoss.tscn")
		if boss_scene != null:
			var boss_inst = boss_scene.instantiate()
			var boss_res = level_data.assigned_boss if level_data != null else null
			var spawn_pos = _get_spawn_position_for_mob(boss_res)
			boss_inst.position = spawn_pos
			parent_scene.add_child.call_deferred(boss_inst)

			if boss_res != null and boss_inst.has_method("initialize_from_entity_data"):
				boss_inst.call("initialize_from_entity_data", boss_res, 1.8)

			var boss_scale = _resolve_mob_scale(boss_res)
			if boss_scale > 0.0:
				boss_inst.scale = Vector2.ONE * boss_scale

			_connect_mob_death(boss_inst)
			active_mobs.append(boss_inst)
			_update_wave_ui()
	else:
		var bat_res = load("res://Resources/SinglePlayer/mob_level1_bat.tres") as SinglePlayerEntityData
		var mob2_res = load("res://Resources/SinglePlayer/mob_level1_combo_warrior.tres") as SinglePlayerEntityData
		var mob3_res = load("res://Resources/SinglePlayer/mob_wave3_orb_caster.tres") as SinglePlayerEntityData

		match current_wave:
			1:
				_current_wave_stat_mult = 1.0
				# Wave 1: Small quantity of bats (4)
				for i in range(4):
					_spawn_queue.append(bat_res)
			2:
				_current_wave_stat_mult = 1.15
				# Wave 2: More bats (8)
				for i in range(8):
					_spawn_queue.append(bat_res)
			3:
				_current_wave_stat_mult = 1.3
				# Wave 3: Mob 2 + Bats (3 Mob 2, 5 Bats)
				for i in range(3):
					_spawn_queue.append(mob2_res)
				for i in range(5):
					_spawn_queue.append(bat_res)
			4:
				_current_wave_stat_mult = 1.45
				# Wave 4: More Mob 2 + Bats (6 Mob 2, 8 Bats)
				for i in range(6):
					_spawn_queue.append(mob2_res)
				for i in range(8):
					_spawn_queue.append(bat_res)
			5:
				_current_wave_stat_mult = 1.6
				# Wave 5: Mob 3 + Mob 2 + Bats (2 Mob 3, 4 Mob 2, 4 Bats)
				for i in range(2):
					_spawn_queue.append(mob3_res)
				for i in range(4):
					_spawn_queue.append(mob2_res)
				for i in range(4):
					_spawn_queue.append(bat_res)
			6:
				_current_wave_stat_mult = 1.75
				# Wave 6: More Mob 3 + Mob 2 + Bats (4 Mob 3, 6 Mob 2, 6 Bats)
				for i in range(4):
					_spawn_queue.append(mob3_res)
				for i in range(6):
					_spawn_queue.append(mob2_res)
				for i in range(6):
					_spawn_queue.append(bat_res)

		_spawn_queue = _spawn_queue.filter(func(res): return res != null)
		_process_spawn_queue()

	_update_target_references()
	_update_wave_ui()

func _get_spawn_position_for_mob(mob_res: SinglePlayerEntityData) -> Vector2:
	var specific_positions: Array[Vector2] = []
	var generic_positions: Array[Vector2] = []

	var is_flying = (mob_res != null and mob_res.is_flying)

	var markers = get_tree().get_nodes_in_group("spawn_points")
	if markers.is_empty():
		var parent = get_parent()
		if parent != null and parent.has_node("SpawnPoints"):
			var container = parent.get_node("SpawnPoints")
			for child in container.get_children():
				if child is Node2D:
					markers.append(child)

	for m in markers:
		if not (m is Node2D):
			continue
		var n_name = m.name.to_lower()
		var meta_type = m.get_meta("mob_type", "").to_lower() if m.has_meta("mob_type") else ""

		var matches_mob = false
		if is_flying:
			if n_name.contains("air") or n_name.contains("bat") or n_name.contains("fly") or meta_type in ["flying", "bat", "air"]:
				matches_mob = true
		else:
			if n_name.contains("ground") or meta_type in ["ground", "warrior", "caster", "archon", "mob2", "mob3", "mob4"]:
				matches_mob = true

		if matches_mob:
			specific_positions.append(m.global_position)
		else:
			generic_positions.append(m.global_position)

	var selected_pos = Vector2(500, 300)

	if not specific_positions.is_empty():
		selected_pos = specific_positions.pick_random()
	elif not generic_positions.is_empty():
		selected_pos = generic_positions.pick_random()
	elif level_data != null and not level_data.spawn_positions.is_empty():
		var tres_positions = level_data.spawn_positions
		var filtered: Array[Vector2] = []
		for pos in tres_positions:
			if is_flying and pos.y <= 300.0:
				filtered.append(pos)
			elif not is_flying and pos.y > 300.0:
				filtered.append(pos)
		if not filtered.is_empty():
			selected_pos = filtered.pick_random()
		else:
			selected_pos = tres_positions.pick_random()

	var offset_x = randf_range(-60.0, 60.0)
	var offset_y = randf_range(-30.0, 20.0) if is_flying else 0.0
	return selected_pos + Vector2(offset_x, offset_y)

func _pick_mob_scene(mob_res: SinglePlayerEntityData) -> PackedScene:
	if mob_res != null:
		var name_str = mob_res.display_name.to_lower()
		if mob_res.is_boss and ResourceLoader.exists("res://Scenes/single_player/SinglePlayerBoss.tscn"):
			return load("res://Scenes/single_player/SinglePlayerBoss.tscn")
		if (name_str.contains("warrior") or name_str.contains("combo")) and ResourceLoader.exists("res://Scenes/single_player/SinglePlayerMob2.tscn"):
			return load("res://Scenes/single_player/SinglePlayerMob2.tscn")
		if (name_str.contains("caster") or name_str.contains("orb")) and ResourceLoader.exists("res://Scenes/single_player/SinglePlayerMob3.tscn"):
			return load("res://Scenes/single_player/SinglePlayerMob3.tscn")
		if mob_res.is_flying and ResourceLoader.exists("res://Scenes/single_player/SinglePlayerMob1.tscn"):
			return load("res://Scenes/single_player/SinglePlayerMob1.tscn")

	if mob_res != null and mob_res.is_flying:
		return load("res://Scenes/single_player/SinglePlayerMob1.tscn")
	return load("res://Scenes/single_player/SinglePlayerMob2.tscn")

func _resolve_mob_scale(mob_res: SinglePlayerEntityData) -> float:
	var entity_scale := 1.0
	if mob_res != null and mob_res.scale_multiplier > 0.0:
		entity_scale = mob_res.scale_multiplier
	return spawned_mob_scale * entity_scale

func _process_spawn_queue() -> void:
	_purge_active_mobs()
	if _spawn_queue.is_empty():
		return

	var parent_scene = get_parent()
	if parent_scene == null:
		return

	while active_mobs.size() < max_concurrent_mobs and not _spawn_queue.is_empty():
		var mob_res = _spawn_queue.pop_front()
		if mob_res == null:
			continue

		var mob_scene = _pick_mob_scene(mob_res)
		if mob_scene == null:
			continue

		var mob_inst = mob_scene.instantiate()
		mob_inst.position = _get_spawn_position_for_mob(mob_res)
		parent_scene.add_child.call_deferred(mob_inst)

		if mob_inst.has_method("initialize_from_entity_data"):
			mob_inst.call("initialize_from_entity_data", mob_res, _current_wave_stat_mult)

		var mob_scale = _resolve_mob_scale(mob_res)
		if mob_scale > 0.0:
			mob_inst.scale = Vector2.ONE * mob_scale

		_connect_mob_death(mob_inst)
		active_mobs.append(mob_inst)

	_update_wave_ui()

func _connect_mob_death(mob_inst: Node) -> void:
	if mob_inst == null or not mob_inst.has_signal("mob_died"):
		return
	if mob_inst.has_meta("_wave_death_connected"):
		return
	mob_inst.set_meta("_wave_death_connected", true)
	mob_inst.connect("mob_died", _on_mob_in_wave_died.bind(mob_inst))

func _purge_active_mobs() -> void:
	active_mobs = active_mobs.filter(func(node):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			return false
		if "is_knocked_out" in node and node.is_knocked_out:
			return false
		return true
	)

func _get_remaining_enemies() -> int:
	return _spawn_queue.size() + active_mobs.size()

func _update_wave_ui() -> void:
	if _ui != null and _ui.has_method("update_wave_info"):
		var is_boss = (current_wave == total_waves)
		_ui.call("update_wave_info", current_wave, total_waves, _get_remaining_enemies(), is_boss)

func _update_target_references() -> void:
	_purge_active_mobs()

	if active_mobs.is_empty():
		if _camera != null and _player != null:
			_camera.update_fighter_references(_player, null)
		if _ui != null and _player != null and _ui.has_method("update_fighter_references"):
			_ui.call("update_fighter_references", _player, null)
		return

	var primary_target = active_mobs[0]
	if _camera != null and _player != null:
		_camera.update_fighter_references(_player, primary_target)

	if _ui != null and _player != null and _ui.has_method("update_fighter_references"):
		_ui.call("update_fighter_references", _player, primary_target)

func _on_mob_in_wave_died(mob_node: Node) -> void:
	if mob_node in active_mobs:
		active_mobs.erase(mob_node)

	_purge_active_mobs()
	_process_spawn_queue()
	_update_wave_ui()
	_check_wave_complete()

	if not active_mobs.is_empty() or not _spawn_queue.is_empty():
		_update_target_references()

func _check_wave_complete() -> void:
	if _level_cleared or current_wave <= 0 or _is_transitioning_wave:
		return

	_purge_active_mobs()
	if not active_mobs.is_empty() or not _spawn_queue.is_empty():
		return

	if current_wave < total_waves:
		_schedule_next_wave()
	else:
		_on_all_waves_cleared()

func _resolve_next_wave_number(from_wave: int) -> int:
	var next_wave = from_wave + 1
	if debug_skip_to_boss_after_wave > 0 and from_wave >= debug_skip_to_boss_after_wave:
		return total_waves
	return mini(next_wave, total_waves)

func _schedule_next_wave() -> void:
	if _is_transitioning_wave:
		return
	_is_transitioning_wave = true
	var next_wave = _resolve_next_wave_number(current_wave)

	# Show chest reward screen between mob waves (not before boss wave)
	var is_going_to_boss = (next_wave == total_waves)
	var show_chest = not is_going_to_boss and current_wave >= 1

	if show_chest and _player != null:
		get_tree().create_timer(1.0).timeout.connect(func():
			_show_chest_reward(current_wave, next_wave)
		, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(1.5).timeout.connect(func():
			_is_transitioning_wave = false
			if _level_cleared:
				return
			_start_wave(next_wave)
		, CONNECT_ONE_SHOT)

func _show_chest_reward(completed_wave: int, next_wave: int) -> void:
	var chest_scene = load("res://Scenes/single_player/ChestPickup.tscn") as PackedScene
	var chest: Area2D = null

	if chest_scene != null:
		chest = chest_scene.instantiate() as Area2D
	else:
		var chest_script = load("res://Scripts/SinglePlayer/ChestPickup.gd")
		if chest_script != null:
			chest = chest_script.new() as Area2D

	if chest == null:
		# Fallback: no chest, just start next wave
		get_tree().create_timer(0.3).timeout.connect(func():
			_is_transitioning_wave = false
			_start_wave(next_wave)
		, CONNECT_ONE_SHOT)
		return

	# Find a good spawn position — center of the level near the ground
	var spawn_pos = _get_chest_spawn_position()

	get_tree().current_scene.add_child.call_deferred(chest)
	chest.global_position = Vector2(spawn_pos.x, spawn_pos.y - 200.0)  # drop from above
	if chest.has_method("setup"):
		chest.call("setup", completed_wave, spawn_pos.y)

	# When chest is opened and card chosen → start next wave
	chest.chest_opened.connect(func():
		# chest_opened fires right before ChestRewardUI takes over;
		# ChestRewardUI.close callback will call on_chosen which we set below
		pass
	, CONNECT_ONE_SHOT)

	# Override the chest's show_reward callback to resume wave when done
	# The chest itself handles reward UI; we listen to it freeing itself via tree_exiting
	chest.tree_exiting.connect(func():
		_is_transitioning_wave = false
		if not _level_cleared:
			_start_wave(next_wave)
	, CONNECT_ONE_SHOT)

	# Show a "Wave Cleared!" banner while the chest drops
	if _ui != null and _ui.has_method("show_wave_banner"):
		_ui.call("show_wave_banner", completed_wave, false, "WAVE CLEARED! A chest appeared!")

func _get_chest_spawn_position() -> Vector2:
	# Try to find a spawn point marker; fallback to center of scene
	var markers = get_tree().get_nodes_in_group("spawn_points")
	if not markers.is_empty():
		# Pick the most central ground marker
		var best: Node2D = null
		var best_x_dist = INF
		for m in markers:
			if not (m is Node2D):
				continue
			if absf(m.global_position.x) < best_x_dist:
				best_x_dist = absf(m.global_position.x)
				best = m as Node2D
		if best != null:
			return best.global_position

	if _player != null and is_instance_valid(_player):
		return _player.global_position + Vector2(180, 0)

	return Vector2(640, 450)

func _on_all_waves_cleared() -> void:
	if _level_cleared:
		return
	_level_cleared = true
	level_cleared.emit()

	if _ui != null and _ui.has_method("show_wave_banner"):
		_ui.call("show_wave_banner", 0, true, "VICTORY! ALL WAVES CLEARED!")

	if AudioManager.instance != null:
		AudioManager.instance.play_match_win_sfx()

	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(_transition_to_results, CONNECT_ONE_SHOT)

func _on_player_died() -> void:
	if _level_cleared:
		return
	_level_cleared = true

	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(func():
		get_tree().reload_current_scene()
	, CONNECT_ONE_SHOT)

func _transition_to_results() -> void:
	if GameManager.instance != null:
		GameManager.instance.go_to_result()
	else:
		get_tree().change_scene_to_file("res://Scenes/Result.tscn")
