class_name SinglePlayerVfxConfig
extends Resource

## Plug-and-play VFX block for SinglePlayerAttackData.
##
## Assign ONE of:
##   • vfx_scene  — a full PackedScene (ArrowVFX, SpellVFX, LaserVFX, etc.)
##   • sprite_frames + animation_name — auto-creates an AnimatedSprite2D
##   • texture — auto-creates a Sprite2D
##
## spawn_marker is the name of the Marker2D node on the character's Sprite
## (e.g. "BowMuzzle", "LaserMuzzle", "SpellCast").

@export_group("Visual")
@export var vfx_scene: PackedScene
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "default"
@export var texture: Texture2D

@export_group("Spawn Point")
## Name of the Marker2D node under the character's Sprite node.
@export var spawn_marker: String = ""
## Additional offset from the marker position.
@export var offset: Vector2 = Vector2.ZERO
## If true, the VFX node is reparented under the caster instead of world root.
@export var attach_to_caster: bool = false
## Tint color applied to the spawned VFX.
@export var tint: Color = Color.WHITE

func has_visual() -> bool:
	return vfx_scene != null or sprite_frames != null or texture != null

func duplicate_config() -> SinglePlayerVfxConfig:
	var copy := SinglePlayerVfxConfig.new()
	copy.vfx_scene = vfx_scene
	copy.sprite_frames = sprite_frames
	copy.animation_name = animation_name
	copy.texture = texture
	copy.spawn_marker = spawn_marker
	copy.offset = offset
	copy.attach_to_caster = attach_to_caster
	copy.tint = tint
	return copy
