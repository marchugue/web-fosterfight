class_name SinglePlayerWaveHUD
extends Control

@onready var _wave_label: Label = %WaveLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _player_health_label: Label = %PlayerHealthLabel

# ── Skill slot icon customization ────────────────────────────────────────────
## Drag any Texture2D (icon/sprite) onto these in the Inspector to customize each skill slot icon
@export var skill1_icon: Texture2D
@export var skill2_icon: Texture2D
@export var skill3_icon: Texture2D

# ── Cooldown tracking ─────────────────────────────────────────────────────────
var _cooldown_durations: Array[float] = [0.0, 0.0, 0.0]  # slots 1, 2, 3
var _cooldown_elapsed: Array[float] = [0.0, 0.0, 0.0]
var _skill_nodes: Array[Control] = []
var _player_ref: Node = null
var _hurt_vignette: HurtVignette = null
var _last_player_hp: float = -1.0

var _pause_panel: Control = null
var _defeat_panel: Control = null
var _master_slider: HSlider = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _master_label: Label = null
var _music_label: Label = null
var _sfx_label: Label = null

# ── Layout ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_vignette = HurtVignette.new()
	add_child(_hurt_vignette)
	if _wave_label != null:
		var panel = _wave_label.get_parent()
		if panel is PanelContainer:
			panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_update_layout()
	_build_cooldown_ui()
	_build_pause_ui()
	_build_defeat_ui()

func _unhandled_input(event: InputEvent) -> void:
	if _defeat_panel != null and _defeat_panel.visible:
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if _defeat_panel != null and _defeat_panel.visible:
		return
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	get_tree().paused = true
	_sync_audio_sliders()
	if _pause_panel != null:
		_pause_panel.visible = true

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
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func show_defeat_screen(wave_reached: int = 1, max_waves: int = 7) -> void:
	if _defeat_panel == null:
		return
	var wave_info_lbl = _defeat_panel.get_node_or_null("%DefeatWaveLabel") as Label
	if wave_info_lbl != null:
		var normal_total = maxi(1, max_waves - 1)
		if wave_reached >= max_waves:
			wave_info_lbl.text = "REACHED FINAL BOSS WAVE!"
		else:
			wave_info_lbl.text = "REACHED WAVE %d OF %d" % [wave_reached, normal_total]

	_defeat_panel.visible = true
	var retry_btn = _defeat_panel.get_node_or_null("%DefeatRetryButton") as Button
	if retry_btn != null:
		retry_btn.grab_focus()

func _build_defeat_ui() -> void:
	_defeat_panel = Control.new()
	_defeat_panel.name = "DefeatPanel"
	_defeat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_defeat_panel.visible = false
	_defeat_panel.z_index = 120
	_defeat_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_defeat_panel)

	var dim = ColorRect.new()
	dim.color = Color(0.12, 0.02, 0.02, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_defeat_panel.add_child(dim)

	var card = PanelContainer.new()
	card.name = "DefeatCard"
	card.custom_minimum_size = Vector2(400, 320)
	card.anchors_preset = Control.PRESET_CENTER
	card.position = Vector2((size.x - 400) * 0.5, (size.y - 320) * 0.5)

	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.12, 0.05, 0.05, 0.95)
	card_sb.border_width_left = 3
	card_sb.border_width_top = 3
	card_sb.border_width_right = 3
	card_sb.border_width_bottom = 3
	card_sb.border_color = Color(0.9, 0.2, 0.2, 0.9)
	card_sb.corner_radius_top_left = 14
	card_sb.corner_radius_top_right = 14
	card_sb.corner_radius_bottom_left = 14
	card_sb.corner_radius_bottom_right = 14
	card_sb.shadow_color = Color(0.8, 0.1, 0.1, 0.3)
	card_sb.shadow_size = 15
	card.add_theme_stylebox_override("panel", card_sb)
	_defeat_panel.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)

	var sub_label = Label.new()
	sub_label.name = "DefeatWaveLabel"
	sub_label.unique_name_in_owner = true
	sub_label.text = "REACHED WAVE 1 OF 6"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	vbox.add_child(sub_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var retry_btn = Button.new()
	retry_btn.name = "DefeatRetryButton"
	retry_btn.unique_name_in_owner = true
	retry_btn.text = "RETRY 🔄"
	retry_btn.custom_minimum_size = Vector2(240, 44)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.pressed.connect(retry_game)
	vbox.add_child(retry_btn)

	var quit_btn = Button.new()
	quit_btn.text = "QUIT TO MENU 🏠"
	quit_btn.custom_minimum_size = Vector2(240, 44)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.pressed.connect(quit_game)
	vbox.add_child(quit_btn)

func _build_pause_ui() -> void:
	var pause_btn = Button.new()
	pause_btn.name = "PauseBtn"
	pause_btn.text = "PAUSE ⏸"
	pause_btn.custom_minimum_size = Vector2(96, 32)
	pause_btn.position = Vector2(size.x - 110, 16)
	pause_btn.add_theme_font_size_override("font_size", 13)
	pause_btn.pressed.connect(toggle_pause)
	pause_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_btn)

	_pause_panel = Control.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	_pause_panel.z_index = 100
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_panel)

	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.add_child(dim)

	var card = PanelContainer.new()
	card.name = "PauseCard"
	card.custom_minimum_size = Vector2(380, 420)
	card.anchors_preset = Control.PRESET_CENTER
	card.position = Vector2((size.x - 380) * 0.5, (size.y - 420) * 0.5)

	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.09, 0.14, 0.95)
	card_sb.border_width_left = 2
	card_sb.border_width_top = 2
	card_sb.border_width_right = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.9, 0.75, 0.2, 0.8)
	card_sb.corner_radius_top_left = 12
	card_sb.corner_radius_top_right = 12
	card_sb.corner_radius_bottom_left = 12
	card_sb.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", card_sb)
	_pause_panel.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var audio_sec = VBoxContainer.new()
	audio_sec.add_theme_constant_override("separation", 6)
	vbox.add_child(audio_sec)

	_master_label = Label.new()
	_master_label.text = "MASTER VOL: 100%"
	_master_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_master_label.add_theme_font_size_override("font_size", 12)
	audio_sec.add_child(_master_label)

	_master_slider = HSlider.new()
	_master_slider.min_value = 0.0
	_master_slider.max_value = 1.0
	_master_slider.step = 0.05
	_master_slider.value_changed.connect(_on_master_volume_changed)
	audio_sec.add_child(_master_slider)

	_music_label = Label.new()
	_music_label.text = "BGM VOL: 80%"
	_music_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_label.add_theme_font_size_override("font_size", 12)
	audio_sec.add_child(_music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.05
	_music_slider.value_changed.connect(_on_music_volume_changed)
	audio_sec.add_child(_music_slider)

	_sfx_label = Label.new()
	_sfx_label.text = "SFX VOL: 100%"
	_sfx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sfx_label.add_theme_font_size_override("font_size", 12)
	audio_sec.add_child(_sfx_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	audio_sec.add_child(_sfx_slider)

	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 38)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.pressed.connect(resume_game)
	vbox.add_child(resume_btn)

	var retry_btn = Button.new()
	retry_btn.text = "RETRY"
	retry_btn.custom_minimum_size = Vector2(200, 38)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.pressed.connect(retry_game)
	vbox.add_child(retry_btn)

	var quit_btn = Button.new()
	quit_btn.text = "QUIT TO MENU"
	quit_btn.custom_minimum_size = Vector2(200, 38)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.pressed.connect(quit_game)
	vbox.add_child(quit_btn)

	_sync_audio_sliders()

func _sync_audio_sliders() -> void:
	if GameManager.instance == null or GameManager.instance.settings == null:
		return
	var settings = GameManager.instance.settings
	if _master_slider != null:
		_master_slider.set_value_no_signal(settings.master_volume)
		_master_label.text = "MASTER VOL: %d%%" % int(round(settings.master_volume * 100.0))
	if _music_slider != null:
		_music_slider.set_value_no_signal(settings.music_volume)
		_music_label.text = "BGM VOL: %d%%" % int(round(settings.music_volume * 100.0))
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(settings.sfx_volume)
		_sfx_label.text = "SFX VOL: %d%%" % int(round(settings.sfx_volume * 100.0))

func _on_master_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.master_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	if _master_label != null:
		_master_label.text = "MASTER VOL: %d%%" % int(round(val * 100.0))

func _on_music_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.music_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	if _music_label != null:
		_music_label.text = "BGM VOL: %d%%" % int(round(val * 100.0))

func _on_sfx_volume_changed(val: float) -> void:
	if GameManager.instance != null and GameManager.instance.settings != null:
		GameManager.instance.settings.sfx_volume = val
		GameManager.instance.settings_changed.emit()
		GameManager.instance.save_settings()
	if _sfx_label != null:
		_sfx_label.text = "SFX VOL: %d%%" % int(round(val * 100.0))

func _build_cooldown_ui() -> void:
	var skill_bar = HBoxContainer.new()
	skill_bar.name = "SkillBar"
	skill_bar.add_theme_constant_override("separation", 8)
	skill_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	skill_bar.position = Vector2(16, -90)
	add_child(skill_bar)

	var labels = ["[f]", "[g]", "[h]"]
	var icons: Array = [skill1_icon, skill2_icon, skill3_icon]

	var colors: Array = [Color(0.742, 0.794, 0.153, 1.0),  Color(0.0, 0.659, 0.235, 1.0), Color(0.84, 0.699, 0.034, 1.0)]

	for i in 3:
		var slot_ctrl = _create_skill_slot(i + 1, labels[i], colors[i], icons[i])
		skill_bar.add_child(slot_ctrl)
		_skill_nodes.append(slot_ctrl)

func _create_skill_slot(slot: int, label_text: String, color: Color, icon: Texture2D = null) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(58, 74)
	container.name = "SkillSlot%d" % slot

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.82)
	bg.custom_minimum_size = Vector2(52, 52)
	bg.size = Vector2(52, 52)
	bg.position = Vector2(3, 0)
	container.add_child(bg)

	# Slot number or icon
	if icon != null:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(52, 52)
		icon_rect.position = Vector2(3, 0)
		icon_rect.name = "IconRect"
		container.add_child(icon_rect)
	var num_lbl = Label.new()
	num_lbl.text = str(slot)
	num_lbl.add_theme_font_size_override("font_size", 22)
	num_lbl.add_theme_color_override("font_color", color)
	num_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	num_lbl.add_theme_constant_override("outline_size", 4)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.size = Vector2(58, 52)
	num_lbl.position = Vector2(0, 0)
	num_lbl.name = "NumLabel"
	num_lbl.visible = (icon == null)  # hide number if icon is set
	container.add_child(num_lbl)

	# Lock overlay (slots 2 and 3 start locked)
	var lock_lbl = Label.new()
	lock_lbl.text = "LOCK"
	lock_lbl.add_theme_font_size_override("font_size", 10)
	lock_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 0.9))
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.size = Vector2(58, 52)
	lock_lbl.position = Vector2(0, 0)
	lock_lbl.name = "LockLabel"
	lock_lbl.visible = (slot > 1)
	container.add_child(lock_lbl)

	# Cooldown arc drawn via inner class
	var arc = CooldownArcControl.new()
	arc.size = Vector2(52, 52)
	arc.position = Vector2(3, 0)
	arc.arc_color = color
	arc.name = "CooldownArc"
	container.add_child(arc)

	# Key hint
	var hint = Label.new()
	hint.text = label_text
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(58, 18)
	hint.position = Vector2(0, 54)
	container.add_child(hint)

	return container

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if _wave_label == null:
		return
	var panel = _wave_label.get_parent() as Control
	if panel != null:
		panel.position.x = (size.x - panel.size.x) * 0.5

func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_update_skill_lock_visuals()

func _tick_cooldowns(delta: float) -> void:
	for i in 3:
		if _cooldown_elapsed[i] > 0.0:
			_cooldown_elapsed[i] = maxf(0.0, _cooldown_elapsed[i] - delta)
			_update_cooldown_arc(i)

func _update_cooldown_arc(slot_idx: int) -> void:
	if slot_idx >= _skill_nodes.size():
		return
	var container = _skill_nodes[slot_idx]
	var arc = container.get_node_or_null("CooldownArc") as CooldownArcControl
	if arc == null:
		return
	var duration = _cooldown_durations[slot_idx]
	arc.progress = _cooldown_elapsed[slot_idx] / maxf(0.01, duration) if duration > 0.0 else 0.0

func _update_skill_lock_visuals() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var skill2 = _player_ref.get("skill2_unlocked") if "skill2_unlocked" in _player_ref else false
	var skill3 = _player_ref.get("skill3_unlocked") if "skill3_unlocked" in _player_ref else false
	_set_slot_locked(1, not skill2)
	_set_slot_locked(2, not skill3)

func _set_slot_locked(slot_idx: int, locked: bool) -> void:
	if slot_idx >= _skill_nodes.size():
		return
	var container = _skill_nodes[slot_idx]
	var lock = container.get_node_or_null("LockLabel") as Label
	var num  = container.get_node_or_null("NumLabel") as Label
	if lock != null:
		lock.visible = locked
	if num != null:
		num.modulate.a = 0.35 if locked else 1.0

func notify_attack_used(slot: int, cooldown_duration: float) -> void:
	var idx = slot - 1
	if idx < 0 or idx >= 3:
		return
	_cooldown_durations[idx] = cooldown_duration
	_cooldown_elapsed[idx] = cooldown_duration
	_update_cooldown_arc(idx)

# ── Public API ────────────────────────────────────────────────────────────────
func update_wave_info(wave_num: int, total_waves: int, enemies_left: int, is_boss: bool = false) -> void:
	if _wave_label == null or _enemies_label == null:
		return
	if is_boss:
		_wave_label.text = "BOSS WAVE"
		_wave_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		var normal_total = maxi(1, total_waves - 1)
		_wave_label.text = "WAVE %d / %d" % [wave_num, normal_total]
		_wave_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_enemies_label.text = "ENEMIES LEFT: %d" % maxi(0, enemies_left)

func show_wave_banner(wave_num: Variant, is_boss: bool = false, custom_text: String = "") -> void:
	var banner = Label.new()
	banner.name = "WaveBanner"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.anchors_preset = Control.PRESET_CENTER
	banner.position = Vector2(size.x * 0.5 - 300.0, size.y * 0.28)
	banner.custom_minimum_size = Vector2(600.0, 100.0)
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
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("outline_size", 8)
	add_child(banner)
	var tw = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)

func update_fighter_references(player_one: Node, _player_two: Node) -> void:
	_player_ref = player_one
	if _player_health_label == null or player_one == null:
		return
	var cur_hp: float = 1000.0
	var max_hp: float = 1000.0
	if "current_health" in player_one:
		cur_hp = float(player_one.current_health)
	if "mob_max_health" in player_one:
		max_hp = float(player_one.mob_max_health)
	_player_health_label.text = "HP: %d / %d" % [int(cur_hp), int(max_hp)]
	_last_player_hp = cur_hp
	if _hurt_vignette != null:
		_hurt_vignette.update_health(cur_hp, max_hp)
	if player_one.has_signal("health_changed") and not player_one.has_meta("_wave_hud_hp_connected"):
		player_one.set_meta("_wave_hud_hp_connected", true)
		player_one.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: float, max_health: float) -> void:
	if _player_health_label != null:
		_player_health_label.text = "HP: %d / %d" % [int(current), int(max_health)]
	if _hurt_vignette != null:
		if _last_player_hp > 0.0 and current < _last_player_hp:
			var damage_taken = _last_player_hp - current
			var ratio = damage_taken / maxf(1.0, max_health)
			_hurt_vignette.trigger_hurt(ratio)
		_hurt_vignette.update_health(current, max_health)
	_last_player_hp = current
