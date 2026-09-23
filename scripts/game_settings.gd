class_name GameSettings
extends RefCounted

## Video and HUD prefs. Quality presets change cost a lot more than FOV zoom.
const PATH := "user://settings.cfg"
const KiteSkins := preload("res://scripts/kite_skins.gd")

var quality: int = 1
var fullscreen: bool = false
var show_hints: bool = true
var kite_id: String = "saffron"
## Which map to fly on: "city" (Jaipur rooftops) or "pahadi" (Himalayan dusk).
var map_id: String = "city"
const MAPS: PackedStringArray = ["city", "pahadi"]
var mute: bool = false
var vol_master: float = 0.85
var vol_ambience: float = 0.80
var vol_sfx: float = 0.90


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("video", "quality", 1)), 0, 2)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	show_hints = bool(cfg.get_value("ui", "hints", true))
	kite_id = KiteSkins.clamp_id(str(cfg.get_value("play", "kite", "saffron")))
	map_id = str(cfg.get_value("play", "map", "city"))
	if not MAPS.has(map_id):
		map_id = "city"
	mute = bool(cfg.get_value("audio", "mute", false))
	vol_master = clampf(float(cfg.get_value("audio", "master", 0.85)), 0.0, 1.0)
	vol_ambience = clampf(float(cfg.get_value("audio", "ambience", 0.80)), 0.0, 1.0)
	vol_sfx = clampf(float(cfg.get_value("audio", "sfx", 0.90)), 0.0, 1.0)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("ui", "hints", show_hints)
	cfg.set_value("play", "kite", kite_id)
	cfg.set_value("play", "map", map_id)
	cfg.set_value("audio", "mute", mute)
	cfg.set_value("audio", "master", vol_master)
	cfg.set_value("audio", "ambience", vol_ambience)
	cfg.set_value("audio", "sfx", vol_sfx)
	cfg.save(PATH)


func apply(main: Node) -> void:
	_ensure_buses()
	AudioServer.set_bus_mute(0, mute)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol_master, 0.001)))
	var amb := AudioServer.get_bus_index("Ambience")
	var sfx := AudioServer.get_bus_index("SFX")
	if amb >= 0:
		AudioServer.set_bus_volume_db(amb, linear_to_db(maxf(vol_ambience, 0.001)))
	if sfx >= 0:
		AudioServer.set_bus_volume_db(sfx, linear_to_db(maxf(vol_sfx, 0.001)))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vp := main.get_viewport()
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = we.environment if we else null
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if vp == null:
		return
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.use_taa = false
			if env:
				env.ssao_enabled = false
				env.glow_enabled = true
				env.glow_intensity = 0.22
				env.glow_bloom = 0.06
			if sun:
				sun.directional_shadow_max_distance = 72.0
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.use_taa = true
			if env:
				env.ssao_enabled = true
				env.ssao_radius = 1.4
				env.ssao_intensity = 1.35
				env.glow_enabled = true
				env.glow_intensity = 0.30
				env.glow_bloom = 0.09
			if sun:
				sun.directional_shadow_max_distance = 150.0
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		2:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.use_taa = true
			if env:
				env.ssao_enabled = true
				env.ssao_radius = 1.6
				env.ssao_intensity = 1.5
				env.glow_enabled = true
				env.glow_intensity = 0.34
				env.glow_bloom = 0.10
			if sun:
				sun.directional_shadow_max_distance = 180.0
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _ensure_buses() -> void:
	_ensure_bus("Ambience")
	_ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
