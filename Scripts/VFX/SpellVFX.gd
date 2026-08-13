class_name SpellVFX
extends Node2D

@export var fade_duration: float = 12.5
@export var vfx_offset: Vector2 = Vector2.ZERO
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "vfx2"
@export var texture: Texture2D
@export var duration_scale: float = 25.0

@export var facing: int = 1:
	set(val):
		facing = val
		if val < 0:
			scale.x = -absf(scale.x)
		else:
			scale.x = absf(scale.x)

func _ready() -> void:
	z_index = 25
	if facing < 0:
		scale.x = -absf(scale.x)
	position += vfx_offset

	var anim_spr = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_spr != null:
		if sprite_frames != null:
			anim_spr.sprite_frames = sprite_frames
		var sf = anim_spr.sprite_frames
		if sf != null:
			var anim = animation_name if not animation_name.is_empty() and sf.has_animation(animation_name) else "vfx2"
			if not sf.has_animation(anim):
				anim = "default"
			if duration_scale > 0.0:
				anim_spr.speed_scale = 1.0 / duration_scale
			anim_spr.play(anim)
			if not anim_spr.animation_finished.is_connected(queue_free):
				anim_spr.animation_finished.connect(queue_free)
			return

	var spr = get_node_or_null("Sprite2D") as Sprite2D
	if spr != null and texture != null:
		spr.texture = texture

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration * duration_scale)
	tween.tween_callback(queue_free)
