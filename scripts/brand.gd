extends RefCounted

const TITLE := "KITE BATTLE 3D"
const TAGLINE := "Patangbaaz"
const SUBTITLE := "Rooftop kite fight"

const GOLD := Color(1.0, 0.84, 0.38)
const SAFFRON := Color(1.0, 0.48, 0.14)
const MAGENTA := Color(0.96, 0.28, 0.52)
const CREAM := Color(1.0, 0.94, 0.82)
const INK := Color(0.16, 0.06, 0.04, 0.88)


static func display_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Sitka Display",
		"Palatino Linotype",
		"Georgia",
		"Cambria",
		"Times New Roman",
	])
	f.font_weight = 800
	return f


static func mark_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Segoe UI Black",
		"Arial Black",
		"Impact",
		"Bahnschrift",
		"Franklin Gothic Heavy",
		"Tahoma",
	])
	f.font_weight = 900
	f.font_stretch = 72
	return f


static func body_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Segoe UI",
		"Bahnschrift",
		"Calibri",
		"Arial",
	])
	f.font_weight = 500
	return f


static func letter_color(i: int) -> Color:
	var palette: Array[Color] = [SAFFRON, GOLD, MAGENTA, GOLD, SAFFRON, MAGENTA, GOLD, SAFFRON, MAGENTA]
	return palette[i % palette.size()]
