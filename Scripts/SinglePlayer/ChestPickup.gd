class_name ChestPickup
extends Area2D

# ── Signals ────────────────────────────────────────────────────────────────────
signal chest_opened

# ── Config ─────────────────────────────────────────────────────────────────────
@export var completed_wave: int = 1
@export var interact_radius: float = 90.0
## Texture shown when the chest is closed
@export var chest_closed_texture: Texture2D
## Texture shown when the chest is open
@export var chest_open_texture: Texture2D

# ── State ──────────────────────────────────────────────────────────────────────
var _player: Node = null
var _is_opened: bool = false
var _player_nearby: bool = false

# ── Node refs (built procedurally) ────────────────────────────────────────────
var _sprite: AnimatedSprite2D
var _prompt_label: Label
var _collision: CollisionShape2D
var _glow: PointLight2D

func _ready() -> void:
	# Keep scene z_index if non-zero, otherwise default to 1 (renders above background)
	if z_index == 0:
		z_index = 1
	collision_layer = 0
	collision_mask = 0xFFFFFFFF  # Detect all layers (players, hurtboxes, bodies)
	monitoring = true
	monitorable = false

	_build_chest()
	_build_prompt()

	# Gravity — settle on ground
	set_meta("_chest_vel_y", 0.0)

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Bob tween
	_animate_idle_bob()

func _build_chest() -> void:
	# Collision shape for proximity detection
	if has_node("ProximityCollision"):
		_collision = get_node("ProximityCollision") as CollisionShape2D
		if _collision != null and _collision.shape is CircleShape2D:
			(_collision.shape as CircleShape2D).radius = interact_radius
	else:
		_collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = interact_radius
		_collision.shape = shape
		add_child(_collision)

	# Sprite
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ChestSprite"
	_build_sprite_frames()

	# Determine texture scale & center-bottom offset
	var frame_tex = _sprite.sprite_frames.get_frame_texture("closed", 0)
	var tex_h: float = 48.0
	if frame_tex != null:
		tex_h = frame_tex.get_height()

	# If custom texture assigned, ensure world height is at least 64px
	if chest_closed_texture != null or chest_open_texture != null:
		var current_world_h = tex_h * scale.y
		if current_world_h < 64.0 and scale.y > 0.0:
			var target_sprite_scale = 64.0 / (tex_h * scale.y)
			_sprite.scale = Vector2(target_sprite_scale, target_sprite_scale)
		else:
			_sprite.scale = Vector2(1.0, 1.0)
	else:
		_sprite.scale = Vector2(3.0, 3.0)

	# Ensure interaction collision shape has 90px radius in WORLD space
	if _collision != null and _collision.shape is CircleShape2D:
		var s_factor = maxf(scale.x, 0.001)
		(_collision.shape as CircleShape2D).radius = interact_radius / s_factor

	# Center-bottom origin: offset y by -half_height so origin (0,0) is at bottom-center of chest
	_sprite.centered = true
	_sprite.offset = Vector2(0, -tex_h * 0.5)
	_sprite.position = Vector2(0, 0)
	add_child(_sprite)

	# Shadow centered at bottom (0,0)
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.custom_minimum_size = Vector2(60, 8)
	shadow.position = Vector2(-30, -4)
	add_child(shadow)

	# Glow light
	if ClassDB.class_exists("PointLight2D"):
		_glow = PointLight2D.new()
		_glow.color = Color(1.0, 0.8, 0.2)
		_glow.energy = 0.6
		_glow.texture_scale = 1.5
		_glow.position = Vector2(0, -tex_h * 0.5)
		add_child(_glow)

func _build_sprite_frames() -> void:
	var frames = SpriteFrames.new()
	frames.add_animation("closed")
	frames.add_animation("opening")
	frames.add_animation("open")
	frames.set_animation_loop("closed", true)
	frames.set_animation_loop("opening", false)
	frames.set_animation_loop("open", true)
	frames.set_animation_speed("closed", 2.0)
	frames.set_animation_speed("opening", 5.0)
	frames.set_animation_speed("open", 2.0)

	var closed_tex: Texture2D = chest_closed_texture
	var open_tex: Texture2D = chest_open_texture

	# Auto-fallback: try default spritesheet if no textures assigned
	if closed_tex == null or open_tex == null:
		var sheet: Texture2D = null
		if ResourceLoader.exists("res://Assets/Sprites/UI/chest_spritesheet.png"):
			sheet = load("res://Assets/Sprites/UI/chest_spritesheet.png") as Texture2D
		if sheet != null:
			var half_w: float = sheet.get_width() / 2.0
			var half_h: float = sheet.get_height() / 2.0
			var a_closed = AtlasTexture.new()
			a_closed.atlas = sheet
			a_closed.region = Rect2(0, 0, half_w, half_h)
			var a_open = AtlasTexture.new()
			a_open.atlas = sheet
			a_open.region = Rect2(half_w, 0, half_w, half_h)
			if closed_tex == null:
				closed_tex = a_closed
			if open_tex == null:
				open_tex = a_open

	# Colour placeholders if still null
	if closed_tex == null:
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.3, 0.1))
		closed_tex = ImageTexture.create_from_image(img)
	if open_tex == null:
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.8, 0.1))
		open_tex = ImageTexture.create_from_image(img)

	frames.add_frame("closed", closed_tex)
	frames.add_frame("opening", closed_tex)
	frames.add_frame("opening", open_tex)
	frames.add_frame("open", open_tex)

	_sprite.sprite_frames = frames
	_sprite.play("closed")
	_sprite.animation_finished.connect(_on_sprite_animation_done)

func _build_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Open Chest"
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Counteract root scale so label is normal size in world space
	var s_x = maxf(scale.x, 0.001)
	var s_y = maxf(scale.y, 0.001)
	if scale.x != 1.0 or scale.y != 1.0:
		_prompt_label.scale = Vector2(1.0 / s_x, 1.0 / s_y)
		_prompt_label.position = Vector2(-80.0 / s_x, -100.0 / s_y)
	else:
		_prompt_label.position = Vector2(-80, -80)

	_prompt_label.custom_minimum_size = Vector2(160, 28)
	_prompt_label.visible = false
	add_child(_prompt_label)

# ── Physics: simple drop-in animation ─────────────────────────────────────────
func _physics_process(delta: float) -> void:
	var gy = _get_ground_y()
	if global_position.y < gy:
		var vel = get_meta("_chest_vel_y", 0.0) as float
		vel += 980.0 * delta
		global_position.y += vel * delta
		set_meta("_chest_vel_y", vel)
		if global_position.y >= gy:
			global_position.y = gy
			set_meta("_chest_vel_y", 0.0)
			_land_bounce()
	_handle_interact_input()

func _get_ground_y() -> float:
	# Snap to nearest floor via raycasting, fallback to spawn y offset 0
	return get_meta("_ground_y", global_position.y) if has_meta("_ground_y") else global_position.y

func _land_bounce() -> void:
	if _sprite == null:
		return
	var base = _sprite.scale
	var tw = create_tween()
	tw.tween_property(_sprite, "scale", Vector2(base.x * 1.15, base.y * 0.85), 0.08)
	tw.tween_property(_sprite, "scale", base, 0.12)

func _animate_idle_bob() -> void:
	if _sprite == null:
		return
	var base_y = _sprite.position.y
	var tw = create_tween().set_loops()
	tw.tween_property(_sprite, "position:y", base_y - 6.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sprite, "position:y", base_y, 0.7).set_trans(Tween.TRANS_SINE)

# ── Interaction ────────────────────────────────────────────────────────────────
func _handle_interact_input() -> void:
	if _is_opened:
		return

	# Auto-check player distance as fallback if area signal missed
	if not _player_nearby:
		var p = _find_player()
		if p != null and is_instance_valid(p) and (p is Node2D):
			var dist = global_position.distance_to((p as Node2D).global_position)
			if dist < 120.0:
				_player = p
				_player_nearby = true
				_prompt_label.visible = true

	if not _player_nearby:
		return

	# Check 'interact' action, 'ui_accept' (Space/Enter), or physical E key
	if Input.is_action_just_pressed("interact") \
	or Input.is_action_just_pressed("ui_accept") \
	or Input.is_key_pressed(KEY_E):
		_open_chest()

func _open_chest() -> void:
	if _is_opened:
		return
	_is_opened = true
	_prompt_label.visible = false

	# Particle burst tween
	var tw = create_tween()
	tw.tween_property(_sprite, "scale", Vector2(3.6, 3.6), 0.1)
	tw.tween_property(_sprite, "scale", Vector2(3.0, 3.0), 0.1)
	tw.tween_callback(func(): _sprite.play("opening"))

	if _glow != null:
		var ltw = create_tween()
		ltw.tween_property(_glow, "energy", 2.5, 0.3)

func _on_sprite_animation_done() -> void:
	if _sprite.animation == "opening":
		_sprite.play("open")
		# Delay a moment then show the card UI
		get_tree().create_timer(0.3).timeout.connect(func():
			chest_opened.emit()
			_show_reward_ui()
		, CONNECT_ONE_SHOT)

func _show_reward_ui() -> void:
	var ui_scene = load("res://Scenes/UI/ChestRewardUI.tscn") as PackedScene
	var chest_ui: CanvasLayer = null
	if ui_scene != null:
		chest_ui = ui_scene.instantiate() as CanvasLayer
	else:
		var chest_script = load("res://Scripts/UI/ChestRewardUI.gd")
		if chest_script != null:
			chest_ui = chest_script.new() as CanvasLayer

	if chest_ui == null:
		return

	var player = _player if _player != null else _find_player()
	get_tree().root.add_child(chest_ui)
	if player != null:
		player.set_meta("_current_wave_for_reward", completed_wave)
	chest_ui.show_reward(completed_wave, player, func():
		queue_free()
	)

func _find_player() -> Node:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		return players[0]
	return null

# ── Proximity detection via Area2D & Body overlap ─────────────────────────────
func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent != null and (parent.is_in_group("players") or parent is CharacterBody2D):
		_set_player_nearby(parent, true)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent != null and (parent.is_in_group("players") or parent is CharacterBody2D):
		_set_player_nearby(parent, false)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") or body is CharacterBody2D:
		_set_player_nearby(body, true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players") or body is CharacterBody2D:
		_set_player_nearby(body, false)

func _set_player_nearby(player_node: Node, nearby: bool) -> void:
	if nearby:
		_player = player_node
		_player_nearby = true
		_prompt_label.visible = not _is_opened
		if _glow != null:
			var tw = create_tween()
			tw.tween_property(_glow, "energy", 1.2, 0.2)
	else:
		_player_nearby = false
		_prompt_label.visible = false
		if _glow != null:
			var tw = create_tween()
			tw.tween_property(_glow, "energy", 0.6, 0.3)

# ── Public setup ───────────────────────────────────────────────────────────────
func setup(wave_num: int, ground_y: float) -> void:
	completed_wave = wave_num
	set_meta("_ground_y", ground_y)
