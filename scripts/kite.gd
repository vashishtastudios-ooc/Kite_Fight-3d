class_name Kite
extends Node3D

## Single-line fighter patang. Slack = spin and drift. Kheench = dart the nose.
## Dheel = pay out, sag, and fall. Q can yank it back until it hits the ground.

enum Phase { GROUNDED, CLIMB, SPIN, FLY, DHEEL, CUT, CRASHED }

const LINE_MIN := 10.0
const LINE_MAX := 500.0
const LINE_START := 18.0
const CLIMB_SPEED := 9.0
const FLY_SPEED := 22.0
const SKY_ALT := 26.0
const NEAR_DIST := 26.0
const IDLE_SPIN_NEAR := TAU / 0.85
const IDLE_SPIN_HIGH := TAU / 1.35
const LINE_SEGS := 16
const TAIL_LEN := 10
const TAIL_SEG := 0.28
const KITE_SPAN := 1.55
const KITE_SHADER := preload("res://shaders/kite.gdshader")
const NOSE_MESH_H := 0.26

signal cut_down
signal manjha_changed(value: float)

var killed_by_rocket: bool = false

const WindSys := preload("res://scripts/wind_system.gd")
const CityGen := preload("res://scripts/city_generator.gd")

var phase: Phase = Phase.GROUNDED
var velocity: Vector3 = Vector3.ZERO
var line_length: float = LINE_START
var tension: float = 0.0
var slack: float = 0.0
var pull: float = 0.0
var heading: float = 0.35
var ang_vel: float = 0.0
var spin_dir: float = 1.0
var elevation: float = 0.0
var manjha: float = 1.0
var is_ai: bool = false
var viewer_pos: Vector3 = Vector3.ZERO
var hand_pos: Vector3 = Vector3.ZERO
## Metres of line paid this second (firki + wind). HUD and spool use this.
var payout_rate: float = 0.0

var wind: WindSys
var city: CityGen

var _kheench: bool = false
var _dheel: bool = false
var _bias: float = 0.0
var _fly_heading: float = 0.35
var _climb_t: float = 0.0
var _bob_t: float = 0.0
var _cut_tumble: float = 0.0
var _sail_colors: Array[Color] = []
var _line_pink: bool = true
var _sail_mat: ShaderMaterial
var _outline_mi: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _nose_marker: MeshInstance3D
var _nose_mat: StandardMaterial3D
var _body: Node3D
var _line_root: Node3D
var _line_segs: Array[MeshInstance3D] = []
var _line_cyls: Array[CylinderMesh] = []
var _tail_pts: Array[Vector3] = []
var _tail_meshes: Array[MeshInstance3D] = []
var _visual_basis: Basis = Basis.IDENTITY
var _line_mat: StandardMaterial3D
var _speed_burst: GPUParticles3D
var _speed_trail: MeshInstance3D
var _trail_imm: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _trail_pts: Array[Vector3] = []
var _trail_age: Array[float] = []
const TRAIL_LIFE := 0.42
const TRAIL_MAX := 28


func setup(wind_in: WindSys, city_in: CityGen, colors: Array[Color] = []) -> void:
	wind = wind_in
	city = city_in
	if colors.is_empty():
		_sail_colors = [
			Color(0.90, 0.16, 0.12),
			Color(0.95, 0.93, 0.86),
			Color(0.82, 0.12, 0.10),
			Color(0.96, 0.55, 0.16),
		]
	else:
		_sail_colors = colors
	_line_pink = colors.is_empty()
	_build_visual()
	park_on_roof()


func park_on_roof() -> void:
	phase = Phase.GROUNDED
	velocity = Vector3.ZERO
	tension = 0.0
	slack = 0.0
	pull = 0.0
	heading = 0.3
	ang_vel = 0.0
	line_length = LINE_START
	manjha = 1.0
	killed_by_rocket = false
	_kheench = false
	_dheel = false
	global_position = hand_pos + Vector3(0.4, 0.2, -0.7)
	_reset_tail()
	_clear_speed_trail()
	manjha_changed.emit(manjha)


func launch() -> void:
	if phase != Phase.GROUNDED and phase != Phase.CRASHED and phase != Phase.CUT:
		return
	phase = Phase.CLIMB
	_climb_t = 0.0
	ang_vel = 0.0
	heading = 0.45
	slack = 0.0
	pull = 0.0
	manjha = 1.0
	killed_by_rocket = false
	line_length = LINE_START
	_kheench = false
	_dheel = false
	var w := _wind_at(hand_pos + Vector3(0.0, 3.0, -4.0))
	var downwind := Vector3(w.x, 0.0, w.z)
	if downwind.length() < 0.2:
		downwind = Vector3(0.0, 0.0, -1.0)
	downwind = downwind.normalized()
	global_position = hand_pos + downwind * 5.5 + Vector3.UP * 4.2
	velocity = downwind * 3.2 + Vector3.UP * CLIMB_SPEED
	_reset_tail()
	_clear_speed_trail()
	manjha_changed.emit(manjha)


func relaunch() -> void:
	park_on_roof()
	launch()


func set_kheench(held: bool) -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED or phase == Phase.CRASHED:
		return
	if held == _kheench:
		return
	_kheench = held
	if held:
		_dheel = false
		# A real kheench is a short yank, not winding the firki home.
		line_length = maxf(LINE_MIN, line_length - 1.6)
		_enter_fly()
		_burst_speed_fx()
	else:
		if phase == Phase.FLY:
			_enter_spin()


func set_dheel(held: bool) -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED or phase == Phase.CRASHED:
		return
	if _kheench:
		held = false
	if held == _dheel:
		return
	_dheel = held
	if held:
		if phase == Phase.CLIMB:
			_dheel = false
			return
		phase = Phase.DHEEL
		slack = maxf(slack, 0.35)
	## Release stops the firki. The kite keeps sagging until Q or the ground.


func kill_by_rocket() -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED or phase == Phase.CRASHED:
		return
	killed_by_rocket = true
	apply_cut()


func apply_cut() -> void:
	if phase == Phase.CUT:
		return
	phase = Phase.CUT
	_kheench = false
	_dheel = false
	slack = 1.0
	tension = 0.0
	pull = 0.0
	manjha = 0.0
	_cut_tumble = 8.0 * spin_dir
	velocity += _wind_at(global_position) * 0.6 + Vector3.UP * 1.5
	_clear_speed_trail()
	manjha_changed.emit(0.0)
	cut_down.emit()


func damage_manjha(amount: float) -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED:
		return
	manjha = clampf(manjha - amount, 0.0, 1.0)
	manjha_changed.emit(manjha)
	if manjha <= 0.0:
		apply_cut()


func nose_dir() -> Vector3:
	var a := _sky_axes()
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	return (right * sin(heading) + up * cos(heading)).normalized()


func is_airborne() -> bool:
	return phase != Phase.GROUNDED and phase != Phase.CRASHED


func tick(delta: float, hand: Vector3, viewer: Vector3, reel: float, bias: float) -> void:
	hand_pos = hand
	viewer_pos = viewer
	_bias = clampf(bias, -1.0, 1.0)
	_bob_t += delta
	if phase == Phase.GROUNDED:
		global_position = hand_pos + Vector3(0.35, 0.15, -0.65)
		heading = 0.25
		_orient_body(delta)
		_update_readability()
		_update_line()
		_update_tail(delta)
		return

	if phase == Phase.CUT:
		_tick_cut(delta)
		_orient_body(delta)
		_update_readability()
		_update_line()
		_update_tail(delta)
		return

	if phase == Phase.CRASHED:
		velocity += Vector3.DOWN * 9.81 * delta
		velocity *= (1.0 - 1.6 * delta)
		global_position += velocity * delta
		global_position.y = maxf(global_position.y, 0.4)
		_slack_constrain()
		_orient_body(delta)
		_update_readability()
		_update_line()
		_update_tail(delta)
		return

	# Dheel pays line out. Wind taking the kite also lengthens the manjha.
	payout_rate = 0.0
	var w := _wind_at(global_position)
	if _dheel:
		var wind_out := Vector3(w.x, 0.0, w.z).length() * 2.2
		var pay := 20.0 + wind_out + maxf(reel, 0.0) * 36.0
		line_length = clampf(line_length + pay * delta, LINE_MIN, LINE_MAX)
		payout_rate = pay
	else:
		line_length = clampf(line_length + reel * 36.0 * delta, LINE_MIN, LINE_MAX)
		payout_rate = reel * 36.0

	match phase:
		Phase.CLIMB:
			_tick_climb(delta, w)
		Phase.SPIN:
			_tick_spin(delta, w)
		Phase.FLY:
			_tick_fly(delta, w)
		Phase.DHEEL:
			_tick_dheel(delta, w)

	_constrain_line(delta)
	if _dheel and phase != Phase.CUT and phase != Phase.CRASHED:
		var paid_dist := global_position.distance_to(hand_pos)
		line_length = clampf(maxf(line_length, paid_dist), LINE_MIN, LINE_MAX)
	_check_crash()
	_update_elevation()
	pull = move_toward(pull, 1.0 if _kheench else 0.0, delta * 6.0)
	_orient_body(delta)
	_update_readability()
	_update_line()
	_update_tail(delta)
	_update_speed_trail(delta)


func _enter_fly() -> void:
	phase = Phase.FLY
	ang_vel = 0.0
	slack = 0.0
	_fly_heading = heading
	var nose := nose_dir()
	var kick := FLY_SPEED
	var w := _wind_at(global_position)
	var along := w.dot(nose)
	kick += clampf(along * 0.35, -6.0, 8.0)
	velocity = nose * kick + Vector3.UP * 2.2
	tension = 28.0


func _enter_spin() -> void:
	phase = Phase.SPIN
	ang_vel = _idle_spin_rate() * spin_dir
	slack = 0.12
	tension = 4.0


func _idle_spin_rate() -> float:
	## Faster tumble near the roof; slower and lazier up high.
	var alt := altitude()
	var hd := horiz_dist()
	var near := 1.0 - clampf(hd / NEAR_DIST, 0.0, 1.0)
	var low := 1.0 - clampf(alt / SKY_ALT, 0.0, 1.0)
	var blend := clampf(0.2 + near * 0.45 + low * 0.55, 0.0, 1.0)
	return lerpf(IDLE_SPIN_HIGH, IDLE_SPIN_NEAR, blend)


func altitude() -> float:
	return global_position.y - hand_pos.y


func horiz_dist() -> float:
	var d := global_position - hand_pos
	d.y = 0.0
	return d.length()


func _tick_climb(delta: float, w: Vector3) -> void:
	_climb_t += delta
	var up := Vector3(w.x * 0.28, CLIMB_SPEED, w.z * 0.28)
	velocity = velocity.lerp(up, 2.4 * delta)
	global_position += velocity * delta
	heading = lerp_angle(heading, 0.4, 2.0 * delta)
	ang_vel = 0.0
	slack = 0.0
	if _climb_t > 0.5 and altitude() > 5.5:
		_enter_spin()


func _tick_spin(delta: float, w: Vector3) -> void:
	if _kheench:
		_enter_fly()
		return
	if _dheel:
		phase = Phase.DHEEL
		return
	var rate := _idle_spin_rate()
	## Light left/right only while slack: nudge the nose before the next tug.
	if absf(_bias) > 0.08:
		spin_dir = signf(_bias)
		rate += absf(_bias) * 1.4
		heading += _bias * 2.4 * delta
	ang_vel = move_toward(ang_vel, rate * spin_dir, 11.0 * delta)
	heading += ang_vel * delta
	var a := _sky_axes()
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	var orbit := right * cos(heading) * 1.15 + up * sin(heading) * 0.32
	var drift := Vector3(w.x, 0.2 + sin(_bob_t * 2.0) * 0.35, w.z) * 0.55
	drift += right * _bias * 1.6
	velocity = velocity.lerp(drift + orbit, 2.1 * delta)
	global_position += velocity * delta
	slack = move_toward(slack, 0.1, delta * 1.4)
	tension = move_toward(tension, 5.0, delta * 20.0)


func _tick_fly(delta: float, w: Vector3) -> void:
	if not _kheench:
		if _dheel:
			phase = Phase.DHEEL
		else:
			_enter_spin()
		return
	ang_vel = move_toward(ang_vel, 0.0, 18.0 * delta)
	heading = lerp_angle(heading, _fly_heading, clampf(14.0 * delta, 0.0, 1.0))
	heading += sin(_bob_t * 9.0) * 0.04 * delta
	slack = move_toward(slack, 0.0, delta * 4.0)
	var nose := nose_dir()
	var room := clampf((line_length - horiz_dist()) / 14.0, 0.0, 1.0)
	var climb_bias := lerpf(-0.05, 0.28, room)
	if altitude() > SKY_ALT * 0.85:
		climb_bias *= 0.35
	var cruise := nose * FLY_SPEED + Vector3(0.0, climb_bias * FLY_SPEED, 0.0)
	cruise += w * 0.5
	cruise += Vector3(sin(_bob_t * 7.0), cos(_bob_t * 5.4), sin(_bob_t * 6.1)) * 0.7
	velocity = velocity.lerp(cruise, 8.2 * delta)
	global_position += velocity * delta
	tension = move_toward(tension, 34.0 + w.length() * 1.2, delta * 40.0)


func _tick_dheel(delta: float, w: Vector3) -> void:
	if _kheench:
		_enter_fly()
		return
	slack = move_toward(slack, 1.0, delta * 1.8)
	if absf(_bias) > 0.08:
		spin_dir = signf(_bias)
		heading += _bias * 1.4 * delta
	heading += lerpf(2.2, 8.0, slack) * spin_dir * delta
	var horiz := Vector3(w.x, 0.0, w.z)
	velocity += horiz * (1.55 * delta)
	velocity.y -= lerpf(6.2, 9.4, slack) * delta
	velocity *= (1.0 - 0.48 * delta)
	velocity.y += sin(_bob_t * 2.4) * 0.55 * delta
	global_position += velocity * delta
	tension = move_toward(tension, 0.5, delta * 22.0)


func _tick_cut(delta: float) -> void:
	var w := _wind_at(global_position)
	_cut_tumble += delta * 10.0
	heading += _cut_tumble * delta
	velocity += Vector3(w.x, -2.4, w.z) * delta
	velocity *= (1.0 - 0.35 * delta)
	global_position += velocity * delta
	if global_position.y < 0.6:
		global_position.y = 0.6
		velocity *= 0.4
		phase = Phase.CRASHED


func _constrain_line(delta: float) -> void:
	if phase == Phase.GROUNDED or phase == Phase.CUT:
		return
	var to_kite := global_position - hand_pos
	var dist := to_kite.length()
	if dist < 0.05:
		return
	var max_len := line_length
	if dist < LINE_MIN * 0.8 and phase != Phase.DHEEL and not _dheel:
		global_position = hand_pos + to_kite.normalized() * (LINE_MIN * 0.8)
	elif dist > max_len:
		var n := to_kite / dist
		var pull_back := (dist - max_len) * clampf(9.0 * delta, 0.0, 1.0)
		global_position -= n * pull_back
		velocity *= lerpf(0.9, 0.98, slack)


func _slack_constrain() -> void:
	var to_kite := global_position - hand_pos
	var dist := to_kite.length()
	if dist > line_length * 1.08 and dist > 0.05:
		global_position = hand_pos + to_kite / dist * line_length * 1.08


func _update_elevation() -> void:
	var to_kite := global_position - hand_pos
	var horiz := Vector3(to_kite.x, 0.0, to_kite.z).length()
	elevation = atan2(to_kite.y, maxf(horiz, 0.01))


func _check_crash() -> void:
	if global_position.y < 1.4:
		_crash()
		return
	if city == null:
		return
	var p := global_position
	for aabb in city.building_aabbs:
		if aabb.grow(0.3).has_point(p):
			if aabb.intersects(city.player_building_aabb) and p.y >= city.rooftop_height - 0.2:
				continue
			_crash()
			return


func _crash() -> void:
	if phase == Phase.CUT:
		phase = Phase.CRASHED
		return
	phase = Phase.CRASHED
	velocity *= 0.25
	tension = 0.0
	_kheench = false
	_dheel = false
	_clear_speed_trail()


func _sky_axes() -> Dictionary:
	var to_cam := viewer_pos - global_position
	if to_cam.length_squared() < 0.01:
		to_cam = hand_pos - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.01:
		to_cam = Vector3(0.0, 0.0, 1.0)
	var face := to_cam.normalized()
	var right := Vector3.UP.cross(face)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := face.cross(right).normalized()
	return {"face": face, "right": right, "up": up}


func _orient_body(delta: float) -> void:
	if _body == null:
		return
	var a := _sky_axes()
	var face: Vector3 = a["face"]
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	var nose := (right * sin(heading) + up * cos(heading)).normalized()
	var z_axis := nose
	var y_axis := face
	var x_axis := y_axis.cross(z_axis)
	if x_axis.length_squared() < 0.0002:
		return
	x_axis = x_axis.normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	var target := Basis(x_axis, y_axis, z_axis)
	if phase == Phase.FLY:
		target = target.rotated(x_axis, clampf(-velocity.y * 0.015, -0.18, 0.14))
	elif phase == Phase.DHEEL or phase == Phase.CUT:
		target = target.rotated(x_axis, 0.28)
	elif phase == Phase.SPIN:
		target = target.rotated(face, sin(_bob_t * 6.0) * 0.08)
	_visual_basis = _visual_basis.orthonormalized().slerp(target, clampf(12.0 * delta, 0.0, 1.0))
	_body.transform.basis = _visual_basis
	_body.position = Vector3.ZERO
	if _nose_marker:
		_nose_marker.position = Vector3(0.0, 0.0, KITE_SPAN * 0.48)


func _update_readability() -> void:
	## Sail stays true size. Rim + nose pip grow with distance so heading still reads.
	if _body == null:
		return
	_body.scale = Vector3.ONE
	var dist := viewer_pos.distance_to(global_position)
	var airborne := phase != Phase.GROUNDED and phase != Phase.CRASHED
	var far := 0.0
	if airborne:
		far = smoothstep(32.0, 150.0, dist)
	var player_boost := 0.0 if is_ai else 1.0
	var lift := far * lerpf(0.38, 0.68, player_boost)
	var rim := far * lerpf(0.45, 1.05, player_boost)
	if _sail_mat:
		_sail_mat.set_shader_parameter("lift", lift)
		_sail_mat.set_shader_parameter("rim", rim)
	if _outline_mat:
		_outline_mat.albedo_color.a = lerpf(0.22, 0.72, far)
		_outline_mat.emission_energy_multiplier = lerpf(0.12, 1.15, far)
	if _nose_marker:
		var grow := dist * lerpf(0.0034, 0.0056, player_boost)
		var s := 1.0
		if airborne:
			s = clampf(grow / NOSE_MESH_H, 1.0, 8.5)
		_nose_marker.scale = Vector3.ONE * s
		if _nose_mat:
			_nose_mat.emission_energy_multiplier = lerpf(0.35, 1.6, far)


func _update_line() -> void:
	if _line_segs.is_empty():
		return
	if phase == Phase.GROUNDED or phase == Phase.CUT:
		_line_root.visible = false
		return
	var a := hand_pos
	var b := global_position
	var length := a.distance_to(b)
	if length < 0.08:
		_line_root.visible = false
		return
	_line_root.visible = true
	var taut := (1.0 - slack) * clampf(tension / 28.0, 0.0, 1.0)
	var sag := lerpf(length * 0.09, length * 0.006, taut)
	var mid := (a + b) * 0.5 + Vector3.DOWN * sag
	var w := _wind_at(mid)
	var wf := Vector3(w.x, 0.0, w.z)
	if wf.length() > 0.2:
		mid += wf.normalized() * (length * 0.02 * slack)
	if _line_mat:
		if _line_pink:
			_line_mat.albedo_color = Color(0.92, 0.22, 0.48).lerp(Color(1.0, 0.48, 0.70), taut)
		else:
			_line_mat.albedo_color = Color(0.93, 0.88, 0.7).lerp(Color(1.0, 0.92, 0.45), taut)
	for i in LINE_SEGS:
		var t0 := float(i) / float(LINE_SEGS)
		var t1 := float(i + 1) / float(LINE_SEGS)
		_place_segment(_line_segs[i], _line_cyls[i], _bezier(a, mid, b, t0), _bezier(a, mid, b, t1), lerpf(0.0045 if _line_pink else 0.003, 0.012 if _line_pink else 0.01, t1))


func _update_tail(delta: float) -> void:
	if _tail_pts.is_empty():
		return
	var back := -nose_dir()
	var desired := global_position + back * 0.5 + Vector3.DOWN * 0.1
	_tail_pts[0] = _tail_pts[0].lerp(desired, clampf(16.0 * delta, 0.0, 1.0))
	var w := _wind_at(global_position) * 0.1
	for i in range(1, _tail_pts.size()):
		var prev: Vector3 = _tail_pts[i - 1]
		var cur: Vector3 = _tail_pts[i] + (w + Vector3.DOWN * 2.2) * delta
		var to := cur - prev
		if to.length() < 0.001:
			to = Vector3.DOWN
		_tail_pts[i] = prev + to.normalized() * TAIL_SEG
	for i in _tail_meshes.size():
		var m: MeshInstance3D = _tail_meshes[i]
		m.global_position = _tail_pts[i]
		if i > 0:
			var dir: Vector3 = _tail_pts[i] - _tail_pts[i - 1]
			if dir.length_squared() > 0.0002 and absf(dir.normalized().dot(Vector3.UP)) < 0.97:
				m.look_at(_tail_pts[i - 1], Vector3.UP)


func _reset_tail() -> void:
	for i in _tail_pts.size():
		_tail_pts[i] = global_position + Vector3.DOWN * (0.4 + float(i) * TAIL_SEG)


func _wind_at(pos: Vector3) -> Vector3:
	if wind == null:
		return Vector3(0.0, 0.0, -8.0)
	var chop := 0.0
	if city:
		chop = city.nearest_building_chop(pos)
	return wind.sample(pos, chop, not is_ai)


func _rim_accent() -> Color:
	if _sail_colors.is_empty():
		return Color(1.0, 0.84, 0.28)
	var c: Color = _sail_colors[0]
	if c.g > c.r + 0.08:
		return Color(0.72, 1.0, 0.32)
	return Color(1.0, 0.84, 0.28)


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Sail"
	add_child(_body)
	var accent := _rim_accent()
	var sail := MeshInstance3D.new()
	sail.mesh = _make_diamond()
	sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sail.extra_cull_margin = 12.0
	_sail_mat = ShaderMaterial.new()
	_sail_mat.shader = KITE_SHADER
	_sail_mat.set_shader_parameter("lift", 0.0)
	_sail_mat.set_shader_parameter("rim", 0.0)
	_sail_mat.set_shader_parameter("rim_color", accent)
	sail.material_override = _sail_mat
	sail.sorting_offset = 0.05
	_body.add_child(sail)
	_outline_mi = MeshInstance3D.new()
	_outline_mi.mesh = _make_outline_diamond()
	_outline_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline_mi.extra_cull_margin = 12.0
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.28)
	_outline_mat.emission_enabled = true
	_outline_mat.emission = accent
	_outline_mat.emission_energy_multiplier = 0.15
	_outline_mat.disable_fog = true
	_outline_mat.disable_receive_shadows = true
	_outline_mi.material_override = _outline_mat
	_outline_mi.position = Vector3(0.0, 0.02, 0.0)
	_body.add_child(_outline_mi)
	_add_spar(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), KITE_SPAN, 0.016)
	_add_spar(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 1.15, 0.014)
	_nose_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.002
	cone.bottom_radius = 0.05
	cone.height = NOSE_MESH_H
	cone.radial_segments = 8
	_nose_marker.mesh = cone
	_nose_mat = StandardMaterial3D.new()
	_nose_mat.albedo_color = accent
	_nose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_nose_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nose_mat.emission_enabled = true
	_nose_mat.emission = accent
	_nose_mat.emission_energy_multiplier = 0.4
	_nose_mat.disable_fog = true
	_nose_mat.disable_receive_shadows = true
	_nose_marker.material_override = _nose_mat
	_nose_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nose_marker.extra_cull_margin = 20.0
	_nose_marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_nose_marker.position = Vector3(0.0, 0.0, KITE_SPAN * 0.48)
	_body.add_child(_nose_marker)
	_build_tail()
	_build_line()
	_build_speed_fx()
	_reset_tail()


func _build_speed_fx() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	glow.albedo_color = Color(1.0, 0.93, 0.5, 0.85)
	glow.vertex_color_use_as_albedo = true
	glow.disable_receive_shadows = true
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var spark := BoxMesh.new()
	spark.size = Vector3(0.035, 0.42, 0.035)
	spark.material = glow

	_speed_burst = GPUParticles3D.new()
	_speed_burst.name = "KheenchBurst"
	_speed_burst.amount = 14
	_speed_burst.lifetime = 0.28
	_speed_burst.one_shot = true
	_speed_burst.explosiveness = 1.0
	_speed_burst.local_coords = false
	_speed_burst.emitting = false
	_speed_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_speed_burst.visibility_aabb = AABB(Vector3(-50.0, -50.0, -50.0), Vector3(100.0, 100.0, 100.0))
	_speed_burst.extra_cull_margin = 40.0
	var bpm := ParticleProcessMaterial.new()
	bpm.direction = Vector3(0.0, 0.0, -1.0)
	bpm.spread = 14.0
	bpm.initial_velocity_min = 6.0
	bpm.initial_velocity_max = 12.0
	bpm.gravity = Vector3.ZERO
	bpm.damping_min = 4.0
	bpm.damping_max = 7.0
	bpm.scale_min = 0.55
	bpm.scale_max = 1.0
	bpm.particle_flag_align_y = true
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.94, 0.5, 0.8),
		Color(1.0, 0.88, 0.42, 0.35),
		Color(1.0, 0.82, 0.35, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	bpm.color_ramp = ramp
	_speed_burst.process_material = bpm
	_speed_burst.draw_pass_1 = spark
	_body.add_child(_speed_burst)
	_speed_burst.position = Vector3(0.0, 0.0, -0.55)

	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.disable_receive_shadows = true
	_trail_imm = ImmediateMesh.new()
	_speed_trail = MeshInstance3D.new()
	_speed_trail.name = "KheenchTrail"
	_speed_trail.mesh = _trail_imm
	_speed_trail.top_level = true
	_speed_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_speed_trail.extra_cull_margin = 80.0
	add_child(_speed_trail)


func _clear_speed_trail() -> void:
	_trail_pts.clear()
	_trail_age.clear()
	if _trail_imm:
		_trail_imm.clear_surfaces()


func _update_speed_trail(delta: float) -> void:
	if _speed_trail == null or _trail_imm == null:
		return
	_speed_trail.global_transform = Transform3D.IDENTITY
	var i := 0
	while i < _trail_age.size():
		_trail_age[i] += delta
		if _trail_age[i] > TRAIL_LIFE:
			_trail_pts.remove_at(i)
			_trail_age.remove_at(i)
		else:
			i += 1
	if _kheench and phase == Phase.FLY:
		var p := global_position
		if _trail_pts.is_empty() or _trail_pts[_trail_pts.size() - 1].distance_squared_to(p) > 0.018:
			_trail_pts.append(p)
			_trail_age.append(0.0)
			while _trail_pts.size() > TRAIL_MAX:
				_trail_pts.remove_at(0)
				_trail_age.remove_at(0)
	_rebuild_trail_mesh()


func _rebuild_trail_mesh() -> void:
	_trail_imm.clear_surfaces()
	var n := _trail_pts.size()
	if n < 2:
		return
	var dist := viewer_pos.distance_to(global_position)
	var half_w := clampf(dist * 0.002, 0.06, 0.55)
	_trail_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_mat)
	for idx in n:
		var p: Vector3 = _trail_pts[idx]
		var along: Vector3
		if idx < n - 1:
			along = _trail_pts[idx + 1] - p
		else:
			along = p - _trail_pts[idx - 1]
		if along.length_squared() < 0.00001:
			along = velocity
		if along.length_squared() < 0.00001:
			along = Vector3(0.0, 0.0, -1.0)
		along = along.normalized()
		var to_cam := viewer_pos - p
		var side := along.cross(to_cam)
		if side.length_squared() < 0.05:
			side = along.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = along.cross(Vector3.RIGHT)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		var u := float(idx) / float(n - 1)
		var t := 1.0 - clampf(_trail_age[idx] / TRAIL_LIFE, 0.0, 1.0)
		var half := half_w * lerpf(0.18, 1.0, u)
		side = side.normalized() * half
		var a := clampf(t * lerpf(0.08, 0.55, u), 0.0, 0.55)
		var col := Color(1.0, 0.93, 0.48, a)
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(p + side)
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(p - side)
	_trail_imm.surface_end()


func _burst_speed_fx() -> void:
	if _speed_burst == null:
		return
	_speed_burst.restart()


func _make_diamond() -> ArrayMesh:
	var nose := Vector3(0.0, 0.0, 0.78)
	var right := Vector3(0.58, 0.0, 0.02)
	var tail := Vector3(0.0, 0.0, -0.62)
	var left := Vector3(-0.58, 0.0, 0.02)
	var bow := Vector3(0.0, 0.08, 0.04)
	var c := _sail_colors
	var panels: Array = [
		[bow, nose, right, c[0]],
		[bow, right, tail, c[1]],
		[bow, tail, left, c[2]],
		[bow, left, nose, c[3]],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in panels:
		_add_tri(st, p[0], p[1], p[2], p[3])
		_add_tri(st, p[0], p[2], p[1], (p[3] as Color).darkened(0.08))
	st.generate_normals()
	return st.commit()


func _make_outline_diamond() -> ArrayMesh:
	var grow := 1.1
	var nose := Vector3(0.0, 0.0, 0.78) * grow
	var right := Vector3(0.58, 0.0, 0.02) * grow
	var tail := Vector3(0.0, 0.0, -0.62) * grow
	var left := Vector3(-0.58, 0.0, 0.02) * grow
	var bow := Vector3(0.0, 0.09, 0.04) * grow
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color.WHITE
	_add_tri(st, bow, nose, right, col)
	_add_tri(st, bow, right, tail, col)
	_add_tri(st, bow, tail, left, col)
	_add_tri(st, bow, left, nose, col)
	st.generate_normals()
	return st.commit()


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


func _add_spar(origin: Vector3, axis: Vector3, length: float, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 6
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.28, 0.14)
	mat.roughness = 0.8
	mi.material_override = mat
	var n := axis.normalized()
	var x := n.cross(Vector3.FORWARD)
	if x.length_squared() < 0.01:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(n).normalized()
	mi.transform = Transform3D(Basis(x, n, z), origin)
	_body.add_child(mi)


func _build_tail() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _sail_colors[0] if not _sail_colors.is_empty() else Color(0.92, 0.18, 0.14)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.7
	for i in TAIL_LEN:
		_tail_pts.append(Vector3.ZERO)
		var bead := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var w := lerpf(0.16, 0.05, float(i) / float(TAIL_LEN))
		bm.size = Vector3(w, 0.015, TAIL_SEG * 0.85)
		bead.mesh = bm
		bead.material_override = mat
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bead)
		_tail_meshes.append(bead)


func _build_line() -> void:
	_line_root = Node3D.new()
	_line_root.name = "Manjha"
	add_child(_line_root)
	_line_mat = StandardMaterial3D.new()
	_line_mat.albedo_color = Color(0.92, 0.22, 0.48) if _line_pink else Color(0.93, 0.88, 0.7)
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.disable_receive_shadows = true
	_line_mat.disable_fog = true
	for i in LINE_SEGS:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.006
		cyl.bottom_radius = 0.006
		cyl.height = 1.0
		cyl.radial_segments = 5
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _line_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_line_root.add_child(mi)
		_line_segs.append(mi)
		_line_cyls.append(cyl)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _place_segment(mi: MeshInstance3D, cyl: CylinderMesh, p0: Vector3, p1: Vector3, radius: float) -> void:
	var delta := p1 - p0
	var length := delta.length()
	if length < 0.001:
		mi.visible = false
		return
	mi.visible = true
	cyl.height = length
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	var up := delta / length
	var x_axis := up.cross(Vector3.RIGHT)
	if x_axis.length_squared() < 0.001:
		x_axis = up.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(up).normalized()
	mi.global_transform = Transform3D(Basis(x_axis, up, z_axis), (p0 + p1) * 0.5)
