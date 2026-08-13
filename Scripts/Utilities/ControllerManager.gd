extends Node

static var instance = null

signal device_assigned(player_index: int, device_id: int)
signal device_disconnected(device_id: int)

var p1_device: int = -1
var p2_device: int = -1

const SLOT_MOVE_LEFT = 0
const SLOT_MOVE_RIGHT = 1
const SLOT_JUMP = 2
const SLOT_CROUCH = 3
const SLOT_ATTACK1 = 4
const SLOT_ATTACK2 = 5
const SLOT_ATTACK3 = 6

var _p1_actions: Array[String] = [
	Constants.ActionsPlayerOne.MOVE_LEFT,
	Constants.ActionsPlayerOne.MOVE_RIGHT,
	Constants.ActionsPlayerOne.JUMP,
	Constants.ActionsPlayerOne.CROUCH,
	Constants.ActionsPlayerOne.ATTACK1,
	Constants.ActionsPlayerOne.ATTACK2,
	Constants.ActionsPlayerOne.ATTACK3
]

var _p2_actions: Array[String] = [
	Constants.ActionsPlayerTwo.MOVE_LEFT,
	Constants.ActionsPlayerTwo.MOVE_RIGHT,
	Constants.ActionsPlayerTwo.JUMP,
	Constants.ActionsPlayerTwo.CROUCH,
	Constants.ActionsPlayerTwo.ATTACK1,
	Constants.ActionsPlayerTwo.ATTACK2,
	Constants.ActionsPlayerTwo.ATTACK3
]

func _ready() -> void:
	instance = self
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	call_deferred("_auto_detect_joypads")

func _auto_detect_joypads() -> void:
	var connected_joys = Input.get_connected_joypads()
	if not connected_joys.is_empty():
		assign_device(0, connected_joys[0])
		if connected_joys.size() > 1:
			assign_device(1, connected_joys[1])

func assign_device(player_index: int, device_id: int) -> void:
	var actions = _p1_actions if player_index == 0 else _p2_actions
	_remove_joypad_events(actions)

	if player_index == 0:
		p1_device = device_id
	else:
		p2_device = device_id

	_add_joypad_events_to_actions(actions, device_id)
	_ensure_pause_button(device_id)

	print("[ControllerManager] Device %d (%s) -> P%d." % [device_id, Input.get_joy_name(device_id), player_index + 1])
	device_assigned.emit(player_index, device_id)

func assign_keyboard(player_index: int) -> void:
	var actions = _p1_actions if player_index == 0 else _p2_actions
	_remove_joypad_events(actions)
	if player_index == 0:
		p1_device = -1
	else:
		p2_device = -1
	device_assigned.emit(player_index, -1)

func is_unassigned(device_id: int) -> bool:
	return p1_device != device_id and p2_device != device_id

func get_source_name(player_index: int) -> String:
	var device = p1_device if player_index == 0 else p2_device
	if device < 0:
		return "Keyboard (WASD)" if player_index == 0 else "Keyboard (Arrows)"

	var dev_name = Input.get_joy_name(device)
	return "Controller %d" % device if dev_name.is_empty() else dev_name

func _handle_disconnect(device_id: int) -> void:
	if p1_device == device_id:
		_remove_joypad_events(_p1_actions)
		p1_device = -1
		print("[ControllerManager] Device %d (P1) disconnected - reverts to keyboard." % device_id)
		device_assigned.emit(0, -1)
	elif p2_device == device_id:
		_remove_joypad_events(_p2_actions)
		p2_device = -1
		print("[ControllerManager] Device %d (P2) disconnected - reverts to keyboard." % device_id)
		device_assigned.emit(1, -1)
	device_disconnected.emit(device_id)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected:
		_handle_disconnect(device_id)

static func _remove_joypad_events(actions: Array[String]) -> void:
	for action in actions:
		var to_remove: Array[InputEvent] = []
		for evt in InputMap.action_get_events(action):
			if evt is InputEventJoypadButton or evt is InputEventJoypadMotion:
				to_remove.append(evt)
		for evt in to_remove:
			InputMap.action_erase_event(action, evt)

static func _add_joypad_events_to_actions(actions: Array[String], device: int) -> void:
	# Move Left
	InputMap.action_add_event(actions[SLOT_MOVE_LEFT], _make_axis(device, JOY_AXIS_LEFT_X, -1.0))
	InputMap.action_add_event(actions[SLOT_MOVE_LEFT], _make_btn(device, JOY_BUTTON_DPAD_LEFT))

	# Move Right
	InputMap.action_add_event(actions[SLOT_MOVE_RIGHT], _make_axis(device, JOY_AXIS_LEFT_X, 1.0))
	InputMap.action_add_event(actions[SLOT_MOVE_RIGHT], _make_btn(device, JOY_BUTTON_DPAD_RIGHT))

	# Jump
	InputMap.action_add_event(actions[SLOT_JUMP], _make_btn(device, JOY_BUTTON_Y))
	InputMap.action_add_event(actions[SLOT_JUMP], _make_btn(device, JOY_BUTTON_DPAD_UP))
	InputMap.action_add_event(actions[SLOT_JUMP], _make_axis(device, JOY_AXIS_LEFT_Y, -1.0))

	# Crouch
	InputMap.action_add_event(actions[SLOT_CROUCH], _make_btn(device, JOY_BUTTON_DPAD_DOWN))
	InputMap.action_add_event(actions[SLOT_CROUCH], _make_axis(device, JOY_AXIS_LEFT_Y, 1.0))

	# Attack 1
	InputMap.action_add_event(actions[SLOT_ATTACK1], _make_btn(device, JOY_BUTTON_A))

	# Attack 2
	InputMap.action_add_event(actions[SLOT_ATTACK2], _make_btn(device, JOY_BUTTON_B))

	# Attack 3
	InputMap.action_add_event(actions[SLOT_ATTACK3], _make_btn(device, JOY_BUTTON_X))

static func _ensure_pause_button(device: int) -> void:
	for evt in InputMap.action_get_events(Constants.ACTIONS_PAUSE):
		if evt is InputEventJoypadButton and evt.button_index == JOY_BUTTON_START and evt.device == device:
			return
	var btn = InputEventJoypadButton.new()
	btn.device = device
	btn.button_index = JOY_BUTTON_START
	btn.pressed = true
	InputMap.action_add_event(Constants.ACTIONS_PAUSE, btn)

static func _make_axis(dev: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var evt = InputEventJoypadMotion.new()
	evt.device = dev
	evt.axis = axis
	evt.axis_value = value
	return evt

static func _make_btn(dev: int, btn: JoyButton) -> InputEventJoypadButton:
	var evt = InputEventJoypadButton.new()
	evt.device = dev
	evt.button_index = btn
	evt.pressed = true
	return evt
