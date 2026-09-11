import "dotenv/config";
import http from "http";
import express from "express";
import { MongoClient, ObjectId } from "mongodb";
import { WebSocketServer } from "ws";
import { attachGame } from "./rooms.js";

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "0.0.0.0";
const PUBLIC_URL = process.env.PUBLIC_URL || `http://127.0.0.1:${PORT}`;
const URI = process.env.MONGODB_URI || "";
const DB_NAME = process.env.MONGODB_DB || "patangbaz";
const RANKS = ["Rookie", "Flyer", "Line", "Clash", "Cutter", "Champ", "Master"];
const XP_NEED = [0, 80, 200, 380, 620, 940, 1360];
const XP_FINISH = 8;
const XP_CUT = 20;
const XP_WIN = 50;
const COIN_FINISH = 10;
const COIN_CUT = 15;
const COIN_WIN = 40;

function rankName(xp) {
  let idx = 0;
  for (let i = 0; i < XP_NEED.length; i++) {
    if (xp >= XP_NEED[i]) idx = i;
  }
  return RANKS[idx];
}

function cardFromBody(playId, body) {
  const owned = Array.isArray(body.owned) && body.owned.length
    ? body.owned
    : ["saffron"];
  const xp = Math.max(0, Number(body.xp) || 0);
  const card = {
    playId,
    name: String(body.name || "You").slice(0, 16),
    flyer: body.flyer === "girl" ? "girl" : "boy",
    kite: String(body.kite || "saffron"),
    avatarUrl: String(body.avatarUrl || body.avatar_path || ""),
    xp,
    coins: Math.max(0, Number(body.coins) || 0),
    owned,
    won: Math.max(0, Number(body.won ?? body.battles_won) || 0),
    lost: Math.max(0, Number(body.lost ?? body.battles_lost) || 0),
    cuts: Math.max(0, Number(body.cuts) || 0),
    rank: rankName(xp),
    updatedAt: new Date(),
  };
  const googleId = String(body.googleId || "").slice(0, 64);
  if (googleId) {
    card.googleId = googleId;
  }
  return card;
}

function playerToClient(doc) {
  if (!doc) return null;
  return {
    playId: doc.playId,
    googleId: doc.googleId || "",
    name: doc.name,
    flyer: doc.flyer,
    kite: doc.kite,
    avatarUrl: doc.avatarUrl || "",
    xp: doc.xp,
    coins: doc.coins,
    owned: doc.owned,
    won: doc.won,
    lost: doc.lost,
    cuts: doc.cuts,
    rank: doc.rank || rankName(doc.xp || 0),
  };
}

function matchToClient(doc) {
  if (!doc) return null;
  return {
    id: String(doc._id),
    joinCode: doc.joinCode,
    mode: doc.mode,
    aId: doc.aId,
    bId: doc.bId,
    aCuts: doc.aCuts,
    bCuts: doc.bCuts,
    winnerId: doc.winnerId || "",
    status: doc.status,
    createdAt: doc.createdAt,
    endedAt: doc.endedAt || null,
  };
}

function joinCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 4; i++) {
    s += chars[Math.floor(Math.random() * chars.length)];
  }
  return s;
}

function payout(cuts, won) {
  const n = Math.max(0, cuts);
  return {
    xp: XP_FINISH + n * XP_CUT + (won ? XP_WIN : 0),
    coins: COIN_FINISH + n * COIN_CUT + (won ? COIN_WIN : 0),
  };
}

if (!URI) {
  console.error("Set MONGODB_URI in server/.env");
  process.exit(1);
}

const client = new MongoClient(URI);
const app = express();
app.set("trust proxy", 1);
app.use(express.json({ limit: "32kb" }));
app.use((_req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,PUT,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (_req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  next();
});

let players;
let matches;

async function findFlyer(id) {
  if (!id) return null;
  return players.findOne({ $or: [{ playId: id }, { googleId: id }] });
}

async function grant(id, addXp, addCoins, extra) {
  const doc = await findFlyer(id);
  if (!doc) return;
  const xp = Math.max(0, (doc.xp || 0) + addXp);
  const coins = Math.max(0, (doc.coins || 0) + addCoins);
  await players.updateOne(
    { _id: doc._id },
    {
      $set: {
        xp,
        coins,
        rank: rankName(xp),
        updatedAt: new Date(),
        won: extra.won != null ? extra.won : doc.won,
        lost: extra.lost != null ? extra.lost : doc.lost,
        cuts: extra.cuts != null ? extra.cuts : doc.cuts,
      },
    }
  );
}

app.get("/", (_req, res) => {
  res.json({
    name: "patangbaz",
    ok: true,
    ws: "/ws",
    publicUrl: PUBLIC_URL,
  });
});

app.get("/health", (_req, res) => {
  res.json({ ok: true, db: DB_NAME, ready: ["players", "matches"], ws: "/ws" });
});

app.get("/players/:playId", async (req, res) => {
  try {
    const doc = await findFlyer(req.params.playId);
    if (!doc) {
      res.status(404).json({ error: "not_found" });
      return;
    }
    res.json(playerToClient(doc));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

app.put("/players/:playId", async (req, res) => {
  try {
    const playId = req.params.playId;
    const card = cardFromBody(playId, req.body || {});
    await players.updateOne(
      { playId },
      { $set: card, $setOnInsert: { createdAt: new Date() } },
      { upsert: true }
    );
    res.json(playerToClient(card));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

app.post("/matches", async (req, res) => {
  try {
    const hostId = String(req.body?.hostId || "");
    const mode = req.body?.mode === "save" ? "save" : "battle";
    if (!hostId) {
      res.status(400).json({ error: "hostId_required" });
      return;
    }
    let code = joinCode();
    for (let i = 0; i < 8; i++) {
      const taken = await matches.findOne({ joinCode: code, status: { $in: ["waiting", "live"] } });
      if (!taken) break;
      code = joinCode();
    }
    const doc = {
      joinCode: code,
      mode,
      aId: hostId,
      bId: "",
      aCuts: 0,
      bCuts: 0,
      winnerId: "",
      status: "waiting",
      createdAt: new Date(),
      endedAt: null,
    };
    const result = await matches.insertOne(doc);
    doc._id = result.insertedId;
    res.json(matchToClient(doc));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

app.post("/matches/join", async (req, res) => {
  try {
    const code = String(req.body?.joinCode || "").toUpperCase();
    const guestId = String(req.body?.guestId || "");
    if (!code || !guestId) {
      res.status(400).json({ error: "joinCode_and_guestId_required" });
      return;
    }
    const doc = await matches.findOne({ joinCode: code, status: "waiting" });
    if (!doc) {
      res.status(404).json({ error: "not_found" });
      return;
    }
    if (doc.aId === guestId) {
      res.json(matchToClient(doc));
      return;
    }
    await matches.updateOne(
      { _id: doc._id },
      { $set: { bId: guestId, status: "live" } }
    );
    doc.bId = guestId;
    doc.status = "live";
    res.json(matchToClient(doc));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

app.get("/matches/:id", async (req, res) => {
  try {
    let doc = null;
    if (ObjectId.isValid(req.params.id)) {
      doc = await matches.findOne({ _id: new ObjectId(req.params.id) });
    }
    if (!doc) {
      doc = await matches.findOne({ joinCode: String(req.params.id).toUpperCase() });
    }
    if (!doc) {
      res.status(404).json({ error: "not_found" });
      return;
    }
    res.json(matchToClient(doc));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

app.post("/matches/:id/finish", async (req, res) => {
  try {
    if (!ObjectId.isValid(req.params.id)) {
      res.status(400).json({ error: "bad_id" });
      return;
    }
    const doc = await matches.findOne({ _id: new ObjectId(req.params.id) });
    if (!doc) {
      res.status(404).json({ error: "not_found" });
      return;
    }
    if (doc.status === "done") {
      res.json(matchToClient(doc));
      return;
    }
    const aCuts = Math.max(0, Number(req.body?.aCuts) || 0);
    const bCuts = Math.max(0, Number(req.body?.bCuts) || 0);
    const winnerId = String(req.body?.winnerId || "");
    const aWon = winnerId !== "" && winnerId === doc.aId;
    const bWon = winnerId !== "" && winnerId === doc.bId;
    await matches.updateOne(
      { _id: doc._id },
      {
        $set: {
          aCuts,
          bCuts,
          winnerId,
          status: "done",
          endedAt: new Date(),
        },
      }
    );
    const aPay = payout(aCuts, aWon);
    const bPay = payout(bCuts, bWon);
    const aFlyer = await findFlyer(doc.aId);
    const bFlyer = await findFlyer(doc.bId);
    if (aFlyer) {
      await grant(doc.aId, aPay.xp, aPay.coins, {
        won: (aFlyer.won || 0) + (aWon ? 1 : 0),
        lost: (aFlyer.lost || 0) + (bWon ? 1 : 0),
        cuts: (aFlyer.cuts || 0) + aCuts,
      });
    }
    if (bFlyer && doc.bId) {
      await grant(doc.bId, bPay.xp, bPay.coins, {
        won: (bFlyer.won || 0) + (bWon ? 1 : 0),
        lost: (bFlyer.lost || 0) + (aWon ? 1 : 0),
        cuts: (bFlyer.cuts || 0) + bCuts,
      });
    }
    const fresh = await matches.findOne({ _id: doc._id });
    res.json(matchToClient(fresh));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "db_error" });
  }
});

try {
  await client.connect();
  const db = client.db(DB_NAME);
  players = db.collection("players");
  matches = db.collection("matches");
  await players.createIndex({ playId: 1 }, { unique: true });
  await players.createIndex({ googleId: 1 }, { unique: true, sparse: true });
  await matches.createIndex({ joinCode: 1 });
  await matches.createIndex({ aId: 1, createdAt: -1 });
  await matches.createIndex({ bId: 1, createdAt: -1 });
  await matches.createIndex({ status: 1 });
  const httpServer = http.createServer(app);
  const wss = new WebSocketServer({ server: httpServer, path: "/ws" });
  attachGame(wss);
  httpServer.listen(PORT, HOST, () => {
    console.log(`Patangbaz API+game ${HOST}:${PORT}  db=${DB_NAME}  ws=/ws  public=${PUBLIC_URL}`);
  });
} catch (err) {
  console.error("Mongo connect failed:", err.message);
  process.exit(1);
}
