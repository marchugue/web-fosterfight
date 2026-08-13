class_name HurtVignette
extends TextureRect

var _tween: Tween
var _pulse_tween: Tween
var _last_hp: float = -1.0
var _is_low_health: bool = false
var _base_low_hp_alpha: float = 0.0

func _ready() -> void:
	name = "HurtVignette"
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	z_index = 90
	modulate.a = 0.0

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.85, 0.0, 0.0, 0.0),    # Center: transparent
		Color(0.9, 0.02, 0.02, 0.4),   # Mid: translucent crimson
		Color(0.95, 0.0, 0.0, 0.95)    # Edges: intense dark blood red
	])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.95, 0.95)
	tex.width = 512
	tex.height = 512

	texture = tex

func trigger_hurt(damage_ratio: float = 0.15) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var peak_alpha: float = clampf(0.55 + damage_ratio * 2.5, 0.6, 0.95)

	# Sudden red flash impact
	modulate.a = peak_alpha

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)

	var target_fade_alpha = _base_low_hp_alpha if _is_low_health else 0.0
	var fade_time = clampf(0.45 + damage_ratio * 0.5, 0.45, 0.75)
	_tween.tween_property(self, "modulate:a", target_fade_alpha, fade_time)

func update_health(current_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	var hp_ratio = current_hp / max_hp
	var is_low = hp_ratio <= 0.25 and current_hp > 0.0

	if is_low != _is_low_health:
		_is_low_health = is_low
		if _is_low_health:
			_start_low_health_pulse()
		else:
			_stop_low_health_pulse()

func _start_low_health_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "modulate:a", 0.35, 0.6)
	_pulse_tween.tween_property(self, "modulate:a", 0.12, 0.6)
	_base_low_hp_alpha = 0.2

func _stop_low_health_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_base_low_hp_alpha = 0.0
	if modulate.a > 0.0 and (_tween == null or not _tween.is_valid()):
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
