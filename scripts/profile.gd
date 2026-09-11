class_name PlayerProfile
extends RefCounted

## Local flyer card. Same fields later go on an online VS card.
const PATH := "user://profile.cfg"
const KiteSkins := preload("res://scripts/kite_skins.gd")

const RANKS: PackedStringArray = [
	"Rookie",
	"Flyer",
	"Line",
	"Clash",
	"Cutter",
	"Champ",
	"Master",
]
const XP_NEED: Array[int] = [0, 80, 200, 380, 620, 940, 1360]

const XP_FINISH := 8
const XP_CUT := 20
const XP_WIN := 50
const COIN_FINISH := 10
const COIN_CUT := 15
const COIN_WIN := 40
const XP_DODGE := 8
const COIN_DODGE := 5

var display_name: String = "You"
var flyer_id: String = "boy"
var kite_id: String = KiteSkins.SAFFRON
var avatar_path: String = ""
var play_id: String = ""
var xp: int = 0
var coins: int = 0
var owned: PackedStringArray = PackedStringArray([KiteSkins.SAFFRON])
var battles_won: int = 0
var battles_lost: int = 0
var cuts: int = 0
var cloud_push: Callable


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_ensure_play_id()
		save_to_disk()
		return
	display_name = str(cfg.get_value("card", "name", "You")).strip_edges()
	if display_name == "":
		display_name = "You"
	play_id = str(cfg.get_value("card", "play_id", "")).strip_edges()
	_ensure_play_id()
	flyer_id = str(cfg.get_value("card", "flyer", "boy"))
	if flyer_id != "girl":
		flyer_id = "boy"
	kite_id = KiteSkins.clamp_id(str(cfg.get_value("card", "kite", KiteSkins.SAFFRON)))
	avatar_path = str(cfg.get_value("card", "avatar", ""))
	xp = maxi(0, int(cfg.get_value("prog", "xp", 0)))
	coins = maxi(0, int(cfg.get_value("prog", "coins", 0)))
	battles_won = maxi(0, int(cfg.get_value("rec", "won", 0)))
	battles_lost = maxi(0, int(cfg.get_value("rec", "lost", 0)))
	cuts = maxi(0, int(cfg.get_value("rec", "cuts", 0)))
	owned = PackedStringArray([KiteSkins.SAFFRON])
	var raw := str(cfg.get_value("shop", "owned", KiteSkins.SAFFRON)).split(",", false)
	for id in raw:
		var k := KiteSkins.clamp_id(id.strip_edges())
		if not owned.has(k):
			owned.append(k)
	if not owns(kite_id):
		kite_id = KiteSkins.SAFFRON
	_ensure_play_id()


func _ensure_play_id() -> void:
	if play_id != "":
		return
	play_id = "%s-%d" % [str(abs(OS.get_unique_id().hash())), Time.get_unix_time_from_system()]


func to_api() -> Dictionary:
	var skins: Array = []
	for id in owned:
		skins.append(id)
	return {
		"name": display_name,
		"flyer": flyer_id,
		"kite": kite_id,
		"avatarUrl": avatar_path,
		"xp": xp,
		"coins": coins,
		"owned": skins,
		"won": battles_won,
		"lost": battles_lost,
		"cuts": cuts,
	}


func apply_remote(data: Dictionary) -> void:
	if data.is_empty():
		return
	display_name = str(data.get("name", display_name)).strip_edges()
	if display_name == "":
		display_name = "You"
	flyer_id = "girl" if str(data.get("flyer", flyer_id)) == "girl" else "boy"
	kite_id = KiteSkins.clamp_id(str(data.get("kite", kite_id)))
	avatar_path = str(data.get("avatarUrl", avatar_path))
	xp = maxi(0, int(data.get("xp", xp)))
	coins = maxi(0, int(data.get("coins", coins)))
	battles_won = maxi(0, int(data.get("won", battles_won)))
	battles_lost = maxi(0, int(data.get("lost", battles_lost)))
	cuts = maxi(0, int(data.get("cuts", cuts)))
	owned = PackedStringArray([KiteSkins.SAFFRON])
	var raw: Variant = data.get("owned", [])
	if raw is Array:
		for id in raw:
			var k := KiteSkins.clamp_id(str(id))
			if not owned.has(k):
				owned.append(k)
	if not owns(kite_id):
		kite_id = KiteSkins.SAFFRON
	save_to_disk()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("card", "name", display_name)
	cfg.set_value("card", "play_id", play_id)
	cfg.set_value("card", "flyer", flyer_id)
	cfg.set_value("card", "kite", kite_id)
	cfg.set_value("card", "avatar", avatar_path)
	cfg.set_value("prog", "xp", xp)
	cfg.set_value("prog", "coins", coins)
	cfg.set_value("rec", "won", battles_won)
	cfg.set_value("rec", "lost", battles_lost)
	cfg.set_value("rec", "cuts", cuts)
	cfg.set_value("shop", "owned", ",".join(owned))
	cfg.save(PATH)
	if cloud_push.is_valid():
		cloud_push.call()


func owns(id: String) -> bool:
	return owned.has(KiteSkins.clamp_id(id))


func buy(id: String) -> bool:
	id = KiteSkins.clamp_id(id)
	if owns(id):
		return true
	var price := KiteSkins.price_for(id)
	if coins < price:
		return false
	coins -= price
	owned.append(id)
	kite_id = id
	save_to_disk()
	return true


func set_kite(id: String) -> bool:
	id = KiteSkins.clamp_id(id)
	if not owns(id):
		return false
	kite_id = id
	save_to_disk()
	return true


func rank_index() -> int:
	var idx := 0
	for i in XP_NEED.size():
		if xp >= XP_NEED[i]:
			idx = i
	return idx


func rank_name() -> String:
	return RANKS[rank_index()]


func rank_progress() -> float:
	var i := rank_index()
	if i >= XP_NEED.size() - 1:
		return 1.0
	var a := float(XP_NEED[i])
	var b := float(XP_NEED[i + 1])
	return clampf((float(xp) - a) / maxf(b - a, 1.0), 0.0, 1.0)


func next_rank_name() -> String:
	var i := rank_index()
	if i >= RANKS.size() - 1:
		return RANKS[RANKS.size() - 1]
	return RANKS[i + 1]


func award_battle(cut_count: int, won: bool) -> Dictionary:
	var n := maxi(0, cut_count)
	var add_xp := XP_FINISH + n * XP_CUT
	var add_coins := COIN_FINISH + n * COIN_CUT
	if won:
		add_xp += XP_WIN
		add_coins += COIN_WIN
		battles_won += 1
	else:
		battles_lost += 1
	cuts += n
	return _apply(add_xp, add_coins)


func award_save(dodge_count: int) -> Dictionary:
	var n := clampi(dodge_count, 0, 8)
	return _apply(XP_FINISH + n * XP_DODGE, COIN_FINISH + n * COIN_DODGE)


func you_card() -> Dictionary:
	return {
		"name": display_name,
		"rank": rank_name(),
		"won": battles_won,
		"kite_id": kite_id,
		"coins": coins,
		"avatar_path": avatar_path,
		"is_you": true,
		"letter": _letter(display_name),
	}


func rival_card(rival_kite: String) -> Dictionary:
	return {
		"name": "Rival",
		"rank": rank_name(),
		"won": 0,
		"kite_id": KiteSkins.rival_id(rival_kite),
		"coins": -1,
		"avatar_path": "",
		"is_you": false,
		"letter": "R",
	}


func _apply(add_xp: int, add_coins: int) -> Dictionary:
	var before := rank_name()
	xp += maxi(0, add_xp)
	coins += maxi(0, add_coins)
	save_to_disk()
	return {
		"xp": add_xp,
		"coins": add_coins,
		"rank": rank_name(),
		"ranked_up": rank_name() != before,
	}


func _letter(n: String) -> String:
	var s := n.strip_edges()
	if s == "":
		return "Y"
	return s.substr(0, 1).to_upper()
