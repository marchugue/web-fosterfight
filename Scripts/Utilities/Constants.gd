class_name Constants
extends RefCounted

class Scenes:
	const MAIN_MENU = "res://Scenes/MainMenu.tscn"
	const PROGRAM_SELECT = "res://Scenes/ProgramSelect.tscn"
	const NAME_ENTRY = "res://Scenes/NameEntry.tscn"
	const CHARACTER_SELECT = "res://Scenes/CharacterSelect.tscn"
	const BATTLE = "res://Scenes/Battle.tscn"
	const RESULT = "res://Scenes/Result.tscn"
	const LEADERBOARD = "res://Scenes/Leaderboard.tscn"
	const CHARACTER_COMPONENT = "res://Scenes/Components/Character.tscn"
	const CHARACTER_1_COMPONENT = "res://Scenes/Components/Character1.tscn"
	const CHARACTER_2_COMPONENT = "res://Scenes/Components/Character2.tscn"
	const CHARACTER_3_COMPONENT = "res://Scenes/Components/Character3.tscn"
	const CHARACTER_4_COMPONENT = "res://Scenes/Components/Character4.tscn"
	const SINGLE_PLAYER_CHARACTER_COMPONENT = "res://Scenes/Components/characters/SinglePlayerCharacter.tscn"
	const SINGLE_PLAYER_MOB = "res://Scenes/single_player/SinglePlayerMob2.tscn"
	const SINGLE_PLAYER_BOSS = "res://Scenes/single_player/SinglePlayerBoss.tscn"
	const SINGLE_PLAYER_LEVEL1 = "res://Scenes/single_player/level1.tscn"
	const HEALTH_BAR_COMPONENT = "res://Scenes/Components/HealthBar.tscn"
	const TIMER_COMPONENT = "res://Scenes/Components/Timer.tscn"

class ActionsPlayerOne:
	const MOVE_LEFT = "move_left"
	const MOVE_RIGHT = "move_right"
	const JUMP = "jump"
	const CROUCH = "crouch"
	const ATTACK1 = "attack1"
	const ATTACK2 = "attack2"
	const ATTACK3 = "attack3"

class ActionsPlayerTwo:
	const MOVE_LEFT = "move_left_p2"
	const MOVE_RIGHT = "move_right_p2"
	const JUMP = "jump_p2"
	const CROUCH = "crouch_p2"
	const ATTACK1 = "attack1_p2"
	const ATTACK2 = "attack2_p2"
	const ATTACK3 = "attack3_p2"

const ACTIONS_PAUSE = "pause"

class Controllers:
	const AXIS_DEADZONE: float = 0.2
	const AXIS_DASH_THRESHOLD: float = 0.5

class Physics:
	const DEFAULT_GRAVITY: float = 980.0
	const MAX_FALL_SPEED: float = 1600.0
	const GROUND_SNAP_DISTANCE: float = 4.0
	const KNOCKBACK_FRICTION: float = 900.0

	const GROUND_LAYER: int = 1
	const PLAYER_LAYER: int = 2
	const GROUND_COLLISION_MASK: int = 1
	const PLAYER_COLLISION_MASK: int = 3

	const RISING_GRAVITY_SCALE: float = 1.10
	const APEX_GRAVITY_SCALE: float = 0.90
	const APEX_THRESHOLD: float = 100.0
	const FALL_GRAVITY_SCALE: float = 1.55
	const LATE_FALL_GRAVITY_SCALE: float = 2.00
	const LATE_FALL_THRESHOLD: float = 800.0

	const GROUND_ACCEL: float = 2400.0
	const GROUND_FRICTION: float = 3200.0
	const TURNAROUND_BOOST: float = 3600.0

	const AIR_ACCEL: float = 1400.0
	const AIR_FRICTION: float = 500.0

	const LANDING_MOMENTUM_KEEP: float = 0.65

	const PLAYER_PUSH_SEPARATION: float = 28.0
	const PLAYER_PUSH_FORCE: float = 1200.0
	const CORNER_MARGIN: float = 8.0

class Combat:
	const LIGHT_ATTACK_KNOCKBACK: float = 120.0
	const HEAVY_ATTACK_KNOCKBACK: float = 220.0
	const SPECIAL_ATTACK_KNOCKBACK: float = 320.0

	const HIT_STUN_LIGHT: float = 0.20
	const HIT_STUN_HEAVY: float = 0.35
	const HIT_STUN_SPECIAL: float = 0.55

	const COMBO_WINDOW_SECONDS: float = 1.2
	const COMBO_DROP_THRESHOLD: int = 1

	const ENERGY_PER_LIGHT_HIT_DEALT: float = 6.0
	const ENERGY_PER_HEAVY_HIT_DEALT: float = 10.0
	const ENERGY_PER_HIT_TAKEN: float = 4.0
	const SPECIAL_ATTACK_ENERGY_COST: float = 50.0
	const MAX_ENERGY: float = 100.0

	const MIN_HURT_KNOCKBACK: float = 60.0
	const KNOCKDOWN_STUN_SECONDS: float = 1.0
	const KNOCKDOWN_KNOCKBACK: float = 260.0
	const KNOCKDOWN_LAUNCH_VELOCITY: float = -520.0
	const KNOCKDOWN_METER_WINDOW_SECONDS: float = 1.2
	const KNOCKDOWN_METER_MAX: int = 6
	const KNOCKDOWN_METER_LIGHT_GAIN: int = 1
	const KNOCKDOWN_METER_HEAVY_GAIN: int = 2
	const STANDUP_SECONDS: float = 0.5

	const BLOCK_DAMAGE_MULTIPLIER: float = 0.20
	const BLOCK_KNOCKBACK_MULTIPLIER: float = 0.60
	const BLOCK_STUN_SECONDS: float = 0.15

	const COMMAND_COMBO_SEQUENCE_SECONDS: float = 0.45
	const COMMAND_COMBO_INPUT_BUFFER_SECONDS: float = 0.18

	const PHYSICS_FPS: int = 60
	const HITSTUN_DETERIORATION_BASE: float = 0.85
	const GRAVITY_SCALE_PER_COMBO_HIT: float = 0.12
	const MAX_COMBO_GRAVITY_SCALE: float = 2.5
	const MIN_HITSTUN_FRAMES: int = 3

	const CRUMPLE_GRAVITY_SCALE: float = 0.3
	const STUN_HITSTUN_MULTIPLIER: float = 1.5
	const WALL_BOUNCE_VELOCITY_MULTIPLIER: float = -0.7
	const WALL_BOUNCE_LAUNCH_Y: float = -400.0
	const WALL_BOUNCE_PROXIMITY: float = 60.0

class Movement:
	const DASH_SPEED: float = 720.0
	const AIR_DASH_SPEED: float = 800.0
	const DASH_DURATION_SECONDS: float = 0.22
	const DASH_COOLDOWN_SECONDS: float = 0.35
	const DASH_TAP_WINDOW_SECONDS: float = 0.25
	const DASH_TRAIL_SPAWN_INTERVAL: float = 0.014
	const DASH_TRAIL_FADE_SECONDS: float = 0.42
	const DASH_TRAIL_START_ALPHA: float = 0.88
	const DASH_TRAIL_POST_SECONDS: float = 0.12

	const DASH_BURST_MULTIPLIER: float = 1.15
	const POST_DASH_FRICTION: float = 1800.0
	const POST_DASH_DURATION: float = 0.12

class Match:
	const ROUNDS_TO_WIN_MATCH: int = 2
	const MAX_ROUNDS_IN_MATCH: int = 3
	const ROUND_TIME_SECONDS: float = 99.0
	const ROUND_END_DELAY_SECONDS: float = 3.0
	const KO_PAUSE_SECONDS: float = 3.0
	const INTRO_PLAYER_FOCUS_SECONDS: float = 2.0
	const INTRO_FIGHT_CALL_SECONDS: float = 1.0
	const ROUND_OVERLAY_SECONDS: float = 2.0

class Database:
	const LEADERBOARD_DB_PATH = "user://leaderboard.db"
	const LEADERBOARD_JSON_PATH = "user://leaderboard.json"

class Stage:
	const WORLD_MIN_X: float = -320.0
	const WORLD_MAX_X: float = 1600.0
	const DEFAULT_CENTER_X: float = 640.0

	const MIN_X: float = -200.0
	const MAX_X: float = 1480.0

	const FIGHTER_BODY_HALF_WIDTH: float = 24.0

	const PLAYER_ONE_SPAWN_X: float = 400.0
	const PLAYER_TWO_SPAWN_X: float = 880.0
	const SPAWN_Y: float = 552.0

class Camera:
	const VIEWPORT_WIDTH: float = 1280.0
	const VIEWPORT_HEIGHT: float = 720.0
	const DEFAULT_Y: float = 360.0
	const PAN_SMOOTH_SPEED: float = 8.0
	const MAX_ZOOM: float = 1.0
	const MIN_ZOOM: float = 0.75
	const KO_ZOOM: float = 1.55
	const INTRO_FULL_BODY_ZOOM: float = 1.28
	const INTRO_VERTICAL_OFFSET: float = 52.0
	const WINNER_ZOOM: float = 1.38
	const ACTION_FOCUS_WEIGHT: float = 0.42
	const CLOSE_SEPARATION_THRESHOLD: float = 480.0
	const FIGHTER_EDGE_PADDING: float = 140.0

class UI:
	const HEALTH_DELAY_HOLD_SECONDS: float = 0.35
	const HEALTH_DELAY_DRAIN_SECONDS: float = 0.45

class Groups:
	const PLAYERS = "players"
	const HURTBOXES = "hurtboxes"
