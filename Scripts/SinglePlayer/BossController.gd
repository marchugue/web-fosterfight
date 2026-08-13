class_name SinglePlayerBossController
extends SinglePlayerMobController

signal phase_changed(new_phase: int)

enum BossPhase {
	PHASE_NORMAL,
	PHASE_ENRAGED
}

@export_group("Boss Config")
@export var current_phase: BossPhase = BossPhase.PHASE_NORMAL
@export var enrage_health_threshold: float = 0.5
@export var boss_slam_attack: Resource
@export var boss_fireball_attack: Resource
@export var invert_sprite_facing: bool = true

var _is_enraged: bool = false

func _ready() -> void:
	if entity_data != null:
		enrage_health_threshold = entity_data.enrage_health_threshold
	elif mob_health == 600.0:
		mob_health = 2000.0
		mob_movement_speed = 220.0

	attack_interval = maxf(attack_interval, 1.55)
	super._ready()
	_load_boss_attacks()

func _load_boss_attacks() -> void:
	if boss_slam_attack == null and ResourceLoader.exists("res://Resources/Attacks/single_player/level1/sp_boss_slam.tres"):
		boss_slam_attack = load("res://Resources/Attacks/single_player/level1/sp_boss_slam.tres")
	elif boss_slam_attack == null and ResourceLoader.exists("res://Resources/Attacks/single_player/sp_boss_slam.tres"):
		boss_slam_attack = load("res://Resources/Attacks/single_player/sp_boss_slam.tres")
	elif boss_slam_attack == null and ResourceLoader.exists("res://Resources/Attacks/boss/boss_slam.tres"):
		boss_slam_attack = load("res://Resources/Attacks/boss/boss_slam.tres")

	if boss_fireball_attack == null and ResourceLoader.exists("res://Resources/Attacks/boss/boss_fireball.tres"):
		boss_fireball_attack = load("res://Resources/Attacks/boss/boss_fireball.tres")

	if primary_attack == null and boss_slam_attack != null:
		primary_attack = boss_slam_attack

func _physics_process(delta: float) -> void:
	_check_phase_transition()
	super._physics_process(delta)

func _check_phase_transition() -> void:
	if _is_enraged or mob_health <= 0.0:
		return

	if (current_health / mob_health) <= enrage_health_threshold:
		trigger_enrage_phase()

func trigger_enrage_phase() -> void:
	if _is_enraged:
		return
	_is_enraged = true
	current_phase = BossPhase.PHASE_ENRAGED
	is_flying = true
	mob_attack_speed *= 1.2
	mob_attack_damage *= 1.2

	if boss_fireball_attack != null and _entity_data != null and boss_fireball_attack not in _entity_data.attacks:
		_entity_data.attacks.append(boss_fireball_attack)

	phase_changed.emit(int(current_phase))

	if _sprite != null:
		_sprite.modulate = Color(1.3, 0.5, 0.5, 1.0)

func _update_facing() -> void:
	super._update_facing()
	if invert_sprite_facing and _sprite != null:
		_sprite.flip_h = not _sprite.flip_h

func perform_attack() -> void:
	if is_attacking or is_knocked_out:
		return

	if _entity_data != null and not _entity_data.attacks.is_empty():
		super.perform_attack()
		return

	var atk_pool: Array[Resource] = []
	if primary_attack != null:
		atk_pool.append(primary_attack)
	if secondary_attack != null:
		atk_pool.append(secondary_attack)
	if boss_slam_attack != null:
		atk_pool.append(boss_slam_attack)
	if _is_enraged and boss_fireball_attack != null:
		atk_pool.append(boss_fireball_attack)

	if atk_pool.is_empty():
		return

	var chosen_attack = atk_pool[randi() % atk_pool.size()]
	is_attacking = true
	_current_attack_res = chosen_attack
	_attack_hit_processed = false
	_processed_hit_frames.clear()
	_hit_entities_this_attack.clear()
	_player_aoe_scheduled = false
	_set_hitbox_active(false)

	if _target != null and is_instance_valid(_target):
		facing_direction = 1 if (_target.global_position.x - global_position.x) > 0 else -1
		_update_facing()

	_play_attack_animation(1, chosen_attack)

	var duration = _compute_attack_duration(chosen_attack, 1)
	get_tree().create_timer(duration).timeout.connect(func():
		_set_hitbox_active(false)
		if not _attack_hit_processed and not is_knocked_out:
			_check_attack_hit(chosen_attack)
		is_attacking = false
		_current_attack_res = null
		_restore_base_sprite_frames()
		_play_animation("idle")
	, CONNECT_ONE_SHOT)
