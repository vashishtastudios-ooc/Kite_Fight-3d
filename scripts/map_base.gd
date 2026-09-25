extends Node3D

## What every playable map gives the game. The city (city_generator.gd) and
## each new map extend this, so kites, rockets, wind, people and the camera
## never care which map they are on.

## Where the flyer stands, and the walkable deck around them (x/z rect).
var spawn_position: Vector3 = Vector3(0.0, 20.3, 92.0)
var rooftop_height: float = 20.0
var rooftop_bounds: Rect2 = Rect2(-6.5, 86.0, 13.0, 13.0)
## Boxes a kite crashes into, and the box of the flyer's own roof (which it
## may sit on). Maps with terrain override is_solid() as well.
var building_aabbs: Array[AABB] = []
## A night map: kite strings carry tukkal lanterns so kites show in the dark.
var night: bool = false
var player_building_aabb: AABB
## Where Diwali rockets launch from in Save mode.
var rocket_pads: Array[Vector3] = []


## Build the map. Called once, before anything else reads it.
func build() -> void:
	pass


## Called after the default dusk look is set up: a map may restyle the sky,
## fog, sun and ambient here.
func configure_world(_env: Environment, _sun: DirectionalLight3D) -> void:
	pass


func rival_hand_position() -> Vector3:
	return spawn_position + Vector3(-40.0, 0.0, -30.0)


func rival_roof_bounds() -> Rect2:
	var h := rival_hand_position()
	return Rect2(h.x - 5.0, h.z - 5.0, 10.0, 10.0)


## A spot where a watcher stands to cheer.
func palace_watch_spot() -> Vector3:
	return spawn_position + Vector3(3.0, 0.0, -1.5)


## 0..1 churn in the air from nearby obstacles (roof air wheels the kite).
func nearest_building_chop(_pos: Vector3) -> float:
	return 0.0


## Upward air (m/s) at a point — ridge lift where wind meets a slope.
func lift_at(_pos: Vector3) -> float:
	return 0.0


## Does a kite at this point hit something?
func is_solid(p: Vector3) -> bool:
	if p.y < 1.4:
		return true
	for aabb in building_aabbs:
		if aabb.grow(0.3).has_point(p):
			if aabb.intersects(player_building_aabb) and p.y >= rooftop_height - 0.2:
				continue
			return true
	return false


func set_water_sun(_to_sun: Vector3) -> void:
	pass
