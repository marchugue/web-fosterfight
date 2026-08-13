@tool
class_name SinglePlayerAttackData
extends Resource

## Simplified single-player attack resource.
##
## Setup:
##   1. Pick a DeliveryType
##   2. Set character_animation + vfx_config
##   3. Fill in vfx_spawn_frames and hit_frames
##   Done — VFX spawns on the frame numbers you specify, from the Marker2D you name.

enum DeliveryType {
	MELEE,
	PROJECTILE,
	BEAM,
	AOE,
}

# ── 1 · Basics ──────────────────────────────────────────────────────────────

@export_group("1 · Basics")
@export var attack_name: String = "Attack"
@export var delivery_type: DeliveryType = DeliveryType.MELEE
@export var damage: float = 40.0
@export var knockback: float = 120.0
@export var attack_speed: float = 1.5
@export var cooldown: float = 0.5

# ── 2 · Character Animation ─────────────────────────────────────────────────

@export_group("2 · Animation")
@export var character_animation: String = "attack_1"
@export var character_sprite_frames: SpriteFrames

# ── 3 · Frame Events ────────────────────────────────────────────────────────

@export_group("3 · Frame Events")
## Activation frame where the melee attack initializes / telegraphs.
@export var activation_frame: int = 1
## Frames on which to spawn the VFX (arrow / spell / beam visual).
@export var vfx_spawn_frames: Array[int] = [2]
## Frames on which the hitbox is active (damage window).
@export var hit_frames: Array[int] = [2, 3]
## Frames on which to check close-range melee hit (PROJECTILE only).
@export var close_range_frames: Array[int] = []
## Recovery frames after the last active frame before returning to idle.
@export var recovery_frames: int = 8

# ── 4 · VFX ─────────────────────────────────────────────────────────────────

@export_group("4 · VFX")
## Single VFX config — set the scene, spawn marker, and offset here.
@export var vfx_config: SinglePlayerVfxConfig

# ── 5 · Delivery Parameters ─────────────────────────────────────────────────

@export_group("5 · Delivery")
@export var melee_range: float = 90.0
@export var close_range_melee: float = 120.0
@export var projectile_speed: float = 800.0
@export var beam_length: float = 800.0
@export var beam_hit_height: float = 40.0
@export var aoe_radius: float = 70.0
@export var aoe_cast_distance: float = 200.0
@export var aoe_targets_enemies: bool = true
## If true, AOE is placed on the player's position when cast begins (dodgeable).
@export var aoe_targets_player_position: bool = false
## Seconds after the cast marker before impact damage resolves.
@export var aoe_impact_delay: float = 0.75
## Visual scale multiplier for AOE spell VFX.
@export var aoe_vfx_scale: float = 1.0
## Prefer casting on enemy clusters instead of a fixed forward offset.
@export var aoe_prioritize_clusters: bool = false

# ── 6 · Auto Lock ───────────────────────────────────────────────────────────

@export_group("6 · Auto Lock & Armor")
@export var auto_lock_on_attack: bool = true
## If true, character cannot be flinched/staggered out of this attack by enemy damage.
@export var is_uninterruptable: bool = true

# ── 7 · Audio ───────────────────────────────────────────────────────────────

@export_group("7 · Audio")
@export var sfx: AudioStream


# ── Frame Queries ────────────────────────────────────────────────────────────

func is_vfx_spawn_frame(frame: int) -> bool:
	return frame in vfx_spawn_frames

func get_activation_frame() -> int:
	if activation_frame > 0:
		return activation_frame
	if not vfx_spawn_frames.is_empty():
		return vfx_spawn_frames[0]
	if not hit_frames.is_empty():
		return hit_frames[0]
	return 1

func is_hit_frame(frame: int) -> bool:
	return frame in hit_frames

func is_close_range_frame(frame: int) -> bool:
	return frame in close_range_frames

func get_total_frames() -> int:
	var max_f := 0
	for f in vfx_spawn_frames:
		max_f = maxi(max_f, f)
	for f in hit_frames:
		max_f = maxi(max_f, f)
	for f in close_range_frames:
		max_f = maxi(max_f, f)
	return max_f + recovery_frames

func get_spawn_marker_name() -> String:
	if vfx_config != null and not vfx_config.spawn_marker.is_empty():
		return vfx_config.spawn_marker
	match delivery_type:
		DeliveryType.PROJECTILE: return "BowMuzzle"
		DeliveryType.BEAM: return "LaserMuzzle"
		DeliveryType.AOE: return "SpellCast"
	return ""


# ── Static Factories ─────────────────────────────────────────────────────────

static func create_melee(p_name: String = "Melee Slash", p_anim: String = "close_attack") -> SinglePlayerAttackData:
	var atk := SinglePlayerAttackData.new()
	atk.attack_name = p_name
	atk.delivery_type = DeliveryType.MELEE
	atk.character_animation = p_anim
	atk.hit_frames = [4, 5, 6]
	atk.recovery_frames = 8
	atk.melee_range = 90.0
	return atk

static func create_projectile(p_name: String = "Bow Shot", p_anim: String = "attack_1") -> SinglePlayerAttackData:
	var atk := SinglePlayerAttackData.new()
	atk.attack_name = p_name
	atk.delivery_type = DeliveryType.PROJECTILE
	atk.character_animation = p_anim
	atk.vfx_spawn_frames = [7]
	atk.hit_frames = [7]
	atk.close_range_frames = [1]
	atk.recovery_frames = 6
	atk.projectile_speed = 800.0
	var cfg := SinglePlayerVfxConfig.new()
	cfg.spawn_marker = "BowMuzzle"
	cfg.animation_name = "arrow"
	atk.vfx_config = cfg
	return atk

static func create_beam(p_name: String = "Laser Beam", p_anim: String = "attack_2") -> SinglePlayerAttackData:
	var atk := SinglePlayerAttackData.new()
	atk.attack_name = p_name
	atk.delivery_type = DeliveryType.BEAM
	atk.character_animation = p_anim
	atk.vfx_spawn_frames = [4]
	atk.hit_frames = [4, 5, 6, 7, 8, 9, 10]
	atk.recovery_frames = 10
	atk.beam_length = 800.0
	var cfg := SinglePlayerVfxConfig.new()
	cfg.spawn_marker = "LaserMuzzle"
	cfg.tint = Color(0.2, 0.85, 1.0, 0.95)
	cfg.animation_name = "vfx2"
	atk.vfx_config = cfg
	return atk

static func create_aoe(p_name: String = "Spell Burst", p_anim: String = "attack_3") -> SinglePlayerAttackData:
	var atk := SinglePlayerAttackData.new()
	atk.attack_name = p_name
	atk.delivery_type = DeliveryType.AOE
	atk.character_animation = p_anim
	atk.vfx_spawn_frames = [6]
	atk.hit_frames = [6, 7, 8]
	atk.recovery_frames = 8
	atk.aoe_radius = 70.0
	var cfg := SinglePlayerVfxConfig.new()
	cfg.spawn_marker = "SpellCast"
	cfg.tint = Color(0.7, 0.25, 1.0, 0.85)
	cfg.animation_name = "vfx3"
	atk.vfx_config = cfg
	return atk
