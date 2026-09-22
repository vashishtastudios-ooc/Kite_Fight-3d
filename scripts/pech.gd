extends Node

## Pech: swipe your string through theirs while your kite is moving. Each time
## the strings pass through each other, the faster string takes a bite out of
## the slower one. A strong swipe on a still kite takes about half its manjha,
## so two clean swipes cut. E drops your line slack (their swipe can pass
## over it) and pays out, which slices a little too — a counter to a lazy kite.
## Strings never hook or stick: they slice past.

signal pech_changed(active: bool)
signal lock_changed(on: bool)
signal kaata(player_won: bool, at: Vector3)
signal cut_wanted(player_won: bool)

const KiteSc := preload("res://scripts/kite.gd")
const PechFxSc := preload("res://scripts/pech_fx.gd")

## Contact. Strings are sampled along the curve that is drawn on screen.
const LINE_SAMPLES := 14
const GAP_NEAR := 5.0        ## close enough to glow as a warning
const GAP_HIT := 1.8         ## strings touching
const GAP_CLEAR := 3.5       ## apart again: the next touch is a new swipe
const END_MARGIN := 0.08     ## the last bit at the hand and the kite does not count
const REBITE := 0.9          ## seconds before strings left touching bite again

## Bites.
const SWIPE_MIN := 5.0       ## m/s: below this a string is just sitting there
const SWIPE_FULL := 15.0     ## m/s faster than the other string for the biggest bite
const BITE_MAX := 0.52       ## manjha taken by a perfect swipe on a still string
const SCRATCH := 0.05        ## what both strings lose on any real swipe
const MEND_RATE := 0.03      ## manjha per second a worn string gets back

var active: bool = false
var net_mode: bool = false
var wind: Node
var touching: bool = false
var contact_pos: Vector3 = Vector3.ZERO
var player_wins: int = 0
var rival_wins: int = 0
## 0..1 flashes that decay after a bite, for the HUD and FX.
var player_hit: float = 0.0
var rival_hit: float = 0.0
## Last bite, for the FX: +1 = the player won it, -1 = the rival did.
var last_edge: float = 0.0

var _spark: MeshInstance3D
var _spark_mat: StandardMaterial3D
var _fx: PechFxSc
var _lock: bool = false
var _rebite: float = 0.0
var _t: float = 0.0


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
	_fx = PechFxSc.new()
	_fx.name = "PechFx"
	add_child(_fx)


func tick(delta: float, player: KiteSc, rival: KiteSc) -> void:
	_t += delta
	player_hit = move_toward(player_hit, 0.0, delta * 1.6)
	rival_hit = move_toward(rival_hit, 0.0, delta * 1.6)
	if not _both_flying(player, rival):
		_lock = false
		_set_touching(false)
		_set_active(false)
		_fx.tick(delta, self)
		return
	player.mend_manjha(MEND_RATE * delta)
	rival.mend_manjha(MEND_RATE * delta)

	var hit := _closest_on_curves(player, rival)
	var gap: float = hit["dist"]
	contact_pos = hit["mid"]

	if gap > GAP_NEAR:
		_lock = false
		_set_touching(false)
		_set_active(false)
		_fx.tick(delta, self)
		return
	_set_active(true)
	_spark.visible = true
	_spark.global_position = contact_pos
	var pulse := 0.45 + 0.55 * absf(sin(_t * 20.0))
	var near := 1.0 - clampf((gap - GAP_HIT) / (GAP_NEAR - GAP_HIT), 0.0, 1.0)
	_spark_mat.albedo_color = Color(1.0, 0.82, 0.28, pulse * lerpf(0.25, 0.7, near))
	_spark.scale = Vector3.ONE * (0.45 + pulse * 0.5) * lerpf(0.7, 1.3, near)

	if gap > GAP_CLEAR:
		_set_touching(false)
	elif gap <= GAP_HIT and not _lock:
		if not touching:
			_set_touching(true)
			_bite(player, rival)
		else:
			## Strings left lying on each other still grind now and then.
			_rebite -= delta
			if _rebite <= 0.0:
				_bite(player, rival)
	_fx.tick(delta, self)


func _both_flying(player: KiteSc, rival: KiteSc) -> bool:
	if player == null or rival == null:
		return false
	if not player.is_airborne() or not rival.is_airborne():
		return false
	return player.phase != KiteSc.Phase.CUT and rival.phase != KiteSc.Phase.CUT


## One pass of the strings: the faster one bites the slower one.
func _bite(player: KiteSc, rival: KiteSc) -> void:
	_rebite = REBITE
	var ps := player.slice_speed()
	var rs := rival.slice_speed()
	if maxf(ps, rs) < SWIPE_MIN:
		return
	var to_rival := SCRATCH + BITE_MAX * clampf((ps - rs) / SWIPE_FULL, 0.0, 1.0)
	var to_player := SCRATCH + BITE_MAX * clampf((rs - ps) / SWIPE_FULL, 0.0, 1.0)
	last_edge = clampf((to_rival - to_player) / BITE_MAX, -1.0, 1.0)
	rival_hit = clampf(to_rival / 0.3, 0.2, 1.0)
	player_hit = clampf(to_player / 0.3, 0.2, 1.0)
	_fx.bite(contact_pos, player, rival, maxf(to_rival, to_player), last_edge)
	_hurt(player, to_player)
	_hurt(rival, to_rival)

	var p_dead := player.manjha <= 0.0 or player.phase == KiteSc.Phase.CUT
	var r_dead := rival.manjha <= 0.0 or rival.phase == KiteSc.Phase.CUT
	if not p_dead and not r_dead:
		return
	_lock = true
	if p_dead and r_dead:
		return
	if r_dead:
		_finish_cut(true, player, rival)
	else:
		_finish_cut(false, rival, player)


func _hurt(k: KiteSc, amount: float) -> void:
	if amount > 0.0:
		k.damage_manjha(amount, not net_mode)


func _finish_cut(player_won: bool, winner: KiteSc, _loser: KiteSc) -> void:
	_fx.buzz(1.0, 0.45)
	if net_mode:
		if player_won:
			cut_wanted.emit(true)
		return
	winner.restore_manjha()
	if player_won:
		player_wins += 1
	else:
		rival_wins += 1
	kaata.emit(player_won, contact_pos)


func _set_touching(v: bool) -> void:
	if v == touching:
		return
	touching = v
	lock_changed.emit(v)


func _set_active(v: bool) -> void:
	if not v:
		_spark.visible = false
	if v == active:
		return
	active = v
	pech_changed.emit(v)


## 0..1: how hard the last bite landed, fading out.
func grind() -> float:
	return maxf(player_hit, rival_hit)


## Closest approach of the two strings as drawn (sagging curves), ignoring
## the ends at the hands and the kites.
func _closest_on_curves(a: KiteSc, b: KiteSc) -> Dictionary:
	var pa := a.line_points(LINE_SAMPLES)
	var pb := b.line_points(LINE_SAMPLES)
	var best := {"dist": 999.0, "mid": (a.global_position + b.global_position) * 0.5}
	var lo := int(ceil(END_MARGIN * LINE_SAMPLES))
	var hi := LINE_SAMPLES - lo
	for i in range(lo, hi):
		for j in range(lo, hi):
			var s := _closest_segment_points(pa[i], pa[i + 1], pb[j], pb[j + 1])
			if s["dist"] < best["dist"]:
				best = {"dist": s["dist"], "mid": s["mid"]}
	return best


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
	return {"dist": pa.distance_to(pb), "mid": (pa + pb) * 0.5}
