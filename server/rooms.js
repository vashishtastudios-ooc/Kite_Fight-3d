// Live 2-player rooms. Kite ticks stay on each Godot client; this relays state and confirms cuts.

export function attachGame(wss) {
	const rooms = new Map();

	function send(ws, msg) {
		if (ws && ws.readyState === 1) {
			ws.send(JSON.stringify(msg));
		}
	}

	function otherOf(room, ws) {
		if (room.a === ws) {
			return room.b;
		}
		if (room.b === ws) {
			return room.a;
		}
		return null;
	}

	const beat = setInterval(() => {
		wss.clients.forEach((ws) => {
			if (ws.isAlive === false) {
				ws.terminate();
				return;
			}
			ws.isAlive = false;
			ws.ping();
		});
	}, 20000);
	wss.on("close", () => clearInterval(beat));

	wss.on("connection", (ws) => {
		ws.roomCode = "";
		ws.isAlive = true;
		ws.on("pong", () => {
			ws.isAlive = true;
		});
		ws.on("message", (raw) => {
			let msg;
			try {
				msg = JSON.parse(String(raw));
			} catch {
				return;
			}
			const t = msg.t;
			if (t === "hello") {
				const code = String(msg.code || "").toUpperCase();
				if (code.length < 4) {
					send(ws, { t: "err", error: "bad_code" });
					return;
				}
				let room = rooms.get(code);
				if (!room) {
					if (msg.role === "guest") {
						send(ws, { t: "err", error: "no_host" });
						return;
					}
					room = {
						code,
						a: ws,
						b: null,
						aId: String(msg.playId || ""),
						bId: "",
						aCard: msg.card || {},
						bCard: {},
						aCuts: 0,
						bCuts: 0,
						cutLock: false,
					};
					rooms.set(code, room);
					ws.roomCode = code;
					send(ws, { t: "welcome", slot: "a", code });
					return;
				}
				if (room.b && room.b.readyState === 1) {
					send(ws, { t: "err", error: "full" });
					return;
				}
				room.b = ws;
				room.bId = String(msg.playId || "");
				room.bCard = msg.card || {};
				ws.roomCode = code;
				send(ws, { t: "welcome", slot: "b", code });
				send(room.a, { t: "peer", card: room.bCard, playId: room.bId });
				send(room.b, { t: "peer", card: room.aCard, playId: room.aId });
				send(room.a, { t: "ready" });
				send(room.b, { t: "ready" });
				return;
			}
			const room = rooms.get(ws.roomCode);
			if (!room) {
				return;
			}
			if (t === "state") {
				send(otherOf(room, ws), msg);
				return;
			}
			if (t === "cut") {
				if (room.cutLock) {
					return;
				}
				room.cutLock = true;
				const by = String(msg.by || "");
				const aWon = by !== "" && by === room.aId;
				if (aWon) {
					room.aCuts += 1;
				} else {
					room.bCuts += 1;
				}
				const payload = {
					t: "kaata",
					winnerId: by,
					aCuts: room.aCuts,
					bCuts: room.bCuts,
				};
				send(room.a, payload);
				send(room.b, payload);
				setTimeout(() => {
					room.cutLock = false;
				}, 900);
				return;
			}
		});
		ws.on("close", () => {
			const room = rooms.get(ws.roomCode);
			if (!room) {
				return;
			}
			const peer = otherOf(room, ws);
			send(peer, { t: "gone" });
			rooms.delete(ws.roomCode);
		});
	});
}
