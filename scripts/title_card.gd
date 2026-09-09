extends Control

## Opening sting: PATANGBAZ kites in from the left and floats out to the right.

const Brand := preload("res://scripts/brand.gd")
const CROSS_SEC := 6.2

signal receded

var _cluster: VBoxContainer
var _letters: Array[Label] = []
var _tag: Label
var _played: bool = false
var _out: bool = false
var _flying: bool = false
var _fly_t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	call_deferred("play")


func _build() -> void:
	_cluster = VBoxContainer.new()
	_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	_cluster.add_theme_constant_override("separation", 2)
	add_child(_cluster)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_cluster.add_child(row)

	var display := Brand.display_font()
	var i := 0
	for ch in Brand.TITLE:
		var l := Label.new()
		l.text = ch
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", display)
		l.add_theme_font_size_override("font_size", 102)
		l.add_theme_color_override("font_color", Brand.letter_color(i))
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02, 1.0))
		l.add_theme_constant_override("outline_size", 16)
		l.add_theme_color_override("font_shadow_color", Color(0.95, 0.22, 0.48, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 8)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		_letters.append(l)
		i += 1

	_tag = Label.new()
	_tag.text = Brand.TAGLINE
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_override("font", Brand.body_font())
	_tag.add_theme_font_size_override("font_size", 30)
	_tag.add_theme_color_override("font_color", Brand.GOLD)
	_tag.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02, 1.0))
	_tag.add_theme_constant_override("outline_size", 10)
	_cluster.add_child(_tag)


func play() -> void:
	if _played:
		return
	_played = true
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	_cluster.reset_size()
	_cluster.pivot_offset = _cluster.size * 0.5
	var vp := get_viewport_rect().size
	_cluster.position = Vector2(-_cluster.size.x - 24.0, vp.y * 0.30)
	_fly_t = 0.0
	_flying = true


func _process(delta: float) -> void:
	if not _flying or _cluster == null or _out:
		return
	_fly_t += delta
	var vp := get_viewport_rect().size
	var start_x := -_cluster.size.x - 24.0
	var end_x := vp.x + 32.0
	var u := clampf(_fly_t / CROSS_SEC, 0.0, 1.0)
	## Ease in, coast, ease out — like a kite catching wind.
	var e := u * u * (3.0 - 2.0 * u)
	var x := lerpf(start_x, end_x, e)
	var base_y := vp.y * 0.30
	var bob := sin(_fly_t * 2.05) * 38.0 + sin(_fly_t * 3.3 + 0.6) * 16.0
	_cluster.position = Vector2(x, base_y + bob)
	_cluster.rotation = sin(_fly_t * 2.05) * 0.09
	if u >= 1.0:
		recede()


func recede() -> void:
	if _out:
		return
	_out = true
	_flying = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		visible = false
		receded.emit()
	)
