extends Node3D

const WindSys := preload("res://scripts/wind_system.gd")

var wind: WindSys
var _segs: Array[MeshInstance3D] = []
var _dirs: Array[Vector3] = []


func setup(wind_in: WindSys) -> void:
	wind = wind_in
	_build()


func _build() -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.04
	cyl.height = 2.6
	pole.mesh = cyl
	pole.position.y = 1.3
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.35, 0.36, 0.38)
	pole.material_override = pole_mat
	add_child(pole)

	var sock_mat := StandardMaterial3D.new()
	sock_mat.albedo_color = Color(0.92, 0.45, 0.12)
	sock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sock_mat.roughness = 0.7
	for i in 5:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		var t := float(i) / 5.0
		cone.top_radius = lerpf(0.16, 0.05, t)
		cone.bottom_radius = lerpf(0.20, 0.08, t)
		cone.height = 0.38
		cone.radial_segments = 8
		mi.mesh = cone
		mi.material_override = sock_mat
		add_child(mi)
		_segs.append(mi)
		_dirs.append(Vector3(0.0, 0.0, -1.0))


func _process(delta: float) -> void:
	if wind == null or _segs.is_empty():
		return
	var sample_pos := global_position + Vector3(0.0, 2.4, 0.0)
	var w := wind.sample(sample_pos, 0.35, false)
	var target := Vector3(w.x, clampf(w.y, -0.4, 0.15), w.z)
	if target.length() < 0.15:
		target = Vector3(0.0, -0.4, -0.2)
	target = target.normalized()
	var speed := clampf(w.length() / 12.0, 0.15, 1.0)
	## The leading edge of a gust reaches the roof first: the sock starts to
	## twitch and lift a beat before the full gust.
	var warn := wind.gust_incoming
	speed = maxf(speed, lerpf(speed, 1.0, warn * 0.6))
	target = (target + Vector3.UP * 0.25 * warn).normalized()
	var origin := global_position + Vector3(0.0, 2.55, 0.0)
	for i in _segs.size():
		var lag := 1.0 + float(i) * 0.55
		_dirs[i] = _dirs[i].lerp(target, clampf(delta * 7.0 / lag, 0.0, 1.0))
		var flap := sin(wind.time * (9.0 + float(i) * 2.0) * (1.0 + warn)) * (0.08 + 0.12 * warn) * speed
		var dir: Vector3 = _dirs[i].normalized()
		dir = dir.rotated(Vector3.UP, flap)
		var pos := origin + dir * (0.22 + float(i) * 0.36)
		_segs[i].global_position = pos
		if absf(dir.dot(Vector3.UP)) < 0.95:
			_segs[i].look_at(pos + dir, Vector3.UP)
			_segs[i].rotate_object_local(Vector3.RIGHT, PI * 0.5)
