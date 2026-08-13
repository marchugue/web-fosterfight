class_name LaserVFX
extends Node2D

@export var facing: int = 1
@export var laser_range: float = 800.0
@export var beam_duration: float = 0.4

@export var vfx_offset: Vector2 = Vector2.ZERO
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "vfx3"
@export var texture: Texture2D

func _ready() -> void:
	z_index = 25
	modulate.a = 1.0
	position += Vector2(float(facing) * vfx_offset.x, vfx_offset.y)

	var anim_spr = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_spr != null:
		if sprite_frames != null:
			anim_spr.sprite_frames = sprite_frames
		var sf = anim_spr.sprite_frames
		if sf != null:
			var scale_x = float(facing) * maxf(1.0, laser_range / 260.0)
			anim_spr.scale = Vector2(scale_x, 1.4)
			var anim = animation_name if not animation_name.is_empty() and sf.has_animation(animation_name) else "vfx3"
			if not sf.has_animation(anim):
				anim = "default"
			anim_spr.play(anim)

	var spr = get_node_or_null("Sprite2D") as Sprite2D
	if spr != null and texture != null:
		spr.texture = texture
		spr.position = Vector2(float(facing) * laser_range * 0.5, 0)

	var line = get_node_or_null("Line2D") as Line2D
	if line == null and anim_spr == null:
		line = Line2D.new()
		line.width = 16.0
		line.default_color = Color(0.2, 0.85, 1.0, 0.95)
		add_child(line)

	if line != null:
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(float(facing) * laser_range, 0))

	var tween = create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
