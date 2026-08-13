class_name RoundIntroOverlay
extends Control

@export var round_title_label_path: NodePath = "%RoundTitleLabel"
@export var focus_name_label_path: NodePath = "%FocusNameLabel"
@export var focus_player_label_path: NodePath = "%FocusPlayerLabel"
@export var fight_label_path: NodePath = "%FightLabel"
@export var dim_panel_path: NodePath = "%DimPanel"

var _round_title_label: Label
var _focus_name_label: Label
var _focus_player_label: Label
var _fight_label: Label
var _dim_panel: ColorRect
var _tween: Tween

func _ready() -> void:
	_round_title_label = get_node_or_null(round_title_label_path) as Label
	_focus_name_label = get_node_or_null(focus_name_label_path) as Label
	_focus_player_label = get_node_or_null(focus_player_label_path) as Label
	_fight_label = get_node_or_null(fight_label_path) as Label
	_dim_panel = get_node_or_null(dim_panel_path) as ColorRect
	visible = false

func show_round_intro(round_number: int, _p1_wins: int, _p2_wins: int) -> void:
	visible = true
	if _fight_label != null: _fight_label.visible = false
	if _focus_name_label != null: _focus_name_label.visible = false
	if _focus_player_label != null: _focus_player_label.visible = false
	if _dim_panel != null: _dim_panel.visible = true

	if _round_title_label != null:
		_round_title_label.text = "ROUND %d" % round_number
		_round_title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_round_title_label.scale = Vector2(1.4, 1.4)
	if _dim_panel != null:
		_dim_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_restart_tween()
	if _dim_panel != null:
		_tween.tween_property(_dim_panel, "modulate:a", 0.45, 0.35)
	if _round_title_label != null:
		_tween.parallel().tween_property(_round_title_label, "modulate:a", 1.0, 0.45)
		_tween.parallel().tween_property(_round_title_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_round_overlay(round_number: int, _p1_wins: int, _p2_wins: int) -> void:
	visible = true
	if _fight_label != null: _fight_label.visible = false
	if _focus_name_label != null: _focus_name_label.visible = false
	if _focus_player_label != null: _focus_player_label.visible = false
	if _dim_panel != null: _dim_panel.visible = false

	if _round_title_label != null:
		_round_title_label.text = "ROUND %d" % round_number
		_round_title_label.modulate = Color(1.0, 0.92, 0.35, 0.0)
		_round_title_label.scale = Vector2(1.6, 1.6)

	_restart_tween()
	if _round_title_label != null:
		_tween.tween_property(_round_title_label, "modulate:a", 1.0, 0.2)
		_tween.parallel().tween_property(_round_title_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func focus_player(display_name: String, player_number: int) -> void:
	if _fight_label != null: _fight_label.visible = false
	if _focus_name_label != null: _focus_name_label.visible = true
	if _focus_player_label != null: _focus_player_label.visible = true

	if _focus_player_label != null:
		_focus_player_label.text = "PLAYER %d" % player_number
		_focus_player_label.modulate = Color(1.0, 0.92, 0.35, 0.0)
		_focus_player_label.position = Vector2(_focus_player_label.position.x, 560.0)

	if _focus_name_label != null:
		_focus_name_label.text = display_name.to_upper()
		_focus_name_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_focus_name_label.scale = Vector2(0.85, 0.85)

	_restart_tween()
	if _focus_player_label != null:
		_tween.tween_property(_focus_player_label, "modulate:a", 1.0, 0.25)
		_tween.parallel().tween_property(_focus_player_label, "position:y", 520.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _focus_name_label != null:
		_tween.parallel().tween_property(_focus_name_label, "modulate:a", 1.0, 0.3)
		_tween.parallel().tween_property(_focus_name_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_fight() -> void:
	if _focus_name_label != null: _focus_name_label.visible = false
	if _focus_player_label != null: _focus_player_label.visible = false
	if _fight_label != null:
		_fight_label.visible = true
		_fight_label.text = ""
		_fight_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_fight_label.scale = Vector2(2.2, 2.2)

	_restart_tween()
	if _fight_label != null:
		_tween.tween_property(_fight_label, "modulate:a", 1.0, 0.12)
		_tween.parallel().tween_property(_fight_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_fight_label, "modulate:a", 0.0, 0.35).set_delay(0.45)

func hide_intro() -> void:
	_restart_tween()
	if _dim_panel != null and _dim_panel.visible:
		_tween.tween_property(_dim_panel, "modulate:a", 0.0, 0.25)
		if _round_title_label != null:
			_tween.parallel().tween_property(_round_title_label, "modulate:a", 0.0, 0.25)
	else:
		if _round_title_label != null:
			_tween.tween_property(_round_title_label, "modulate:a", 0.0, 0.25)

	_tween.tween_callback(func(): visible = false)

func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
