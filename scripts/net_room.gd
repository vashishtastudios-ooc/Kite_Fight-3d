extends Node

## Talks to the Node game server. Relays kite state; server confirms cuts.

signal waiting(code: String)
signal live
signal peer_ready(card: Dictionary)
signal remote_state(data: Dictionary)
signal kaata(winner_id: String, a_cuts: int, b_cuts: int)
signal gone
signal fail(why: String)

const Cfg := preload("res://scripts/net_config.gd")

var API: String = Cfg.api()
var WS: String = Cfg.ws()

var play_id: String = ""
var slot: String = "a"
var join_code: String = ""
var match_id: String = ""
var _ws: WebSocketPeer
var _http: HTTPRequest
var _http_kind: String = ""
var _card: Dictionary = {}
var _open: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_http)
	_ws = WebSocketPeer.new()
	set_process(true)


func host(play: String, card: Dictionary) -> void:
	play_id = play
	_card = card
	slot = "a"
	_http_kind = "host"
	var body := JSON.stringify({ "hostId": play_id, "mode": "battle" })
	_http.request(API + "/matches", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)


func join(play: String, card: Dictionary, code: String) -> void:
	play_id = play
	_card = card
	slot = "b"
	join_code = code.strip_edges().to_upper()
	_http_kind = "join"
	var body := JSON.stringify({ "joinCode": join_code, "guestId": play_id })
	_http.request(API + "/matches/join", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)


func send_state(data: Dictionary) -> void:
	if not _open:
		return
	_ws.send_text(JSON.stringify(data))


func send_cut() -> void:
	if not _open:
		return
	_ws.send_text(JSON.stringify({ "t": "cut", "by": play_id }))


func finish_match(a_cuts: int, b_cuts: int, winner_id: String) -> void:
	if match_id == "":
		return
	var body := JSON.stringify({ "aCuts": a_cuts, "bCuts": b_cuts, "winnerId": winner_id })
	_http_kind = "finish"
	_http.request(
		API + "/matches/" + match_id + "/finish",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		body
	)


func _on_http(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _http_kind
	_http_kind = ""
	if code < 200 or code >= 300:
		if kind == "host" or kind == "join":
			fail.emit("Couldn't reach the game server.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	if kind == "host" or kind == "join":
		join_code = str(data.get("joinCode", join_code))
		match_id = str(data.get("id", ""))
		if kind == "host":
			waiting.emit(join_code)
		_open_ws()


func _hello_payload() -> Dictionary:
	return {
		"t": "hello",
		"code": join_code,
		"playId": play_id,
		"card": _card,
		"role": "guest" if slot == "b" else "host",
	}


func _open_ws() -> void:
	var err := _ws.connect_to_url(WS)
	if err != OK:
		fail.emit("Couldn't open the fight socket.")
		return


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _open:
			_open = true
			_ws.send_text(JSON.stringify(_hello_payload()))
		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				_handle(parsed)
	elif st == WebSocketPeer.STATE_CLOSED:
		if _open:
			_open = false
			gone.emit()


func _handle(msg: Dictionary) -> void:
	var t := str(msg.get("t", ""))
	if t == "welcome":
		slot = str(msg.get("slot", slot))
	elif t == "peer":
		var card: Variant = msg.get("card", {})
		if card is Dictionary:
			var copy: Dictionary = (card as Dictionary).duplicate()
			copy["playId"] = str(msg.get("playId", ""))
			peer_ready.emit(copy)
	elif t == "ready":
		live.emit()
	elif t == "state":
		remote_state.emit(msg)
	elif t == "kaata":
		kaata.emit(str(msg.get("winnerId", "")), int(msg.get("aCuts", 0)), int(msg.get("bCuts", 0)))
	elif t == "gone":
		gone.emit()
	elif t == "err":
		if str(msg.get("error", "")) == "no_host":
			var tree := get_tree()
			if tree:
				tree.create_timer(0.25).timeout.connect(_resend_hello, CONNECT_ONE_SHOT)
		else:
			fail.emit("Room is full or the code is wrong.")


func _resend_hello() -> void:
	if _open and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(_hello_payload()))
