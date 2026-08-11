class_name FrameInput
extends RefCounted

var horizontal: float = 0.0
var jump_pressed: bool = false
var crouch_held: bool = false
var attack1: bool = false
var attack2: bool = false
var attack3: bool = false
var pause_pressed: bool = false
var move_left_just_pressed: bool = false
var move_right_just_pressed: bool = false

func _init(
	p_horizontal: float = 0.0,
	p_jump_pressed: bool = false,
	p_crouch_held: bool = false,
	p_attack1: bool = false,
	p_attack2: bool = false,
	p_attack3: bool = false,
	p_pause_pressed: bool = false,
	p_move_left_just_pressed: bool = false,
	p_move_right_just_pressed: bool = false
) -> void:
	horizontal = p_horizontal
	jump_pressed = p_jump_pressed
	crouch_held = p_crouch_held
	attack1 = p_attack1
	attack2 = p_attack2
	attack3 = p_attack3
	pause_pressed = p_pause_pressed
	move_left_just_pressed = p_move_left_just_pressed
	move_right_just_pressed = p_move_right_just_pressed

static func none() -> FrameInput:
	return FrameInput.new()
