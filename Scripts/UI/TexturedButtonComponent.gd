class_name TexturedButtonComponent
extends TextureButton

@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var pressed_texture: Texture2D

@export_group("Label")
@export var button_text: String = ""
@export var font_size: int = 20
@export var font_color: Color = Color.WHITE

@export_group("Navigation")
@export_file("*.tscn") var target_scene: String = ""

func _ready() -> void:
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ignore_texture_size = true

	if normal_texture != null:
		texture_normal = normal_texture

	if hover_texture != null:
		texture_hover = hover_texture

	if pressed_texture != null:
		texture_pressed = pressed_texture

	if not button_text.is_empty():
		var lbl = Label.new()
		lbl.text = button_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_color_override("font_color", font_color)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(lbl)

	if not target_scene.is_empty():
		pressed.connect(func(): get_tree().change_scene_to_file(target_scene))
