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
@export var retry_button_path: NodePath = "%RetryButton"
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
var _wave_info_label: Label = null
var _hurt_vignette: HurtVignette = null
var _last_p1_hp: float = -1.0

var _pause_panel: Control
var _resume_button: BaseButton
var _retry_button: BaseButton
var _quit_button: BaseButton

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _master_label: Label
var _music_label: Label
var _sfx_label: Label

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	var player_one = get_node_or_null(player_one_path)
	var player_two = get_node_or_null(player_two_path)
	var round_manager = get_node_or_null(round_manager_path) as RoundManager
	var match_manager = get_node_or_null(match_manager_path) as MatchManager

	_p1_health = get_node_or_null(player_one_health_bar_path) as HealthBarComponent
	_p2_health = get_node_or_null(player_two_health_bar_path) as HealthBarComponent
	_p1_energy = get_node_or_null(player_one_energy_bar_path) as TextureProgressBar
	_p2_energy = get_node_or_null(player_two_energy_bar_path) as TextureProgressBar
	_timer = get_node_or_null(timer_component_path) as TimerComponent
	_combo_label = get_node_or_null(combo_label_path) as Label
	_intro_overlay = get_node_or_null(round_intro_overlay_path) as RoundIntroOverlay
	_hud_root = get_node_or_null("HudRoot") as Control

	if player_one != null:
		_setup_fighters(player_one, player_two)

	if round_manager != null:
		round_manager.round_timer_tick.connect(func(rem): if _timer != null: _timer.set_time(rem))
		round_manager.round_intro_started.connect(_on_round_intro_started)
		round_manager.round_intro_player_focus.connect(func(_p, name_str, p_num): if _intro_overlay != null: _intro_overlay.focus_player(name_str, p_num))
		round_manager.round_intro_fight.connect(func(): if _intro_overlay != null: _intro_overlay.show_fight())
		round_manager.round_started.connect(_on_round_started)

	if match_manager != null:
		match_manager.rounds_score_changed.connect(func(p1_w, p2_w):
			if _p1_health != null: _p1_health.set_round_wins(p1_w)
			if _p2_health != null: _p2_health.set_round_wins(p2_w)
		)

	if _combo_label != null: _combo_label.visible = false

	_pause_panel = get_node_or_null(pause_panel_path) as Control
	_resume_button = get_node_or_null(resume_button_path) as BaseButton
	_retry_button = get_node_or_null(retry_button_path) as BaseButton
	_quit_button = get_node_or_null(quit_button_path) as BaseButton

	if _resume_button != null: _resume_button.pressed.connect(resume_game)
	if _retry_button != null: _retry_button.pressed.connect(retry_game)
	if _quit_button != null: _quit_button.pressed.connect(quit_game)
	if _pause_panel != null: _pause_panel.visible = false

	_master_slider = get_node_or_null(master_volume_slider_path) as HSlider
	_music_slider = get_node_or_null(music_volume_slider_path) as HSlider
	_sfx_slider = get_node_or_null(sfx_volume_slider_path) as HSlider
	_master_label = get_node_or_null(master_volume_label_path) as Label
	_music_label = get_node_or_null(music_volume_label_path) as Label
	_sfx_label = get_node_or_null(sfx_volume_label_path) as Label

	_setup_audio_sliders()

func update_fighter_references(player_one: Node, player_two: Node) -> void:
	_setup_fighters(player_one, player_two)

func _setup_fighters(player_one: Node, player_two: Node) -> void:
	if _hurt_vignette == null:
		_hurt_vignette = HurtVignette.new()
		add_child(_hurt_vignette)

	if player_one == null:
		return

	var p1_name = "Player 1"
	if "data" in player_one and player_one.data != null and "display_name" in player_one.data:
		p1_name = player_one.data.display_name
	elif GameManager.instance != null and not GameManager.instance.player_one_name.strip_edges().is_empty():
		p1_name = GameManager.instance.player_one_name

	if _p1_health != null:
		_p1_health.set_fighter_name(p1_name)

		var cur_hp: float = 1000.0
		var max_hp: float = 1000.0
		if "current_health" in player_one:
			cur_hp = player_one.get("current_health")
		elif "health" in player_one and player_one.health != null:
			cur_hp = player_one.health.current_health

		if "mob_max_health" in player_one:
			max_hp = player_one.get("mob_max_health")
		elif "health" in player_one and player_one.health != null:
			max_hp = player_one.health.max_health

		_last_p1_hp = cur_hp
		if _hurt_vignette != null:
			_hurt_vignette.update_health(cur_hp, max_hp)

		var on_p1_hp = func(cur: float, max_v: float):
			if _p1_health != null:
				_p1_health.set_health(cur, max_v)
			if _hurt_vignette != null:
				if _last_p1_hp > 0.0 and cur < _last_p1_hp:
					var damage_taken = _last_p1_hp - cur
					var ratio = damage_taken / maxf(1.0, max_v)
					_hurt_vignette.trigger_hurt(ratio)
				_hurt_vignette.update_health(cur, max_v)
			_last_p1_hp = cur

		if player_one.has_signal("health_changed") and not player_one.has_meta("_bui_hp_connected"):
			player_one.set_meta("_bui_hp_connected", true)
			player_one.health_changed.connect(on_p1_hp)
		elif "health" in player_one and player_one.health != null and player_one.health.has_signal("health_changed") and not player_one.health.has_meta("_bui_hp_connected"):
			player_one.health.set_meta("_bui_hp_connected", true)
			player_one.health.health_changed.connect(on_p1_hp)

		_p1_health.set_health(cur_hp, max_hp)
		_p1_health.set_round_wins(0)

	if player_two != null and _p2_health != null:
		var p2_name = "Player 2"
		if "data" in player_two and player_two.data != null and "display_name" in player_two.data:
			p2_name = player_two.data.display_name
		elif "mob_health" in player_two:
			p2_name = "Enemy"
		elif GameManager.instance != null and not GameManager.instance.player_two_name.strip_edges().is_empty():
			p2_name = GameManager.instance.player_two_name

		_p2_health.set_fighter_name(p2_name)
		if player_two.has_signal("mob_health_changed"):
			player_two.connect("mob_health_changed", func(cur, max_v): _p2_health.set_health(cur, max_v))
		elif player_two.has_signal("health_changed"):
			player_two.connect("health_changed", func(cur, max_v): _p2_health.set_health(cur, max_v))
		elif "health" in player_two and player_two.health != null and player_two.health.has_signal("health_changed"):
			player_two.health.health_changed.connect(func(cur, max_v): _p2_health.set_health(cur, max_v))

		var cur_p2_hp: float = 1000.0
		var max_p2_hp: float = 1000.0
		if "current_health" in player_two:
			cur_p2_hp = player_two.get("current_health")
		elif "health" in player_two and player_two.health != null:
			cur_p2_hp = player_two.health.current_health

		if "mob_health" in player_two:
			max_p2_hp = player_two.get("mob_health")
		elif "health" in player_two and player_two.health != null:
			max_p2_hp = player_two.health.max_health

		_p2_health.set_health(cur_p2_hp, max_p2_hp)
		_p2_health.set_round_wins(0)
	elif _p2_health != null:
		_p2_health.visible = false

	if _p1_energy != null and "energy" in player_one and player_one.energy != null:
		player_one.energy.energy_changed.connect(func(cur, max_v): _update_bar(_p1_energy, cur, max_v))
		_update_bar(_p1_energy, player_one.energy.current_energy, player_one.energy.max_energy)
	elif _p1_energy != null:
		_p1_energy.visible = false

	if player_two != null and _p2_energy != null and "energy" in player_two and player_two.energy != null:
		player_two.energy.energy_changed.connect(func(cur, max_v): _update_bar(_p2_energy, cur, max_v))
		_update_bar(_p2_energy, player_two.energy.current_energy, player_two.energy.max_energy)
	elif _p2_energy != null:
		_p2_energy.visible = false

	if "combo" in player_one and player_one.combo != null:
		player_one.combo.combo_changed.connect(func(count): _update_combo(count, true))
	if player_two != null and "combo" in player_two and player_two.combo != null:
		player_two.combo.combo_changed.connect(func(count): _update_combo(count, false))
		player_two.combo.combo_changed.connect(func(count): _update_combo(count, false))

func _on_round_intro_started(round_num: int, p1_wins: int, p2_wins: int) -> void:
	if _p1_health != null: _p1_health.set_round_wins(p1_wins)
	if _p2_health != null: _p2_health.set_round_wins(p2_wins)

	if round_num <= 1:
		if _hud_root != null: _hud_root.modulate = Color(1.0, 1.0, 1.0, 0.35)
		if _intro_overlay != null: _intro_overlay.show_round_intro(round_num, p1_wins, p2_wins)
	else:
		if _intro_overlay != null: _intro_overlay.show_round_overlay(round_num, p1_wins, p2_wins)

func _on_round_started() -> void:
	if _intro_overlay != null: _intro_overlay.hide_intro()
	if _hud_root != null: _hud_root.modulate = Color.WHITE

func update_wave_info(wave_num: int, total_waves: int, enemies_left: int, is_boss: bool = false) -> void:
	if _wave_info_label == null:
		_wave_info_label = Label.new()
		_wave_info_label.name = "WaveInfoHUD"
		_wave_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wave_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wave_info_label.anchors_preset = Control.PRESET_CENTER_TOP
		_wave_info_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 200.0, 20.0)
		_wave_info_label.custom_minimum_size = Vector2(400.0, 45.0)
		_wave_info_label.z_index = 40
		_wave_info_label.add_theme_font_size_override("font_size", 22)
		_wave_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		_wave_info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_wave_info_label.add_theme_constant_override("outline_size", 6)
		add_child(_wave_info_label)

	if is_boss:
		_wave_info_label.text = "BOSS WAVE | ENEMIES LEFT: %d" % enemies_left
		_wave_info_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		var normal_total = max(1, total_waves - 1)
		_wave_info_label.text = "WAVE %d / %d | ENEMIES LEFT: %d" % [wave_num, normal_total, enemies_left]
		_wave_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))

func show_wave_banner(wave_num: Variant, is_boss: bool = false, custom_text: String = "") -> void:
	var banner = Label.new()
	banner.name = "WaveBanner"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.anchors_preset = Control.PRESET_CENTER
	banner.position = Vector2(get_viewport_rect().size.x * 0.5 - 300, get_viewport_rect().size.y * 0.3)
	banner.custom_minimum_size = Vector2(600, 100)
	banner.z_index = 50

	if not custom_text.is_empty():
		banner.text = custom_text
	elif is_boss:
		banner.text = "FINAL WAVE: BOSS!"
	else:
		banner.text = "WAVE %s" % str(wave_num)

	if is_boss:
		banner.modulate = Color(1.0, 0.2, 0.2, 0.0)
		banner.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		banner.add_theme_font_size_override("font_size", 48)
	else:
		banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
		banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		banner.add_theme_font_size_override("font_size", 44)

	add_child(banner)

	var tw = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)

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

func retry_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit_game() -> void:
	get_tree().paused = false
	if GameManager.instance != null:
		GameManager.instance.go_to_main_menu()

func show_defeat_screen(_wave_reached: int = 1, _max_waves: int = 7) -> void:
	get_tree().paused = true
	if _pause_panel != null:
		_pause_panel.visible = true
		var title_lbl = _pause_panel.get_node_or_null("%PauseTitleLabel") as Label
		if title_lbl != null:
			title_lbl.text = "GAME OVER"
		if _resume_button != null:
			_resume_button.visible = false
		if _retry_button != null:
			_retry_button.visible = true
			_retry_button.grab_focus()
	else:
		retry_game()

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
	if _combo_label == null:
		return

	if count <= 1:
		_combo_label.visible = false
		return

	_combo_label.visible = true
	_combo_label.text = "%d HIT COMBO — %s" % [count, "P1" if is_player_one else "P2"]

static func _update_bar(bar: TextureProgressBar, current: float, max_val: float) -> void:
	if bar != null:
		bar.max_value = max_val
		bar.value = current
