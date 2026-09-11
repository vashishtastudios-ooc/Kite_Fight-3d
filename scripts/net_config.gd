extends Object
class_name NetConfig

## One switch for the fight + profile API.
## false = this PC (127.0.0.1:8787). true = VPS at game.azziop.com.
## Override at launch with:  --  --live-server   or   --  --local-server

const USE_LIVE := false
const LIVE_API := "https://www.game.azziop.com"
const LIVE_WS := "wss://www.game.azziop.com/ws"
const LOCAL_API := "http://127.0.0.1:8787"
const LOCAL_WS := "ws://127.0.0.1:8787/ws"


static func live() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--local-server":
			return false
		if arg == "--live-server":
			return true
	return USE_LIVE


static func api() -> String:
	return LIVE_API if live() else LOCAL_API


static func ws() -> String:
	return LIVE_WS if live() else LOCAL_WS
