extends Node

## First-launch tutorial: six short steps on the roof, each done by doing it.
## Toss, pull, steer, give line, give slack — then a gentle rival comes up
## and the last step is the real thing: cut its kite. The coach card shows
## one step at a time; a step done flashes green and the next slides in.

const KiteSc := preload("res://scripts/kite.gd")

signal rival_wanted
signal finished

## Keys shown on the coach chip. One place to swap for touch icons.
const STEPS := [
	{"id": "toss", "key": "SPACE", "title": "Toss", "body": "Toss your patang into the wind."},
	{"id": "pull", "key": "Q", "title": "Kheench  ·  pull", "body": "Hold Q to pull the string. The kite darts the way its nose points, and climbs."},
	{"id": "steer", "key": "← →", "title": "Steer", "body": "Tilt the nose with ← and →, then pull to fly that way."},
	{"id": "line", "key": "↓", "title": "Give line", "body": "Hold ↓ to let out string. More line, more sky."},
	{"id": "dheel", "key": "E", "title": "Dheel  ·  slack", "body": "Hold E to give slack. The kite sinks and slips under an attack."},
	{"id": "cut", "key": "Q", "title": "Cut their kite!", "body": "Your rival is up. Swing across their string and pull hard — the faster string cuts."},
]

var kite: KiteSc
var pech: Node
var coach: Node

var _i: int = -1
var _acc: float = 0.0
var _line0: float = 0.0
var _next_t: float = -1.0
var _done: bool = false


func start() -> void:
	_go(0)


func step_id() -> String:
	if _i < 0 or _i >= STEPS.size():
		return ""
	return str(STEPS[_i]["id"])


func tick(delta: float, kheench: bool, dheel: bool, bias: float, reel: float) -> void:
	if _done or kite == null:
		return
	if _next_t >= 0.0:
		_next_t -= delta
		if _next_t < 0.0:
			if _i + 1 >= STEPS.size():
				_done = true
				finished.emit()
			else:
				_go(_i + 1)
		return
	var down := kite.phase == KiteSc.Phase.GROUNDED or kite.phase == KiteSc.Phase.CRASHED or kite.phase == KiteSc.Phase.CUT
	var air := kite.is_airborne() and not down
	if _i > 0 and down:
		coach.hint("Your kite is down. Press SPACE to toss it again.", 0.3)
		return
	match step_id():
		"toss":
			if air:
				_complete()
		"pull":
			if air and kheench:
				_acc += delta
			if _acc >= 1.2:
				_complete()
		"steer":
			if air and absf(bias) > 0.5:
				_acc += delta
			if _acc >= 1.4:
				_complete()
		"line":
			if air and reel > 0.3:
				_acc += delta
			if kite.line_length - _line0 >= 10.0 or _acc >= 2.5:
				_complete()
		"dheel":
			if air and dheel:
				_acc += delta
			if _acc >= 1.0:
				_complete()
		"cut":
			## Strings close: tell them now is the moment.
			if pech and bool(pech.get("active")) and not kheench:
				coach.hint("Now! Hold Q and swipe through their string!", 0.6)


## A clash ended. In the last step, a cut of theirs finishes the tutorial;
## losing yours just sends you back up to try again.
func on_kaata(player_won: bool) -> void:
	if step_id() != "cut" or _next_t >= 0.0:
		return
	if player_won:
		_complete()
		_next_t = 2.2
	else:
		coach.hint("They got you! Toss again with SPACE, and swipe faster.", 3.5)


func _complete() -> void:
	coach.complete()
	_next_t = 0.8


func _go(i: int) -> void:
	_i = i
	_acc = 0.0
	_line0 = kite.line_length if kite else 0.0
	var s: Dictionary = STEPS[i]
	coach.show_step(i, STEPS.size(), str(s["key"]), str(s["title"]), str(s["body"]))
	if s["id"] == "cut":
		rival_wanted.emit()
