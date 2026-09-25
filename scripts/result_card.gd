extends Control

## The card at the end of a fight (and of the tutorial): a big headline, what
## you earned counting up, and big buttons for what next — Rematch, Home.

const Brand := preload("res://scripts/brand.gd")

signal action(id: String)

var _dim: ColorRect
var _card: PanelContainer
var _title: Label
var _sub: Label
var _coins: Label
var _xp: Label
var _rank: Label
var _buttons: HBoxContainer
var _coin_to: int = 0
var _xp_to: int = 0
var _count_t: float = -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.02, 0.05, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.09, 0.94)
	sb.border_color = Brand.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(30)
	sb.shadow_color = Color(1.0, 0.5, 0.12, 0.28)
	sb.shadow_size = 30
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 38
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(col)

	_title = _label(64, Brand.GOLD, Brand.kite_word_font())
	_title.add_theme_color_override("font_outline_color", Color(0.42, 0.10, 0.04))
	_title.add_theme_constant_override("outline_size", 12)
	col.add_child(_title)
	_sub = _label(22, Brand.CREAM, Brand.body_font())
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)

	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 26)
	col.add_child(rewards)
	_coins = _pill(rewards, Color(1.0, 0.72, 0.18))
	_xp = _pill(rewards, Color(0.56, 0.78, 1.0))
	_rank = _label(18, Color(1.0, 0.94, 0.82, 0.8), Brand.body_font())
	col.add_child(_rank)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 20)
	col.add_child(_buttons)


func _pill(parent: Control, accent: Color) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.16)
	sb.border_color = Color(accent, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var l := _label(30, accent.lerp(Color.WHITE, 0.25), Brand.display_font())
	p.add_child(l)
	return l


## title, a line under it, the payout dictionary from PlayerProfile, and the
## buttons as [id, text, primary] rows.
func open(title: String, sub: String, result: Dictionary, buttons: Array) -> void:
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_coin_to = int(result.get("coins", 0))
	_xp_to = int(result.get("xp", 0))
	_coins.text = "+0 coins"
	_xp.text = "+0 XP"
	var rank := str(result.get("rank", ""))
	_rank.text = ("Rank up!  " + rank) if bool(result.get("ranked_up", false)) else rank
	_rank.visible = rank != ""
	for b in _buttons.get_children():
		b.queue_free()
	for row in buttons:
		_buttons.add_child(_button(str(row[0]), str(row[1]), bool(row[2])))
	visible = true
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.86
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_t = 0.0


func close() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if _count_t < 0.0:
		return
	## Count the purse up over a second, after a short beat.
	_count_t += delta
	var u := clampf((_count_t - 0.35) / 1.0, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	_coins.text = "+%d coins" % int(round(float(_coin_to) * e))
	_xp.text = "+%d XP" % int(round(float(_xp_to) * e))
	if u >= 1.0:
		_count_t = -1.0
	_card.pivot_offset = _card.size * 0.5


func _button(id: String, text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(250, 84)
	b.add_theme_font_override("font", Brand.kite_word_font() if primary else Brand.display_font())
	b.add_theme_font_size_override("font_size", 34 if primary else 26)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(22)
	if primary:
		sb.bg_color = Color(1.0, 0.56, 0.16)
		sb.border_color = Color(1.0, 0.86, 0.46)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 8
		b.add_theme_color_override("font_color", Brand.CREAM)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color(0.42, 0.10, 0.04))
		b.add_theme_constant_override("outline_size", 8)
	else:
		sb.bg_color = Color(0.14, 0.10, 0.14, 0.9)
		sb.border_color = Color(1.0, 0.84, 0.38, 0.6)
		sb.set_border_width_all(2)
		sb.border_width_bottom = 6
		b.add_theme_color_override("font_color", Brand.CREAM)
	var hot := sb.duplicate() as StyleBoxFlat
	hot.bg_color = sb.bg_color.lightened(0.1)
	var down := sb.duplicate() as StyleBoxFlat
	down.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: action.emit(id))
	return b


func _label(px: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
