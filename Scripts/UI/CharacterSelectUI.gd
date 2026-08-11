class_name CharacterSelectUI
extends Control

const CHARACTERS_FOLDER = "res://Resources/Characters"

@export var style_box_not_focused: StyleBox
@export var style_box_p1_focus: StyleBox
@export var style_box_p2_focus: StyleBox
@export var style_box_both_focus: StyleBox

@export var portrait_one_path: NodePath = "%PortraitOne"
@export var name_one_path: NodePath = "%NameOne"
@export var idle_preview_one_path: NodePath = "%IdlePreviewOne"

@export var portrait_two_path: NodePath = "%PortraitTwo"
@export var name_two_path: NodePath = "%NameTwo"
@export var idle_preview_two_path: NodePath = "%IdlePreviewTwo"

@export var status_label_path: NodePath = "%StatusLabel"
@export var back_button_path: NodePath = "%BackButton"

@export var slot0_path: NodePath = "%Slot0"
@export var slot1_path: NodePath = "%Slot1"
@export var slot2_path: NodePath = "%Slot2"
@export var slot3_path: NodePath = "%Slot3"

@export var slot_container0_path: NodePath = "%SlotContainer0"
@export var slot_container1_path: NodePath = "%SlotContainer1"
@export var slot_container2_path: NodePath = "%SlotContainer2"
@export var slot_container3_path: NodePath = "%SlotContainer3"

@export var p1_indicator_path: NodePath = "%P1SlotIndicator"
@export var p2_indicator_path: NodePath = "%P2SlotIndicator"

@export var sfx_navigate: AudioStream
@export var sfx_confirm: AudioStream
@export var sfx_hover: AudioStream

var _roster: Array[CharacterData] = []
var _slots: Array[TextureRect] = [null, null, null, null]
var _slot_containers: Array[PanelContainer] = [null, null, null, null]

var _p1_slot_indicator: TextureRect
var _p2_slot_indicator: TextureRect

var _index_one: int = 0
var _index_two: int = 1
var _confirmed_one: bool = false
var _confirmed_two: bool = false

const P1_LEFT = "move_left"
const P1_RIGHT = "move_right"
const P1_UP = "jump"
const P1_DOWN = "crouch"
const P1_CONFIRM1 = "attack1"
const P1_CONFIRM2 = "attack2"
const P1_CONFIRM3 = "attack3"

const P2_LEFT = "move_left_p2"
const P2_RIGHT = "move_right_p2"
const P2_UP = "jump_p2"
const P2_DOWN = "crouch_p2"
const P2_CONFIRM1 = "attack1_p2"
const P2_CONFIRM2 = "attack2_p2"
const P2_CONFIRM3 = "attack3_p2"

const GRID_COLUMNS = 2

func _ready() -> void:
	_load_roster()

	_slots[0] = get_node_or_null(slot0_path) as TextureRect
	_slots[1] = get_node_or_null(slot1_path) as TextureRect
	_slots[2] = get_node_or_null(slot2_path) as TextureRect
	_slots[3] = get_node_or_null(slot3_path) as TextureRect

	_slot_containers[0] = get_node_or_null(slot_container0_path) as PanelContainer
	_slot_containers[1] = get_node_or_null(slot_container1_path) as PanelContainer
	_slot_containers[2] = get_node_or_null(slot_container2_path) as PanelContainer
	_slot_containers[3] = get_node_or_null(slot_container3_path) as PanelContainer

	_p1_slot_indicator = get_node_or_null(p1_indicator_path) as TextureRect
	if _p1_slot_indicator == null:
		_p1_slot_indicator = get_node_or_null("%P1SlotIndicator") as TextureRect

	_p2_slot_indicator = get_node_or_null(p2_indicator_path) as TextureRect
	if _p2_slot_indicator == null:
		_p2_slot_indicator = get_node_or_null("%P2SlotIndicator") as TextureRect

	if _p1_slot_indicator == null:
		_p1_slot_indicator = TextureRect.new()
		_p1_slot_indicator.name = "P1SlotIndicator"
		_p1_slot_indicator.texture = load("res://Assets/Sprites/UI/battleHUD/indicator/Property 1=Variant2.png") as Texture2D
		_p1_slot_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_p1_slot_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_p1_slot_indicator.custom_minimum_size = Vector2(48, 48)
		_p1_slot_indicator.z_index = 10
		_p1_slot_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_p1_slot_indicator)

	if _p2_slot_indicator == null:
		_p2_slot_indicator = TextureRect.new()
		_p2_slot_indicator.name = "P2SlotIndicator"
		_p2_slot_indicator.texture = load("res://Assets/Sprites/UI/battleHUD/indicator/Property 1=Default.png") as Texture2D
		_p2_slot_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_p2_slot_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_p2_slot_indicator.custom_minimum_size = Vector2(48, 48)
		_p2_slot_indicator.z_index = 10
		_p2_slot_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_p2_slot_indicator)

	for i in range(4):
		if _slots[i] != null and i < _roster.size():
			_slots[i].texture = _roster[i].portrait

	if _roster.is_empty():
		var status_label = get_node_or_null(status_label_path) as Label
		if status_label != null:
			status_label.text = "No characters found in Resources/Characters/."
		return

	if _roster.size() > 1:
		_index_two = 1

	var back_button = get_node_or_null(back_button_path) as BaseButton
	if back_button != null:
		back_button.pressed.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_program_select())
		back_button.mouse_entered.connect(func(): if AudioManager.instance != null and sfx_hover != null: AudioManager.instance.play_sfx(sfx_hover))

	if ControllerManager.instance != null:
		ControllerManager.instance.device_assigned.connect(_on_device_assigned)

	if AudioManager.instance != null:
		AudioManager.instance.play_menu_music()
		AudioManager.instance.play_select_character_voice_sfx()

	_refresh_panels()
	_update_device_hint_label()

func _process(_delta: float) -> void:
	_update_slot_indicator_positions()

func _on_device_assigned(_player_index: int, _device_id: int) -> void:
	_update_device_hint_label()

func _update_device_hint_label() -> void:
	var status_label = get_node_or_null(status_label_path) as Label
	if status_label == null: return
	if _confirmed_one or _confirmed_two: return

	var cm = ControllerManager.instance
	var p1_source = cm.get_source_name(0) if cm != null else "Keyboard (WASD)"
	var p2_source = cm.get_source_name(1) if cm != null else "Keyboard (Arrows)"

	var any_unassigned = false
	if cm != null:
		for id in Input.get_connected_joypads():
			if cm.is_unassigned(id):
				any_unassigned = true
				break

	if any_unassigned:
		status_label.text = "P1: %s | P2: %s\nUnassigned controller detected — press any button to claim a slot." % [p1_source, p2_source]
	else:
		status_label.text = "P1: %s | P2: %s" % [p1_source, p2_source]

func _input(event: InputEvent) -> void:
	if _roster.is_empty(): return

	var cm = ControllerManager.instance

	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if cm != null and cm.is_unassigned(event.device):
			if not _confirmed_one and cm.p1_device < 0:
				cm.assign_device(0, event.device)
			elif not _confirmed_two and cm.p2_device < 0:
				cm.assign_device(1, event.device)

	if not _confirmed_one:
		var p1_can_input = true
		if event is InputEventKey and cm != null and cm.p1_device >= 0:
			p1_can_input = false

		if p1_can_input:
			if event.is_action_pressed(P1_LEFT) and not event.is_echo():
				_index_one = _wrap_index(_index_one - 1)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P1_RIGHT) and not event.is_echo():
				_index_one = _wrap_index(_index_one + 1)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P1_UP) and not event.is_echo():
				_index_one = _wrap_index(_index_one - GRID_COLUMNS)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P1_DOWN) and not event.is_echo():
				_index_one = _wrap_index(_index_one + GRID_COLUMNS)
				_refresh_panels()
				_play_navigate_sfx()
			elif (event.is_action_pressed(P1_CONFIRM1) or event.is_action_pressed(P1_CONFIRM2) or event.is_action_pressed(P1_CONFIRM3) or _is_p1_accept_pressed(event)) and not event.is_echo():
				_confirm(true)

	if not _confirmed_two:
		var p2_can_input = true
		if event is InputEventKey and cm != null and cm.p2_device >= 0:
			p2_can_input = false

		if p2_can_input:
			if event.is_action_pressed(P2_LEFT) and not event.is_echo():
				_index_two = _wrap_index(_index_two - 1)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P2_RIGHT) and not event.is_echo():
				_index_two = _wrap_index(_index_two + 1)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P2_UP) and not event.is_echo():
				_index_two = _wrap_index(_index_two - GRID_COLUMNS)
				_refresh_panels()
				_play_navigate_sfx()
			elif event.is_action_pressed(P2_DOWN) and not event.is_echo():
				_index_two = _wrap_index(_index_two + GRID_COLUMNS)
				_refresh_panels()
				_play_navigate_sfx()
			elif (event.is_action_pressed(P2_CONFIRM1) or event.is_action_pressed(P2_CONFIRM2) or event.is_action_pressed(P2_CONFIRM3) or _is_p2_accept_pressed(event)) and not event.is_echo():
				_confirm(false)

static func _is_p1_key(key: Key) -> bool:
	return key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_SPACE]

static func _is_p2_key(key: Key) -> bool:
	return key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_ENTER, KEY_KP_ENTER]

static func _is_p1_accept_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.is_echo():
		return event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE
	if event is InputEventJoypadButton and event.pressed:
		var cm = ControllerManager.instance
		if cm != null and cm.p1_device == event.device:
			return event.button_index in [JOY_BUTTON_START, JOY_BUTTON_A]
	return false

static func _is_p2_accept_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.is_echo():
		return event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventJoypadButton and event.pressed:
		var cm = ControllerManager.instance
		if cm != null and cm.p2_device == event.device:
			return event.button_index in [JOY_BUTTON_START, JOY_BUTTON_A]
	return false

func _wrap_index(index: int) -> int:
	return (index % _roster.size() + _roster.size()) % _roster.size()

func _load_roster() -> void:
	_roster.clear()
	var file_list: Array[String] = []
	var dir = DirAccess.open(CHARACTERS_FOLDER)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			var clean_name = file_name
			if clean_name.ends_with(".remap"):
				clean_name = clean_name.trim_suffix(".remap")
			if clean_name.ends_with(".import"):
				file_name = dir.get_next()
				continue
			if clean_name.ends_with(".tres"):
				if not file_list.has(clean_name):
					file_list.append(clean_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	file_list.sort()

	for fname in file_list:
		var data = load("%s/%s" % [CHARACTERS_FOLDER, fname]) as CharacterData
		if data != null and not _roster.has(data):
			_roster.append(data)

	if _roster.is_empty():
		var default_paths = [
			"res://Resources/Characters/Character1.tres",
			"res://Resources/Characters/Character2.tres",
			"res://Resources/Characters/Character3.tres",
			"res://Resources/Characters/Character4.tres"
		]
		for path in default_paths:
			var data = load(path) as CharacterData
			if data != null and not _roster.has(data):
				_roster.append(data)

func _refresh_panels() -> void:
	if _roster.is_empty(): return

	var one = _roster[_index_one]
	var two = _roster[_index_two]

	var port_one = get_node_or_null(portrait_one_path) as TextureRect
	var name_one = get_node_or_null(name_one_path) as Label
	var anim_one = get_node_or_null(idle_preview_one_path) as AnimatedSprite2D

	var port_two = get_node_or_null(portrait_two_path) as TextureRect
	var name_two = get_node_or_null(name_two_path) as Label
	var anim_two = get_node_or_null(idle_preview_two_path) as AnimatedSprite2D

	if port_one != null: port_one.texture = one.portrait
	if name_one != null: name_one.text = one.display_name
	if anim_one != null and one.frames != null:
		anim_one.stop()
		anim_one.sprite_frames = one.frames
		var idle_anim = one.get_animation_name("idle")
		var anim_to_play = idle_anim if one.frames.has_animation(idle_anim) else ("idle" if one.frames.has_animation("idle") else "")
		if not anim_to_play.is_empty():
			anim_one.play(anim_to_play)

	if port_two != null: port_two.texture = two.portrait
	if name_two != null: name_two.text = two.display_name
	if anim_two != null and two.frames != null:
		anim_two.stop()
		anim_two.sprite_frames = two.frames
		var idle_anim = two.get_animation_name("idle")
		var anim_to_play = idle_anim if two.frames.has_animation(idle_anim) else ("idle" if two.frames.has_animation("idle") else "")
		if not anim_to_play.is_empty():
			anim_two.play(anim_to_play)

	_update_indicators()

func _update_indicators() -> void:
	for i in range(4):
		if _slot_containers[i] == null: continue

		var is_p1 = (i == _index_one)
		var is_p2 = (i == _index_two)

		if is_p1 and is_p2 and style_box_both_focus != null:
			_slot_containers[i].add_theme_stylebox_override("panel", style_box_both_focus)
		elif is_p1 and style_box_p1_focus != null:
			_slot_containers[i].add_theme_stylebox_override("panel", style_box_p1_focus)
		elif is_p2 and style_box_p2_focus != null:
			_slot_containers[i].add_theme_stylebox_override("panel", style_box_p2_focus)
		elif style_box_not_focused != null:
			_slot_containers[i].add_theme_stylebox_override("panel", style_box_not_focused)

	_update_slot_indicator_positions()

func _update_slot_indicator_positions() -> void:
	if _roster.is_empty(): return
	if _p1_slot_indicator == null or _p2_slot_indicator == null: return

	if _index_one < 0 or _index_one >= _slot_containers.size(): return
	if _index_two < 0 or _index_two >= _slot_containers.size(): return

	var container1 = _slot_containers[_index_one]
	var container2 = _slot_containers[_index_two]

	if container1 == null or container2 == null: return

	var rect1 = container1.get_global_rect()
	var rect2 = container2.get_global_rect()

	if rect1.size.x <= 0 or rect1.size.y <= 0: return
	if rect2.size.x <= 0 or rect2.size.y <= 0: return

	var indicator_size1 = _p1_slot_indicator.size
	if indicator_size1.x <= 0 or indicator_size1.y <= 0: indicator_size1 = Vector2(48, 48)

	var indicator_size2 = _p2_slot_indicator.size
	if indicator_size2.x <= 0 or indicator_size2.y <= 0: indicator_size2 = Vector2(48, 48)

	if _index_one == _index_two:
		var p1_center_x = rect1.position.x + rect1.size.x * 0.28
		var p1_top_y = rect1.position.y - indicator_size1.y * 0.45
		_p1_slot_indicator.global_position = Vector2(p1_center_x - indicator_size1.x * 0.5, p1_top_y)

		var p2_center_x = rect1.position.x + rect1.size.x * 0.72
		var p2_top_y = rect1.position.y - indicator_size2.y * 0.45
		_p2_slot_indicator.global_position = Vector2(p2_center_x - indicator_size2.x * 0.5, p2_top_y)
	else:
		var p1_center_x = rect1.position.x + rect1.size.x * 0.5
		var p1_top_y = rect1.position.y - indicator_size1.y * 0.45
		_p1_slot_indicator.global_position = Vector2(p1_center_x - indicator_size1.x * 0.5, p1_top_y)

		var p2_center_x = rect2.position.x + rect2.size.x * 0.5
		var p2_top_y = rect2.position.y - indicator_size2.y * 0.45
		_p2_slot_indicator.global_position = Vector2(p2_center_x - indicator_size2.x * 0.5, p2_top_y)

	_p1_slot_indicator.visible = true
	_p2_slot_indicator.visible = true

func _confirm(player_one: bool) -> void:
	if player_one: _confirmed_one = true
	else:          _confirmed_two = true

	if sfx_confirm != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(sfx_confirm)

	var cm = ControllerManager.instance
	var p1_src = cm.get_source_name(0) if cm != null else "Keyboard (WASD)"
	var p2_src = cm.get_source_name(1) if cm != null else "Keyboard (Arrows)"

	var status_label = get_node_or_null(status_label_path) as Label
	if status_label != null:
		if _confirmed_one and _confirmed_two:
			status_label.text = "Both players ready! Starting..."
		elif _confirmed_one:
			status_label.text = "P1 ready [%s] — waiting on P2 [%s]" % [p1_src, p2_src]
		else:
			status_label.text = "P2 ready [%s] — waiting on P1 [%s]" % [p2_src, p2_src]

	if _confirmed_one and _confirmed_two:
		if GameManager.instance != null:
			GameManager.instance.set_selected_characters(_roster[_index_one], _roster[_index_two])

		if AudioManager.instance != null:
			AudioManager.instance.fade_out_music(0.8)

		var transition_timer = get_tree().create_timer(0.8)
		transition_timer.timeout.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_battle())

func _play_navigate_sfx() -> void:
	if sfx_navigate != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(sfx_navigate)
