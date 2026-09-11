extends Node

## Cut dash vs manjha. Pink Q crosses their string. E sag can slip if you leave the cross.

signal pech_changed(active: bool)
signal kaata(player_won: bool, at: Vector3)
signal cut_wanted(player_won: bool)

const KiteSc := preload("res://scripts/kite.gd")

var active: bool = false
var net_mode: bool = false
var contact_pos: Vector3 = Vector3.ZERO
var pech_time: float = 0.0
var player_wins: int = 0
var rival_wins: int = 0

var _spark: MeshInstance3D
var _spark_mat: StandardMaterial3D
var _gap: float = 99.0
var _lock: bool = false


func _ready() -> void:
	_spark = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	_spark.mesh = sph
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.0)
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark.material_override = _spark_mat
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spark)
	_spark.visible = false


func tick(delta: float, player: KiteSc, rival: KiteSc) -> void:
	if player == null or rival == null:
		_set_active(false)
		return
	if not player.is_airborne() or not rival.is_airborne():
		_lock = false
		_set_active(false)
		return
	if player.phase == KiteSc.Phase.CUT or rival.phase == KiteSc.Phase.CUT:
		_set_active(false)
		return
	if not player.is_dashing() and not rival.is_dashing():
		_lock = false

	var pts := _closest_segment_points(player.hand_pos, player.global_position, rival.hand_pos, rival.global_position)
	_gap = pts["dist"]
	contact_pos = pts["mid"]
	var crossed := _is_cross(pts)

	if _gap < 2.4:
		var was := active
		_set_active(true)
		pech_time += delta
		_spark.visible = true
		_spark.global_position = contact_pos
		var pulse := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.02))
		var hot := player.is_dashing() or rival.is_dashing()
		_spark_mat.albedo_color = Color(1.0, 0.35, 0.62, pulse) if hot else Color(1.0, 0.82, 0.28, pulse)
		_spark.scale = Vector3.ONE * (0.7 + pulse * 0.8)
		if not was:
			pech_changed.emit(true)
		if not _lock:
			if player.is_dashing():
				_resolve_dash(true, player, rival, pts, crossed)
			elif rival.is_dashing():
				_resolve_dash(false, rival, player, pts, crossed)
	else:
		pech_time = maxf(0.0, pech_time - delta * 1.6)
		_spark.visible = false
		if active and pech_time <= 0.05:
			_set_active(false)
			pech_changed.emit(false)


func _resolve_dash(player_swings: bool, attacker: KiteSc, defender: KiteSc, pts: Dictionary, crossed: bool) -> void:
	if not crossed and pts["dist"] > 1.45:
		return
	var ta: float = pts["ta"]
	var tb: float = pts["tb"]
	if ta < 0.12 or ta > 0.90 or tb < 0.12 or tb > 0.90:
		return
	## Slack and already off the line = slip. Slack still on the string = cut.
	if defender.is_slack_for_cut() and pts["dist"] > 1.05:
		return
	_lock = true
	if net_mode:
		cut_wanted.emit(player_swings)
		return
	defender.apply_cut()
	if player_swings:
		player_wins += 1
	else:
		rival_wins += 1
	kaata.emit(player_swings, pts["mid"])


func _is_cross(pts: Dictionary) -> bool:
	if pts["dist"] > 1.55:
		return false
	var pa: Vector3 = pts["pa"]
	var pb: Vector3 = pts["pb"]
	var a: Vector3 = pts["a"]
	var b: Vector3 = pts["b"]
	if a.length_squared() < 0.01 or b.length_squared() < 0.01:
		return false
	var ang := rad_to_deg(a.normalized().angle_to(b.normalized()))
	if ang < 22.0:
		return false
	return pa.distance_to(pb) <= 1.55


func _set_active(v: bool) -> void:
	active = v
	if not v:
		_spark.visible = false


func _closest_segment_points(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Dictionary:
	var a := a1 - a0
	var b := b1 - b0
	var r := a0 - b0
	var aa := a.dot(a)
	var bb := b.dot(b)
	var ab := a.dot(b)
	var ra := r.dot(a)
	var rb := r.dot(b)
	var denom := aa * bb - ab * ab
	var ta := 0.0
	var tb := 0.0
	if denom > 0.0001:
		ta = clampf((ab * rb - bb * ra) / denom, 0.0, 1.0)
	tb = clampf((ab * ta + rb) / maxf(bb, 0.0001), 0.0, 1.0)
	ta = clampf((ab * tb - ra) / maxf(aa, 0.0001), 0.0, 1.0)
	var pa := a0 + a * ta
	var pb := b0 + b * tb
	return {
		"dist": pa.distance_to(pb),
		"mid": (pa + pb) * 0.5,
		"pa": pa,
		"pb": pb,
		"ta": ta,
		"tb": tb,
		"a": a,
		"b": b,
	}
