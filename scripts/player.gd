class_name PlayerFlyer
extends CharacterBody3D

const WALK_SPEED := 3.4
const SPRINT_SPEED := 5.2
const HEIGHT := 1.62
const CAM_BOOM := Vector3(0.42, 1.82, 2.65)
const BODY_BOY := preload("res://assets/people/stylized+boy+3d+model (1).glb")
const BODY_GIRL := preload("res://assets/people/stylized+female+3d+newmodel.glb")

var look_yaw: float = 0.0
var look_pitch: float = -0.08
var mouse_sens: float = 0.0022
var rooftop_bounds: Rect2 = Rect2(-6.4, 86.2, 12.8, 12.4)
var rooftop_y: float = 20.3
var intro_lock: bool = false
var body_id: String = "boy"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var handle: Node3D = $Head/Handle

var _bob_t: float = 0.0
var _fov_kick: float = 0.0
var _pech_push: float = 0.0
var _pech_want: float = 0.0
var _spool_w: float = 0.0
var _anim: AnimationPlayer
var _idle: StringName = &""
var _walk: StringName = &""
var _yank: StringName = &""
var _line_anim: bool = false
const BASE_FOV := 62.0
const CLOSE_FOV := 5.5


func _ready() -> void:
	floor_snap_length = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if camera:
		camera.far = 2400.0
	if head:
		head.position = CAM_BOOM


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func move_to_roof(pos: Vector3, bounds: Rect2) -> void:
	global_position = pos
	rooftop_y = pos.y
	rooftop_bounds = bounds


func setup_avatar(id: String = "boy") -> void:
	body_id = "girl" if id == "girl" else "boy"
	if handle and handle.get_parent() != null and handle.get_parent() != head:
		handle.reparent(head)
	var old := get_node_or_null("Body")
	if old:
		old.free()
	_anim = null
	_idle = &""
	_walk = &""
	_yank = &""
	_line_anim = false
	var scene: PackedScene = BODY_GIRL if body_id == "girl" else BODY_BOY
	var model := scene.instantiate() as Node3D
	if model == null:
		push_warning("Missing player body GLB")
		return
	model.name = "Body"
	add_child(model)
	_hide_slab(model)
	model.rotation.y = PI
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var h := aabb.size.y
	if h < 0.2:
		h = HEIGHT
	model.scale *= HEIGHT / h
	model.force_update_transform()
	aabb = _world_aabb(model)
	model.global_position.y += global_position.y - aabb.position.y
	model.force_update_transform()
	var skel := _find_skel(model)
	_anim = _find_anim(model)
	_bind_clips()
	if _anim:
		if not _anim.animation_finished.is_connected(_on_anim_finished):
			_anim.animation_finished.connect(_on_anim_finished)
	if skel and handle:
		var hold := BoneAttachment3D.new()
		hold.name = "CharkhiHold"
		hold.bone_name = "R_Hand"
		skel.add_child(hold)
		handle.reparent(hold)
		## Wrist → palm along the hand bone (+Y). Shift left into the grip
		## (from behind, +X on the right hand sits outside the palm).
		handle.position = Vector3(-0.04, 0.08, 0.018)
		handle.rotation_degrees = Vector3(8.0, 0.0, 0.0)
		handle.scale = Vector3.ONE
	if camera:
		camera.far = 2400.0
	if head:
		head.position = CAM_BOOM
		head.rotation = Vector3(look_pitch, 0.0, 0.0)
	_play_clip(_idle)


func clear_avatar() -> void:
	if handle:
		if head and handle.get_parent() != head:
			handle.reparent(head)
			handle.position = Vector3.ZERO
			handle.rotation = Vector3.ZERO
		var firki := handle.get_node_or_null("Firki")
		if firki:
			firki.queue_free()
		var line_at := handle.get_node_or_null("LineOrigin")
		if line_at:
			line_at.queue_free()
	var old := get_node_or_null("Body")
	if old:
		old.queue_free()
	_anim = null
	_idle = &""
	_walk = &""
	_yank = &""
	_line_anim = false
	body_id = "boy"


func tick(delta: float, _tension: float, _pull: float, _slack: float, _bias: float, payout: float = 0.0, zoom: float = 0.0, kheench_held: bool = false, dheel_held: bool = false) -> void:
	rotation.y = look_yaw
	if head:
		head.position = CAM_BOOM
		head.rotation.x = look_pitch
		head.rotation.y = 0.0
		head.rotation.z = 0.0

	var input := Vector2.ZERO
	if not intro_lock:
		input = Vector2(
			Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
			Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward")
		)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_locomotion(wish.length() > 0.12, speed)

	global_position.x = clampf(global_position.x, rooftop_bounds.position.x, rooftop_bounds.end.x)
	global_position.z = clampf(global_position.z, rooftop_bounds.position.y, rooftop_bounds.end.y)
	if global_position.y < rooftop_y - 0.5:
		global_position.y = rooftop_y

	_bob_t += delta * (1.0 + wish.length() * 6.0)
	var bob := sin(_bob_t * 8.0) * wish.length() * 0.025
	camera.position.y = bob
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 9.0)
	var z := clampf(zoom, 0.0, 1.0)
	## Ease the last stretch of the bar so the kite fills the frame.
	z = z * z * (3.0 - 2.0 * z)
	## A pech leans the view in a touch, harder as the strings grind.
	_pech_push = move_toward(_pech_push, _pech_want, delta * (2.5 if _pech_want > _pech_push else 1.2))
	camera.fov = lerpf(BASE_FOV, CLOSE_FOV, z) + _fov_kick * (1.0 - z * 0.92) - _pech_push * 5.0 * (1.0 - z * 0.8)
	if handle:
		var firki := handle.get_node_or_null("Firki")
		if firki:
			## Q winds in (negative). E pays out (positive). Opposite spins.
			var target := 0.0
			if kheench_held:
				target = -18.0
			elif dheel_held:
				target = 20.0
			else:
				target = clampf(payout / 0.45, -24.0, 24.0)
			var accel := 70.0 if absf(target) > absf(_spool_w) else 22.0
			_spool_w = move_toward(_spool_w, target, accel * delta)
			firki.rotate_x(_spool_w * delta)


## 0 = no pech, 1 = strings crossed and grinding hard.
func set_pech_push(v: float) -> void:
	_pech_want = clampf(v, 0.0, 1.0)


func kick_speed_fov() -> void:
	_fov_kick = 6.5


func yank_spool() -> void:
	## Each Q tap yanks manjha in — a visible inward flick of the firki.
	_spool_w = -26.0
	_play_line(true)


func sag_spool() -> void:
	_play_line(false)


func look_towards(world_point: Vector3, delta: float, weight: float = 3.0, chase: bool = false) -> void:
	var to := world_point - camera.global_position
	if to.length() < 0.2:
		return
	var target_yaw := atan2(-to.x, -to.z)
	var target_pitch := atan2(to.y, Vector3(to.x, 0.0, to.z).length())
	look_yaw = lerp_angle(look_yaw, target_yaw, clampf(weight * delta, 0.0, 1.0))
	## Chase must look almost overhead — a high patang sits at 50–70° up.
	var lo := deg_to_rad(-72.0) if chase else deg_to_rad(-22.0)
	var hi := deg_to_rad(80.0) if chase else deg_to_rad(18.0)
	look_pitch = lerp(look_pitch, clampf(target_pitch, lo, hi), clampf(weight * delta, 0.0, 1.0))


func hand_position() -> Vector3:
	if handle:
		var origin := handle.get_node_or_null("LineOrigin") as Node3D
		if origin:
			return origin.global_position
		return handle.global_position
	return camera.global_position + camera.global_transform.basis * Vector3(0.08, -0.14, -0.38)


func _update_locomotion(moving: bool, speed: float) -> void:
	if _anim == null or _line_anim:
		return
	var clip := _walk if moving and _walk != &"" else _idle
	if clip == &"":
		return
	if _anim.current_animation != String(clip):
		_anim.speed_scale = 1.0
		_play_clip(clip)
	else:
		_anim.speed_scale = 1.15 if moving and speed > WALK_SPEED + 0.2 else 1.0


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
			_loop(clip)
		elif (low.contains("spell") or low.contains("cast") or low.contains("yank") or low.contains("kheench")) and _yank == &"":
			_yank = StringName(clip)
	if _idle == &"" and not _anim.get_animation_list().is_empty():
		_idle = StringName(_anim.get_animation_list()[0])


func _play_line(kheench: bool) -> void:
	if _anim == null or _yank == &"":
		return
	_line_anim = true
	if kheench:
		_anim.speed_scale = 1.35
		_anim.play(_yank, 0.08)
	else:
		_anim.speed_scale = 1.25
		_anim.play_backwards(_yank)


func _on_anim_finished(_anim_name: StringName) -> void:
	_line_anim = false
	if _anim:
		_anim.speed_scale = 1.0


func _play_clip(clip: StringName) -> void:
	if _anim == null or clip == &"":
		return
	_anim.play(clip, 0.2)


func _loop(clip: String) -> void:
	if _anim == null:
		return
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
