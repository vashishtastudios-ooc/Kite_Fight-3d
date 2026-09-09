extends Node3D

## Spawns a flock of soaring eagles and is their shared brain. Birds live in
## groups (a mix of solo and 2-3 flocks); each group roams the sky over the
## city, sometimes dives at a kite, and its members peel off to perch on
## rooftops now and then. bird.gd is just the body.

const BirdSc := preload("res://scripts/bird.gd")

enum Mode { PERCH, FLY, LAND }

var _birds: Array = []      ## each: {node, group, mode, perch, offset, timer}
var _groups: Array = []     ## each: {roam, roam_target, roam_t, chase_t, cooldown}
var _hub: Vector3 = Vector3(0.0, 0.0, 92.0)
var _base_y: float = 22.0
var _radius: float = 320.0
var _perch: Array[Vector3] = []
var _kites: Array = []
var _rng := RandomNumberGenerator.new()


func setup(city: Node, kites: Array, count: int = 6) -> void:
	_rng.randomize()
	_kites = kites
	var c: Vector3 = city.spawn_position
	_hub = Vector3(c.x, 0.0, c.z)
	_base_y = c.y
	_collect_perch(city)

	var assigned := 0
	var gid := 0
	while assigned < count:
		var sz := clampi(_rng.randi_range(1, 3), 1, count - assigned)
		_groups.append({
			"roam": _rand_sky(),
			"roam_target": _rand_sky(),
			"roam_t": _rng.randf_range(3.0, 7.0),
			"chase_t": 0.0,
			"cooldown": _rng.randf_range(6.0, 16.0),
		})
		for i in sz:
			var node := BirdSc.new()
			add_child(node)
			node.setup()
			var b := {
				"node": node,
				"group": gid,
				"mode": Mode.FLY,
				"perch": Vector3.ZERO,
				"offset": Vector3(_rng.randf_range(-15.0, 15.0), _rng.randf_range(-7.0, 7.0), _rng.randf_range(-15.0, 15.0)),
				"timer": _rng.randf_range(4.0, 12.0),
			}
			if _rng.randf() < 0.4 and not _perch.is_empty():
				b["mode"] = Mode.PERCH
				b["perch"] = _perch[_rng.randi_range(0, _perch.size() - 1)]
				node.global_position = b["perch"]
			else:
				node.global_position = _groups[gid]["roam"] + b["offset"]
			_birds.append(b)
			assigned += 1
		gid += 1


func tick(delta: float) -> void:
	for g in _groups:
		g["roam_t"] -= delta
		if g["roam_t"] <= 0.0:
			g["roam_target"] = _rand_sky()
			g["roam_t"] = _rng.randf_range(4.0, 9.0)
		g["roam"] = (g["roam"] as Vector3).lerp(g["roam_target"], clampf(0.45 * delta, 0.0, 1.0))
		if g["chase_t"] > 0.0:
			g["chase_t"] -= delta
		else:
			g["cooldown"] -= delta
			if g["cooldown"] <= 0.0:
				g["cooldown"] = _rng.randf_range(9.0, 22.0)
				if _airborne_kite() != null:
					g["chase_t"] = _rng.randf_range(3.5, 6.0)

	for b in _birds:
		var g = _groups[b["group"]]
		var node: Node3D = b["node"]
		match b["mode"]:
			Mode.PERCH:
				node.perch_at(b["perch"], delta)
				b["timer"] -= delta
				if b["timer"] <= 0.0:
					b["mode"] = Mode.FLY
					b["timer"] = _rng.randf_range(7.0, 16.0)
			Mode.LAND:
				node.fly_to(b["perch"] + Vector3(0.0, 1.2, 0.0), delta, 0.3)
				if node.global_position.distance_to(b["perch"]) < 2.5:
					b["mode"] = Mode.PERCH
					b["timer"] = _rng.randf_range(6.0, 15.0)
			Mode.FLY:
				var effort := 0.35
				var target: Vector3 = (g["roam"] as Vector3) + b["offset"]
				if g["chase_t"] > 0.0:
					var k := _airborne_kite()
					if k != null:
						target = k.global_position + b["offset"] * 0.35
						effort = 0.9
				else:
					b["timer"] -= delta
					if b["timer"] <= 0.0 and not _perch.is_empty():
						b["mode"] = Mode.LAND
						b["perch"] = _nearest_perch(node.global_position)
				node.fly_to(target, delta, effort)


func _airborne_kite() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for k in _kites:
		if k == null or not is_instance_valid(k):
			continue
		if k.has_method("is_airborne") and not k.is_airborne():
			continue
		var d: float = _hub.distance_to(k.global_position)
		if d < bd:
			bd = d
			best = k
	return best


func _rand_sky() -> Vector3:
	var ang := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * _radius
	return Vector3(
		_hub.x + cos(ang) * r,
		_base_y + _rng.randf_range(28.0, 108.0),
		_hub.z + sin(ang) * r
	)


func _nearest_perch(from: Vector3) -> Vector3:
	if _perch.is_empty():
		return from
	var best := _perch[0]
	var bd := 1e9
	for p in _perch:
		var d := from.distance_to(p)
		if d < bd:
			bd = d
			best = p
	return best


func _collect_perch(city: Node) -> void:
	## Rooftop tops near the play area make the perch spots.
	var aabbs: Array = city.building_aabbs
	for aabb in aabbs:
		var ctr: Vector3 = (aabb as AABB).get_center()
		var top := Vector3(ctr.x, (aabb as AABB).end.y + 0.4, ctr.z)
		if Vector2(top.x - _hub.x, top.z - _hub.z).length() > 220.0:
			continue
		_perch.append(top)
	if _perch.is_empty():
		_perch.append(Vector3(_hub.x, _base_y + 6.0, _hub.z))
