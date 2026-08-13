class_name ChestRewardUI
extends CanvasLayer

# ── Signals ────────────────────────────────────────────────────────────────
signal reward_chosen(card_id: String, value: float)

# ── Card types ──────────────────────────────────────────────────────────────
enum CardType {
	STAT_ATK_DMG,
	STAT_ATK_SPD,
	STAT_HEALTH,
	SKILL_2,
	SKILL_3,
}

# ── Card texture customization ────────────────────────────────────────────────
## Drag any Texture2D icons here in Inspector to customize card art
@export var icon_atk_dmg: Texture2D
@export var icon_atk_spd: Texture2D
@export var icon_health: Texture2D
@export var icon_skill2: Texture2D
@export var icon_skill3: Texture2D

@export_group("Card Background Textures")
## Optional custom texture for the card frame in normal state
@export var card_normal_texture: Texture2D
## Optional custom texture for the card frame when hovered
@export var card_hover_texture: Texture2D

# ── Internal state ──────────────────────────────────────────────────────────
var _player: Node = null
var _on_chosen: Callable
var _chest_opened: bool = false

# ── Node refs (built in code, no tscn dependency) ───────────────────────────
var _overlay: ColorRect
var _chest_sprite: AnimatedSprite2D
var _title_label: Label
var _subtitle_label: Label
var _cards_container: HBoxContainer

# ── Entry point ─────────────────────────────────────────────────────────────
func show_reward(_wave_num: int, player: Node, on_chosen: Callable) -> void:
	_player = player
	_on_chosen = on_chosen
	_chest_opened = false

	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	_build_chest_animation()

	layer = 120
	get_tree().paused = true

	await get_tree().process_frame
	_animate_in()

# ── UI builder ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Root control
	var root = Control.new()
	root.name = "ChestRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(root)

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.75)
	_overlay.modulate.a = 0.0
	root.add_child(_overlay)

	# Central container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	vbox.set("custom_minimum_size", Vector2(600, 400))
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "WAVE CLEARED!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.modulate.a = 0.0
	vbox.add_child(_title_label)

	# Chest
	_chest_sprite = AnimatedSprite2D.new()
	_chest_sprite.scale = Vector2(2.0, 2.0)
	var chest_holder = CenterContainer.new()
	chest_holder.custom_minimum_size = Vector2(160, 160)
	chest_holder.add_child(_chest_sprite)
	vbox.add_child(chest_holder)

	# Subtitle / Header
	_subtitle_label = Label.new()
	_subtitle_label.text = "Choose a power-up:"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_subtitle_label.modulate.a = 0.0
	vbox.add_child(_subtitle_label)

	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 18)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.modulate.a = 0.0
	vbox.add_child(_cards_container)

func _build_chest_animation() -> void:
	var frames = SpriteFrames.new()
	frames.add_animation("closed")
	frames.add_animation("opening")
	frames.set_animation_loop("closed", true)
	frames.set_animation_loop("opening", false)
	frames.set_animation_speed("closed", 1.0)
	frames.set_animation_speed("opening", 4.0)

	var tex: Texture2D = null
	if ResourceLoader.exists("res://Assets/Sprites/UI/chest_spritesheet.png"):
		tex = load("res://Assets/Sprites/UI/chest_spritesheet.png") as Texture2D
	if tex != null:
		# Use top-left chest (closed) and top-right chest (open) as the two frames
		var half_w: float = tex.get_width() / 2.0
		var h: float = tex.get_height() / 2.0

		var closed_atlas = AtlasTexture.new()
		closed_atlas.atlas = tex
		closed_atlas.region = Rect2(0, 0, half_w, h)

		var open_atlas = AtlasTexture.new()
		open_atlas.atlas = tex
		open_atlas.region = Rect2(half_w, 0, half_w, h)

		frames.add_frame("closed", closed_atlas)
		frames.add_frame("opening", closed_atlas)
		frames.add_frame("opening", open_atlas)
	else:
		# Fallback: coloured placeholder frames
		var img_c = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img_c.fill(Color(0.5, 0.3, 0.1))
		var img_o = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img_o.fill(Color(1.0, 0.8, 0.1))
		frames.add_frame("closed", ImageTexture.create_from_image(img_c))
		frames.add_frame("opening", ImageTexture.create_from_image(img_c))
		frames.add_frame("opening", ImageTexture.create_from_image(img_o))

	_chest_sprite.sprite_frames = frames
	_chest_sprite.animation = "opening"
	_chest_sprite.play("opening")

# ── Animation ────────────────────────────────────────────────────────────────
func _animate_in() -> void:
	_show_cards()
	var tw = create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.25)
	tw.tween_property(_subtitle_label, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_cards_container, "modulate:a", 1.0, 0.3)

func _show_cards() -> void:
	if _player == null:
		return

	var wave_num = 1
	if _player.has_meta("_current_wave_for_reward"):
		wave_num = _player.get_meta("_current_wave_for_reward")

	var cards = _build_cards(wave_num)
	for card in cards:
		_cards_container.add_child(_create_card_button(card))

	var tw = create_tween()
	tw.tween_property(_subtitle_label, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_cards_container, "modulate:a", 1.0, 0.4)

# ── Card building ────────────────────────────────────────────────────────────
func _build_cards(wave_num: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []

	var skill2_unlocked = _player.get("skill2_unlocked") if _player != null else true
	var skill3_unlocked = _player.get("skill3_unlocked") if _player != null else true

	# Always available stat cards (randomise which ones appear)
	var stat_pool: Array[Dictionary] = [
		{
			"id": "atk_dmg",
			"type": CardType.STAT_ATK_DMG,
			"label": "⚔ Attack Power",
			"desc": "+20% Attack Damage",
			"value": 0.2,
			"color": Color(1.0, 0.35, 0.35),
			"icon": icon_atk_dmg,
		},
		{
			"id": "atk_spd",
			"type": CardType.STAT_ATK_SPD,
			"label": "⚡ Attack Speed",
			"desc": "+15% Attack Speed",
			"value": 0.15,
			"color": Color(0.35, 0.85, 1.0),
			"icon": icon_atk_spd,
		},
		{
			"id": "health",
			"type": CardType.STAT_HEALTH,
			"label": "❤ Vitality",
			"desc": "+150 Max Health",
			"value": 150.0,
			"color": Color(0.4, 1.0, 0.5),
			"icon": icon_health,
		},
	]
	stat_pool.shuffle()

	# Slot counts: wave 1 = 2 cards, wave 2+ = 3 cards

	match wave_num:
		1:
			# Wave 1 Clear: 2 stat booster cards
			cards.append(stat_pool[0])
			cards.append(stat_pool[1])

		2:
			# Wave 2 Clear: Skill 2 Unlock (Laser)
			if not skill2_unlocked:
				cards.append({
					"id": "skill2",
					"type": CardType.SKILL_2,
					"label": "✨ New Skill: Laser",
					"desc": "Unlock Skill 2\n(Laser Beam)",
					"value": 0.0,
					"color": Color(0.8, 0.4, 1.0),
					"icon": icon_skill2,
				})
			else:
				cards.append(stat_pool[2])
			cards.append(stat_pool[0])
			cards.append(stat_pool[1])

		3:
			# Wave 3 Clear: 3 stat booster cards
			cards.append(stat_pool[0])
			cards.append(stat_pool[1])
			cards.append(stat_pool[2])

		4:
			# Wave 4 Clear: Skill 3 Unlock (Spell Burst)
			if not skill3_unlocked:
				cards.append({
					"id": "skill3",
					"type": CardType.SKILL_3,
					"label": "💥 New Skill: Spell",
					"desc": "Unlock Skill 3\n(Spell Burst)",
					"value": 0.0,
					"color": Color(1.0, 0.6, 0.2),
					"icon": icon_skill3,
				})
			else:
				cards.append({
					"id": "atk_dmg_big",
					"type": CardType.STAT_ATK_DMG,
					"label": "⚔ Power Surge",
					"desc": "+40% Attack Damage",
					"value": 0.4,
					"color": Color(1.0, 0.2, 0.2),
					"icon": icon_atk_dmg,
				})
			cards.append(stat_pool[0])
			cards.append(stat_pool[1])

		5, 6, _:
			# Wave 5+ Clear: High stat boosters
			cards.append({
				"id": "atk_dmg_big",
				"type": CardType.STAT_ATK_DMG,
				"label": "⚔ Power Surge",
				"desc": "+40% Attack Damage",
				"value": 0.4,
				"color": Color(1.0, 0.2, 0.2),
				"icon": icon_atk_dmg,
			})
			cards.append(stat_pool[0])
			cards.append(stat_pool[1])

	# Shuffle card order
	cards.shuffle()
	return cards

# ── Card button creation ─────────────────────────────────────────────────────
func _create_card_button(card: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(165, 230)
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.pivot_offset = Vector2(82.5, 115)

	# Frame styles
	var normal_style: StyleBox
	var hover_style: StyleBox

	if card_normal_texture != null:
		var s_norm = StyleBoxTexture.new()
		s_norm.texture = card_normal_texture
		normal_style = s_norm
	else:
		var s_flat = StyleBoxFlat.new()
		s_flat.bg_color = Color(0.1, 0.1, 0.18, 0.95)
		s_flat.border_color = card.get("color", Color.WHITE)
		s_flat.set_border_width_all(3)
		s_flat.corner_radius_top_left = 10
		s_flat.corner_radius_top_right = 10
		s_flat.corner_radius_bottom_left = 10
		s_flat.corner_radius_bottom_right = 10
		normal_style = s_flat

	if card_hover_texture != null:
		var s_hov = StyleBoxTexture.new()
		s_hov.texture = card_hover_texture
		hover_style = s_hov
	else:
		hover_style = normal_style

	panel.add_theme_stylebox_override("panel", normal_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	# Card color header stripe
	var stripe = ColorRect.new()
	stripe.color = card.get("color", Color.WHITE)
	stripe.color.a = 0.25
	stripe.custom_minimum_size = Vector2(0, 8)
	stripe.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(stripe)

	# Icon (texture or emoji fallback)
	var card_icon: Texture2D = card.get("icon")
	if card_icon != null:
		var tex_rect = TextureRect.new()
		tex_rect.texture = card_icon
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(52, 52)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(tex_rect)
	else:
		var icon_lbl = Label.new()
		icon_lbl.text = card.get("label", "?").substr(0, 2)
		icon_lbl.add_theme_font_size_override("font_size", 40)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(icon_lbl)

	# Title
	var title_lbl = Label.new()
	var raw = card.get("label", "Card")
	var parts = raw.split(" ", false, 1)
	title_lbl.text = parts[-1] if parts.size() > 1 else raw
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", card.get("color", Color.WHITE))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(title_lbl)

	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = card.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(desc_lbl)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(spacer)

	# Select button
	var btn = Button.new()
	btn.text = "SELECT"
	btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = card.get("color", Color.WHITE)
	btn_style.bg_color.a = 0.8
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_card_selected.bind(card))
	vbox.add_child(btn)

	# Entire card click trigger
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_selected(card)
	)

	# Hover glow & texture swap effect
	panel.mouse_entered.connect(func():
		if hover_style != normal_style:
			panel.add_theme_stylebox_override("panel", hover_style)
		var tw = create_tween()
		tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.12)
	)
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", normal_style)
		var tw = create_tween()
		tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.12)
	)

	return panel

# ── Card selection ────────────────────────────────────────────────────────────
func _on_card_selected(card: Dictionary) -> void:
	_apply_card_to_player(card)

	# Flash feedback
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = card.get("color", Color.WHITE)
	flash.color.a = 0.0
	add_child(flash)
	var tw = flash.create_tween()
	tw.tween_property(flash, "color:a", 0.4, 0.1)
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)

	# Close UI after short delay
	await get_tree().create_timer(0.4).timeout
	_close()

func _apply_card_to_player(card: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	reward_chosen.emit(card.get("id", ""), card.get("value", 0.0))

	if _player.has_method("apply_booster"):
		_player.call("apply_booster", card.get("id", ""), card.get("value", 0.0))
	else:
		# Direct fallback application
		match card.get("type"):
			CardType.STAT_ATK_DMG:
				if "attack_damage" in _player:
					_player.attack_damage += card.get("value", 0.0)
			CardType.STAT_ATK_SPD:
				if "attack_speed" in _player:
					_player.attack_speed += card.get("value", 0.0)
			CardType.STAT_HEALTH:
				if "mob_max_health" in _player:
					_player.mob_max_health += card.get("value", 0.0)
					_player.current_health = minf(_player.current_health + card.get("value", 0.0), _player.mob_max_health)
			CardType.SKILL_2:
				if "skill2_unlocked" in _player:
					_player.skill2_unlocked = true
			CardType.SKILL_3:
				if "skill3_unlocked" in _player:
					_player.skill3_unlocked = true

func _close() -> void:
	get_tree().paused = false
	if _on_chosen.is_valid():
		_on_chosen.call()
	queue_free()
