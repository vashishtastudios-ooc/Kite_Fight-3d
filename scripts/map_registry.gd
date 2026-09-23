extends RefCounted

## Every map the player can pick, in grid order. Adding a map = one row here,
## its script in main.gd's map switch, and a card image in assets/ui/maps
## (capture with THUMB_SHOT, see main.gd).
##   size: "wide" (2 columns) or "tall" / "square" (1 column)

const MAPS := [
	{
		"id": "city",
		"title": "Jaipur Rooftops",
		"mood": "Pink-city dusk. Roof to roof.",
		"image": "res://assets/ui/maps/city.jpg",
		"size": "wide",
	},
	{
		"id": "pahadi",
		"title": "Pahadi Sham",
		"mood": "Monastery hill, valley mist, ridge lift.",
		"image": "res://assets/ui/maps/pahadi.jpg",
		"size": "wide",
	},
]

## Teasers for the grid. No image: drawn as a silhouette.
const COMING := [
	{"title": "Registan", "mood": "Desert dunes at sundown", "art": "dunes"},
	{"title": "Tukkal Raat", "mood": "A night of lantern kites", "art": "lanterns"},
]


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
