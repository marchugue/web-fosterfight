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
	HEAVY_FINISHER,
	BOW_RANGED,
	SPELL_TARGET,
	LASER_BEAM
}

@export_group("Identity")
@export var attack_name: String = "Attack"
@export var character_id: String = ""
@export var type: AttackType = AttackType.MELEE

@export_group("Bow Ranged Config")
@export var close_range_threshold: float = 120.0
@export var close_range_hitbox_frame: int = 1
@export var arrow_spawn_frame: int = 3
@export var arrow_spawn_frames: Array[int] = [3]
@export var arrow_spawn_marker_name: String = "BowMuzzle"
@export var arrow_speed: float = 800.0
@export var arrow_vfx_offset: Vector2 = Vector2(25.0, -15.0)
@export var arrow_vfx_scene: PackedScene
@export var arrow_sprite_frames: SpriteFrames
@export var arrow_animation_name: String = "default"
@export var arrow_texture: Texture2D

@export_group("Spell Target Config")
@export var spell_spawn_frame: int = 2
@export var spell_aoe_radius: float = 60.0
@export var spell_vfx_color: Color = Color(0.6, 0.2, 1.0, 0.8)
@export var spell_vfx_offset: Vector2 = Vector2(0.0, 0.0)
@export var spell_vfx_scene: PackedScene
@export var spell_sprite_frames: SpriteFrames
@export var spell_animation_name: String = "default"
@export var spell_texture: Texture2D

@export_group("Laser Beam Config")
@export var laser_range_horizontal: float = 800.0
@export var laser_start_frame: int = 2
@export var laser_spawn_frames: Array[int] = [2]
@export var laser_duration_frames: int = 4
@export var laser_spawn_marker_name: String = "LaserMuzzle"
@export var laser_vfx_color: Color = Color(0.2, 0.8, 1.0, 0.9)
@export var laser_vfx_offset: Vector2 = Vector2(20.0, -15.0)
@export var laser_vfx_scene: PackedScene
@export var laser_sprite_frames: SpriteFrames
@export var laser_animation_name: String = "default"
@export var laser_texture: Texture2D

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

@export_group("Single-Player Frame Compatibility")
@export var startup_frames: int = 0
@export var active_frames: int = 0
@export var recovery_frames: int = 0

func is_hitbox_active_on_frame(frame: int) -> bool:
	return frame >= hitbox_start_frame and frame < (hitbox_start_frame + hitbox_duration)

@export_group("Audio")
@export var sound_effect: AudioStream
@export var sfx_on_start: AudioStream
@export var sfx_on_swing: AudioStream

@export_group("VFX")
@export var vfx_scene: PackedScene
@export var vfx_offset: Vector2 = Vector2(40, -20)

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
