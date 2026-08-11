class_name AttackData
extends Resource

enum HitEffect {
	NORMAL,
	AIRBORNE,
	STUN,
	CRUMPLE,
	WALL_BOUNCE
}

enum AttackType {
	MELEE,
	RANGED,
	AIRBORNE_LAUNCH,
	STUN_STAGGER,
	HEAVY_FINISHER
}

@export_group("Identity")
@export var attack_name: String = "Attack"
@export var character_id: String = ""
@export var type: AttackType = AttackType.MELEE

func is_valid_for_character(p_character_id: String) -> bool:
	if character_id.is_empty():
		return true
	return character_id.nocasecmp_to(p_character_id) == 0

@export_group("Animation")
@export var sprite_animation_name: String = ""
@export var custom_sprite_frames: SpriteFrames
@export var attack_speed: float = 1.0

var animation_name: String:
	get: return sprite_animation_name
	set(val): sprite_animation_name = val

@export_group("Hitbox Activation")
@export var hitbox_start_frame: int = 2
@export var hitbox_duration: int = 2
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var hitbox_scale_multiplier: Vector2 = Vector2.ONE

func is_hitbox_active_on_frame(frame: int) -> bool:
	return frame >= hitbox_start_frame and frame < (hitbox_start_frame + hitbox_duration)

@export_group("Audio")
@export var sfx_on_start: AudioStream
@export var sfx_on_swing: AudioStream

@export_group("Damage")
@export var damage: float = 40.0
@export var knockback: float = 120.0
@export var hitstun: float = 0.3
@export var launch_force: Vector2 = Vector2.ZERO
@export var effect: HitEffect = HitEffect.NORMAL

@export_group("Combat")
@export var cooldown: float = 0.5
@export var energy_cost: float = 0.0
@export var energy_gained_on_hit: float = 6.0
@export var can_cancel_after_hit: bool = false
@export var allowed_cancel_targets: Array[int] = []

func is_cancel_target_allowed(input_val: int) -> bool:
	return input_val in allowed_cancel_targets

@export var light_attack_string_cancel: bool = false
@export var string_steps: Array[AttackData] = []

var has_cancel_window: bool:
	get: return can_cancel_after_hit and (allowed_cancel_targets.size() > 0 or light_attack_string_cancel)
