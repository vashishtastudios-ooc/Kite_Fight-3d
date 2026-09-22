extends Node3D

## Visible rooftop flyer. Not the first-person camera body.

const PACK_PATH := "res://assets/people/stylized+boy+3d+model (1).glb"
const HEIGHT := 1.62

var _anim: AnimationPlayer
var _idle: StringName = &""
var _walk: StringName = &""
var _yank: StringName = &""
var _clap: StringName = &""
var _emotes: Array[StringName] = []
var _emote_i: int = 0
var _until: float = 4.0
var _line_anim: bool = false
var _fly_mate: bool = false
var _spool: Node3D
var _spool_w: float = 0.0


func setup(feet: Vector3, look_at_point: Vector3, hold: PackedScene = null, body: PackedScene = null, fly_mate: bool = false, idle_only: bool = false) -> void:
	_fly_mate = fly_mate
	var pack: Variant = body if body else load(PACK_PATH)
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
	var skel := _find_skel(model)
	if hold != null and fly_mate and skel:
		_attach_hand_charkhi(hold, skel)
	elif hold != null:
		_attach_charkhi(hold)
	_anim = _find_anim(model)
	_bind_clips()
	if idle_only:
		_emotes.clear()
		_until = 9999.0
	_play_idle()
	if not idle_only:
		_until = 1.2 if _fly_mate else 5.0
	if _anim and not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)


func _attach_hand_charkhi(scene: PackedScene, skel: Skeleton3D) -> void:
	var hold := BoneAttachment3D.new()
	hold.name = "CharkhiHold"
	hold.bone_name = "R_Hand"
	skel.add_child(hold)
	var firki := Node3D.new()
	firki.name = "Firki"
	hold.add_child(firki)
	firki.position = Vector3(-0.04, 0.08, 0.018)
	firki.rotation_degrees = Vector3(8.0, 0.0, 0.0)
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	firki.add_child(model)
	_hide_slab(model)
	model.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var disc := maxf(aabb.size.x, aabb.size.z)
	var axle := aabb.size.y
	if disc < 0.02:
		disc = 0.08
	if axle < 0.02:
		axle = 0.12
	model.scale = Vector3(0.16 / disc, 0.12 / axle, 0.16 / disc)
	model.force_update_transform()
	aabb = _world_aabb(model)
	model.global_position += firki.global_position - aabb.get_center()
	_no_shadow(model)
	_spool = firki


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


func play_clap() -> void:
	if _anim == null or _clap == &"" or _line_anim:
		return
	_until = 2.6
	_anim.play(_clap, 0.12)


func _on_anim_finished(anim_name: StringName) -> void:
	_line_anim = false
	if _anim:
		_anim.speed_scale = 1.0
	if String(anim_name).to_lower().contains("idle"):
		return
	_play_idle()
	_until = 2.2 if _fly_mate else 5.0


func _process(delta: float) -> void:
	if _spool:
		_spool_w = move_toward(_spool_w, 0.0, 28.0 * delta)
		_spool.rotate_x(_spool_w * delta)
	if _anim == null or _line_anim:
		return
	_until -= delta
	if _until > 0.0:
		return
	if _emotes.is_empty():
		_play_idle()
		_until = 6.0
		return
	var current := String(_anim.current_animation).to_lower()
	if current.contains("idle") or not _anim.is_playing():
		_play_emote(_emotes[_emote_i % _emotes.size()])
		_emote_i += 1
	else:
		_play_idle()
		_until = 2.2 if _fly_mate else 5.0


func _play_emote(clip: StringName) -> void:
	if _anim == null or clip == &"":
		_until = 2.0
		return
	_unloop(String(clip))
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.2)
	var a := _anim.get_animation(clip)
	var hold := 2.4
	if a:
		hold = maxf(a.length / maxf(_anim.speed_scale, 0.01), 1.2) + 0.15
	_until = hold


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
		elif low.contains("walk") and _walk == &"":
			_walk = StringName(clip)
		elif (low.contains("spell") or low.contains("cast") or low.contains("yank") or low.contains("kheench")) and _yank == &"":
			_yank = StringName(clip)
		elif low.contains("clap") and _clap == &"":
			_clap = StringName(clip)
		elif low.contains("greet") or low.contains("bow") or low.contains("wave") or low.contains("cheer"):
			_emotes.append(StringName(clip))
	if _idle == &"" and not _anim.get_animation_list().is_empty():
		_idle = StringName(_anim.get_animation_list()[0])
		_loop(String(_idle))
	_emotes.clear()
	for clip in _anim.get_animation_list():
		var low := String(clip).to_lower()
		if low.contains("idle"):
			continue
		if low.contains("spell") or low.contains("cast") or low.contains("yank") or low.contains("kheench"):
			continue
		_emotes.append(StringName(clip))
		_unloop(clip)


func _unloop(clip: String) -> void:
	var a := _anim.get_animation(clip)
	if a:
		a.loop_mode = Animation.LOOP_NONE


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


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var found := _find_skel(c)
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
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var la := mi.get_aabb()
			var slab := la.size.y < 0.22 and maxf(la.size.x, la.size.z) > 1.6 and la.position.y < 0.35
			if not slab:
				acc = mi.global_transform * la
				first = false
	elif n is VisualInstance3D and (n as Node3D).visible:
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
