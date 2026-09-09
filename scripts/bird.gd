class_name Bird
extends Node3D

## A soaring eagle body. The flock (bird_flock.gd) is the brain — it decides
## where each bird goes and when to chase; the bird just flies there, banks,
## flaps, and perches. Rig is Tripo auto-rig: wings are bone_6.. and bone_10...

const MODEL := preload("res://assets/birds/eagle 3d model_Clone1.glb")

## --- tuning (safe to tweak) ---
const MODEL_SCALE := 2.4
const FWD_FIX_Y := 0.0            ## yaw offset so the model's nose faces -Z
const WING_AXIS := Vector3(0.0, 0.0, 1.0)
const WING_SIGN := 1.0
const FLAP_FOLD := 0.9           ## wing angle when perched (radians)
const MAX_BANK := 0.7            ## how hard it rolls into turns

var perched: bool = false
var velocity: Vector3 = Vector3.ZERO
var speed: float = 13.0

var _model: Node3D
var _skel: Skeleton3D
var _wl: int = -1
var _wr: int = -1
var _t: float = 0.0
var _roll: float = 0.0
var _prev_yaw: float = 0.0
var _flap_amp: float = 0.45
var _flap_rate: float = 9.0


func setup() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation.y = FWD_FIX_Y
	_no_shadow(_model)
	_skel = _find_skel(_model)
	if _skel:
		_wl = _skel.find_bone("bone_6")
		_wr = _skel.find_bone("bone_10")


## Fly toward a point. effort 0=gentle glide, 1=hard-flapping chase/climb.
func fly_to(target: Vector3, delta: float, effort: float) -> void:
	perched = false
	var to := target - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var desired := velocity
	if to.length() > 0.5:
		desired = to.normalized() * speed
	var turn := lerpf(1.8, 3.4, effort)
	velocity = velocity.lerp(desired, clampf(turn * delta, 0.0, 1.0))
	if velocity.length() > speed * 1.4:
		velocity = velocity.normalized() * speed * 1.4
	global_position += velocity * delta

	_orient(delta)
	_flap_amp = lerpf(0.2, 0.7, effort)
	_flap_rate = lerpf(6.0, 15.0, effort)
	_t += delta * _flap_rate
	_beat(sin(_t) * _flap_amp)


func perch_at(pos: Vector3, delta: float) -> void:
	perched = true
	velocity = velocity.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	global_position = global_position.lerp(pos, clampf(5.0 * delta, 0.0, 1.0))
	_roll = lerp_angle(_roll, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	## Gentle idle sway + folded wings.
	_t += delta * 1.4
	_beat(FLAP_FOLD + sin(_t) * 0.05)


func _orient(delta: float) -> void:
	if velocity.length() < 0.6:
		return
	var fwd := velocity.normalized()
	var yaw := atan2(-fwd.x, -fwd.z)
	var pitch := atan2(fwd.y, Vector2(fwd.x, fwd.z).length())
	## Bank: roll proportional to how fast the heading is turning.
	var dyaw := wrapf(yaw - _prev_yaw, -PI, PI)
	_prev_yaw = yaw
	var want_roll := clampf(-dyaw / maxf(delta, 0.001) * 0.18, -MAX_BANK, MAX_BANK)
	_roll = lerp_angle(_roll, want_roll, clampf(4.0 * delta, 0.0, 1.0))
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Basis.from_euler(Vector3(0.0, 0.0, _roll))
	global_transform.basis = global_transform.basis.slerp(b, clampf(8.0 * delta, 0.0, 1.0))


func _beat(_angle: float) -> void:
	## The Tripo auto-rig deforms the wings badly when driven, so we fly the
	## eagle in its clean spread-wing bind pose and soar/bank instead of flap.
	pass


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skel(c)
		if s:
			return s
	return null


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)
