class_name KiteSkins
extends RefCounted

## Player kite skins. Rival always gets a different sail so the two read apart.
## Two kinds: three premium sculpted sails (GLB), and the patangs — flat paper
## kites painted by the shared pattern library (shaders/patang.gdshaderinc).
## Patangs cost no textures and one draw call, so adding one is just a row below.

const SAFFRON := "saffron"
const FESTIVAL := "festival"
const ROYAL := "royal"

const SCENE_SAFFRON := preload("res://assets/Kite/colorful+kite+3d+model.glb")
const SCENE_FESTIVAL := preload("res://assets/Kite/colorful+diamond+kite+3d+model.glb")
const SCENE_ROYAL := preload("res://assets/Kite/purple+diamond+kite+3d+model.glb")
const PREVIEW_SHADER := preload("res://shaders/patang_preview.gdshader")
const Preview3dSc := preload("res://scripts/kite_preview_3d.gd")

## Pattern ids — must match the #defines in patang.gdshaderinc.
const PAT_ADHA := 1
const PAT_CHAAND := 2
const PAT_AANKH := 3
const PAT_PATTA := 4
const PAT_CHAAND_TARA := 5
const PAT_MAANG := 6
const PAT_SHATRANJ := 7
const PAT_DHAARI := 8
const PAT_CHAKRI := 9
const PAT_TUKKAL := 10
const PAT_KINARI := 11

## Dyed kite-paper colours.
const RANI := Color(0.90, 0.13, 0.45)
const HALDI := Color(0.98, 0.80, 0.12)
const TOTA := Color(0.30, 0.72, 0.20)
const NARANGI := Color(0.97, 0.48, 0.10)
const ASMANI := Color(0.25, 0.62, 0.92)
const LAAL := Color(0.84, 0.10, 0.10)
const JAMUNI := Color(0.44, 0.18, 0.72)
const KAALA := Color(0.08, 0.07, 0.08)
const SAFED := Color(0.96, 0.94, 0.88)
const NEELA := Color(0.10, 0.18, 0.52)
const SONA := Color(0.98, 0.76, 0.25)
const MAROON := Color(0.40, 0.06, 0.11)
const RAAT := Color(0.07, 0.09, 0.26)
const GEHRA_HARA := Color(0.07, 0.30, 0.10)

## id -> title, pattern, [paper, ink, accent, kinari], price. Shop order = listing order.
const PATANGS := {
	"adha": {"title": "Adha", "pat": PAT_ADHA, "cols": [RANI, HALDI, MAROON, MAROON], "price": 0},
	"maang": {"title": "Maang", "pat": PAT_MAANG, "cols": [ASMANI, SAFED, LAAL, NEELA], "price": 0},
	"chaand": {"title": "Chaand", "pat": PAT_CHAAND, "cols": [NEELA, SAFED, SONA, SONA], "price": 120},
	"patta": {"title": "Patta", "pat": PAT_PATTA, "cols": [HALDI, LAAL, TOTA, MAROON], "price": 120},
	"kinari": {"title": "Kinari", "pat": PAT_KINARI, "cols": [SAFED, LAAL, HALDI, MAROON], "price": 150},
	"hara": {"title": "Hara Adha", "pat": PAT_ADHA, "cols": [TOTA, HALDI, GEHRA_HARA, GEHRA_HARA], "price": 200},
	## Kinari = paper colour: no painted border.
	"aankh": {"title": "Aankh", "pat": PAT_AANKH, "cols": [NARANGI, KAALA, SAFED, NARANGI], "price": 240},
	"tukkal": {"title": "Tukkal", "pat": PAT_TUKKAL, "cols": [RANI, TOTA, HALDI, MAROON], "price": 240},
	"dhaari": {"title": "Dhaari", "pat": PAT_DHAARI, "cols": [SAFED, LAAL, SONA, MAROON], "price": 300},
	"shatranj": {"title": "Shatranj", "pat": PAT_SHATRANJ, "cols": [SAFED, KAALA, SONA, KAALA], "price": 400},
	"chakri": {"title": "Chakri", "pat": PAT_CHAKRI, "cols": [HALDI, LAAL, HALDI, MAROON], "price": 400},
	"jamuni": {"title": "Jamuni", "pat": PAT_TUKKAL, "cols": [JAMUNI, SONA, RANI, RAAT], "price": 450},
	"chaand_tara": {"title": "Chaand Tara", "pat": PAT_CHAAND_TARA, "cols": [RAAT, SONA, HALDI, SONA], "price": 600},
}


## Every patang is framed with an arched kaman (bow) that points at the nose,
## so the front of the kite reads at a glance.
static func has_kaman_arch(id: String) -> bool:
	return is_patang(id)


static func ids() -> PackedStringArray:
	var out := PackedStringArray([SAFFRON])
	for id in PATANGS:
		out.append(id)
	out.append(FESTIVAL)
	out.append(ROYAL)
	return out


static func clamp_id(id: String) -> String:
	if id == FESTIVAL or id == ROYAL or PATANGS.has(id):
		return id
	return SAFFRON


static func is_patang(id: String) -> bool:
	return PATANGS.has(id)


static func pattern_for(id: String) -> int:
	if PATANGS.has(id):
		return int(PATANGS[id]["pat"])
	return 0


## [paper, ink, accent, kinari]
static func palette_for(id: String) -> Array[Color]:
	var out: Array[Color] = []
	if PATANGS.has(id):
		for c in PATANGS[id]["cols"]:
			out.append(c)
	return out


static func title_for(id: String) -> String:
	id = clamp_id(id)
	if PATANGS.has(id):
		return str(PATANGS[id]["title"])
	match id:
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
		SAFFRON:
			return SCENE_SAFFRON
		_:
			return null


static func swatches_for(id: String) -> Array[Color]:
	id = clamp_id(id)
	if PATANGS.has(id):
		var p := palette_for(id)
		## [main, paper, accent] — the tail ribbons read these.
		return [p[1], p[0], p[2]]
	match id:
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


## The rival flies the green half-and-half from the other roof — a fixed
## identity, so you always know which string is theirs.
static func rival_id(player_id: String) -> String:
	if clamp_id(player_id) == "hara":
		return "adha"
	return "hara"


static func price_for(id: String) -> int:
	id = clamp_id(id)
	if PATANGS.has(id):
		return int(PATANGS[id]["price"])
	match id:
		FESTIVAL:
			return 200
		ROYAL:
			return 350
		_:
			return 0


## Flat painted preview of a patang, same code as the 3D sail.
static func make_preview(id: String, px_w: float) -> Control:
	var rect := ColorRect.new()
	## The sail footprint is 1.16 m wide by 1.40 m tall, plus the shader's margin.
	rect.custom_minimum_size = Vector2(px_w, px_w * 1.40 / 1.16)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PREVIEW_SHADER
	var p := palette_for(id)
	mat.set_shader_parameter("pattern", pattern_for(id))
	mat.set_shader_parameter("col0", p[0])
	mat.set_shader_parameter("col1", p[1])
	mat.set_shader_parameter("col2", p[2])
	mat.set_shader_parameter("col3", p[3])
	mat.set_shader_parameter("kaman_arch", 1.0 if has_kaman_arch(id) else 0.0)
	rect.material = mat
	return rect


static func make_card(id: String, selected: bool, on_pick: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 170)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: on_pick.call(id))
	var sw := swatches_for(id)
	## Border in the kite's brightest colour — a black-inked kite (Aankh,
	## Shatranj) would otherwise get an invisible edge.
	var accent: Color = sw[0]
	for c in sw:
		if c.get_luminance() > accent.get_luminance():
			accent = c
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
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	if is_patang(id):
		row.add_child(make_preview(id, 76.0))
	else:
		## Sculpted sails: the real model, swaying in a small 3D window.
		var pv := Preview3dSc.new()
		pv.custom_minimum_size = Vector2(96, 96)
		pv.setup(scene_for(id))
		row.add_child(pv)
	var name := Label.new()
	name.text = title_for(id)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 17)
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
