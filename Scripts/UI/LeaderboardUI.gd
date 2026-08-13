class_name LeaderboardUI
extends Control

enum SortMode { TOP_PLAYER, HIGHEST_COMBO, FASTEST_WIN, SP_FASTEST_WIN }

@export var scroll_container_path: NodePath = "%ScrollContainer"
@export var entries_hbox_path: NodePath = "%EntriesHBox"
@export var rank_container_path: NodePath = "%RankContainer"
@export var player_container_path: NodePath = "%PlayerContainer"
@export var wins_container_path: NodePath = "%WinsContainer"

@export var wins_tab_button_path: NodePath = "%WinsTabButton"
@export var combo_tab_button_path: NodePath = "%ComboTabButton"
@export var fastest_tab_button_path: NodePath = "%FastestTabButton"
@export var sp_fastest_tab_button_path: NodePath = "%SPFastestTabButton"
@export var back_button_path: NodePath = "%BackButton"
@export var scroll_up_button_path: NodePath = "%ScrollUpButton"
@export var scroll_down_button_path: NodePath = "%ScrollDownButton"
@export var custom_v_scroll_bar_path: NodePath = "%CustomVScrollBar"
@export var col3_header_path: NodePath = "%Col3Header"
@export var max_entries: int = 50

@export_group("Custom Scrollbar Textures")
@export var scrollbar_grabber_texture: Texture2D
@export var scrollbar_track_texture: Texture2D

@export_group("Grabber Sizing & Margins")
@export var ghost_entry_count: int = 50
@export var min_grabber_height: float = 40.0
@export var grabber_margin_left: float = 4.0
@export var grabber_margin_right: float = 4.0
@export var grabber_margin_top: float = 4.0
@export var grabber_margin_bottom: float = 4.0

@export_group("Entries Font & Styling")
@export var entry_font: FontFile
@export var entry_font_size: int = 14
@export var row_height: float = 42.0
@export var row_separation: float = 6.0

@export_group("Entry Colors")
@export var gold_rank_color: Color = Color(1.0, 0.84, 0.0)
@export var silver_rank_color: Color = Color(0.75, 0.75, 0.75)
@export var bronze_rank_color: Color = Color(0.80, 0.50, 0.20)
@export var default_rank_color: Color = Color(0.85, 0.85, 0.85)
@export var name_color: Color = Color(1.0, 1.0, 1.0)
@export var stat_color: Color = Color(0.4, 0.85, 1.0)

@export_group("Entry Alignments")
@export var rank_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var name_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
@export var stat_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT

@export_group("Entry Font Shadow")
@export var enable_text_shadow: bool = true
@export var shadow_color: Color = Color(0, 0, 0, 0.8)
@export var shadow_offset_x: int = 2
@export var shadow_offset_y: int = 2
@export var shadow_outline_size: int = 4

var _scroll_container: ScrollContainer
var _entries_hbox: HBoxContainer
var _rank_container: VBoxContainer
var _player_container: VBoxContainer
var _wins_container: VBoxContainer
var _custom_scroll_bar: VScrollBar
var _col3_header: Label
var _scroll_up_button: BaseButton
var _scroll_down_button: BaseButton
var _mode: SortMode = SortMode.TOP_PLAYER
var _use_online: bool = true
var _mode_toggle_button: Button

var _sfx_hover: AudioStream
var _sfx_select: AudioStream

func _ready() -> void:
	if ResourceLoader.exists("res://Assets/Audio/SFX/hover.mp3"):
		_sfx_hover = load("res://Assets/Audio/SFX/hover.mp3") as AudioStream
	if ResourceLoader.exists("res://Assets/Audio/SFX/select.mp3"):
		_sfx_select = load("res://Assets/Audio/SFX/select.mp3") as AudioStream

	if scrollbar_track_texture == null and ResourceLoader.exists("res://Assets/Sprites/UI/leaderboard/image 244.png"):
		scrollbar_track_texture = load("res://Assets/Sprites/UI/leaderboard/image 244.png") as Texture2D
	if scrollbar_grabber_texture == null and ResourceLoader.exists("res://Assets/Sprites/UI/leaderboard/image 231.png"):
		scrollbar_grabber_texture = load("res://Assets/Sprites/UI/leaderboard/image 231.png") as Texture2D

	if entry_font == null and ResourceLoader.exists("res://Assets/Fonts/Press_Start_2P/PressStart2P-Regular.ttf"):
		entry_font = load("res://Assets/Fonts/Press_Start_2P/PressStart2P-Regular.ttf") as FontFile

	_scroll_container = get_node(scroll_container_path) as ScrollContainer
	_entries_hbox = get_node(entries_hbox_path) as HBoxContainer
	_rank_container = get_node(rank_container_path) as VBoxContainer
	_player_container = get_node(player_container_path) as VBoxContainer
	_wins_container = get_node(wins_container_path) as VBoxContainer
	_custom_scroll_bar = get_node(custom_v_scroll_bar_path) as VScrollBar
	_col3_header = get_node_or_null(col3_header_path) as Label

	var internal_vbar = _scroll_container.get_v_scroll_bar()
	if internal_vbar != null:
		internal_vbar.custom_minimum_size = Vector2.ZERO
		internal_vbar.modulate = Color(0, 0, 0, 0)
		internal_vbar.changed.connect(_sync_scroll_bar_properties)
		internal_vbar.value_changed.connect(func(val):
			if _custom_scroll_bar != null and not is_equal_approx(_custom_scroll_bar.value, val):
				_custom_scroll_bar.value = val
		)

	if _custom_scroll_bar != null:
		_custom_scroll_bar.value_changed.connect(func(val):
			if _scroll_container != null:
				_scroll_container.scroll_vertical = int(val)
		)

	var wins_tab = get_node_or_null(wins_tab_button_path) as BaseButton
	var combo_tab = get_node_or_null(combo_tab_button_path) as BaseButton
	var fastest_tab = get_node_or_null(fastest_tab_button_path) as BaseButton
	var sp_fastest_tab = get_node_or_null(sp_fastest_tab_button_path) as BaseButton

	if wins_tab != null: wins_tab.pressed.connect(func(): set_sort_mode(SortMode.TOP_PLAYER))
	if combo_tab != null: combo_tab.pressed.connect(func(): set_sort_mode(SortMode.HIGHEST_COMBO))
	if fastest_tab != null: fastest_tab.pressed.connect(func(): set_sort_mode(SortMode.FASTEST_WIN))

	var tabs_container = get_node_or_null("Tabs") as HBoxContainer
	if tabs_container != null:
		if sp_fastest_tab == null:
			var sp_btn = Button.new()
			sp_btn.name = "SPFastestTabButton"
			sp_btn.text = "SP FASTEST"
			sp_btn.custom_minimum_size = Vector2(170, 42)
			sp_btn.add_theme_font_size_override("font_size", 12)
			if entry_font != null:
				sp_btn.add_theme_font_override("font", entry_font)
			tabs_container.add_child(sp_btn)
			sp_fastest_tab = sp_btn

	if sp_fastest_tab != null:
		sp_fastest_tab.pressed.connect(func(): set_sort_mode(SortMode.SP_FASTEST_WIN))

	_scroll_up_button = get_node_or_null(scroll_up_button_path) as BaseButton
	_scroll_down_button = get_node_or_null(scroll_down_button_path) as BaseButton

	if _scroll_up_button != null:
		_scroll_up_button.pressed.connect(func(): _scroll_by(-42))
		_scroll_up_button.mouse_entered.connect(_play_hover_sfx)
		_scroll_up_button.button_down.connect(_play_select_sfx)

	if _scroll_down_button != null:
		_scroll_down_button.pressed.connect(func(): _scroll_by(42))
		_scroll_down_button.mouse_entered.connect(_play_hover_sfx)
		_scroll_down_button.button_down.connect(_play_select_sfx)

	_apply_custom_scrollbar_style()

	var back_button = get_node_or_null(back_button_path) as BaseButton
	if back_button != null:
		back_button.pressed.connect(func(): if GameManager.instance != null: GameManager.instance.go_to_main_menu())

	if LeaderboardManager.instance != null:
		if not LeaderboardManager.instance.leaderboard_data_ready.is_connected(_on_leaderboard_data_ready):
			LeaderboardManager.instance.leaderboard_data_ready.connect(_on_leaderboard_data_ready)

	_setup_mode_toggle_button()
	refresh()

func _setup_mode_toggle_button() -> void:
	_mode_toggle_button = get_node_or_null("%ModeToggleButton") as Button
	if _mode_toggle_button == null:
		_mode_toggle_button = Button.new()
		_mode_toggle_button.name = "ModeToggleButton"
		_mode_toggle_button.position = Vector2(1040, 35)
		_mode_toggle_button.size = Vector2(200, 50)
		_mode_toggle_button.add_theme_font_size_override("font_size", 12)
		if entry_font != null:
			_mode_toggle_button.add_theme_font_override("font", entry_font)
		add_child(_mode_toggle_button)

	_mode_toggle_button.pressed.connect(func():
		_use_online = !_use_online
		refresh()
	)
	_update_mode_button_text()

func _update_mode_button_text(is_online_actual: bool = _use_online) -> void:
	if _mode_toggle_button != null:
		if _use_online:
			_mode_toggle_button.text = "ONLINE [CLOUD]" if is_online_actual else "OFFLINE [LOCAL]"
		else:
			_mode_toggle_button.text = "OFFLINE [LOCAL]"

func _sync_scroll_bar_properties() -> void:
	var internal_vbar = _scroll_container.get_v_scroll_bar() if _scroll_container != null else null
	if internal_vbar == null or _custom_scroll_bar == null: return

	_custom_scroll_bar.min_value = internal_vbar.min_value
	_custom_scroll_bar.max_value = internal_vbar.max_value
	_custom_scroll_bar.page = internal_vbar.page
	_custom_scroll_bar.step = internal_vbar.step if internal_vbar.step > 0 else 42.0

func _play_hover_sfx() -> void:
	if _sfx_hover != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(_sfx_hover)

func _play_select_sfx() -> void:
	if _sfx_select != null and AudioManager.instance != null:
		AudioManager.instance.play_sfx(_sfx_select)

func _process(delta: float) -> void:
	if _scroll_up_button != null and _scroll_up_button.is_pressed():
		_scroll_by(int(-300 * delta))
	if _scroll_down_button != null and _scroll_down_button.is_pressed():
		_scroll_by(int(300 * delta))

func _scroll_by(delta_y: int) -> void:
	if _custom_scroll_bar != null:
		_custom_scroll_bar.value = clampf(_custom_scroll_bar.value + delta_y, _custom_scroll_bar.min_value, maxf(0.0, _custom_scroll_bar.max_value - _custom_scroll_bar.page))
	elif _scroll_container != null:
		var v_bar = _scroll_container.get_v_scroll_bar()
		var max_val = maxf(0.0, v_bar.max_value - v_bar.page) if v_bar != null else 0.0
		_scroll_container.scroll_vertical = clampi(_scroll_container.scroll_vertical + delta_y, 0, int(max_val))

func set_sort_mode(mode: SortMode) -> void:
	_mode = mode
	refresh()

func refresh() -> void:
	_rank_container.add_theme_constant_override("separation", int(row_separation))
	_player_container.add_theme_constant_override("separation", int(row_separation))
	_wins_container.add_theme_constant_override("separation", int(row_separation))

	for child in _rank_container.get_children(): child.queue_free()
	for child in _player_container.get_children(): child.queue_free()
	for child in _wins_container.get_children(): child.queue_free()

	var loading_lbl = _create_label("Loading...", default_rank_color, HORIZONTAL_ALIGNMENT_CENTER)
	_player_container.add_child(loading_lbl)

	if _col3_header != null:
		match _mode:
			SortMode.TOP_PLAYER: _col3_header.text = "WINS"
			SortMode.HIGHEST_COMBO: _col3_header.text = "HIGHEST COMBO"
			SortMode.FASTEST_WIN: _col3_header.text = "FASTEST WIN"
			SortMode.SP_FASTEST_WIN: _col3_header.text = "SP FASTEST"
			_: _col3_header.text = "STAT"

	var mode_str = "Wins"
	match _mode:
		SortMode.TOP_PLAYER: mode_str = "Wins"
		SortMode.HIGHEST_COMBO: mode_str = "HighestCombo"
		SortMode.FASTEST_WIN: mode_str = "FastestWinSeconds"
		SortMode.SP_FASTEST_WIN: mode_str = "SPFastestWinSeconds"

	if LeaderboardManager.instance != null:
		LeaderboardManager.instance.request_leaderboard(mode_str, max_entries, _use_online)
	else:
		_on_leaderboard_data_ready([], false)

func _on_leaderboard_data_ready(records: Array, is_online: bool) -> void:
	for child in _rank_container.get_children(): child.queue_free()
	for child in _player_container.get_children(): child.queue_free()
	for child in _wins_container.get_children(): child.queue_free()

	_update_mode_button_text(is_online)

	if records.is_empty():
		var empty_text = "No online matches recorded yet." if is_online else "No local matches recorded yet."
		var empty_label = _create_label(empty_text, default_rank_color, HORIZONTAL_ALIGNMENT_CENTER)
		_player_container.add_child(empty_label)
		_ensure_minimum_scrollable_height(1)
		_sync_scroll_bar_properties.call_deferred()
		return

	var rank: int = 1
	for record in records:
		var r_color = default_rank_color
		match rank:
			1: r_color = gold_rank_color
			2: r_color = silver_rank_color
			3: r_color = bronze_rank_color

		var rank_lbl = _create_label("#%d" % rank, r_color, rank_alignment)
		_rank_container.add_child(rank_lbl)

		var player_name = record.get("player_name", record.get("PlayerName", "Player"))
		var name_lbl = _create_label(player_name, name_color, name_alignment)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_player_container.add_child(name_lbl)

		var stat_text = ""
		match _mode:
			SortMode.TOP_PLAYER:
				var wins = record.get("wins", record.get("Wins", 0))
				var matches = record.get("matches_played", record.get("MatchesPlayed", 0))
				stat_text = "%d W (%d matches)" % [wins, matches]
			SortMode.HIGHEST_COMBO:
				var combo_val = record.get("highest_combo", record.get("HighestCombo", 0))
				stat_text = "%d Hits" % combo_val
			SortMode.FASTEST_WIN:
				var fast_sec = record.get("fastest_win_seconds", record.get("FastestWinSeconds", null))
				stat_text = _format_seconds(fast_sec)
			SortMode.SP_FASTEST_WIN:
				var sp_fast_sec = record.get("sp_fastest_win_seconds", record.get("SPFastestWinSeconds", null))
				stat_text = _format_seconds(sp_fast_sec)

		var stat_lbl = _create_label(stat_text, stat_color, stat_alignment)
		_wins_container.add_child(stat_lbl)
		rank += 1

	_ensure_minimum_scrollable_height(records.size())
	_sync_scroll_bar_properties.call_deferred()

func _create_label(p_text: String, p_color: Color, alignment: HorizontalAlignment) -> Label:
	var lbl = Label.new()
	lbl.text = p_text
	lbl.custom_minimum_size = Vector2(0, row_height)
	lbl.horizontal_alignment = alignment
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	lbl.add_theme_color_override("font_color", p_color)
	lbl.add_theme_font_size_override("font_size", entry_font_size)

	if entry_font != null:
		lbl.add_theme_font_override("font", entry_font)

	if enable_text_shadow:
		lbl.add_theme_color_override("font_shadow_color", shadow_color)
		lbl.add_theme_constant_override("shadow_offset_x", shadow_offset_x)
		lbl.add_theme_constant_override("shadow_offset_y", shadow_offset_y)
		lbl.add_theme_constant_override("shadow_outline_size", shadow_outline_size)

	return lbl

func _ensure_minimum_scrollable_height(row_count: int) -> void:
	var eff_count = maxi(row_count, ghost_entry_count)
	var content_h = eff_count * row_height + (eff_count - 1) * row_separation
	var page_h = _scroll_container.size.y if _scroll_container.size.y > 0 else 400.0
	var min_size = Vector2(0, maxf(content_h, page_h + 80.0))

	_rank_container.custom_minimum_size = min_size
	_player_container.custom_minimum_size = min_size
	_wins_container.custom_minimum_size = min_size
	_entries_hbox.custom_minimum_size = min_size

static func _format_seconds(sec) -> String:
	if sec != null:
		return "%.1fs" % float(sec)
	return "—"

func _apply_custom_scrollbar_style() -> void:
	var v_bar = _custom_scroll_bar if _custom_scroll_bar != null else (_scroll_container.get_v_scroll_bar() if _scroll_container != null else null)
	if v_bar == null: return

	v_bar.custom_minimum_size = Vector2(40, 0)
	v_bar.add_theme_constant_override("grabber_min_size", int(min_grabber_height))

	if scrollbar_grabber_texture != null:
		var grabber_tex = StyleBoxTexture.new()
		grabber_tex.texture = scrollbar_grabber_texture
		grabber_tex.texture_margin_left = 2
		grabber_tex.texture_margin_top = 4
		grabber_tex.texture_margin_right = 2
		grabber_tex.texture_margin_bottom = 4
		grabber_tex.expand_margin_left = -grabber_margin_left
		grabber_tex.expand_margin_right = -grabber_margin_right
		grabber_tex.expand_margin_top = -grabber_margin_top
		grabber_tex.expand_margin_bottom = -grabber_margin_bottom
		grabber_tex.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		grabber_tex.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

		v_bar.add_theme_stylebox_override("grabber", grabber_tex)
		v_bar.add_theme_stylebox_override("grabber_highlight", grabber_tex)
		v_bar.add_theme_stylebox_override("grabber_pressed", grabber_tex)
	else:
		var grabber_flat = StyleBoxFlat.new()
		grabber_flat.bg_color = Color(0.20, 0.28, 0.45, 0.95)
		grabber_flat.border_color = Color(0.40, 0.70, 1.00, 1.00)
		grabber_flat.border_width_left = 2
		grabber_flat.border_width_top = 2
		grabber_flat.border_width_right = 2
		grabber_flat.border_width_bottom = 2
		grabber_flat.corner_radius_top_left = 6
		grabber_flat.corner_radius_top_right = 6
		grabber_flat.corner_radius_bottom_right = 6
		grabber_flat.corner_radius_bottom_left = 6
		grabber_flat.shadow_color = Color(0, 0, 0, 0.4)
		grabber_flat.shadow_size = 3
		grabber_flat.expand_margin_left = -grabber_margin_left
		grabber_flat.expand_margin_right = -grabber_margin_right
		grabber_flat.expand_margin_top = -grabber_margin_top
		grabber_flat.expand_margin_bottom = -grabber_margin_bottom

		v_bar.add_theme_stylebox_override("grabber", grabber_flat)
		v_bar.add_theme_stylebox_override("grabber_highlight", grabber_flat)
		v_bar.add_theme_stylebox_override("grabber_pressed", grabber_flat)

	if scrollbar_track_texture != null:
		var track_tex = StyleBoxTexture.new()
		track_tex.texture = scrollbar_track_texture
		track_tex.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		track_tex.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		v_bar.add_theme_stylebox_override("scroll", track_tex)
		v_bar.add_theme_stylebox_override("scroll_focus", track_tex)
	else:
		var track_flat = StyleBoxFlat.new()
		track_flat.bg_color = Color(0.06, 0.08, 0.13, 0.85)
		track_flat.border_color = Color(0.25, 0.35, 0.50, 0.80)
		track_flat.border_width_left = 1
		track_flat.border_width_top = 1
		track_flat.border_width_right = 1
		track_flat.border_width_bottom = 1
		track_flat.corner_radius_top_left = 6
		track_flat.corner_radius_top_right = 6
		track_flat.corner_radius_bottom_right = 6
		track_flat.corner_radius_bottom_left = 6
		track_flat.content_margin_left = 2
		track_flat.content_margin_top = 2
		track_flat.content_margin_right = 2
		track_flat.content_margin_bottom = 2

		v_bar.add_theme_stylebox_override("scroll", track_flat)
		v_bar.add_theme_stylebox_override("scroll_focus", track_flat)
