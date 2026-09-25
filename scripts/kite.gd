class_name Kite
extends Node3D

## Single-line fighter patang. Idle hangs and sways, then dies if left.
## Kheench = dart. Dheel = pay out, sag, and tumble. Q yanks it back.

enum Phase { GROUNDED, CLIMB, SPIN, FLY, DHEEL, CUT, CRASHED }

const LINE_MIN := 10.0
const LINE_MAX := 500.0
const LINE_START := 18.0
const CLIMB_SPEED := 9.0
const FLY_SPEED := 22.0
const SKY_ALT := 26.0
const IDLE_AIR_SPAN := 36.0     ## altitude where idle air becomes clean enough to sit
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
## Low, dirty roof air: a loose tailless fighter can't hang there — it wheels.
const WHEEL_RATE := TAU * 2.2      ## peak turns/s in the roof air (avg ≈1.3 after churn/dwell)
const WHEEL_SPINUP := 0.35         ## s after releasing Q before it is fully wheeling
const WHEEL_UP_DWELL := 0.5        ## rate multiplier as the nose sweeps straight up
const WHEEL_LOOP := 2.6            ## m/s the nose drags the kite round each turn
const LINE_SEGS := 28
const TAIL_LEN := 18
const TAIL_SEG := 0.24
const KITE_SPAN := 1.55
## Wind is the engine, never a brake. A dart runs at FLY_SPEED at the edge of
## the wind window and up to POWER_ZONE faster in its heart (downwind, a third
## of the way up the sky). A gust at the kite adds up to GUST_SURGE more and
## lifts it.
const POWER_ZONE := 0.15
const POWER_ZONE_ELEV := 0.55     ## rad above the horizon of the window's heart
const GUST_SURGE := 0.3
const GUST_LIFT := 4.0            ## m/s of climb in a full gust
const KITE_SHADER := preload("res://shaders/kite.gdshader")
const SPAR_SHADER := preload("res://shaders/kite_spar.gdshader")
const RIM_SHADER := preload("res://shaders/kite_rim.gdshader")
## Peak of the arched kaman on the spine — must match KAMAN_PEAK in patang.gdshaderinc.
const KAMAN_PEAK := 0.30
const FLEX_GRID := 12              ## subdivisions per sail quarter
const FLEX_STIFF := 150.0          ## spring stiffness of the tug
const FLEX_DAMP := 11.0            ## damping — ~20% overshoot, settles in ~0.4 s
const FLEX_KICK := 7.5             ## velocity added by a Q yank
const RIBBON_SHADER := preload("res://shaders/kite_ribbon.gdshader")
const TRAIL_SHADER := preload("res://shaders/kite_trail.gdshader")
const FLARE_SHADER := preload("res://shaders/rocket_flare.gdshader")
const PAPER_STREAM := preload("res://assets/audio/pure_phad_phad_paper_only.wav")
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

## Pech swipe: how fast this string slices sideways. A darting kite swings
## its whole string through the sky; E pays line out, which slides it too.
const DHEEL_SLICE := 11.0          ## m/s a running firki counts as
## Letting go of E: the kite settles back into its hover by itself. A tap is
## a quick duck; the longer the let-out, the longer the wobble before it holds.
const DHEEL_SETTLE_TAP := 0.22
const DHEEL_SETTLE_LONG := 0.9
const DHEEL_LONG := 1.5            ## seconds of E counted as a long let-out
var _dheel_t: float = 0.0
var _settle_t: float = 0.0

## AI thumka: a practised flyer flicks the nose round on purpose instead of
## waiting for the air to roll it. Only the rival uses this.
const STEER_RATE := 3.2            ## rad/s the nose can be flicked round
var _steer_on: bool = false
var _steer_heading: float = 0.0
var _line_mid: Vector3 = Vector3.ZERO

const WindSys := preload("res://scripts/wind_system.gd")
const MapBase := preload("res://scripts/map_base.gd")

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
## The other flyer's kite (AI or online). Paper kites carry no outline, except
## the rival's, which keeps a faint rim once it is far off so you can find it.
var is_rival: bool = false
## Upward air the map is giving the kite right now (ridge lift), m/s.
var lift_now: float = 0.0
## Tukkals: paper lanterns tied along the string under the kite at night.
const TUKKAL_COUNT := 4
const TUKKAL_GAP := 3.2            ## metres of string between lanterns
var _tukkals: Array[MeshInstance3D] = []
var sail_id: String = KiteSkins.SAFFRON
var viewer_pos: Vector3 = Vector3.ZERO
var _eye: Vector3 = Vector3.ZERO
var hand_pos: Vector3 = Vector3.ZERO
## Metres of line paid this second (firki + wind). HUD and spool use this.
var payout_rate: float = 0.0

var wind: WindSys
var city: MapBase

var _kheench: bool = false
var _dheel: bool = false
var _bias: float = 0.0
var _fly_heading: float = 0.35
var _climb_t: float = 0.0
var _bob_t: float = 0.0
var _idle_t: float = 0.0
var _idle_stall: float = 0.0
var _wheel: float = 0.0
var _flex_on: bool = false
var _tug: float = 0.0
var _tug_v: float = 0.0
var _flex_mats: Array[ShaderMaterial] = []
var _outline_smat: ShaderMaterial
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
var _paper: AudioStreamPlayer3D
const TRAIL_LIFE := 0.58
const TRAIL_MAX := 44


func setup(wind_in: WindSys, city_in: MapBase, colors: Array[Color] = [], skin: String = "") -> void:
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
	_idle_t = 0.0
	_idle_stall = 0.0
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
	_idle_t = 0.0
	_idle_stall = 0.0
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
		## The yank snaps the paper taut: kick the flex spring.
		_tug_v += FLEX_KICK
		_enter_fly()
		_burst_speed_fx()
		_play_paper()
	else:
		_stop_paper()
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
		_dheel_t = 0.0
	else:
		## Release stops the firki; the kite wobbles, then catches the air again.
		_settle_t = lerpf(DHEEL_SETTLE_TAP, DHEEL_SETTLE_LONG, clampf(_dheel_t / DHEEL_LONG, 0.0, 1.0))


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
	_stop_paper()
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


func damage_manjha(amount: float, fatal: bool = true) -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED:
		return
	manjha = clampf(manjha - amount, 0.0, 1.0)
	manjha_changed.emit(manjha)
	if fatal and manjha <= 0.0:
		apply_cut()


func mend_manjha(amount: float) -> void:
	if phase == Phase.CUT or manjha >= 1.0:
		return
	manjha = minf(1.0, manjha + amount)
	manjha_changed.emit(manjha)


func restore_manjha() -> void:
	if phase == Phase.CUT or phase == Phase.GROUNDED or phase == Phase.CRASHED:
		return
	manjha = 1.0
	manjha_changed.emit(manjha)


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


func is_biting() -> bool:
	return _kheench and slack < 0.42 and is_airborne() and phase != Phase.CUT


## Point the nose along a sky direction (AI only). Call stop_steer() to let go.
func steer_nose(dir: Vector3) -> void:
	var a := _sky_axes()
	var r: Vector3 = a["right"]
	var u: Vector3 = a["up"]
	_steer_heading = atan2(dir.dot(r), dir.dot(u))
	_steer_on = true


func stop_steer() -> void:
	_steer_on = false


func is_dheeling() -> bool:
	return _dheel and is_airborne() and phase != Phase.CUT


## Sideways speed of the string: the kite's motion across its own line.
func slice_speed() -> float:
	if not is_airborne() or phase == Phase.CUT:
		return 0.0
	var along := global_position - hand_pos
	var across := velocity
	if along.length_squared() > 0.01:
		along = along.normalized()
		across = velocity - along * velocity.dot(along)
	var v := across.length()
	if _dheel:
		v = maxf(v, DHEEL_SLICE)
	return v


## The string as drawn: a sagging curve.
func line_points(n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(n + 1)
	for i in n + 1:
		out[i] = line_point(float(i) / float(n))
	return out


func line_point(t: float) -> Vector3:
	var a := hand_pos
	var b := global_position
	if _line_mid == Vector3.ZERO:
		return a.lerp(b, t)
	return _bezier(a, _line_mid, b, t)


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
		"q": 1 if _kheench else 0,
		"e": 1 if _dheel else 0,
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
	_kheench = int(d.get("q", 0)) != 0
	_dheel = int(d.get("e", 0)) != 0
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
	_update_flex(delta)
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
	if phase != Phase.SPIN:
		_wheel = move_toward(_wheel, 0.0, delta * 4.0)
	_update_wheel_audio()

	## Ridge lift: wind blowing up a slope carries the kite up with it.
	lift_now = city.lift_at(global_position) if city else 0.0
	if lift_now > 0.0:
		global_position.y += lift_now * delta
		if velocity.y < 0.0:
			velocity.y = move_toward(velocity.y, 0.0, lift_now * 2.0 * delta)
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
	var kick := FLY_SPEED * _wind_power()
	if dash_t > 0.0:
		kick *= 2.0
	velocity = nose * kick + Vector3.UP * 2.2
	tension = 28.0
	_idle_t = 0.0
	_idle_stall = 0.0


func _enter_spin() -> void:
	phase = Phase.SPIN
	slack = maxf(slack, 0.12)
	tension = 4.0
	_idle_t = 0.0
	_idle_stall = 0.0


func _idle_air() -> float:
	## 0 = dirty roof layer (wants up, cannot hold). 1 = clean high air.
	var t := clampf(altitude() / IDLE_AIR_SPAN, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	## Fighting up through the roof air: it waggles, it doesn't rise like a lift.
	var waggle := sin(_bob_t * 6.3) * 0.30 + sin(_bob_t * 11.0) * 0.10
	heading = lerp_angle(heading, 0.4 + waggle, 4.0 * delta)
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

	var air := _idle_air()
	_idle_t += delta
	## Dirty roof air: the paper can't hold its nose up, so it wheels. Clean
	## high air lets it hang and sway. Buildings close by churn it harder.
	var chop_b := city.nearest_building_chop(global_position) if city else 0.0
	var rough := clampf((1.0 - air) * (0.95 + 0.3 * chop_b), 0.0, 1.0)
	var spin_up := clampf(_idle_t / WHEEL_SPINUP, 0.0, 1.0)
	spin_up = spin_up * spin_up * (3.0 - 2.0 * spin_up)
	var wheel := rough * spin_up
	_wheel = wheel
	## Living hang, then the hover dies. Low/slow air dies first.
	var hang := lerpf(2.0, 7.2, air)
	var die := lerpf(5.0, 13.0, air)
	var stall := 0.0
	if _idle_t > hang:
		var u := clampf((_idle_t - hang) / maxf(die - hang, 0.5), 0.0, 1.0)
		stall = u * u * (3.0 - 2.0 * u)
	_idle_stall = stall

	var slack_max := lerpf(IDLE_SLACK_MAX, 0.88, stall)
	slack = move_toward(slack, slack_max, IDLE_SLACK_RATE * (1.0 + stall * 0.8) * delta)
	tension = move_toward(tension, lerpf(9.0, 1.2, slack), delta * 8.0)

	var a := _sky_axes()
	var right: Vector3 = a["right"]
	var up: Vector3 = a["up"]
	var wind_hz := Vector3(w.x, 0.0, w.z)
	var lat := 0.0
	if wind_hz.length() > 0.15:
		lat = clampf(wind_hz.dot(right) / 9.4, -1.0, 1.0)
	var gust := wind.gust_at(global_position) if wind else 0.0
	if wheel >= 0.3:
		## Once wheeling it keeps its turn; only your hand can reverse it.
		if absf(_bias) > 0.12:
			spin_dir = signf(_bias)
	elif stall < 0.18:
		if absf(lat) > 0.14:
			spin_dir = signf(lat)
		elif absf(_bias) > 0.12:
			spin_dir = signf(_bias)

	var sway_amp := lerpf(0.62, 0.18, air)
	var lean_lim := lerpf(0.95, 0.40, air)
	var wander := sin(_bob_t * lerpf(1.85, 1.15, air) + lat * 0.4)
	var chop := sin(_bob_t * lerpf(4.6, 2.2, air)) * sin(_bob_t * 0.73)
	var home := lat * sway_amp * 0.40
	home += wander * sway_amp * 0.70
	home += chop * sway_amp * lerpf(0.85, 0.18, air)
	var gust_lean := clampf(gust * 0.055, 0.0, 0.22)
	if absf(lat) > 0.08:
		home += gust_lean * signf(lat)
	else:
		home += gust_lean * signf(wander if absf(wander) > 0.05 else spin_dir)
	## Untended: nose droops, then a slow roll. Not a parked weathercock.
	home += stall * lerpf(1.55, 0.80, air) * spin_dir
	var lim := lerpf(lean_lim, PI * 0.94, stall)
	home = clampf(home, -lim, lim)

	var center := lerpf(0.14, 0.42, air) * (1.0 - stall * 0.9) * (1.0 - wheel)
	var roll := stall * stall * lerpf(0.92, 0.26, air) * spin_dir
	## Wheel rate: surges and stutters with the churn, and slows as the nose
	## sweeps up — the paper catches the wind for a beat. That beat is the
	## window to time a Q.
	var surge := 0.86 + 0.24 * sin(_bob_t * 3.1 + chop_b * 2.0) + 0.16 * sin(_bob_t * 7.7)
	var near_up := 1.0 - smoothstep(0.2, 1.0, absf(heading))
	var wheel_rate := WHEEL_RATE * wheel * maxf(surge, 0.35)
	wheel_rate *= lerpf(1.0, WHEEL_UP_DWELL, near_up) * lerpf(0.8, 1.1, slack)
	if gust > 0.22:
		wheel_rate *= 1.0 + gust * 0.12
	var ang_target := spin_dir * wheel_rate + roll * (1.0 - wheel)
	ang_vel = move_toward(ang_vel, ang_target, lerpf(lerpf(2.0, 6.5, air), 16.0, wheel) * delta)
	heading = lerp_angle(heading, home, clampf(center * delta, 0.0, 1.0))
	heading += ang_vel * delta
	if gust > 0.28:
		heading += spin_dir * gust * (0.06 + stall * 0.12) * delta
	if _steer_on:
		ang_vel = move_toward(ang_vel, 0.0, 8.0 * delta)
		heading = rotate_toward(heading, _steer_heading, STEER_RATE * delta)
	heading = wrapf(heading, -PI, PI)
	if not _steer_on and stall < 0.32 and wheel < 0.2 and absf(heading) > lean_lim:
		heading = move_toward(heading, signf(heading) * lean_lim * 0.92, 2.4 * delta)

	var alt := altitude()
	var height_t := clampf(alt / IDLE_HEIGHT_SPAN, 0.0, 1.0)
	var downwind := Vector3(w.x, 0.0, w.z) * lerpf(IDLE_DRIFT_LO, IDLE_DRIFT_HI, slack)
	downwind += right * _bias * 1.6
	var slide := right * sin(heading) * lerpf(1.35, 0.55, air)
	var bob := up * (sin(_bob_t * 2.1) * lerpf(0.42, 0.16, air) + sin(_bob_t * 3.4) * lerpf(0.20, 0.05, air))
	bob *= (1.0 - stall * 0.75)
	if gust > 0.22:
		bob += Vector3.UP * gust * 0.08 * (1.0 - stall)
		slide += right * lat * gust * 0.08
	## Wheeling, the nose drags the kite round a small loop every turn — it
	## thrashes in place rather than pivoting like a propeller.
	var loop := nose_dir() * WHEEL_LOOP * wheel * (1.0 - slack * 0.45)
	var target := downwind + slide * (1.0 - wheel * 0.6) + bob * (1.0 - wheel * 0.7) + loop
	target.y += sin(_bob_t * 2.2) * 0.12 * (1.0 - stall * 0.6)
	velocity = velocity.lerp(target, lerpf(lerpf(2.1, 1.35, stall), 3.4, wheel) * delta)

	var sink_mul := lerpf(IDLE_SINK_LOW_MUL, IDLE_SINK_HIGH_MUL, height_t)
	var ground_soft := clampf(alt / IDLE_GROUND_SOFT, 0.35, 1.0)
	ground_soft = lerpf(ground_soft, 1.0, stall)
	var stall_sink := 1.0 + stall * lerpf(2.6, 1.2, air)
	velocity.y -= IDLE_SINK * slack * sink_mul * ground_soft * stall_sink * delta
	if gust > 0.22:
		velocity.y -= gust * lerpf(0.85, 0.28, air) * (0.25 + stall * 0.9) * delta

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
	## A dart goes where the nose points, at full speed whichever way the wind
	## blows — the wind only ever adds (power zone, gusts), never shoves.
	var dash_mul := 2.0 if dash_t > 0.0 else 1.0
	var speed := FLY_SPEED * _wind_power() * dash_mul
	var cruise := nose * speed + Vector3(0.0, climb_bias * FLY_SPEED * dash_mul, 0.0)
	var g := _gust01()
	if g > 0.02:
		## Gust: the kite surges and climbs, with a tremble in the paper.
		cruise.y += g * GUST_LIFT
		heading += sin(_bob_t * 16.0) * 0.01 * g * delta
	cruise += Vector3(sin(_bob_t * 7.0), cos(_bob_t * 5.4), sin(_bob_t * 6.1)) * 0.7
	velocity = velocity.lerp(cruise, 8.2 * delta)
	global_position += velocity * delta
	tension = move_toward(tension, 34.0 + w.length() * 1.2, delta * 40.0)


func _tick_dheel(delta: float, w: Vector3) -> void:
	if _kheench:
		_enter_fly()
		return
	if _dheel:
		_dheel_t += delta
		slack = move_toward(slack, 1.0, delta * 1.8)
	else:
		## Settling: the line firms up and the sink eases until it hovers.
		_settle_t -= delta
		slack = move_toward(slack, 0.3, delta * 1.6)
		if _settle_t <= 0.0:
			_enter_spin()
			return
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
		## A taut line only stops the kite flying further out. Across the sky
		## it keeps full speed — a tight line is where a kite flies sharpest.
		var n := to_kite / dist
		var pull_back := (dist - max_len) * clampf(9.0 * delta, 0.0, 1.0)
		global_position -= n * pull_back
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward * lerpf(1.0, 0.6, slack)


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
	if city.is_solid(global_position):
		_crash()


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
		var air := _idle_air()
		var roll := sin(_bob_t * lerpf(7.5, 3.5, air)) * lerpf(0.16, 0.05, air)
		roll += _idle_stall * sin(_bob_t * 2.4) * 0.12
		## Thrashing low: the paper buckles and flutters as it wheels.
		roll += sin(_bob_t * 21.0) * 0.08 * _wheel
		target = target.rotated(face, roll)
		target = target.rotated(x_axis, sin(_bob_t * 13.0) * 0.10 * _wheel)
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
	var dist := _eye_pos().distance_to(global_position)
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
	## Paper kites: no outline. Only the rival keeps a rim, and only far off.
	## A charged dash still glows on anyone's kite.
	var paper := KiteSkins.is_patang(sail_id)
	var outline_a := lerpf(0.22, 0.72, far)
	var outline_g := lerpf(0.12, 1.15, far)
	if paper:
		var far_rim := far * 0.45 if is_rival else 0.0
		rim = far_rim
		outline_a = far * 0.55 if is_rival else 0.0
		outline_g = far * 1.0 if is_rival else 0.0
		if heat > 0.04:
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
	if _outline_smat:
		_outline_smat.set_shader_parameter("alpha", outline_a)
		_outline_smat.set_shader_parameter("glow", outline_g)
	if _outline_mi and paper:
		_outline_mi.visible = outline_a > 0.01
	if _nose_marker:
		## Small tip pointer: a backup for reading direction when the kite is a
		## speck; the curved kaman does the work up close.
		var grow := dist * lerpf(0.0024, 0.0036, player_boost)
		var s := 1.0
		if airborne:
			s = clampf(grow / NOSE_MESH_H, 1.0, 5.0)
		_nose_marker.scale = Vector3.ONE * s
		if _nose_mat:
			_nose_mat.emission_energy_multiplier = lerpf(0.35, 1.6, far)


## Hang (or take down) the night lanterns on this kite's string.
func set_tukkals(on: bool) -> void:
	for t in _tukkals:
		t.queue_free()
	_tukkals.clear()
	if not on:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.70, 0.34)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.28)
	m.emission_energy_multiplier = 4.5
	for i in TUKKAL_COUNT:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.4, 0.28)
		mi.mesh = box
		mi.material_override = m
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Tukkal%d" % i
		add_child(mi)
		_tukkals.append(mi)


func _update_tukkals(on: bool) -> void:
	if _tukkals.is_empty():
		return
	var length := hand_pos.distance_to(global_position)
	var eye := _eye_pos()
	for i in _tukkals.size():
		var t := _tukkals[i]
		t.visible = on and length > 6.0
		if not t.visible:
			continue
		## Strung down the line from the kite, each swinging a little below it.
		var along := 1.0 - (TUKKAL_GAP * float(i + 1)) / maxf(length, 1.0)
		var p := line_point(clampf(along, 0.0, 1.0)) + Vector3.DOWN * 0.45
		p += Vector3(sin(_bob_t * 1.7 + float(i)), 0.0, cos(_bob_t * 1.3 + float(i))) * 0.08
		t.global_position = p
		## Grow with distance so a far kite still shows its lights.
		var s := clampf(eye.distance_to(p) * 0.012, 1.0, 7.0)
		t.scale = Vector3.ONE * s


func _update_line() -> void:
	if _line_segs.is_empty():
		return
	if phase == Phase.GROUNDED or phase == Phase.CUT:
		_line_root.visible = false
		_update_tukkals(false)
		return
	var a := hand_pos
	var b := global_position
	var length := a.distance_to(b)
	if length < 0.08:
		_line_root.visible = false
		return
	_line_root.visible = true
	_update_tukkals(true)
	var taut := (1.0 - slack) * clampf(tension / 28.0, 0.0, 1.0)
	var sag := lerpf(length * 0.09, length * 0.006, taut)
	var mid := (a + b) * 0.5 + Vector3.DOWN * sag
	var w := _wind_at(mid)
	var wf := Vector3(w.x, 0.0, w.z)
	if wf.length() > 0.2:
		mid += wf.normalized() * (length * 0.02 * slack)
	_line_mid = mid
	if _line_mat:
		if _line_pink:
			_line_mat.albedo_color = Color(1.0, 0.42, 0.72).lerp(Color(1.0, 0.78, 0.92), taut)
		else:
			_line_mat.albedo_color = Color(1.0, 0.88, 0.42).lerp(Color(1.0, 0.96, 0.72), taut)
		var wear := 1.0 - clampf(manjha, 0.0, 1.0)
		if wear > 0.08:
			var hot := Color(1.0, 0.93, 0.78)
			_line_mat.albedo_color = _line_mat.albedo_color.lerp(hot, wear * 0.7)
		_line_mat.emission = _line_mat.albedo_color
		_line_mat.emission_energy_multiplier = lerpf(1.8, 2.8, taut) + wear * 1.1
	if _line_glow_mat and _line_mat:
		_line_glow_mat.albedo_color = Color(_line_mat.albedo_color, 0.22)
		_line_glow_mat.emission = _line_mat.albedo_color
		_line_glow_mat.emission_energy_multiplier = lerpf(1.4, 2.2, taut)
	## Thin thread that still reads at dusk. Worn manjha reads thinner. Each
	## end of each piece is sized by its own distance from the eye, so the
	## string is a hair at your hands and still visible far out.
	var eye := _eye_pos()
	var wear_r := lerpf(1.0, 0.48, 1.0 - clampf(manjha, 0.0, 1.0))
	## Past a quarter worn the glass coat is gone in patches: the thread goes
	## knotty, thick and thin, so you can see a string that is about to go.
	var fray := clampf((1.0 - manjha - 0.25) / 0.6, 0.0, 1.0)
	for i in LINE_SEGS:
		var t0 := float(i) / float(LINE_SEGS)
		var t1 := float(i + 1) / float(LINE_SEGS)
		var p0 := line_point(t0)
		var p1 := line_point(t1)
		var r0 := _thread_radius(eye.distance_to(p0), t0) * wear_r
		var r1 := _thread_radius(eye.distance_to(p1), t1) * wear_r
		if fray > 0.0:
			var h := fposmod(sin(float(i) * 12.9898 + 4.1) * 43758.5453, 1.0)
			var f := lerpf(1.0, 0.3 if h < 0.4 else 1.25, fray)
			r0 *= f
			r1 *= f
		_place_segment(_line_segs[i], _line_cyls[i], p0, p1, r0, r1)
		if i < _line_glows.size():
			_place_segment(_line_glows[i], _line_glow_cyls[i], p0, p1, r0 * 1.7, r1 * 1.7)


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


## 1.0 at the edge of the wind window, up to 1 + POWER_ZONE in its heart,
## times the gust surge at the kite. Never below 1.
func _wind_power() -> float:
	var p := 1.0
	if wind:
		var to_kite := global_position - hand_pos
		if to_kite.length_squared() > 1.0:
			var d := wind.wind_dir()
			var heart := (d * cos(POWER_ZONE_ELEV) + Vector3.UP * sin(POWER_ZONE_ELEV)).normalized()
			var z := smoothstep(0.55, 1.0, to_kite.normalized().dot(heart))
			p += POWER_ZONE * z
	return p * (1.0 + GUST_SURGE * _gust01())


func _gust01() -> float:
	return wind.gust01_at(global_position) if wind else 0.0


## Where the picture is seen from right now. Sizes that grow with distance
## (nose pip, string, speed streak) must use this, not the flyer's roof —
## otherwise the kite cam, a metre behind the kite, draws them roof-sized.
func _eye_pos() -> Vector3:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam:
		return cam.global_position
	return viewer_pos


func _wind_at(pos: Vector3) -> Vector3:
	if wind == null:
		return Vector3(0.0, 0.0, -8.0)
	var chop := 0.0
	if city:
		chop = city.nearest_building_chop(pos)
	return wind.sample(pos, chop, not is_ai)


func _rim_accent() -> Color:
	if _sail_colors.is_empty() and not KiteSkins.is_patang(sail_id):
		return Color(1.0, 0.84, 0.28)
	var c: Color = KiteSkins.palette_for(sail_id)[0] if KiteSkins.is_patang(sail_id) else _sail_colors[0]
	if c.g > c.r + 0.08:
		return Color(0.72, 1.0, 0.32)
	return Color(1.0, 0.84, 0.28)


func _build_paper_audio() -> void:
	if is_ai:
		return
	_paper = AudioStreamPlayer3D.new()
	_paper.name = "PaperFlutter"
	_paper.stream = PAPER_STREAM
	_paper.bus = "SFX"
	_paper.volume_db = 2.0
	_paper.max_db = 2.0
	_paper.unit_size = 26.0
	_paper.max_distance = 0.0
	_paper.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_paper.attenuation_filter_cutoff_hz = 7200.0
	_paper.attenuation_filter_db = -10.0
	_paper.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	_paper.panning_strength = 0.7
	add_child(_paper)
	_paper.finished.connect(_on_paper_finished)


func _play_paper() -> void:
	if is_ai or _paper == null:
		return
	_paper.volume_db = 2.0
	_paper.pitch_scale = randf_range(0.97, 1.04)
	_paper.play()


func _update_wheel_audio() -> void:
	## A kite thrashing low in the roof air goes "phad-phad" — quieter and
	## busier than the full crack of a kheench.
	if is_ai or _paper == null or _kheench:
		return
	if _wheel > 0.45 and not _paper.playing:
		_paper.play()
	if _paper.playing:
		_paper.volume_db = lerpf(-24.0, -6.0, clampf(_wheel, 0.0, 1.0))
		_paper.pitch_scale = lerpf(0.9, 1.16, _wheel)
		if _wheel < 0.12:
			_paper.stop()


func _stop_paper() -> void:
	if _paper and _paper.playing:
		_paper.stop()


func _on_paper_finished() -> void:
	if is_ai or _paper == null:
		return
	if _kheench or _wheel > 0.45:
		_paper.play()


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
	_build_paper_audio()
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
	_outline_smat = null
	_flex_on = false
	_flex_mats.clear()
	var painted := not _attach_glb_sail()
	if painted:
		var accent := _rim_accent()
		_build_diamond_sail(accent)
		if _nose_marker == null:
			_add_nose_marker(accent)
		elif _nose_mat:
			_nose_mat.albedo_color = accent
			_nose_mat.emission = accent
	if _nose_marker:
		_nose_marker.visible = painted
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
	## Every paper kite flexes on its frame; the sculpted GLB sails do not.
	_flex_on = KiteSkins.is_patang(sail_id)
	_flex_mats.clear()
	_outline_smat = null
	var sail := MeshInstance3D.new()
	sail.mesh = _make_diamond_fine() if _flex_on else _make_diamond()
	sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sail.extra_cull_margin = 12.0
	_sail_mat = ShaderMaterial.new()
	_sail_mat.shader = KITE_SHADER
	_sail_mat.set_shader_parameter("lift", 0.0)
	_sail_mat.set_shader_parameter("rim", 0.0)
	_sail_mat.set_shader_parameter("rim_color", accent)
	var pat := KiteSkins.pattern_for(sail_id)
	_sail_mat.set_shader_parameter("pattern", pat)
	_sail_mat.set_shader_parameter("kaman_arch", _arch_flag())
	if pat > 0:
		var pal := KiteSkins.palette_for(sail_id)
		for i in 4:
			_sail_mat.set_shader_parameter("col%d" % i, pal[i])
	sail.material_override = _sail_mat
	sail.sorting_offset = 0.05
	_body.add_child(sail)
	if _flex_on:
		_flex_mats.append(_sail_mat)
		_build_flex_frame(accent)
		return
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
	if KiteSkins.has_kaman_arch(sail_id):
		var bow := MeshInstance3D.new()
		bow.mesh = _make_bow_mesh(0.014)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.42, 0.28, 0.14)
		wood.roughness = 0.8
		wood.cull_mode = BaseMaterial3D.CULL_DISABLED
		bow.material_override = wood
		_body.add_child(bow)
	else:
		_add_spar(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 1.15, 0.014)


## Rim + bamboo frame that bend with the paper (shared flex shader include).
func _build_flex_frame(accent: Color) -> void:
	_outline_mat = null
	_outline_mi = MeshInstance3D.new()
	_outline_mi.mesh = _make_ring_fine(16)
	_outline_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline_mi.extra_cull_margin = 12.0
	_outline_smat = ShaderMaterial.new()
	_outline_smat.shader = RIM_SHADER
	_outline_smat.set_shader_parameter("rim_col", accent)
	_outline_smat.set_shader_parameter("kaman_arch", _arch_flag())
	_outline_mi.material_override = _outline_smat
	_outline_mi.position = Vector3(0.0, 0.02, 0.0)
	_body.add_child(_outline_mi)
	_flex_mats.append(_outline_smat)
	_add_flex_spars()


func _add_flex_spars() -> void:
	var spar_mat := ShaderMaterial.new()
	spar_mat.shader = SPAR_SHADER
	spar_mat.set_shader_parameter("kaman_arch", _arch_flag())
	_flex_mats.append(spar_mat)
	var half := KITE_SPAN * 0.5
	var spine: ArrayMesh
	if KiteSkins.has_kaman_arch(sail_id):
		## Frame on the flyer's side of the paper, as on a real patang.
		var pts := PackedVector3Array()
		for i in 25:
			var z := lerpf(-half, half, float(i) / 24.0)
			pts.append(Vector3(0.0, _paper_y(0.0, z) + 0.021, z))
		spine = _make_tube_path(pts, 0.016)
	else:
		spine = _make_tube(Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, half), 0.016, 24)
	var bow := _make_bow_mesh(0.014)
	for mesh in [spine, bow]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = spar_mat
		mi.extra_cull_margin = 12.0
		_body.add_child(mi)


func _arch_flag() -> float:
	return 1.0 if KiteSkins.has_kaman_arch(sail_id) else 0.0


func _kaman_z(x: float) -> float:
	var t := clampf(x / 0.58, -1.0, 1.0)
	return 0.02 + (KAMAN_PEAK - 0.02) * (1.0 - t * t)


## The bow: an arch bowed toward the nose, or the old straight cross stick.
func _make_bow_mesh(r: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var n := 24
	var arch := KiteSkins.has_kaman_arch(sail_id)
	for i in n + 1:
		var x := lerpf(-0.575, 0.575, float(i) / float(n))
		if arch:
			## Riding the flyer's face of the paper.
			var z := _kaman_z(x)
			pts.append(Vector3(x, _paper_y(x, z) + r + 0.005, z))
		else:
			pts.append(Vector3(x, 0.0, 0.0))
	return _make_tube_path(pts, r)


## Height of the paper surface (the sail rises to a shallow peak at the centre).
func _paper_y(x: float, z: float) -> float:
	var qx := absf(x / 0.58)
	var dz := z - 0.02
	var qy := absf(dz / (0.76 if dz > 0.0 else 0.64))
	return 0.08 * maxf(0.0, 1.0 - qx - qy)


func _update_flex(delta: float) -> void:
	if not _flex_on or _flex_mats.is_empty():
		return
	## How taut the line holds the paper in each phase.
	var target := 0.15
	match phase:
		Phase.FLY:
			target = 1.0
		Phase.CLIMB:
			target = 0.55
		Phase.SPIN:
			target = 0.42 - 0.3 * slack
		Phase.DHEEL:
			target = 0.05
	## Underdamped spring: a yank snaps, overshoots, settles.
	var dt := minf(delta, 1.0 / 30.0)
	_tug_v += (FLEX_STIFF * (target - _tug) - FLEX_DAMP * _tug_v) * dt
	_tug += _tug_v * dt
	var bow := clampf(0.3 + 0.8 * _tug, 0.0, 1.6)
	var billow := clampf(0.25 + 0.9 * _tug, 0.0, 1.7)
	var flutter := 0.2 + clampf(absf(_tug_v) * 0.06, 0.0, 0.5)
	match phase:
		Phase.FLY:
			flutter += 0.25 + clampf(velocity.length() / 40.0, 0.0, 0.4)
		Phase.SPIN:
			flutter += _wheel * 0.7 + slack * 0.2
		Phase.DHEEL:
			flutter += 0.5 + slack * 0.5
	flutter = clampf(flutter, 0.0, 1.4)
	for m in _flex_mats:
		m.set_shader_parameter("flex_bow", bow)
		m.set_shader_parameter("flex_billow", billow)
		m.set_shader_parameter("flex_flutter", flutter)


func _add_nose_marker(accent: Color) -> void:
	_nose_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.002
	cone.bottom_radius = 0.038
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
	var eye := _eye_pos()
	var dist := eye.distance_to(global_position)
	var core_w := clampf(dist * 0.00035, 0.018, 0.055)
	var glow_w := core_w * 3.2
	_add_trail_strip(glow_w, Color(1.0, 0.55, 0.12, 0.22), 0.55)
	_add_trail_strip(core_w, Color(1.0, 0.96, 0.78, 0.85), 1.0)


func _add_trail_strip(half_w: float, tint: Color, alpha_mul: float) -> void:
	_eye = _eye_pos()
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
		var to_cam := _eye - p
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
	if KiteSkins.is_patang(sail_id):
		## The shader paints the design; vertex colour only darkens the back.
		c = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
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


## Same sail as _make_diamond, finely gridded so the paper can bend.
func _make_diamond_fine() -> ArrayMesh:
	var bow := Vector3(0.0, 0.08, 0.04)
	var tips: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.78),
		Vector3(0.58, 0.0, 0.02),
		Vector3(0.0, 0.0, -0.62),
		Vector3(-0.58, 0.0, 0.02),
	]
	var n := FLEX_GRID
	var front := Color.WHITE
	var back := Color.WHITE.darkened(0.08)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in 4:
		var a: Vector3 = tips[q]
		var b: Vector3 = tips[(q + 1) % 4]
		for i in n:
			for j in n - i:
				var p00 := _bary(bow, a, b, i, j, n)
				var p10 := _bary(bow, a, b, i + 1, j, n)
				var p01 := _bary(bow, a, b, i, j + 1, n)
				_add_tri(st, p00, p10, p01, front)
				_add_tri(st, p00, p01, p10, back)
				if i + j + 2 <= n:
					var p11 := _bary(bow, a, b, i + 1, j + 1, n)
					_add_tri(st, p10, p11, p01, front)
					_add_tri(st, p10, p01, p11, back)
	## The shader derives the true face normal itself.
	st.generate_normals()
	return st.commit()


func _bary(o: Vector3, a: Vector3, b: Vector3, i: int, j: int, n: int) -> Vector3:
	return o + (a - o) * (float(i) / float(n)) + (b - o) * (float(j) / float(n))


func _make_ring_fine(segs: int) -> ArrayMesh:
	var tips: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.78),
		Vector3(0.58, 0.0, 0.02),
		Vector3(0.0, 0.0, -0.62),
		Vector3(-0.58, 0.0, 0.02),
	]
	var center := Vector3(0.0, 0.0, 0.08)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in 4:
		var a := tips[e]
		var b := tips[(e + 1) % 4]
		var ai := center + (a - center) * 0.985
		var bi := center + (b - center) * 0.985
		var ao := center + (a - center) * 1.10
		var bo := center + (b - center) * 1.10
		for s in segs:
			var t0 := float(s) / float(segs)
			var t1 := float(s + 1) / float(segs)
			var i0 := ai.lerp(bi, t0)
			var i1 := ai.lerp(bi, t1)
			var o0 := ao.lerp(bo, t0)
			var o1 := ao.lerp(bo, t1)
			_add_tri(st, i0, o0, o1, Color.WHITE)
			_add_tri(st, i0, o1, i1, Color.WHITE)
	st.generate_normals()
	return st.commit()


## A straight bamboo stick from a to b, in the sail's own space, segmented so it bends.
func _make_tube(a: Vector3, b: Vector3, r: float, segs: int) -> ArrayMesh:
	var pts := PackedVector3Array()
	for s in segs + 1:
		pts.append(a.lerp(b, float(s) / float(segs)))
	return _make_tube_path(pts, r)


## A bamboo stick along any path (the arched bow), six-sided, following its curve.
func _make_tube_path(pts: PackedVector3Array, r: float) -> ArrayMesh:
	var sides := 6
	var rings: Array = []
	for i in pts.size():
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var u := tangent.cross(Vector3.UP)
		if u.length_squared() < 0.01:
			u = tangent.cross(Vector3.RIGHT)
		u = u.normalized()
		var v := tangent.cross(u).normalized()
		var ring: Array[Vector3] = []
		for k in sides:
			ring.append(u * cos(TAU * k / sides) + v * sin(TAU * k / sides))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		for k in sides:
			var k1 := (k + 1) % sides
			for pv in [[pts[i], r0[k]], [pts[i + 1], r1[k]], [pts[i + 1], r1[k1]], [pts[i], r0[k]], [pts[i + 1], r1[k1]], [pts[i], r0[k1]]]:
				st.set_normal(pv[1])
				st.add_vertex(pv[0] + pv[1] * r)
	return st.commit()


func _make_outline_diamond() -> ArrayMesh:
	## A glowing rim just outside the sail — it keeps a far kite readable
	## without laying a tinted film over the paper's design.
	var tips: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.78),
		Vector3(0.58, 0.0, 0.02),
		Vector3(0.0, 0.0, -0.62),
		Vector3(-0.58, 0.0, 0.02),
	]
	var center := Vector3(0.0, 0.0, 0.08)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color.WHITE
	for i in 4:
		var a := tips[i]
		var b := tips[(i + 1) % 4]
		var ai := center + (a - center) * 0.985
		var bi := center + (b - center) * 0.985
		var ao := center + (a - center) * 1.10
		var bo := center + (b - center) * 1.10
		_add_tri(st, ai, ao, bo, col)
		_add_tri(st, ai, bo, bi, col)
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


## Thread radius for a point this far from the eye: about a pixel wide at
## any distance, a touch finer toward the kite.
func _thread_radius(d: float, t: float) -> float:
	return clampf(d * lerpf(0.00019, 0.000145, t), 0.0005, lerpf(0.009, 0.007, t))


func _place_segment(mi: MeshInstance3D, cyl: CylinderMesh, p0: Vector3, p1: Vector3, radius: float, radius_end: float = -1.0) -> void:
	var delta := p1 - p0
	var length := delta.length()
	if length < 0.001:
		mi.visible = false
		return
	mi.visible = true
	cyl.height = length
	## Bottom of the cylinder sits at p0, top at p1.
	cyl.bottom_radius = radius
	cyl.top_radius = radius if radius_end < 0.0 else radius_end
	var up := delta / length
	var x_axis := up.cross(Vector3.RIGHT)
	if x_axis.length_squared() < 0.001:
		x_axis = up.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(up).normalized()
	mi.global_transform = Transform3D(Basis(x_axis, up, z_axis), (p0 + p1) * 0.5)
