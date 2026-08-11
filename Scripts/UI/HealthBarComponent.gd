class_name HealthBarComponent
extends Control

@export var bar_clip_path: NodePath = "%BarClip"
@export var bar_path: NodePath = "%Bar"
@export var delay_clip_path: NodePath = "%DelayClip"
@export var delay_bar_path: NodePath = "%DelayBar"
@export var name_label_path: NodePath = "%NameLabel"
@export var round_indicator1_path: NodePath = "%RoundIndicator1"
@export var round_indicator2_path: NodePath = "%RoundIndicator2"

@export var win_texture: Texture2D
@export var off_texture: Texture2D

var _bar_clip: Control
var _bar: TextureRect
var _delay_clip: Control
var _delay_bar: TextureRect
var _name_label: Label
var _round_indicator1: TextureRect
var _round_indicator2: TextureRect

var _max_width: float = 0.0
var _max_val: float = 1.0
var _last_known_current: float = -1.0
var _delay_tween: Tween
var _rounds_won: int = 0

func _ready() -> void:
	_bar_clip = get_node(bar_clip_path) as Control
	_bar = get_node(bar_path) as TextureRect
	_delay_clip = get_node(delay_clip_path) as Control
	_delay_bar = get_node(delay_bar_path) as TextureRect
	_name_label = get_node(name_label_path) as Label

	_round_indicator1 = get_node_or_null(round_indicator1_path) as TextureRect
	_round_indicator2 = get_node_or_null(round_indicator2_path) as TextureRect

	_max_width = _bar_clip.size.x
	_bar.size = Vector2(_max_width, _bar.size.y)
	_bar.position = Vector2(0.0, _bar.position.y)
	_delay_bar.size = Vector2(_max_width, _delay_bar.size.y)
	_delay_bar.position = Vector2(0.0, _delay_bar.position.y)

	_update_indicator_visuals()

func set_health(current: float, max_val: float) -> void:
	_max_val = maxf(max_val, 0.0001)
	var clamped_current = clampf(current, 0.0, _max_val)
	var took_damage = _last_known_current >= 0.0 and clamped_current < _last_known_current

	_bar_clip.size = Vector2(_width_for_value(clamped_current), _bar_clip.size.y)

	if _delay_tween != null:
		_delay_tween.kill()

	if took_damage:
		var hold_width = maxf(_delay_clip.size.x, _width_for_value(_last_known_current))
		_delay_clip.size = Vector2(hold_width, _delay_clip.size.y)

		_delay_tween = create_tween()
		_delay_tween.tween_interval(Constants.UI.HEALTH_DELAY_HOLD_SECONDS)
		_delay_tween.tween_property(_delay_clip, "size:x", _width_for_value(clamped_current), Constants.UI.HEALTH_DELAY_DRAIN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_delay_clip.size = Vector2(_width_for_value(clamped_current), _delay_clip.size.y)

	_last_known_current = clamped_current

func set_fighter_name(fighter_name: String) -> void:
	_name_label.text = fighter_name

func set_round_wins(wins: int) -> void:
	_rounds_won = maxi(wins, 0)
	_update_indicator_visuals()

func set_indicator_textures(p_win_texture: Texture2D, p_off_texture: Texture2D = null) -> void:
	win_texture = p_win_texture
	off_texture = p_off_texture
	_update_indicator_visuals()

func _update_indicator_visuals() -> void:
	_update_single_indicator(_round_indicator1, _rounds_won >= 1)
	_update_single_indicator(_round_indicator2, _rounds_won >= 2)

func _update_single_indicator(indicator: TextureRect, is_won: bool) -> void:
	if indicator == null:
		return

	if is_won:
		if win_texture != null:
			indicator.texture = win_texture
		indicator.modulate = Color.WHITE
	else:
		if off_texture != null:
			indicator.texture = off_texture
			indicator.modulate = Color.WHITE
		else:
			if win_texture != null:
				indicator.texture = win_texture
			indicator.modulate = Color(0.25, 0.25, 0.25, 0.4)

func _width_for_value(val: float) -> float:
	return _max_width * (val / _max_val)
