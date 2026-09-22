extends Node

## Rooftop air: city bed, looping Jaipur wind, gust one-shot when the breeze spikes.

const WindSys := preload("res://scripts/wind_system.gd")
const CITY_STREAM := preload("res://assets/audio/urban_rooftop.mp3")
const WIND_STREAM := preload("res://assets/audio/wind_jaipur.mp3")
const GUST_STREAM := preload("res://assets/audio/wind_gust.mp3")

var wind: WindSys
var _city: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _gust: AudioStreamPlayer
var _city_lin: float = 0.22
var _wind_lin: float = 0.26


func setup(wind_in: WindSys) -> void:
	wind = wind_in
	process_mode = Node.PROCESS_MODE_ALWAYS
	_city = _make_player("CityBed", _looped(CITY_STREAM), 0.22)
	_wind = _make_player("JaipurWind", _looped(WIND_STREAM), 0.26)
	_gust = _make_player("WindGust", GUST_STREAM, 0.58)
	add_child(_city)
	add_child(_wind)
	add_child(_gust)
	_city.play()
	_wind.play()
	if wind:
		wind.gust_warning.connect(_on_gust_warning)


func _process(delta: float) -> void:
	var speed := wind.last_speed if wind else 8.4
	var speed_t := clampf((speed - 6.0) / 10.0, 0.0, 1.0)
	var city_want := lerpf(0.16, 0.26, speed_t)
	var wind_want := lerpf(0.20, 0.40, speed_t)
	if wind:
		## The bed swells as the front comes up behind you, then with the gust.
		wind_want += wind.gust_incoming * 0.08 + clampf(wind.gust_amount * 0.03, 0.0, 0.16)
	_city_lin = move_toward(_city_lin, city_want, delta * 0.35)
	_wind_lin = move_toward(_wind_lin, wind_want, delta * 0.5)
	if _city:
		_city.volume_db = linear_to_db(maxf(_city_lin, 0.001))
	if _wind:
		_wind.volume_db = linear_to_db(maxf(_wind_lin, 0.001))


## You hear a gust before it lands: the rush starts faint and builds until
## the front reaches the roof.
func _on_gust_warning(lead: float) -> void:
	if _gust == null:
		return
	_gust.pitch_scale = randf_range(0.94, 1.06)
	_gust.volume_db = -38.0
	_gust.play()
	var tw := create_tween()
	tw.tween_property(_gust, "volume_db", linear_to_db(0.72), lead + 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3:
		var mp3 := (stream as AudioStreamMP3).duplicate() as AudioStreamMP3
		mp3.loop = true
		return mp3
	return stream


func _make_player(name_: String, stream: AudioStream, lin: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = name_
	p.stream = stream
	p.volume_db = linear_to_db(maxf(lin, 0.001))
	p.bus = "Ambience" if name_ != "WindGust" else "SFX"
	return p
