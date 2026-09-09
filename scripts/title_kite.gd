extends Node3D

## Decorative sail that banks across the opening sky.

const SAIL := preload("res://assets/Kite/colorful+kite+3d+model.glb")
const SPAN := 4.6

var _t: float = 0.0
var _anchor: Vector3 = Vector3.ZERO
var _prev: Vector3 = Vector3.ZERO


func setup(anchor: Vector3) -> void:
	_anchor = anchor + Vector3(4.0, 54.0, -22.0)
	var model := SAIL.instantiate() as Node3D
	if model == null:
		return
	add_child(model)
	_hide_slab(model)
	model.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var span := maxf(aabb.size.x, aabb.size.z)
	if span < 0.2:
		span = 1.0
	model.scale *= SPAN / span
	global_position = _anchor
	_prev = _anchor
	_face(Vector3(-1.0, 0.15, -0.4))


func _process(delta: float) -> void:
	_t += delta
	var x := sin(_t * 0.62) * 18.0
	var y := sin(_t * 1.05) * 5.5
	var z := cos(_t * 0.38) * 14.0 - _t * 1.8
	var next := _anchor + Vector3(x, y, z)
	var vel := next - _prev
	_prev = global_position
	global_position = next
	if vel.length_squared() > 0.0004:
		_face(vel)


func recede() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _face(dir: Vector3) -> void:
	var d := dir.normalized()
	if absf(d.dot(Vector3.UP)) > 0.92:
		d = Vector3(-1.0, 0.1, -0.3).normalized()
	look_at(global_position + d, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-18.0))
	var bank := clampf(-d.x * 0.55, -0.45, 0.45)
	rotate_object_local(Vector3.FORWARD, bank)


func _hide_slab(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.get_aabb()
		if aabb.size.y < 0.22 and maxf(aabb.size.x, aabb.size.z) > 1.6 and aabb.position.y < 0.35:
			mi.visible = false
	for c in n.get_children():
		_hide_slab(c)


func _world_aabb(n: Node) -> AABB:
	var acc := AABB()
	var first := true
	if n is VisualInstance3D:
		acc = (n as Node3D).global_transform * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var sub := _world_aabb(c)
		if sub.size.length_squared() < 0.0001:
			continue
		if first:
			acc = sub
			first = false
		else:
			acc = acc.merge(sub)
	return acc
