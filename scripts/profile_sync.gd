extends Node

## Pushes the local flyer card to Mongo via the tiny API. Game still works offline.

const Cfg := preload("res://scripts/net_config.gd")

var API: String = Cfg.api()

var profile: PlayerProfile
var _http: HTTPRequest
var _busy: bool = false
var _queued_push: bool = false
var _mode: String = ""


func setup(profile_in: PlayerProfile) -> void:
	profile = profile_in
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	pull()


func pull() -> void:
	if profile == null or _http == null:
		return
	if _busy:
		return
	_busy = true
	_mode = "pull"
	var err := _http.request(API + "/players/" + profile.play_id)
	if err != OK:
		_busy = false
		_mode = ""


func push() -> void:
	if profile == null or _http == null:
		return
	if _busy:
		_queued_push = true
		return
	_busy = true
	_mode = "push"
	var body := JSON.stringify(profile.to_api())
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(API + "/players/" + profile.play_id, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		_busy = false
		_mode = ""


func _on_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var mode := _mode
	_mode = ""
	if mode == "pull" and code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			profile.apply_remote(parsed)
	elif mode == "pull" and code == 404:
		push()
		return
	if _queued_push:
		_queued_push = false
		push()
