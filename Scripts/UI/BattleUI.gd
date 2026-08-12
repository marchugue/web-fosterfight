class_name BattleUI
extends Control

@export var player_one_path: NodePath = ""
@export var player_two_path: NodePath = ""
@export var round_manager_path: NodePath = ""
@export var match_manager_path: NodePath = ""

@export var player_one_health_bar_path: NodePath = "%PlayerOneHealthBar"
@export var player_two_health_bar_path: NodePath = "%PlayerTwoHealthBar"
@export var player_one_energy_bar_path: NodePath = "%PlayerOneEnergyBar"
@export var player_two_energy_bar_path: NodePath = "%PlayerTwoEnergyBar"
@export var timer_component_path: NodePath = "%TimerComponent"
@export var combo_label_path: NodePath = "%ComboLabel"
@export var round_intro_overlay_path: NodePath = "%RoundIntroOverlay"

@export var pause_panel_path: NodePath = "%PausePanel"
@export var resume_button_path: NodePath = "%ResumeButton"
@export var quit_button_path: NodePath = "%QuitButton"

@export var master_volume_slider_path: NodePath = "%MasterVolumeSlider"
@export var music_volume_slider_path: NodePath = "%MusicVolumeSlider"
@export var sfx_volume_slider_path: NodePath = "%SFXVolumeSlider"
@export var master_volume_label_path: NodePath = "%MasterVolumeLabel"
@export var music_volume_label_path: NodePath = "%MusicVolumeLabel"
@export var sfx_volume_label_path: NodePath = "%SFXVolumeLabel"

var _p1_health: HealthBarComponent
var _p2_health: HealthBarComponent
var _p1_energy: TextureProgressBar
var _p2_energy: TextureProgressBar
var _timer: TimerComponent
var _combo_label: Label
var _intro_overlay: RoundIntroOverlay
var _hud_root: Control

var _pause_panel: Control
var _resume_button: BaseButton
var _quit_button: BaseButton

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _master_label: Label
var _music_label: Label
var _sfx_label: Label

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	var player_one = get_node_or_null(player_one_path) as CharacterController
	var player_two = get_node_or_null(player_two_path) as CharacterController
	var round_manager = get_node_or_null(round_manager_path) as RoundManager
	var match_manager = get_node_or_null(match_manager_path) as MatchManager

	_p1_health = get_node(player_one_health_bar_path) as HealthBarComponent
	_p2_health = get_node(player_two_health_bar_path) as HealthBarComponent
	_p1_energy = get_node(player_one_energy_bar_path) as TextureProgressBar
	_p2_energy = get_node(player_two_energy_bar_path) as TextureProgressBar
	_timer = get_node(timer_component_path) as TimerComponent
	_combo_label = get_node(combo_label_path) as Label
	_intro_overlay = get_node(round_intro_overlay_path) as RoundIntroOverlay
	_hud_root = get_node("HudRoot") as Control

	if player_one != null and player_two != null:
		_setup_fighters(player_one, player_two)

	if round_manager != null:
		round_manager.round_timer_tick.connect(func(rem): _timer.set_time(rem))
		round_manager.round_intro_started.connect(_on_round_intro_started)
		round_manager.round_intro_player_focus.connect(func(_p, name_str, p_num): _intro_overlay.focus_player(name_str, p_num))
		round_manager.round_intro_fight.connect(func(): _intro_overlay.show_fight())
		round_manager.round_started.connect(_on_round_started)

	if match_manager != null:
		match_manager.rounds_score_changed.connect(func(p1_w, p2_w):
			_p1_health.set_round_wins(p1_w)
			_p2_health.set_round_wins(p2_w)
		)

	_combo_label.visible = false

	_pause_panel = get_node_or_null(pause_panel_path) as Control
	_resume_button = get_node_or_null(resume_button_path) as BaseButton
	_quit_button = get_node_or_null(quit_button_path) as BaseButton

	if _resume_button != null: _resume_button.pressed.connect(resume_game)
	if _quit_button != null: _quit_button.pressed.connect(quit_game)
	if _pause_panel != null: _pause_panel.visible = false

	_master_slider = get_node_or_null(master_volume_slider_path) as HSlider
	_music_slider = get_node_or_null(music_volume_slider_path) as HSlider
	_sfx_slider = get_node_or_null(sfx_volume_slider_path) as HSlider
	_master_label = get_node_or_null(master_volume_label_path) as Label
	_music_label = get_node_or_null(music_volume_label_path) as Label
	_sfx_label = get_node_or_null(sfx_volume_label_path) as Label

	_setup_audio_sliders()

func update_fighter_references(player_one: CharacterController, player_two: CharacterController) -> void:
	_setup_fighters(player_one, player_two)

func _setup_fighters(player_one: CharacterController, player_two: CharacterController) -> void:
	var p1_name = GameManager.instance.player_one_name if GameManager.instance != null and not GameManager.instance.player_one_name.strip_edges().is_empty() else (player_one.data.display_name if player_one.data != null else "Player 1")
	var p2_name = GameManager.instance.player_two_name if GameManager.instance != null and not GameManager.instance.player_two_name.strip_edges().is_empty() else (player_two.data.display_name if player_two.data != null else "Player 2")

	_p1_health.set_fighter_name(p1_name)
	_p2_health.set_fighter_name(p2_name)

	player_one.health.health_changed.connect(func(cur, max_v): _p1_health.set_health(cur, max_v))
	player_two.health.health_changed.connect(func(cur, max_v): _p2_health.set_health(cur, max_v))
	player_one.energy.energy_changed.connect(func(cur, max_v): _update_bar(_p1_energy, cur, max_v))
	player_two.energy.energy_changed.connect(func(cur, max_v): _update_bar(_p2_energy, cur, max_v))

	player_one.combo.combo_changed.connect(func(count): _update_combo(count, true))
	player_two.combo.combo_changed.connect(func(count): _update_combo(count, false))

	_p1_health.set_health(player_one.health.current_health, player_one.health.max_health)
	_p2_health.set_health(player_two.health.current_health, player_two.health.max_health)
	_p1_health.set_round_wins(0)
	_p2_health.set_round_wins(0)
	_update_bar(_p1_energy, player_one.energy.current_energy, player_one.energy.max_energy)
	_update_bar(_p2_energy, player_two.energy.current_energy, player_two.energy.max_energy)

func _on_round_intro_started(round_num: int, p1_wins: int, p2_wins: int) -> void:
	_p1_health.set_round_wins(p1_wins)
	_p2_health.set_round_wins(p2_wins)

	if round_num <= 1:
		_hud_root.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_intro_overlay.show_round_intro(round_num, p1_wins, p2_wins)
	else:
		_intro_overlay.show_round_overlay(round_num, p1_wins, p2_wins)

func _on_round_started() -> void:
	_intro_overlay.hide_intro()
	_hud_root.modulate = Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	get_tree().paused = true
	_sync_audio_sliders()
	if _pause_panel != null:
		_pause_panel.visible = true
	if _resume_button != null:
		_resume_button.grab_focus()

func resume_game() -> void:
	get_tree().paused = false
	if _pause_panel != null:
		_pause_panel.visible = false

func quit_game() -> void:
	get_tree().paused = false
	if GameManager.instance != null:
		GameManager.instance.go_to_main_menu()

func _setup_audio_sliders() -> void:
	if _master_slider != null:
		_master_slider.min_value = 0.0
		_master_slider.max_value = 1.0
		_master_slider.step = 0.05
		_master_slider.value_changed.connect(_on_master_volume_changed)

	if _music_slider != null:
		_music_slider.min_value = 0.0
		_music_slider.max_value = 1.0
		_music_slider.step = 0.05
		_music_slider.value_changed.connect(_on_music_volume_changed)

	if _sfx_slider != null:
		_sfx_slider.min_value = 0.0
		_sfx_slider.max_value = 1.0
		_sfx_slider.step = 0.05
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	_sync_audio_sliders()

func _sync_audio_sliders() -> void:
	if GameManager.instance == null or GameManager.instance.settings == null:
		return

	var settings = GameManager.instance.settings

	if _master_slider != null:
		_master_slider.set_value_no_signal(settings.master_volume)
		_update_master_label(settings.master_volume)

	if _music_slider != null:
		_music_slider.set_value_no_signal(settings.music_volume)
		_update_music_label(settings.music_volume)

	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(settings.sfx_volume)
		_update_sfx_label(settings.sfx_volume)

func _on_master_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.master_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	_update_master_label(val)

func _on_music_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.music_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	_update_music_label(val)

func _on_sfx_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.sfx_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	_update_sfx_label(val)

func _update_master_label(val: float) -> void:
	if _master_label != null:
		_master_label.text = "MASTER VOL: %d%%" % int(round(val * 100.0))

func _update_music_label(val: float) -> void:
	if _music_label != null:
		_music_label.text = "BGM VOL: %d%%" % int(round(val * 100.0))

func _update_sfx_label(val: float) -> void:
	if _sfx_label != null:
		_sfx_label.text = "SFX VOL: %d%%" % int(round(val * 100.0))

func _update_combo(count: int, is_player_one: bool) -> void:
	if count <= 1:
		_combo_label.visible = false
		return

	_combo_label.visible = true
	_combo_label.text = "%d HIT COMBO — %s" % [count, "P1" if is_player_one else "P2"]

static func _update_bar(bar: TextureProgressBar, current: float, max_val: float) -> void:
	bar.max_value = max_val
	bar.value = current
