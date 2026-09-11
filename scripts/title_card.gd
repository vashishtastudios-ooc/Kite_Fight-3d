extends Control

## Opening sting: the wordmark kites across the dusk, then hands off to the terrace.

const Brand := preload("res://scripts/brand.gd")
const TitleMarkSc := preload("res://scripts/title_mark.gd")
const CROSS_SEC := 6.2

signal receded

var _cluster: Control
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
	_cluster = TitleMarkSc.new()
	_cluster.mark_scale = 1.15
	_cluster.show_tag = true
	_cluster.lively = true
	add_child(_cluster)


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
	_cluster.position = Vector2(-_cluster.size.x - 24.0, vp.y * 0.28)
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
	var e := u * u * (3.0 - 2.0 * u)
	var x := lerpf(start_x, end_x, e)
	var base_y := vp.y * 0.28
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
