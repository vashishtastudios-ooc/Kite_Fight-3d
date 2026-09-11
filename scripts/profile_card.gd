class_name ProfileCard
extends PanelContainer

## VS card: photo, name, rank, games won. Full profile stays in Mongo / pause.

const Brand := preload("res://scripts/brand.gd")

var _name: Label
var _rank: Label
var _won: Label
var _letter: Label
var _face: Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(232, 236)
	_build()


func fill(data: Dictionary) -> void:
	if _name == null:
		_build()
	var you := bool(data.get("is_you", true))
	_apply_style(you)
	_name.text = str(data.get("name", "You"))
	_rank.text = str(data.get("rank", "Rookie"))
	_won.text = "%d won" % int(data.get("won", 0))
	_letter.text = str(data.get("letter", "Y"))


func _build() -> void:
	if _name:
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)

	_face = Panel.new()
	_face.custom_minimum_size = Vector2(76, 76)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_sb := StyleBoxFlat.new()
	face_sb.bg_color = Color(0.28, 0.16, 0.12)
	face_sb.set_corner_radius_all(38)
	face_sb.border_color = Brand.GOLD
	face_sb.set_border_width_all(3)
	_face.add_theme_stylebox_override("panel", face_sb)
	var face_wrap := CenterContainer.new()
	face_wrap.add_child(_face)
	col.add_child(face_wrap)
	_letter = Label.new()
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_letter.add_theme_font_override("font", Brand.display_font())
	_letter.add_theme_font_size_override("font_size", 34)
	_letter.add_theme_color_override("font_color", Brand.CREAM)
	_face.add_child(_letter)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", Brand.display_font())
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", Brand.CREAM)
	col.add_child(_name)

	_rank = Label.new()
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.add_theme_font_override("font", Brand.body_font())
	_rank.add_theme_font_size_override("font_size", 16)
	_rank.add_theme_color_override("font_color", Brand.GOLD)
	col.add_child(_rank)

	_won = Label.new()
	_won.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_won.add_theme_font_size_override("font_size", 15)
	_won.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 0.85))
	col.add_child(_won)
	_apply_style(true)


func _apply_style(you: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.62)
	sb.border_color = Brand.GOLD if you else Brand.MAGENTA
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	add_theme_stylebox_override("panel", sb)
	if _face:
		var face_sb := _face.get_theme_stylebox("panel") as StyleBoxFlat
		if face_sb:
			face_sb.border_color = Brand.GOLD if you else Brand.MAGENTA
