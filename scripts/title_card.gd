extends Control

## Opening sting: the Patang mark rises softly into the upper sky as the camera
## comes down, holds while the flyover plays, then fades as it lands.

const PatangMarkSc := preload("res://scripts/patang_mark.gd")
const HOLD_SEC := 4.6

signal receded

var _cluster: Control
var _played: bool = false
var _out: bool = false
var _t: float = 0.0
var _live: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	call_deferred("play")


func _build() -> void:
	_cluster = PatangMarkSc.new()
	_cluster.variant = 1
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
	if _out:
		return
	var vp := get_viewport_rect().size
	var home := Vector2((vp.x - _cluster.size.x) * 0.5, vp.y * 0.16)
	_cluster.position = home + Vector2(0.0, 26.0)
	_cluster.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_cluster, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cluster, "position", home, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_t = 0.0
	_live = true


func _process(delta: float) -> void:
	if not _live or _out:
		return
	_t += delta
	if _t >= HOLD_SEC:
		recede()


func replay() -> void:
	_played = false
	_out = false
	_live = false
	visible = true
	modulate.a = 1.0
	play()


func recede() -> void:
	if _out:
		return
	_out = true
	_live = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		visible = false
		receded.emit()
	)
