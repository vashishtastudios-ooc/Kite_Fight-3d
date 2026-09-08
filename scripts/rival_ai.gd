extends Node

## Rival: climb out, chase the player kite, charge slowly, pink-dash to cut.

const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")

var kite: KiteSc
var target: KiteSc
var pech: PechSc
var hand: Vector3 = Vector3.ZERO

var _respawn: float = 0.0
var _yank_left: float = 0.0
var _pip_t: float = 0.0
var _slip_t: float = 0.0


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
	if kite.phase == KiteSc.Phase.CUT or kite.phase == KiteSc.Phase.CRASHED:
		_respawn += delta
		if _respawn > 4.5:
			_respawn = 0.0
			kite.hand_pos = hand
			kite.relaunch()
		else:
			kite.tick(delta, hand, hand + Vector3(0, 1.6, 0), 0.0, 0.0)
		return
	_respawn = 0.0

	if kite.phase == KiteSc.Phase.GROUNDED:
		kite.launch()

	var kheench := false
	var dheel := false
	var bias := 0.0
	var reel := 0.55
	var alt := kite.altitude()
	var to := target.global_position - kite.global_position
	var dist := to.length()
	var nose := kite.nose_dir()
	var aim := to.normalized() if dist > 0.4 else Vector3(0.0, 0.35, -1.0)
	if alt < 20.0:
		aim = Vector3(aim.x, maxf(aim.y, 0.55), aim.z).normalized()
	var align := nose.dot(aim)
	var axes_right := Vector3.UP.cross(Vector3(aim.x, 0.0, aim.z).normalized() if Vector3(aim.x, 0.0, aim.z).length() > 0.1 else Vector3(0, 0, -1))
	if axes_right.length_squared() > 0.01:
		bias = clampf(nose.dot(axes_right.normalized()), -1.0, 1.0) * -1.35

	if kite.line_length < 42.0:
		reel = 0.85
	elif kite.line_length > 72.0:
		reel = -0.2
	else:
		reel = 0.12

	_pip_t += delta
	if alt > 16.0 and kite.phase != KiteSc.Phase.CLIMB and _pip_t > 9.0:
		_pip_t = 0.0
		kite.add_pip()

	var player_dashing := target.has_method("is_dashing") and target.is_dashing()
	if player_dashing and dist < 38.0:
		_slip_t = 0.7
	if _slip_t > 0.0:
		_slip_t -= delta
		dheel = true
		kheench = false
	elif kite.phase == KiteSc.Phase.CLIMB:
		kheench = false
		dheel = false
	elif kite.is_cut_ready() and dist < 42.0 and align > 0.12:
		kheench = true
		_yank_left = 0.7
	elif alt < 24.0:
		## Get into the sky — do not sit in a low spin.
		if align > 0.08 or kite.phase == KiteSc.Phase.SPIN:
			_yank_left = maxf(_yank_left, 0.48)
		kheench = _yank_left > 0.12
	elif dist > 22.0:
		if align > 0.18:
			_yank_left = maxf(_yank_left, 0.42)
		kheench = _yank_left > 0.12
		dheel = align < -0.15 and alt > 28.0
	else:
		if align > 0.22:
			_yank_left = maxf(_yank_left, 0.38)
		kheench = _yank_left > 0.12

	if _yank_left > 0.0 and not dheel:
		_yank_left -= delta
		kheench = _yank_left > 0.1

	kite.set_kheench(kheench)
	kite.set_dheel(dheel)
	var viewer := hand + Vector3(0.0, 1.6, 4.0)
	kite.tick(delta, hand, viewer, reel, bias)
