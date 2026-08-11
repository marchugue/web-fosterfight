class_name InputHelper
extends RefCounted

static func none() -> FrameInput:
	return FrameInput.new()

static func read_player_one() -> FrameInput:
	return _read(
		Constants.ActionsPlayerOne.MOVE_LEFT, Constants.ActionsPlayerOne.MOVE_RIGHT,
		Constants.ActionsPlayerOne.JUMP, Constants.ActionsPlayerOne.CROUCH,
		Constants.ActionsPlayerOne.ATTACK1, Constants.ActionsPlayerOne.ATTACK2,
		Constants.ActionsPlayerOne.ATTACK3
	)

static func read_player_two() -> FrameInput:
	return _read(
		Constants.ActionsPlayerTwo.MOVE_LEFT, Constants.ActionsPlayerTwo.MOVE_RIGHT,
		Constants.ActionsPlayerTwo.JUMP, Constants.ActionsPlayerTwo.CROUCH,
		Constants.ActionsPlayerTwo.ATTACK1, Constants.ActionsPlayerTwo.ATTACK2,
		Constants.ActionsPlayerTwo.ATTACK3
	)

static func read_device(device_id: int) -> FrameInput:
	if ControllerManager.instance != null:
		if ControllerManager.instance.p1_device == device_id:
			return read_player_one()
		if ControllerManager.instance.p2_device == device_id:
			return read_player_two()
	return read_player_one()

static func _read(
	move_left: String, move_right: String, jump: String, crouch: String,
	attack1: String, attack2: String, attack3: String
) -> FrameInput:
	return FrameInput.new(
		Input.get_axis(move_left, move_right),
		Input.is_action_just_pressed(jump),
		Input.is_action_pressed(crouch),
		Input.is_action_just_pressed(attack1),
		Input.is_action_just_pressed(attack2),
		Input.is_action_just_pressed(attack3),
		Input.is_action_just_pressed(Constants.ACTIONS_PAUSE),
		Input.is_action_just_pressed(move_left),
		Input.is_action_just_pressed(move_right)
	)
