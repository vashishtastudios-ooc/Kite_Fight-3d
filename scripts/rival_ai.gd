extends Node

## Moderate rooftop rival: climbs into the fly window, hunts the player sail,
## charges a cut on taut line, and pink-dashes when the strings can cross.

const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")

var kite: KiteSc
var target: KiteSc
var pech: PechSc
var hand: Vector3 = Vector3.ZERO

var _respawn: float = 0.0
var _yank: float = 0.0
var _think: float = 0.0
var _kheench: bool = false
var _dheel: bool = false
var _bias: float = 0.0
var _reel: float = 0.4
var _hesitate: float = 0.0


func setup(k: KiteSc, t: KiteSc, p: PechSc, hand_pos: Vector3) -> void:
	kite = k
	target = t
	pech = p
	hand = hand_pos
	kite.is_ai = true
	kite.hand_pos = hand


func tick(delta: float) -> void:
	if kite == null or target == null:
		return
	kite.fight_pips = true
	if kite.phase == KiteSc.Phase.CUT or kite.phase == KiteSc.Phase.CRASHED:
		_respawn += delta
		_kheench = false
		_dheel = false
		if _respawn > 3.8:
			_respawn = 0.0
			kite.hand_pos = hand
			kite.relaunch()
		else:
			kite.tick(delta, hand, hand + Vector3(0, 1.6, 2.0), 0.0, 0.0)
		return
	_respawn = 0.0

	if kite.phase == KiteSc.Phase.GROUNDED:
		kite.launch()

	_think -= delta
	_hesitate = maxf(0.0, _hesitate - delta)
	if _think <= 0.0:
		_think = randf_range(0.12, 0.28)
		_plan()

	if _yank > 0.0 and not _dheel:
		_yank -= delta
		_kheench = _yank > 0.08

	kite.set_kheench(_kheench)
	kite.set_dheel(_dheel)
	var viewer := hand + Vector3(0.0, 2.0, 3.0)
	kite.tick(delta, hand, viewer, _reel, _bias)


func _plan() -> void:
	var alt := kite.altitude()
	var to := target.global_position - kite.global_position
	var dist := to.length()
	var nose := kite.nose_dir()
	var want := to
	if dist < 0.4:
		want = Vector3(0.0, 0.4, -1.0)
	## Stay a little high of the player so the dart reads as a cut from above.
	want.y += clampf(6.0 - alt + target.altitude() * 0.15, -4.0, 10.0)
	var aim := want.normalized()
	var align := nose.dot(aim)
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() > 0.08:
		var right := Vector3.UP.cross(flat.normalized())
		_bias = clampf(-nose.dot(right) * 1.55, -1.0, 1.0)
	else:
		_bias = 0.0

	var player_line := target.line_length
	if kite.line_length < player_line - 10.0:
		_reel = 0.72
	elif kite.line_length > player_line + 14.0:
		_reel = -0.25
	else:
		_reel = 0.18

	_dheel = false
	_kheench = false

	if alt < 14.0:
		_reel = 0.55
		if align > 0.02 or kite.phase == KiteSc.Phase.SPIN:
			_yank = maxf(_yank, 0.55)
		return

	if target.has_method("is_dashing") and target.is_dashing() and dist < 36.0:
		_dheel = true
		_hesitate = 0.35
		return

	var pech_on := pech and pech.active
	var close := dist < 26.0
	var striking := kite.is_cut_ready() and dist < 38.0 and align > 0.10
	if striking and _hesitate <= 0.0:
		if randf() < 0.72:
			_yank = maxf(_yank, 0.62)
		else:
			_hesitate = randf_range(0.25, 0.55)
		return

	if pech_on and close and _hesitate <= 0.0:
		if kite.is_cut_ready() or randf() < 0.38:
			_yank = maxf(_yank, 0.48)
		else:
			_dheel = randf() < 0.22
		return

	if dist > 34.0:
		if align > 0.12:
			_yank = maxf(_yank, 0.40)
		_reel = 0.42
		return

	## Hold station in the fight box: short yanks, small dheel to circle.
	if align > 0.20:
		_yank = maxf(_yank, 0.32)
	elif align < -0.22 and alt > 22.0:
		_dheel = true
	elif kite.phase == KiteSc.Phase.SPIN and alt > 16.0:
		_yank = maxf(_yank, 0.28)
