class_name DiwaliRockets
extends Node3D

const RocketSc := preload("res://scripts/diwali_rocket.gd")
const MAX_LIVE := 3
signal player_dodged

var enabled: bool = true
var _kite: Node
var _city: Node
var _wait: float = 2.4
var _live: int = 0


func setup(kite: Node, city: Node) -> void:
	_kite = kite
	_city = city


func inbound_launches() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in get_children():
		if child.has_method("is_inbound") and child.is_inbound():
			out.append(child.launch_pos)
	return out


func _process(delta: float) -> void:
	if not enabled:
		return
	if _kite == null or _city == null:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if not _kite.has_method("is_airborne") or not _kite.is_airborne():
		_wait = 1.2
		return
	if _kite.global_position.y < _city.rooftop_height + 6.0:
		_wait = 1.2
		return
	var room := MAX_LIVE - _live
	if room <= 0:
		_wait = randf_range(0.8, 1.6)
		return
	var together := randf() < 0.42
	if together and room >= 2:
		var n := mini(room, randi_range(2, 3))
		_salvo(n)
		_wait = randf_range(3.6, 6.4)
	else:
		_spawn_from(_pick_pad([]), _kite.global_position)
		_wait = randf_range(1.0, 2.6)


func _salvo(count: int) -> void:
	var used: Array[Vector3] = []
	var aim: Vector3 = _kite.global_position
	for _i in count:
		var pad := _pick_pad(used)
		if pad.y < 1.0:
			break
		used.append(pad)
		_spawn_from(pad, aim)


func _spawn_from(pad: Vector3, aim: Vector3) -> void:
	if pad.y < 1.0:
		return
	var rocket = RocketSc.new()
	add_child(rocket)
	_live += 1
	rocket.tree_exited.connect(_on_gone)
	if rocket.has_signal("resolved"):
		rocket.resolved.connect(_on_resolved)
	rocket.fire(pad, aim, _kite)


func _on_resolved(_hit: bool, dodged: bool) -> void:
	if dodged and _kite and _kite.has_method("add_pip"):
		_kite.add_pip()
		player_dodged.emit()


func _pick_pad(used: Array[Vector3]) -> Vector3:
	var pads: Array = _city.rocket_pads
	var free: Array[Vector3] = []
	for p in pads:
		var pad: Vector3 = p
		var taken := false
		for u in used:
			if u.distance_to(pad) < 1.0:
				taken = true
				break
		if not taken:
			free.append(pad)
	if free.is_empty():
		return Vector3.ZERO
	return free[randi() % free.size()]


func _on_gone() -> void:
	_live = maxi(0, _live - 1)
