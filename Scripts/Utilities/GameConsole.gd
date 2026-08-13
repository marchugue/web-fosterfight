class_name GameConsole
extends CanvasLayer

static var instance: GameConsole = null

var is_console_open: bool = false
var god_mode: bool = false

var _panel: PanelContainer
var _log_label: RichTextLabel
var _input_line: LineEdit
var _history: Array[String] = []
var _history_idx: int = -1

func _ready() -> void:
	instance = self
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ConsolePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 280)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.6, 1.0, 0.8)
	sb.content_margin_left = 12
	sb.content_margin_top = 12
	sb.content_margin_right = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚡ GAME CONSOLE [Press ~ or F12 or Select to close | Type 'help' for commands]"
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(0, 180)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.text = "[color=#888888]System Console Ready. Type 'help' for list of commands.[/color]\n"
	vbox.add_child(_log_label)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Enter console command..."
	_input_line.text_submitted.connect(_on_command_submitted)
	vbox.add_child(_input_line)

	add_child(_panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F12:
			toggle_console()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and not event.is_echo():
		if event.button_index == JOY_BUTTON_BACK:
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	is_console_open = not is_console_open
	_panel.visible = is_console_open
	if is_console_open:
		_input_line.grab_focus()

func print_line(msg: String, color_hex: String = "#CCCCCC") -> void:
	if _log_label != null:
		_log_label.append_text("[color=%s]%s[/color]\n" % [color_hex, msg])

func _on_command_submitted(raw_cmd: String) -> void:
	var cmd = raw_cmd.strip_edges()
	if _input_line != null:
		_input_line.clear()
	if cmd.is_empty():
		return

	print_line("> " + cmd, "#40E0D0")
	_history.append(cmd)
	_history_idx = _history.size()

	execute_command(cmd)

func execute_command(cmd_text: String) -> void:
	var parts = cmd_text.split(" ", false)
	if parts.is_empty():
		return

	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	match cmd:
		"help":
			print_line("Available Commands:", "#FFD700")
			print_line("  god              - Toggle invincibility")
			print_line("  heal / hp        - Restore full player health")
			print_line("  clear_wave       - Defeat active wave enemies")
			print_line("  unlock_skills    - Unlock all single-player skills")
			print_line("  set_speed [val]  - Set attack speed multiplier")
			print_line("  clear            - Clear console log")
		"god":
			god_mode = not god_mode
			print_line("God mode: " + ("ENABLED" if god_mode else "DISABLED"), "#00FF00" if god_mode else "#FF6666")
		"heal", "hp":
			var players = get_tree().get_nodes_in_group("player")
			for p in players:
				if "current_health" in p and "mob_max_health" in p:
					p.current_health = p.mob_max_health
					if p.has_signal("health_changed"):
						p.health_changed.emit(p.current_health, p.mob_max_health)
			print_line("Health restored!", "#00FF00")
		"clear_wave", "skip_wave":
			var mobs = get_tree().get_nodes_in_group("mobs")
			for m in mobs:
				if is_instance_valid(m) and m.has_method("take_damage"):
					m.call("take_damage", 99999.0)
			print_line("Wave cleared!", "#00FF00")
		"unlock_skills":
			var players = get_tree().get_nodes_in_group("player")
			for p in players:
				if "skill2_unlocked" in p: p.skill2_unlocked = true
				if "skill3_unlocked" in p: p.skill3_unlocked = true
			print_line("All skills unlocked!", "#00FF00")
		"set_speed":
			if args.size() > 0 and args[0].is_valid_float():
				var spd = args[0].to_float()
				var players = get_tree().get_nodes_in_group("player")
				for p in players:
					if "attack_speed" in p: p.attack_speed = spd
				print_line("Attack speed set to %f" % spd, "#00FF00")
			else:
				print_line("Usage: set_speed <multiplier>", "#FF6666")
		"clear":
			if _log_label != null:
				_log_label.clear()
		_:
			print_line("Unknown command: %s. Type 'help' for available commands." % cmd, "#FF6666")
