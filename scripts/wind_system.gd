class_name WindSystem
extends Node

## Layered wind for a rooftop kite.
## Base breeze drifts slowly. Gusts and lulls ramp in and out — they never snap.
## Heading wanders. Higher air is stronger and smoother; near rooftops it chops.

signal gust_began
signal lull_began

@export var mean_speed: float = 9.4
@export var base_drift: float = 2.3
## Wind blows toward -Z (out over the city) with this yaw in degrees.
## A few degrees off dead-ahead so you feel it on one cheek, not a laser.
@export var mean_heading_degrees: float = 8.0
@export var wander_degrees: float = 22.0
@export var rooftop_height: float = 20.0

var time: float = 0.0
var last_sample: Vector3 = Vector3(0.0, 0.0, -8.4)
var last_speed: float = 8.4
var last_heading: float = 0.0
var gust_amount: float = 0.0
var lull_amount: float = 0.0
var is_gusting: bool = false
var is_lull: bool = false

var _noise_base: FastNoiseLite
var _noise_wander: FastNoiseLite
var _noise_chop: FastNoiseLite
var _gusts: Array[Dictionary] = []
var _lulls: Array[Dictionary] = []
var _next_gust: float = 3.5
var _next_lull: float = 16.0


func _ready() -> void:
	_noise_base = FastNoiseLite.new()
	_noise_base.seed = 1103
	_noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_base.frequency = 0.055
	_noise_wander = FastNoiseLite.new()
	_noise_wander.seed = 7741
	_noise_wander.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_wander.frequency = 0.04
	_noise_chop = FastNoiseLite.new()
	_noise_chop.seed = 22019
	_noise_chop.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_chop.frequency = 0.55


func _physics_process(delta: float) -> void:
	time += delta
	_next_gust -= delta
	_next_lull -= delta
	if _next_gust <= 0.0:
		_spawn_gust()
		_next_gust = randf_range(4.5, 12.0)
	if _next_lull <= 0.0:
		_spawn_lull()
		_next_lull = randf_range(18.0, 38.0)
	_age_events(_gusts, delta)
	_age_events(_lulls, delta)
	gust_amount = _envelope_sum(_gusts)
	lull_amount = _envelope_sum(_lulls)
	var was_gust := is_gusting
	var was_lull := is_lull
	is_gusting = gust_amount > 0.22
	is_lull = lull_amount > 0.28
	if is_gusting and not was_gust:
		gust_began.emit()
	if is_lull and not was_lull:
		lull_began.emit()


func sample(world_pos: Vector3, near_buildings: float = 0.0, record: bool = true) -> Vector3:
	var heading := _heading_at()
	var base := _base_speed()
	var gust := gust_amount
	var lull := lull_amount

	var speed := (base + gust) * (1.0 - 0.72 * lull)
	speed = maxf(speed, 0.35)

	var height_t := clampf((world_pos.y - rooftop_height) / 55.0, 0.0, 1.0)
	# Low in the window: weaker and choppier. Near zenith: cleaner, stronger push.
	var height_mul := lerpf(0.72, 1.22, height_t * height_t * (3.0 - 2.0 * height_t))
	var chop_amp := lerpf(0.38, 0.05, height_t) + near_buildings * 0.45
	var chop := _noise_chop.get_noise_3d(world_pos.x * 0.08, world_pos.y * 0.1, time * 1.7)
	speed *= height_mul * (1.0 + chop * chop_amp)

	var dir := Vector3(sin(heading), 0.0, -cos(heading))
	# Slight vertical mixing in choppy air, almost none up high.
	dir.y = chop * lerpf(0.08, 0.012, height_t)
	dir = dir.normalized()
	var v := dir * speed
	if record:
		last_sample = v
		last_speed = speed
		last_heading = heading
	return v


func debug_label() -> String:
	if is_lull:
		return "LULL"
	if is_gusting:
		return "GUST"
	if last_speed >= 9.5:
		return "WINDY"
	if last_speed >= 6.0:
		return "BREEZE"
	return "LIGHT"


func compass_letter() -> String:
	# Wind blows toward this point of the compass (mean is north / -Z).
	var deg := wrapf(rad_to_deg(last_heading), 0.0, 360.0)
	if deg >= 337.5 or deg < 22.5:
		return "N"
	if deg < 67.5:
		return "NE"
	if deg < 112.5:
		return "E"
	if deg < 157.5:
		return "SE"
	if deg < 202.5:
		return "S"
	if deg < 247.5:
		return "SW"
	if deg < 292.5:
		return "W"
	return "NW"


func _heading_at() -> float:
	var wander := _noise_wander.get_noise_2d(time * 0.35, 4.0)
	return deg_to_rad(mean_heading_degrees) + wander * deg_to_rad(wander_degrees)


func _base_speed() -> float:
	var n := _noise_base.get_noise_2d(time * 0.22, 0.0)
	return mean_speed + n * base_drift


func _spawn_gust() -> void:
	# Ramp in over 1–2 s, a short peak, then a longer trail-off.
	_gusts.append({
		"age": 0.0,
		"peak": randf_range(2.8, 6.4),
		"ramp_in": randf_range(1.15, 2.05),
		"hold": randf_range(0.35, 0.9),
		"ramp_out": randf_range(1.8, 3.4),
	})


func _spawn_lull() -> void:
	_lulls.append({
		"age": 0.0,
		"peak": randf_range(0.45, 0.78),
		"ramp_in": randf_range(1.2, 2.2),
		"hold": randf_range(1.1, 2.8),
		"ramp_out": randf_range(1.6, 3.0),
	})


func _age_events(events: Array[Dictionary], delta: float) -> void:
	var i := 0
	while i < events.size():
		events[i]["age"] = float(events[i]["age"]) + delta
		var life: float = float(events[i]["ramp_in"]) + float(events[i]["hold"]) + float(events[i]["ramp_out"])
		if float(events[i]["age"]) >= life:
			events.remove_at(i)
		else:
			i += 1


func _envelope_sum(events: Array[Dictionary]) -> float:
	var total := 0.0
	for e in events:
		total += float(e["peak"]) * _smooth_envelope(
			float(e["age"]),
			float(e["ramp_in"]),
			float(e["hold"]),
			float(e["ramp_out"])
		)
	return total


static func _smooth_envelope(age: float, ramp_in: float, hold: float, ramp_out: float) -> float:
	## Smoothstep in, hold, smoothstep out. Never a step function.
	if age < ramp_in:
		var t := clampf(age / maxf(ramp_in, 0.001), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)
	if age < ramp_in + hold:
		return 1.0
	var t_out := clampf((age - ramp_in - hold) / maxf(ramp_out, 0.001), 0.0, 1.0)
	var s := t_out * t_out * (3.0 - 2.0 * t_out)
	return 1.0 - s
