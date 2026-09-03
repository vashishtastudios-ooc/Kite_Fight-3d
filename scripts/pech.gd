extends Node

## When two manjhas get close, they saw. A taut kheench cuts.
## Dheel sags the line to slip out of the pech — it does not grind.

signal pech_changed(active: bool)
signal kaata(player_won: bool, at: Vector3)

const KiteSc := preload("res://scripts/kite.gd")

var active: bool = false
var contact_pos: Vector3 = Vector3.ZERO
var pech_time: float = 0.0

var _spark: MeshInstance3D
var _spark_mat: StandardMaterial3D
var _gap: float = 99.0


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
		_set_active(false)
		return
	if player.phase == KiteSc.Phase.CUT or rival.phase == KiteSc.Phase.CUT:
		_set_active(false)
		return

	var pts := _closest_segment_points(player.hand_pos, player.global_position, rival.hand_pos, rival.global_position)
	_gap = pts["dist"]
	contact_pos = pts["mid"]

	if _gap < 2.15:
		var was := active
		_set_active(true)
		pech_time += delta
		_spark.visible = true
		_spark.global_position = contact_pos
		var pulse := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.02))
		_spark_mat.albedo_color = Color(1.0, 0.82, 0.28, pulse)
		_spark.scale = Vector3.ONE * (0.7 + pulse * 0.8)
		if not was:
			pech_changed.emit(true)
		_saw(delta, player, rival)
	else:
		pech_time = maxf(0.0, pech_time - delta * 1.6)
		_spark.visible = false
		if active and pech_time <= 0.05:
			_set_active(false)
			pech_changed.emit(false)


func _saw(delta: float, player: KiteSc, rival: KiteSc) -> void:
	if pech_time < 0.28:
		return
	## Taut fly/spin grinds. Dheel is an escape: almost no cut dealt, hard to bite.
	var p_taut := player.phase == KiteSc.Phase.FLY or player.phase == KiteSc.Phase.SPIN
	var r_taut := rival.phase == KiteSc.Phase.FLY or rival.phase == KiteSc.Phase.SPIN
	var p_sag := player.phase == KiteSc.Phase.DHEEL or player.slack > 0.55
	var r_sag := rival.phase == KiteSc.Phase.DHEEL or rival.slack > 0.55
	var p_slide := 0.16 if p_taut else 0.05
	var r_slide := 0.14 if r_taut else 0.05
	if p_sag:
		p_slide *= 0.08
		r_slide *= 0.28
	if r_sag:
		r_slide *= 0.08
		p_slide *= 0.28
	var p_cut := p_slide * delta * 0.40
	var r_cut := r_slide * delta * 0.36
	var closeness := 1.0 - clampf(_gap / 2.15, 0.0, 1.0)
	p_cut *= 0.55 + closeness * 0.9
	r_cut *= 0.55 + closeness * 0.9
	var rival_before := rival.manjha
	var player_before := player.manjha
	rival.damage_manjha(p_cut)
	player.damage_manjha(r_cut)
	if rival_before > 0.0 and rival.manjha <= 0.0:
		kaata.emit(true, contact_pos)
	elif player_before > 0.0 and player.manjha <= 0.0:
		kaata.emit(false, contact_pos)


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
	return {"dist": pa.distance_to(pb), "mid": (pa + pb) * 0.5, "pa": pa, "pb": pb}
