class_name PlayerFlyer
extends CharacterBody3D

const WALK_SPEED := 3.4
const SPRINT_SPEED := 5.2

var look_yaw: float = 0.0
var look_pitch: float = -0.08
var mouse_sens: float = 0.0022
var rooftop_bounds: Rect2 = Rect2(-6.4, 86.2, 12.8, 12.4)
var rooftop_y: float = 20.3

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var handle: Node3D = $Head/Handle

var _bob_t: float = 0.0
var _fov_kick: float = 0.0
var _spool_w: float = 0.0
const BASE_FOV := 68.0


func _ready() -> void:
	floor_snap_length = 0.4


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			capture_mouse()


func tick(delta: float, tension: float, pull: float, _slack: float, bias: float, payout: float = 0.0) -> void:
	head.rotation.x = look_pitch
	rotation.y = look_yaw

	var input := Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward")
	)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	global_position.x = clampf(global_position.x, rooftop_bounds.position.x, rooftop_bounds.end.x)
	global_position.z = clampf(global_position.z, rooftop_bounds.position.y, rooftop_bounds.end.y)
	if global_position.y < rooftop_y - 0.5:
		global_position.y = rooftop_y

	_bob_t += delta * (1.0 + wish.length() * 6.0)
	var bob := sin(_bob_t * 8.0) * wish.length() * 0.025
	camera.position.y = bob
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 9.0)
	camera.fov = BASE_FOV + _fov_kick
	if handle:
		handle.rotation.z = lerp_angle(handle.rotation.z, -bias * 0.12, 8.0 * delta)
		handle.rotation.x = lerp_angle(handle.rotation.x, pull * 0.42 + clampf(tension / 70.0, 0.0, 0.22), 10.0 * delta)
		handle.position.x = 0.05
		handle.position.z = lerpf(-0.40, -0.34, pull)
		handle.position.y = lerpf(-0.12, -0.16, pull)
		var firki := handle.get_node_or_null("Firki")
		if firki:
			## ω ≈ line speed / spool radius, then clamped so it reads in first person.
			var target := clampf(payout / 0.62, -24.0, 24.0)
			var accel := 52.0 if absf(target) > absf(_spool_w) else 18.0
			_spool_w = move_toward(_spool_w, target, accel * delta)
			firki.rotate_x(_spool_w * delta)


func kick_speed_fov() -> void:
	_fov_kick = 6.5


func look_towards(world_point: Vector3, delta: float, weight: float = 3.0) -> void:
	var to := world_point - camera.global_position
	if to.length() < 0.2:
		return
	var target_yaw := atan2(-to.x, -to.z)
	var target_pitch := atan2(to.y, Vector3(to.x, 0.0, to.z).length())
	look_yaw = lerp_angle(look_yaw, target_yaw, clampf(weight * delta, 0.0, 1.0))
	look_pitch = lerp(look_pitch, clampf(target_pitch, deg_to_rad(-80.0), deg_to_rad(75.0)), clampf(weight * delta, 0.0, 1.0))


func hand_position() -> Vector3:
	if handle:
		var origin := handle.get_node_or_null("LineOrigin") as Node3D
		if origin:
			return origin.global_position
		return handle.global_position
	return camera.global_position + camera.global_transform.basis * Vector3(0.08, -0.14, -0.38)
