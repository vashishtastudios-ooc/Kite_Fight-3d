class_name KiteSkins
extends RefCounted

## Player kite skins. Rival always gets a different sail so the two read apart.

const SAFFRON := "saffron"
const FESTIVAL := "festival"
const ROYAL := "royal"

const SCENE_SAFFRON := preload("res://assets/Kite/colorful+kite+3d+model.glb")
const SCENE_FESTIVAL := preload("res://assets/Kite/colorful+diamond+kite+3d+model.glb")
const SCENE_ROYAL := preload("res://assets/Kite/purple+diamond+kite+3d+model.glb")


static func ids() -> PackedStringArray:
	return PackedStringArray([SAFFRON, FESTIVAL, ROYAL])


static func clamp_id(id: String) -> String:
	if id == FESTIVAL or id == ROYAL:
		return id
	return SAFFRON


static func title_for(id: String) -> String:
	match clamp_id(id):
		FESTIVAL:
			return "Festival"
		ROYAL:
			return "Royal"
		_:
			return "Saffron"


static func scene_for(id: String) -> PackedScene:
	match clamp_id(id):
		FESTIVAL:
			return SCENE_FESTIVAL
		ROYAL:
			return SCENE_ROYAL
		_:
			return SCENE_SAFFRON


static func swatches_for(id: String) -> Array[Color]:
	match clamp_id(id):
		FESTIVAL:
			return [
				Color(0.72, 0.12, 0.52),
				Color(0.45, 0.16, 0.72),
				Color(0.98, 0.78, 0.18),
			]
		ROYAL:
			return [
				Color(0.38, 0.16, 0.68),
				Color(0.72, 0.42, 0.95),
				Color(0.98, 0.82, 0.22),
			]
		_:
			return [
				Color(0.90, 0.16, 0.12),
				Color(0.96, 0.55, 0.16),
				Color(0.95, 0.90, 0.55),
			]


static func rival_id(player_id: String) -> String:
	match clamp_id(player_id):
		ROYAL:
			return SAFFRON
		SAFFRON:
			return ROYAL
		_:
			return SAFFRON


static func price_for(id: String) -> int:
	match clamp_id(id):
		FESTIVAL:
			return 200
		ROYAL:
			return 350
		_:
			return 0


static func make_card(id: String, selected: bool, on_pick: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 148)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: on_pick.call(id))
	var sw := swatches_for(id)
	var accent: Color = sw[0]
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.08, 0.92)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.16, 0.12, 0.10, 0.96)
	hot.border_color = Color(1.0, 0.84, 0.38, 1.0)
	hot.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", hot if selected else normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("focus", hot)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for c in sw:
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(28, 52)
		chip.color = c
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	var name := Label.new()
	name.text = title_for(id)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	return b


static func make_shop_card(id: String, selected: bool, owned: bool, on_pick: Callable) -> Button:
	var b := make_card(id, selected and owned, on_pick)
	if owned:
		return b
	var price := Label.new()
	price.text = "%d coins" % price_for(id)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", 14)
	price.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	b.get_child(0).add_child(price)
	b.modulate = Color(1, 1, 1, 0.88)
	return b
