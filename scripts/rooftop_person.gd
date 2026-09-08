extends Node3D

## Visible rooftop flyer. Not the first-person camera body.

const PACK_PATH := "res://assets/people/green_boy.glb"
const HEIGHT := 1.62

var _anim: AnimationPlayer
var _idle: StringName = &""
var _emotes: Array[StringName] = []
var _emote_i: int = 0
var _until: float = 5.0


func setup(feet: Vector3, look_at_point: Vector3, hold: PackedScene = null) -> void:
	var pack := load(PACK_PATH)
	if pack == null:
		push_warning("Missing rooftop person: %s" % PACK_PATH)
		return
	var model := pack.instantiate() as Node3D
	if model == null:
		return
	add_child(model)
	_hide_slab(model)
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var h := aabb.size.y
	if h < 0.2:
		h = HEIGHT
	model.scale *= HEIGHT / h
	model.force_update_transform()
	aabb = _world_aabb(model)
	global_position = Vector3(feet.x, feet.y - aabb.position.y, feet.z)
	var aim := look_at_point
	aim.y = global_position.y
	if global_position.distance_to(aim) > 0.25:
		look_at(aim, Vector3.UP)
		rotate_y(PI)
	force_update_transform()
	if hold != null:
		_attach_charkhi(hold)
	_anim = _find_anim(model)
	_bind_clips()
	_play_idle()
	if _anim:
		print("Rooftop person clips: ", _anim.get_animation_list())


func _attach_charkhi(scene: PackedScene) -> void:
	## A firki (thread spool) held across the chest, facing the fly window.
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	var firki := Node3D.new()
	firki.name = "HeldCharkhi"
	add_child(firki)
	## +Z faces the aim after look_at + rotate_y(PI). Hold the reel out to the
	## side at chest height so it reads even when the flyer is seen from behind.
	var fwd := global_transform.basis.z.normalized()
	var side := global_transform.basis.x.normalized()
	firki.global_position = global_position + Vector3.UP * (HEIGHT * 0.46) + fwd * 0.08 + side * 0.22
	firki.global_transform.basis = global_transform.basis
	firki.add_child(model)
	_hide_slab(model)
	## Lay the spool horizontal so the reel axis crosses the body.
	model.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var disc := maxf(aabb.size.x, aabb.size.z)
	if disc < 0.02:
		disc = maxf(aabb.size.y * 0.22, 0.08)
	var s := 0.24 / disc
	model.scale = Vector3(s, s, s)
	model.force_update_transform()
	aabb = _world_aabb(model)
	model.global_position += firki.global_position - aabb.get_center()
	_no_shadow(model)


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


func _process(delta: float) -> void:
	if _anim == null or _emotes.is_empty():
		return
	_until -= delta
	if _until > 0.0:
		return
	if _anim.is_playing() and String(_anim.current_animation).to_lower().contains("idle"):
		_anim.play(_emotes[_emote_i % _emotes.size()], 0.2)
		_emote_i += 1
		_until = 3.2
	else:
		_play_idle()
		_until = 7.0 + float(_emote_i % 3)


func _play_idle() -> void:
	if _anim == null or String(_idle) == "":
		return
	_loop(_idle)
	_anim.play(_idle, 0.25)


func _bind_clips() -> void:
	if _anim == null:
		return
	for clip in _anim.get_animation_list():
		var low := String(clip).to_lower()
		if low.contains("idle") and _idle == &"":
			_idle = StringName(clip)
			_loop(clip)
		elif low.contains("greet") or low.contains("bow") or low.contains("wave") or low.contains("cheer"):
			_emotes.append(StringName(clip))
	if _idle == &"" and not _anim.get_animation_list().is_empty():
		_idle = StringName(_anim.get_animation_list()[0])
		_loop(String(_idle))


func _loop(clip: String) -> void:
	var a := _anim.get_animation(clip)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null


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
