extends Node

## Rival ustad: same kheench / dheel language. Spins until the nose aims
## at you, tugs to close, dheels in the pech.

const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")

var kite: KiteSc
var target: KiteSc
var pech: PechSc
var hand: Vector3 = Vector3.ZERO

var _pech_wait: float = 0.0
var _respawn: float = 0.0
var _think: float = 0.0


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

	_think += delta
	var kheench := false
	var dheel := false
	var bias := 0.0
	var reel := 0.0

	if pech and pech.active:
		if _pech_wait <= 0.0:
			_pech_wait = randf_range(0.28, 0.85)
		_pech_wait -= delta
		## Stay taut to cut. Sag only if the manjha is nearly gone.
		kheench = kite.manjha > 0.42
		dheel = kite.manjha <= 0.42
	else:
		_pech_wait = 0.0
		var to := target.global_position - kite.global_position
		var dist := to.length()
		var nose := kite.nose_dir()
		var aim := to.normalized() if dist > 0.2 else Vector3(0, 0, -1)
		var align := nose.dot(aim)
		var axes_right := Vector3.UP.cross(aim)
		if axes_right.length_squared() > 0.01:
			bias = clampf(nose.dot(axes_right.normalized()), -1.0, 1.0) * -1.2

		if kite.altitude() < 8.0:
			kheench = false
			dheel = false
		elif dist > 28.0:
			if align > 0.42:
				kheench = true
			else:
				dheel = kite.altitude() > 16.0 and align < 0.1
			reel = 0.35 if kite.line_length < 40.0 else 0.0
		else:
			if align > 0.28:
				kheench = true
			else:
				dheel = false
			reel = -0.15 if kite.line_length > 55.0 else 0.1

	kite.set_kheench(kheench)
	kite.set_dheel(dheel)
	var viewer := hand + Vector3(0.0, 1.6, 4.0)
	kite.tick(delta, hand, viewer, reel, bias)
