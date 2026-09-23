extends Node

## Rooftop rival. It flies its kite to the far side of a point on the
## player's string and darts, so its own string swipes through yours, then
## swings back for another pass. Line is kept just long enough for that — it
## never drifts off downwind. When the player darts at its string it reacts
## like a person: sometimes ducks with E, sometimes swipes back, sometimes
## is caught napping. It hears gusts coming too, and presses the attack while
## the surge lasts.

const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")

const SWEEP_AT := 0.6        ## where on the player's string it aims (0 = their hand)
const SWEEP_PAST := 14.0     ## metres its kite goes past that point
const SWEEP_WIDE := 7.0      ## side-to-side swing of the sweep
const SWEEP_SWING := Vector2(2.2, 3.6)  ## seconds before it swings back across
const MIN_ALT := 20.0
const THREAT_SPEED := 11.0   ## player string slicing this fast is an attack
const THREAT_GAP := 9.0      ## and this close to our string
const DUCK_CHANCE := 0.4
const COUNTER_CHANCE := 0.35

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
var _side: float = 1.0
var _swing_t: float = 3.0
var _goal: Vector3 = Vector3.ZERO
var _duck_t: float = 0.0
var _reacted: bool = false
var _last_gap: float = 99.0


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
	_duck_t = maxf(0.0, _duck_t - delta)
	_swing_t -= delta
	if _think <= 0.0:
		_think = randf_range(0.12, 0.26)
		_plan()

	if _yank > 0.0 and not _dheel:
		_yank -= delta
		_kheench = _yank > 0.08

	kite.set_kheench(_kheench)
	kite.set_dheel(_dheel)
	var viewer := hand + Vector3(0.0, 2.0, 3.0)
	kite.tick(delta, hand, viewer, _reel, _bias)


func _plan() -> void:
	_dheel = false
	_kheench = false
	var alt := kite.altitude()
	if alt >= 14.0 and _react_to_attack():
		return

	_goal = _sweep_goal()
	var want := _goal - kite.global_position
	## A kite on a line only flies across the sky; toward or away from the
	## hand is the line's job (the reel below). Steer on the sky part only.
	var radial := kite.global_position - hand
	var sky := want
	if radial.length() > 1.0:
		var r := radial.normalized()
		sky = want - r * want.dot(r)
	var aim := sky.normalized() if sky.length() > 0.5 else Vector3.UP
	var nose := kite.nose_dir()
	var align := nose.dot(aim)
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() > 0.08:
		var right := Vector3.UP.cross(flat.normalized())
		_bias = clampf(-nose.dot(right) * 1.55, -1.0, 1.0)
	else:
		_bias = 0.0

	## Enough line to reach the far side of the sweep, never much more.
	var need := hand.distance_to(_goal) + 6.0
	if kite.line_length < need - 4.0:
		_reel = 0.5
	elif kite.line_length > need + 8.0:
		_reel = -0.35
	else:
		_reel = 0.05

	if alt < 14.0:
		kite.stop_steer()
		_reel = maxf(_reel, 0.4)
		## Roof air wheels the kite: time the tug for when the nose swings up,
		## like a real flyer, instead of yanking it sideways into the roof.
		if nose.y > 0.55 or (kite.phase != KiteSc.Phase.SPIN and align > 0.02):
			_yank = maxf(_yank, 0.55)
		return

	## A gust on its way or blowing: swing through sooner and dart harder.
	var w: Node = pech.wind if pech else null
	var eager: bool = w != null and (w.gust_incoming > 0.4 or w.gust01_at(kite.global_position) > 0.2)
	## Reached one end of the sweep, or took too long: swing back across.
	if sky.length() < 5.0 or _swing_t <= 0.0:
		_side = -_side
		_swing_t = randf_range(SWEEP_SWING.x, SWEEP_SWING.y) * (0.55 if eager else 1.0)
	## Flick the nose onto the line to the goal, then dart along it.
	kite.steer_nose(aim)
	if align > (0.6 if eager else 0.8):
		_yank = maxf(_yank, 0.6 if eager else 0.5)


## Where to put our kite so our string passes through their string.
func _sweep_goal() -> Vector3:
	## Their kite is down: wait in the sky above our own roof.
	if not target.is_airborne() or target.phase == KiteSc.Phase.CUT:
		return hand + Vector3(0.0, 34.0, 0.0) + (target.hand_pos - hand).normalized() * 20.0
	var on_theirs := target.hand_pos.lerp(target.global_position, SWEEP_AT)
	var through := on_theirs - hand
	if through.length() < 1.0:
		through = Vector3(0.0, 1.0, -1.0)
	through = through.normalized()
	var theirs := target.global_position - target.hand_pos
	var across := theirs.cross(through)
	if across.length() < 0.01:
		across = Vector3.RIGHT
	across = across.normalized()
	var goal := on_theirs + through * SWEEP_PAST + across * SWEEP_WIDE * _side
	goal.y = maxf(goal.y, hand.y + MIN_ALT)
	## A kite can only hold the sky downwind of its flyer. If the goal is too
	## far round to the side, push it downwind until it is within ~50°.
	var w: Node = pech.wind if pech else null
	var wd: Vector3 = w.wind_dir() if w else Vector3(0.0, 0.0, -1.0)
	var rel := goal - hand
	rel.y = 0.0
	var fwd := rel.dot(wd)
	var lateral := (rel - wd * fwd).length()
	var need := lateral * 0.85
	if fwd < need:
		goal += wd * (need - fwd)
	return goal


## The player's string is slicing toward ours: duck, swipe back, or freeze.
## Returns true while ducking (E held), which overrides the flight plan.
func _react_to_attack() -> bool:
	if _duck_t > 0.0:
		kite.stop_steer()
		_dheel = true
		return true
	if pech == null or not target.is_airborne():
		return false
	var gap: float = pech._closest_on_curves(target, kite)["dist"]
	var closing := gap < _last_gap
	_last_gap = gap
	if gap > THREAT_GAP * 1.4:
		_reacted = false
		return false
	if _reacted or not closing or gap > THREAT_GAP or target.slice_speed() < THREAT_SPEED:
		return false
	_reacted = true
	var roll := randf()
	if roll < DUCK_CHANCE:
		_duck_t = randf_range(0.45, 0.7)
		kite.stop_steer()
		_dheel = true
		return true
	if roll < DUCK_CHANCE + COUNTER_CHANCE:
		_yank = maxf(_yank, 0.5)
	return false
