class_name SinglePlayerAnimation
extends CharacterAnimation

func _resolve_existing_animation_name(p_name: String) -> String:
	if p_name.strip_edges().is_empty() or _sprite == null or _sprite.sprite_frames == null:
		return ""

	if _sprite.sprite_frames.has_animation(p_name):
		return p_name

	if p_name == "walk" and _sprite.sprite_frames.has_animation("run"):
		return "run"

	if (p_name == "close_attack" or p_name.begins_with("close")) and _sprite.sprite_frames.has_animation("close_attack"):
		return "close_attack"

	if p_name.begins_with("attack") and _sprite.sprite_frames.has_animation("close_attack"):
		return "close_attack"

	return super._resolve_existing_animation_name(p_name)
