extends Control

## Tutorial coach: one instruction at a time at the foot of the screen — the
## key to press on a chip, the step's name, one line of what to do — and a row
## of progress dots. A step done flashes the chip green before the next slides
## in. "Skip tutorial" sits top right for players who already know.

const Brand := preload("res://scripts/brand.gd")

signal skip_pressed

const GREEN := Color(0.46, 0.86, 0.46)

var _card: PanelContainer
var _chip: PanelContainer
var _chip_sb: StyleBoxFlat
var _key: Label
var _step: Label
var _body: Label
var _dots: HBoxContainer
var _skip: Button
var _body_text: String = ""
var _hint_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	_card = PanelContainer.new()
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -420.0
	_card.offset_right = 420.0
	_card.offset_top = -196.0
	_card.offset_bottom = -52.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.08, 0.84)
	sb.border_color = Color(1.0, 0.84, 0.38, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 20
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_card.add_child(row)

	_chip = PanelContainer.new()
	_chip.custom_minimum_size = Vector2(124, 100)
	_chip_sb = StyleBoxFlat.new()
	_chip_sb.bg_color = Color(1.0, 0.84, 0.38)
	_chip_sb.set_corner_radius_all(18)
	_chip_sb.border_color = Color(0.62, 0.36, 0.06)
	_chip_sb.border_width_bottom = 7
	_chip.add_theme_stylebox_override("panel", _chip_sb)
	row.add_child(_chip)
	_key = Label.new()
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key.add_theme_font_override("font", Brand.mark_font())
	_key.add_theme_font_size_override("font_size", 36)
	_key.add_theme_color_override("font_color", Color(0.30, 0.10, 0.04))
	_chip.add_child(_key)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_step = Label.new()
	_step.add_theme_font_override("font", Brand.display_font())
	_step.add_theme_font_size_override("font_size", 26)
	_step.add_theme_color_override("font_color", Brand.GOLD)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_step)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_dots)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", Brand.body_font())
	_body.add_theme_font_size_override("font_size", 21)
	_body.add_theme_color_override("font_color", Brand.CREAM)
	col.add_child(_body)

	_skip = Button.new()
	_skip.text = "Skip tutorial  ›"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -250.0
	_skip.offset_right = -40.0
	_skip.offset_top = 84.0
	_skip.offset_bottom = 136.0
	_skip.add_theme_font_override("font", Brand.body_font())
	_skip.add_theme_font_size_override("font_size", 19)
	_skip.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 0.85))
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.07, 0.05, 0.08, 0.55)
	ssb.border_color = Color(1.0, 0.94, 0.82, 0.3)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(26)
	var shot := ssb.duplicate() as StyleBoxFlat
	shot.bg_color = Color(0.16, 0.12, 0.10, 0.8)
	_skip.add_theme_stylebox_override("normal", ssb)
	_skip.add_theme_stylebox_override("hover", shot)
	_skip.add_theme_stylebox_override("pressed", shot)
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	add_child(_skip)


func show_step(i: int, count: int, key: String, title: String, body: String) -> void:
	visible = true
	_key.text = key
	_key.add_theme_font_size_override("font_size", 36 if key.length() <= 3 else 26)
	_chip_sb.bg_color = Color(1.0, 0.84, 0.38)
	_step.text = title
	_body_text = body
	_body.text = body
	_body.add_theme_color_override("font_color", Brand.CREAM)
	_hint_t = 0.0
	for d in _dots.get_children():
		d.queue_free()
	for k in count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26 if k == i else 12, 12)
		var dsb := StyleBoxFlat.new()
		dsb.set_corner_radius_all(6)
		dsb.bg_color = Brand.GOLD if k <= i else Color(1, 1, 1, 0.22)
		dot.add_theme_stylebox_override("panel", dsb)
		_dots.add_child(dot)
	## Slide the card up into place.
	_card.modulate.a = 0.0
	_card.position.y += 30.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_property(_card, "position:y", _card.position.y - 30.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A nudge in the moment ("Now! Hold Q!"), shown over the step's line.
func hint(text: String, hold: float = 1.6) -> void:
	_body.text = text
	_body.add_theme_color_override("font_color", Brand.GOLD)
	_hint_t = hold


## The step is done: the key chip goes green with a tick.
func complete() -> void:
	_chip_sb.bg_color = GREEN
	_key.text = "✓"
	_key.add_theme_font_size_override("font_size", 44)


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			_body.text = _body_text
			_body.add_theme_color_override("font_color", Brand.CREAM)
	## The key chip bobs gently so the eye finds it.
	_chip.pivot_offset = _chip.size * 0.5
	_chip.scale = Vector2.ONE * (1.0 + 0.035 * sin(_t * 4.0))
