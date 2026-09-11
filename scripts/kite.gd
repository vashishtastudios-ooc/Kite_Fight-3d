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
## Idle (no kheench): the line goes slack, the kite loses lift and settles
## down-wind on a slow glide. Tune the feel here.
const IDLE_SLACK_MAX := 0.62       ## how loose the manjha gets when left alone
const IDLE_SLACK_RATE := 0.5       ## slack built per second toward the max
const IDLE_SINK := 3.1             ## base sink accel (m/s²), scaled by slack
const IDLE_SINK_LOW_MUL := 1.3     ## sinks faster low in the weak, choppy air
const IDLE_SINK_HIGH_MUL := 0.7    ## the stronger high wind holds it up longer
const IDLE_DRIFT_LO := 0.45        ## down-wind push at a taut line
const IDLE_DRIFT_HI := 1.15        ## down-wind push when fully slack (a loose sail)
const IDLE_HEIGHT_SPAN := 45.0     ## altitude over which the layer blend runs
const IDLE_GROUND_SOFT := 9.0      ## metres over the deck where the sink eases off
const LINE_SEGS := 28
const TAIL_LEN := 18
const TAIL_SEG := 0.24
const KITE_SPAN := 1.55
const KITE_SHADER := preload("res://shaders/kite.gdshader")
const RIBBON_SHADER := preload("res://shaders/kite_ribbon.gdshader")
const TRAIL_SHADER := preload("res://shaders/kite_trail.gdshader")
const FLARE_SHADER := preload("res://shaders/rocket_flare.gdshader")
const KiteSkins := preload("res://scripts/kite_skins.gd")
const NOSE_MESH_H := 0.26

signal cut_down
signal manjha_changed(value: float)
signal pips_changed(pips: int)

var killed_by_rocket: bool = false
var pips: int = 0
var dash_t: float = 0.0
var steered_t: float = 0.0
var fight_pips: bool = false
var _fight_t: float = 0.0
const PIPS_MAX := 3
const DASH_TIME := 0.88

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
var sail_id: String = KiteSkins.SAFFRON
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
var _model_mats: Array[StandardMaterial3D] = []
var _outline_mi: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _nose_marker: MeshInstance3D
var _nose_mat: StandardMaterial3D
var _body: Node3D
var _line_root: Node3D
var _line_segs: Array[MeshInstance3D] = []
var _line_cyls: Array[CylinderMesh] = []
var _line_glows: Array[MeshInstance3D] = []
var _line_glow_cyls: Array[CylinderMesh] = []
var _tail_pts: Array[Vector3] = []
var _tail_draw: MeshInstance3D
var _tail_imm: ImmediateMesh
var _ribbon_mat: ShaderMaterial
var _visual_basis: Basis = Basis.IDENTITY
var _line_mat: StandardMaterial3D
var _line_glow_mat: StandardMaterial3D
var _speed_burst: GPUParticles3D
var _speed_trail: MeshInstance3D
var _trail_imm: ImmediateMesh
var _trail_mat: ShaderMaterial
var _trail_pts: Array[Vector3] = []
var _trail_age: Array[float] = []
const TRAIL_LIFE := 0.58
const TRAIL_MAX := 44


func setup(wind_in: WindSys, city_in: CityGen, colors: Array[Color] = [], skin: String = "") -> void:
	wind = wind_in
	city = city_in
	sail_id = KiteSkins.clamp_id(skin) if skin != "" else KiteSkins.SAFFRON
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
	pips = 0
	dash_t = 0.0
	_kheench = false
	_dheel = false
	global_position = hand_pos + Vector3(0.4, 0.2, -0.7)
	_reset_tail()
	_clear_speed_trail()
	manjha_changed.emit(manjha)
	pips_changed.emit(0)


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
	pips = 0
	dash_t = 0.0
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
	pips_changed.emit(pips)


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
		if pips >= PIPS_MAX and dash_t <= 0.0:
			pips = 0
			dash_t = DASH_TIME
			pips_changed.emit(pips)
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
	pips = 0
	dash_t = 0.0
	pips_changed.emit(0)
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
	pips = 0
	dash_t = 0.0
	pips_changed.emit(0)
	cut_down.emit()


func damage_manjha(amount: float) -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED:
		return
	manjha = clampf(manjha - amount, 0.0, 1.0)
	manjha_changed.emit(manjha)
	if manjha <= 0.0:
		apply_cut()


func add_pip() -> void:
	if not is_airborne() or phase == Phase.CUT:
		return
	var next := mini(PIPS_MAX, pips + 1)
	if next != pips:
		pips = next
		pips_changed.emit(pips)


func is_dashing() -> bool:
	return dash_t > 0.0


func is_kheenching() -> bool:
	return _kheench


func is_cut_ready() -> bool:
	return pips >= PIPS_MAX and dash_t <= 0.0


func is_slack_for_cut() -> bool:
	return phase == Phase.DHEEL or slack > 0.48


func steered_recently() -> bool:
	return steered_t > 0.0


func nose_dir() -> Vector3:
	var a := _sky_axes()
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	return (right * sin(heading) + up * cos(heading)).normalized()


func is_airborne() -> bool:
	return phase != Phase.GROUNDED and phase != Phase.CRASHED


func pack_net() -> Dictionary:
	var p := global_position
	var v := velocity
	var h := hand_pos
	return {
		"t": "state",
		"px": p.x, "py": p.y, "pz": p.z,
		"vx": v.x, "vy": v.y, "vz": v.z,
		"hx": h.x, "hy": h.y, "hz": h.z,
		"line": line_length,
		"phase": int(phase),
		"slack": slack,
		"heading": heading,
		"dash": dash_t,
		"pips": pips,
	}


func apply_net(d: Dictionary, delta: float) -> void:
	global_position = Vector3(float(d.get("px", 0.0)), float(d.get("py", 0.0)), float(d.get("pz", 0.0)))
	velocity = Vector3(float(d.get("vx", 0.0)), float(d.get("vy", 0.0)), float(d.get("vz", 0.0)))
	hand_pos = Vector3(float(d.get("hx", 0.0)), float(d.get("hy", 0.0)), float(d.get("hz", 0.0)))
	line_length = float(d.get("line", line_length))
	phase = int(d.get("phase", phase)) as Phase
	slack = float(d.get("slack", slack))
	heading = float(d.get("heading", heading))
	dash_t = float(d.get("dash", 0.0))
	pips = int(d.get("pips", pips))
	visible = true
	_orient_body(delta)
	_update_readability()
	_update_line()
	_update_tail(delta)


func tick(delta: float, hand: Vector3, viewer: Vector3, reel: float, bias: float) -> void:
	hand_pos = hand
	viewer_pos = viewer
	_bias = clampf(bias, -1.0, 1.0)
	_bob_t += delta
	if _kheench or _dheel:
		steered_t = 0.55
	else:
		steered_t = maxf(0.0, steered_t - delta)
	if dash_t > 0.0:
		dash_t = maxf(0.0, dash_t - delta)
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
	if fight_pips:
		_tick_fight_pips(delta)
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
	kick += clampf(along * 0.18, -2.5, 3.5)
	if dash_t > 0.0:
		kick *= 2.0
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


func _tick_fight_pips(delta: float) -> void:
	if not is_airborne() or phase == Phase.CUT or pips >= PIPS_MAX:
		return
	if altitude() < 12.0 or slack > 0.42:
		_fight_t = maxf(0.0, _fight_t - delta * 0.6)
		return
	var rate := 0.48
	if _kheench:
		rate = 0.95
	elif phase == Phase.FLY:
		rate = 0.72
	_fight_t += delta * rate
	if _fight_t >= 5.4:
		_fight_t = 0.0
		add_pip()


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

	## Left alone, the line pays no tension: it sags and the kite loses lift.
	slack = move_toward(slack, IDLE_SLACK_MAX, IDLE_SLACK_RATE * delta)
	tension = move_toward(tension, lerpf(9.0, 2.0, slack), delta * 8.0)

	var a := _sky_axes()
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	var orbit := right * cos(heading) * 1.15 + up * sin(heading) * 0.32

	## Wind layer: weak/choppy near the roof, strong/clean up high (from sample()).
	var alt := altitude()
	var height_t := clampf(alt / IDLE_HEIGHT_SPAN, 0.0, 1.0)
	## A slack kite is just a loose sail — the wind carries it down-wind. The
	## push grows as the line goes slack, and the high-altitude wind is already
	## stronger in w, so it naturally drifts faster near the zenith.
	var downwind := Vector3(w.x, 0.0, w.z) * lerpf(IDLE_DRIFT_LO, IDLE_DRIFT_HI, slack)
	downwind += right * _bias * 1.6
	var target := downwind + orbit
	target.y += sin(_bob_t * 2.2) * 0.25  ## a little flutter, not lift
	velocity = velocity.lerp(target, 2.1 * delta)

	## Gravity-fed sink, scaled by how slack the line is and by the air layer.
	## The lerp above damps it to a steady terminal glide, so it never nose-dives.
	var sink_mul := lerpf(IDLE_SINK_LOW_MUL, IDLE_SINK_HIGH_MUL, height_t)
	var ground_soft := clampf(alt / IDLE_GROUND_SOFT, 0.35, 1.0)
	velocity.y -= IDLE_SINK * slack * sink_mul * ground_soft * delta

	global_position += velocity * delta


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
	var wind_dir := Vector3(w.x, 0.0, w.z)
	var wind_mul := 1.0
	if wind_dir.length() > 0.25:
		wind_mul = lerpf(0.94, 1.08, clampf(nose.dot(wind_dir.normalized()) * 0.5 + 0.5, 0.0, 1.0))
	var dash_mul := 2.0 if dash_t > 0.0 else 1.0
	var cruise := nose * FLY_SPEED * wind_mul * dash_mul + Vector3(0.0, climb_bias * FLY_SPEED * dash_mul, 0.0)
	cruise += w * 0.22
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
	var heat := 1.0 if (pips >= PIPS_MAX or dash_t > 0.0) else float(pips) / float(PIPS_MAX)
	if heat > 0.04:
		lift = maxf(lift, 0.22 + heat * 0.55)
		rim = maxf(rim, 0.35 + heat * 1.1)
	if _sail_mat:
		_sail_mat.set_shader_parameter("lift", lift)
		_sail_mat.set_shader_parameter("rim", rim)
		if heat > 0.6:
			_sail_mat.set_shader_parameter("rim_color", Color(1.0, 0.32, 0.72))
		elif heat > 0.04:
			_sail_mat.set_shader_parameter("rim_color", Color(1.0, 0.72, 0.38))
		else:
			_sail_mat.set_shader_parameter("rim_color", Color(1.0, 0.84, 0.28) if is_ai else Color(1.0, 0.84, 0.28))
	var glow := Color(1.0, 0.84, 0.28)
	if heat > 0.6:
		glow = Color(1.0, 0.32, 0.72)
	elif heat > 0.04:
		glow = Color(1.0, 0.72, 0.38)
	for mat in _model_mats:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = maxf(far * 0.22, heat * 1.35)
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
			_line_mat.albedo_color = Color(1.0, 0.42, 0.72).lerp(Color(1.0, 0.78, 0.92), taut)
		else:
			_line_mat.albedo_color = Color(1.0, 0.88, 0.42).lerp(Color(1.0, 0.96, 0.72), taut)
		_line_mat.emission = _line_mat.albedo_color
		_line_mat.emission_energy_multiplier = lerpf(1.8, 2.8, taut)
	if _line_glow_mat:
		_line_glow_mat.albedo_color = Color(_line_mat.albedo_color, 0.22)
		_line_glow_mat.emission = _line_mat.albedo_color
		_line_glow_mat.emission_energy_multiplier = lerpf(1.4, 2.2, taut)
	## Thin thread that still reads at dusk — not a neon beam.
	var dist_cam := viewer_pos.distance_to((a + b) * 0.5)
	var r_hand := clampf(dist_cam * 0.000192, 0.00312, 0.009)
	var r_kite := clampf(dist_cam * 0.000144, 0.0024, 0.00696)
	for i in LINE_SEGS:
		var t0 := float(i) / float(LINE_SEGS)
		var t1 := float(i + 1) / float(LINE_SEGS)
		var p0 := _bezier(a, mid, b, t0)
		var p1 := _bezier(a, mid, b, t1)
		var radius := lerpf(r_hand, r_kite, t1)
		_place_segment(_line_segs[i], _line_cyls[i], p0, p1, radius)
		if i < _line_glows.size():
			_place_segment(_line_glows[i], _line_glow_cyls[i], p0, p1, radius * 1.7)


func _tail_anchor() -> Vector3:
	## Rear vertex of the sail in flight axes (local -Z).
	if _body:
		return _body.to_global(Vector3(0.0, 0.0, -KITE_SPAN * 0.50))
	return global_position - nose_dir() * (KITE_SPAN * 0.50)


func _update_tail(delta: float) -> void:
	if _tail_pts.is_empty():
		return
	var anchor := _tail_anchor()
	_tail_pts[0] = anchor
	var w := _wind_at(global_position)
	var hang := Vector3.DOWN * 4.2 + Vector3(w.x, 0.0, w.z) * 0.22
	var side := _visual_basis.x
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	for i in range(1, _tail_pts.size()):
		var prev: Vector3 = _tail_pts[i - 1]
		var flutter := sin(_bob_t * 8.5 + float(i) * 0.72) * 0.55
		var cur: Vector3 = _tail_pts[i] + (hang + side * flutter) * delta
		var to := cur - prev
		if to.length() < 0.001:
			to = Vector3.DOWN + -nose_dir() * 0.2
		_tail_pts[i] = prev + to.normalized() * TAIL_SEG
	_rebuild_tail_mesh()


func _reset_tail() -> void:
	var anchor := _tail_anchor() if _body else global_position
	var back := -nose_dir()
	for i in _tail_pts.size():
		_tail_pts[i] = anchor + (back * 0.15 + Vector3.DOWN * 0.85) * float(i) * TAIL_SEG
	_rebuild_tail_mesh()


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
	var used_glb := _attach_glb_sail()
	if not used_glb:
		_build_diamond_sail(accent)
		_add_nose_marker(accent)
	_build_tail()
	_build_line()
	_build_speed_fx()
	_reset_tail()


func set_sail(id: String) -> void:
	sail_id = KiteSkins.clamp_id(id)
	if _body == null:
		return
	for c in _body.get_children():
		if c == _speed_burst or c == _nose_marker:
			continue
		_body.remove_child(c)
		c.free()
	_model_mats.clear()
	_sail_mat = null
	_outline_mi = null
	_outline_mat = null
	if not _attach_glb_sail():
		_build_diamond_sail(_rim_accent())
	_rebuild_tail_mesh()


func _attach_glb_sail() -> bool:
	var scene := KiteSkins.scene_for(sail_id)
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		return false
	model.name = "Model"
	_body.add_child(model)
	## GLB stands in XY (Y = nose). Flight axes: +Z nose, +X span, +Y face.
	model.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	model.force_update_transform()
	var aabb := _world_aabb(model)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest < 0.05:
		longest = 1.0
	model.scale *= KITE_SPAN / longest
	model.force_update_transform()
	aabb = _world_aabb(model)
	model.global_position += _body.global_position - aabb.get_center()
	_unique_sail_mats(model)
	return true


func _unique_sail_mats(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.extra_cull_margin = 16.0
		var surf_count := mi.mesh.get_surface_count() if mi.mesh else 0
		for s in surf_count:
			var src := mi.get_active_material(s)
			if src == null:
				continue
			var mat := src.duplicate() as Material
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
				sm.emission_enabled = true
				_model_mats.append(sm)
			mi.set_surface_override_material(s, mat)
	for c in n.get_children():
		_unique_sail_mats(c)


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


func _build_diamond_sail(accent: Color) -> void:
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


func _add_nose_marker(accent: Color) -> void:
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


func _build_speed_fx() -> void:
	var flare := ShaderMaterial.new()
	flare.shader = FLARE_SHADER
	var spark := QuadMesh.new()
	spark.size = Vector2(0.22, 0.22)
	spark.material = flare

	_speed_burst = GPUParticles3D.new()
	_speed_burst.name = "KheenchBurst"
	_speed_burst.amount = 22
	_speed_burst.lifetime = 0.38
	_speed_burst.one_shot = false
	_speed_burst.explosiveness = 0.15
	_speed_burst.local_coords = true
	_speed_burst.emitting = false
	_speed_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_speed_burst.visibility_aabb = AABB(Vector3(-80.0, -80.0, -80.0), Vector3(160.0, 160.0, 160.0))
	_speed_burst.extra_cull_margin = 40.0
	var bpm := ParticleProcessMaterial.new()
	bpm.direction = Vector3(0.0, 0.0, -1.0)
	bpm.spread = 9.0
	bpm.initial_velocity_min = 4.0
	bpm.initial_velocity_max = 11.0
	bpm.gravity = Vector3.ZERO
	bpm.damping_min = 3.0
	bpm.damping_max = 6.0
	bpm.scale_min = 0.35
	bpm.scale_max = 0.85
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.97, 0.82, 0.95),
		Color(1.0, 0.72, 0.28, 0.55),
		Color(1.0, 0.35, 0.12, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	bpm.color_ramp = ramp
	_speed_burst.process_material = bpm
	_speed_burst.draw_pass_1 = spark
	_body.add_child(_speed_burst)
	_speed_burst.position = Vector3(0.0, 0.0, -KITE_SPAN * 0.50)

	_trail_mat = ShaderMaterial.new()
	_trail_mat.shader = TRAIL_SHADER
	_trail_imm = ImmediateMesh.new()
	_speed_trail = MeshInstance3D.new()
	_speed_trail.name = "KheenchTrail"
	_speed_trail.mesh = _trail_imm
	_speed_trail.material_override = _trail_mat
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
	var darting := (_kheench and phase == Phase.FLY) or dash_t > 0.0
	if _speed_burst:
		_speed_burst.emitting = darting
	if darting:
		var p := _tail_anchor()
		if _trail_pts.is_empty() or _trail_pts[_trail_pts.size() - 1].distance_squared_to(p) > 0.012:
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
	var core_w := clampf(dist * 0.00035, 0.018, 0.055)
	var glow_w := core_w * 3.2
	_add_trail_strip(glow_w, Color(1.0, 0.55, 0.12, 0.22), 0.55)
	_add_trail_strip(core_w, Color(1.0, 0.96, 0.78, 0.85), 1.0)


func _add_trail_strip(half_w: float, tint: Color, alpha_mul: float) -> void:
	var n := _trail_pts.size()
	_trail_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_mat)
	for idx in n:
		var p: Vector3 = _trail_pts[idx]
		var along: Vector3
		if idx < n - 1:
			along = _trail_pts[idx + 1] - p
		else:
			along = p - _trail_pts[idx - 1]
		if along.length_squared() < 0.00001:
			along = velocity if velocity.length_squared() > 0.00001 else Vector3(0.0, 0.0, -1.0)
		along = along.normalized()
		var to_cam := viewer_pos - p
		var side := along.cross(to_cam)
		if side.length_squared() < 0.05:
			side = along.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		var u := float(idx) / float(maxi(n - 1, 1))
		var age_t := 1.0 - clampf(_trail_age[idx] / TRAIL_LIFE, 0.0, 1.0)
		## Newest (at the kite, u=1) stays tight. Oldest tapers to a point.
		var half := half_w * lerpf(0.08, 1.0, u * u)
		side = side.normalized() * half
		var a := tint.a * alpha_mul * age_t * lerpf(0.15, 1.0, u)
		var col := Color(tint.r, tint.g, tint.b, clampf(a, 0.0, 1.0))
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(p + side)
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(p - side)
	_trail_imm.surface_end()


func _burst_speed_fx() -> void:
	if _speed_burst == null:
		return
	_speed_burst.restart()
	_speed_burst.emitting = true


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


func _rebuild_tail_mesh() -> void:
	if _tail_imm == null or _tail_draw == null:
		return
	_tail_draw.global_transform = Transform3D.IDENTITY
	_tail_imm.clear_surfaces()
	var n := _tail_pts.size()
	if n < 3:
		return
	var sw := KiteSkins.swatches_for(sail_id)
	var red: Color = sw[0]
	var gold: Color = sw[2] if sw.size() > 2 else Color(1.0, 0.78, 0.18)
	var cream := Color(0.98, 0.93, 0.82)
	var specs: Array = [
		{"off": 0.0, "w": 0.085, "col": gold, "cut": 0},
		{"off": -0.045, "w": 0.055, "col": red, "cut": 2},
		{"off": 0.045, "w": 0.048, "col": cream, "cut": 3},
	]
	for spec in specs:
		var last := n - 1 - int(spec["cut"])
		if last < 2:
			continue
		_tail_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _ribbon_mat)
		for i in (last + 1):
			var p: Vector3 = _tail_pts[i]
			var along: Vector3
			if i < last:
				along = _tail_pts[i + 1] - p
			else:
				along = p - _tail_pts[i - 1]
			if along.length_squared() < 0.00001:
				along = Vector3.DOWN
			along = along.normalized()
			var side := along.cross(Vector3.UP)
			if side.length_squared() < 0.0002:
				side = along.cross(_visual_basis.x if _visual_basis.x.length_squared() > 0.01 else Vector3.RIGHT)
			side = side.normalized()
			var u := float(i) / float(last)
			var half: float = float(spec["w"]) * lerpf(1.0, 0.12, u)
			var lat: float = float(spec["off"]) * lerpf(1.0, 0.25, u)
			p += side * lat
			var a := lerpf(0.95, 0.08, u * u)
			var col: Color = spec["col"]
			col.a = a
			_tail_imm.surface_set_color(col)
			_tail_imm.surface_add_vertex(p + side * half)
			_tail_imm.surface_set_color(col)
			_tail_imm.surface_add_vertex(p - side * half)
		_tail_imm.surface_end()


func _build_tail() -> void:
	_ribbon_mat = ShaderMaterial.new()
	_ribbon_mat.shader = RIBBON_SHADER
	_tail_imm = ImmediateMesh.new()
	_tail_draw = MeshInstance3D.new()
	_tail_draw.name = "PatangTail"
	_tail_draw.mesh = _tail_imm
	_tail_draw.material_override = _ribbon_mat
	_tail_draw.top_level = true
	_tail_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tail_draw.extra_cull_margin = 40.0
	add_child(_tail_draw)
	_tail_pts.clear()
	for _i in TAIL_LEN:
		_tail_pts.append(Vector3.ZERO)


func _build_line() -> void:
	_line_root = Node3D.new()
	_line_root.name = "Manjha"
	_line_root.top_level = true
	add_child(_line_root)
	_line_mat = StandardMaterial3D.new()
	_line_mat.albedo_color = Color(1.0, 0.42, 0.72) if _line_pink else Color(1.0, 0.88, 0.42)
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.disable_receive_shadows = true
	_line_mat.disable_fog = true
	_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mat.emission_enabled = true
	_line_mat.emission = _line_mat.albedo_color
	_line_mat.emission_energy_multiplier = 2.2
	_line_glow_mat = StandardMaterial3D.new()
	_line_glow_mat.albedo_color = Color(_line_mat.albedo_color, 0.22)
	_line_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_line_glow_mat.disable_receive_shadows = true
	_line_glow_mat.disable_fog = true
	_line_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_glow_mat.emission_enabled = true
	_line_glow_mat.emission = _line_mat.albedo_color
	_line_glow_mat.emission_energy_multiplier = 1.8
	_line_glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_line_glow_mat.render_priority = 1
	for i in LINE_SEGS:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0042
		cyl.bottom_radius = 0.0042
		cyl.height = 1.0
		cyl.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _line_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 80.0
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_line_root.add_child(mi)
		_line_segs.append(mi)
		_line_cyls.append(cyl)
		var glow_cyl := CylinderMesh.new()
		glow_cyl.top_radius = 0.0072
		glow_cyl.bottom_radius = 0.0072
		glow_cyl.height = 1.0
		glow_cyl.radial_segments = 8
		var glow_mi := MeshInstance3D.new()
		glow_mi.mesh = glow_cyl
		glow_mi.material_override = _line_glow_mat
		glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow_mi.extra_cull_margin = 80.0
		glow_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_line_root.add_child(glow_mi)
		_line_glows.append(glow_mi)
		_line_glow_cyls.append(glow_cyl)


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
