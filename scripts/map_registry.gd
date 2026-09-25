extends RefCounted

## Every map the player can pick, in grid order. Adding a map = one row here
## and a card image in assets/ui/maps (capture with THUMB_SHOT, see main.gd).
##   script: the map's script, loaded only when the map is played
##   size: "wide" (2 columns) or "tall" / "square" (1 column)

## The map the game opens on, and the one the title flies over.
const DEFAULT := "pahadi"

const MAPS := [
	{
		"id": "city",
		"script": "res://scripts/city_generator.gd",
		"title": "Jaipur Rooftops",
		"mood": "Pink-city dusk. Roof to roof.",
		"image": "res://assets/ui/maps/city.jpg",
		"size": "wide",
	},
	{
		"id": "pahadi",
		"script": "res://scripts/map_pahadi.gd",
		"title": "Pahadi Sham",
		"mood": "Monastery hill, valley mist, ridge lift.",
		"image": "res://assets/ui/maps/pahadi.jpg",
		"size": "wide",
	},
	{
		"id": "registan",
		"script": "res://scripts/map_registan.gd",
		"title": "Registan",
		"mood": "Golden dunes, a fort, thermals off hot sand.",
		"image": "res://assets/ui/maps/registan.jpg",
		"size": "wide",
	},
	{
		"id": "jaipur_night",
		"script": "res://scripts/map_jaipur_night.gd",
		"title": "Jaipur Night",
		"mood": "Moonlit palaces. Amber lanterns. Indigo skies.",
		"image": "res://assets/ui/maps/jaipur_night.jpg",
		"size": "wide",
	},
	{
		"id": "tukkal_raat",
		"script": "res://scripts/map_tukkal.gd",
		"title": "Tukkal Raat",
		"mood": "Moonrise over the aqueduct. Lanterns on every string.",
		"image": "res://assets/ui/maps/tukkal_raat.jpg",
		"size": "wide",
	},
]

## Teasers for the grid. No image: drawn as a silhouette.
const COMING := []


static func find(id: String) -> Dictionary:
	for m in MAPS:
		if m["id"] == id:
			return m
	return MAPS[0]


static func has(id: String) -> bool:
	for m in MAPS:
		if m["id"] == id:
			return true
	return false
