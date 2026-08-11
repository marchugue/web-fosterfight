class_name GameSettingsData
extends Resource

@export_group("Match Rules")
@export var rounds_to_win_match: int = 2
@export var round_time_seconds: float = 99.0

@export_group("Audio")
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.8
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0

@export_group("Display")
@export var fullscreen: bool = false
@export var screen_shake_enabled: bool = true
