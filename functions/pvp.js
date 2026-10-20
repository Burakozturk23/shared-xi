"use strict";
const crypto = require("node:crypto");
const zlib = require("node:zlib");
const E = require("./pvp_engine");
const {validId} = require("./career_transfer");
const {fail, hash, norm, catalog} = E;
const catalogBody = JSON.stringify(catalog);
const catalogArchive = {hash: hash(catalogBody), gzip: zlib.gzipSync(catalogBody).toString("base64")};
const defaults = {friendEnabled: false, rankedEnabled: false, rewardsEnabled: false, eloEnabled: false};
function createService({db, isLinked, blocked, profile, settle, getPolicy = async () => ({}),
  now = Date.now, random = () => crypto.randomBytes(32).toString("hex")}) {
  const caches = new Map([[catalog.version, catalog]]);
  async function pinned(version) {
    if (caches.has(version)) return caches.get(version);
    const data = (await db.ref(`pvpCatalogs/${version}`).get()).val();
    if (!data?.gzip) fail("unavailable", "Maçın veri sürümü yüklenemedi; kaydın korunuyor.");
    const c = JSON.parse(zlib.gunzipSync(Buffer.from(data.gzip, "base64")));
    if (c.version !== version || hash(JSON.stringify(c)) !== data.hash) {
      fail("unavailable",
          "Veri sürümü doğrulanamadı.");
    }
    caches.set(version, c); return c;
  }
  function check(input, current = false) {
    if (!E.MODES.includes(input.mode) || input.schemaVersion !== 1 || input.ruleVersion !== E.RULE ||
      current && input.dataRevision !== catalog.version) {
      fail("failed-precondition",
          "Online sürüm güncellendi; ekranı yeniden aç.");
    }
  }
  async function policy(mode) {
    const p = await getPolicy(); const result = {...defaults, ...p, ...p.modes?.[mode]};
    if (mode === "club_manager" && result.managerRankedVerified !== true) result.rankedEnabled = false;
    return result;
  }
  async function change(mode, fn) {
    let error; const time = now();
    const tx = await db.ref(`pvpV1/${mode}`).transaction((raw) => {
      error = null;
      const s = {rooms: {}, active: {}, queue: {}, requests: {}, rate: {}, pairs: {}, ...structuredClone(raw)};
      for (const k of ["rooms", "active", "queue", "requests", "rate", "pairs"]) s[k] ||= {};
      try {
        fn(s, time); return s;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "İşlem çakıştı; aynı isteği yeniden dene.");
    return tx.snapshot.val();
  }
  async function status(uid, input) {
    check(input);
    const p = await policy(input.mode);
    const s = (await db.ref(`pvpV1/${input.mode}`).get()).val() || {};
    const active = E.hydrate(s.rooms?.[s.active?.[uid]]);
    return {schemaVersion: 1, ruleVersion: E.RULE, dataRevision: catalog.version,
      availability: {friendEnabled: p.friendEnabled, rankedEnabled: p.rankedEnabled,
        rewardsEnabled: p.rewardsEnabled, eloEnabled: p.eloEnabled},
      activeId: active?.id || null, activePlayKind: active?.playKind || null, linked: await isLinked(uid),
      history: Object.values(s?.rooms || {}).filter((r) => [r.host, r.guest].includes(uid) && E.terminal(r))
          .sort((a, b) => b.finishedAt - a.finishedAt).slice(0, 20).map((r) => ({id: r.id, mode: r.mode,
            playKind: r.playKind, scores: r.scores, winnerUid: r.winnerUid, status: r.status,
            finishedAt: r.finishedAt, ruleVersion: r.ruleVersion, dataRevision: r.dataRevision})),
      clubs: catalog.clubOptions.map((id) => catalog.criteria[id]), countries:
          catalog.countryOptions.map((id) => catalog.criteria[id])};
  }
  async function enter(uid, input) {
    check(input, input.action !== "resume");
    if (!await isLinked(uid)) fail("permission-denied", "Online maç için kalıcı Google hesabını bağla.");
    if (!validId(input.actionId) || !["create", "join", "search", "resume"].includes(input.action) ||
      !["friend", "ranked"].includes(input.playKind)) fail("invalid-argument", "Geçersiz oda isteği.");
    if (input.action === "search" && input.playKind !== "ranked" ||
      ["create", "join"].includes(input.action) && input.playKind !== "friend") {
      fail("invalid-argument",
          "Eşleşme türü uyuşmuyor.");
    }
    const p = await policy(input.mode);
    if (input.action !== "resume" && !(input.playKind === "ranked" ? p.rankedEnabled : p.friendEnabled)) {
      fail("failed-precondition", input.playKind === "ranked" ?
          "Bu modda sıralamalı maç henüz açılmadı." : "Arkadaş güncellemesi henüz açılmadı.");
    }
    if (input.action === "join" && !/^[A-F0-9]{8}$/.test(input.code || "")) {
      fail("invalid-argument",
          "Oda kodu 8 karakter olmalı.");
    }
    if (input.playKind === "ranked" && input.profile && input.profile !== "standard" ||
      input.profile && !["standard", "series3"].includes(input.profile)) {
      fail("invalid-argument",
          "Geçersiz kural profili.");
    }
    const name = (await profile(uid)).displayName || "Oyuncu";
    const denied = await blocked(uid); const seed = random();
    // Recheck both sides at join time: a host may block an account after opening a room.
    // Fresh queue candidates retain their creation-time checks so simultaneous arrivals can pair.
    const peers = new Set();
    if (input.action === "join") {
      const room = (await db.ref(`pvpV1/${input.mode}/rooms/${input.code}`).get()).val();
      if (room?.host) peers.add(room.host);
    } else if (input.action === "search") {
      const queue = (await db.ref(`pvpV1/${input.mode}/queue`).get()).val() || {};
      for (const peer of Object.keys(queue)) if (peer !== uid) peers.add(peer);
    }
    const allowedPeers = new Set();
    await Promise.all([...peers].map(async (peer) => {
      if (!denied.has(peer) && await isLinked(peer) && !(await blocked(peer)).has(uid)) allowedPeers.add(peer);
    }));
    const fingerprint = hash([input.action, input.code || null, input.playKind, input.profile || "standard"]);
    if (input.action !== "resume") {
      await db.ref(`pvpCatalogs/${catalog.version}`).transaction((raw) => raw ||
        catalogArchive);
    }
    const s = await change(input.mode, (s, time) => {
      const key = uid + "__" + input.actionId; const receipt = s.requests[key];
      if (receipt) {
        if (receipt.fingerprint !== fingerprint) {
          fail("invalid-argument",
              "Aynı istek farklı seçimle kullanılamaz.");
        } return;
      }
      const old = E.hydrate(s.rooms[s.active[uid]]);
      if (input.action === "resume") {
        if (!old || old.playKind !== input.playKind) fail("not-found", "Bu modda devam eden maç yok.");
        s.requests[key] = {id: old.id, fingerprint}; return;
      }
      if (old) {
        E.advance(old, time); s.rooms[old.id] = old;
        if (!E.terminal(old)) fail("already-exists", "Önce kayıtlı maça devam et veya aramayı iptal et.");
      }
      const rate = s.rate[uid] || {at: time, count: 0};
      if (time - rate.at >= 60000) {
        rate.at = time; rate.count = 0;
      }
      if (++rate.count > 12) fail("resource-exhausted", "Çok sık oda isteği; biraz bekle.");
      s.rate[uid] = rate;
      for (const [u, q] of Object.entries(s.queue)) {
        if (time >= q.expiresAt) {
          const stale = E.hydrate(s.rooms[q.id]);
          if (stale && stale.status === "waiting") {
            E.finish(stale, "expired", "Rakip bulunamadı.", time, null); s.rooms[q.id] = stale;
          }
          delete s.queue[u];
        }
      }
      let room;
      if (input.action === "join") {
        room = E.hydrate(s.rooms[input.code]);
        if (!room || room.mode !== input.mode || room.playKind !== "friend" || room.status !== "waiting" ||
          room.guest || time >= room.createdAt + 300000 || room.host === uid || room.dataRevision !== catalog.version) {
          fail("failed-precondition", "Bu kod seçilen moda ait değil, oda dolu veya süresi doldu.");
        }
        if (!allowedPeers.has(room.host) || denied.has(room.host) || (room.blocked || []).includes(uid)) {
          fail("permission-denied",
              "Bu odaya katılamazsın.");
        }
      } else if (input.action === "search") {
        for (const [u, q] of Object.entries(s.queue)) {
          const candidate = E.hydrate(s.rooms[q.id]); const pairKey = [uid, u].sort().join("__");
          const recent = s.pairs[pairKey] || [];
          if (u === uid || peers.has(u) && !allowedPeers.has(u) || denied.has(u) || !candidate ||
            candidate.status !== "waiting" ||
              candidate.dataRevision !== catalog.version ||
            (candidate.blocked || []).includes(uid) || recent.filter((t) => time - t < 86400000).length >= 2) continue;
          room = candidate; delete s.queue[u]; s.pairs[pairKey] = [...recent.filter((t) =>
            time - t < 86400000), time]; break;
        }
      }
      if (!room) {
        const code = hash([seed, uid, input.actionId]).slice(0, 8).toUpperCase();
        if (s.rooms[code]) fail("already-exists", "Yeni bir oda isteği oluştur.");
        room = E.hydrate({id: code, mode: input.mode, playKind: input.playKind, schemaVersion: 1, ruleVersion: E.RULE,
          dataRevision: catalog.version, seed, host: uid, guest: null, names: {[uid]: name}, blocked: [...denied],
          status: "waiting", revision: 0, createdAt: time, profile: input.profile || "standard",
          rankedEligible: input.playKind === "ranked" && p.rankedEnabled, rewardPolicy: {rewardsEnabled:
              p.rewardsEnabled, eloEnabled: p.eloEnabled},
          series: {id: code, game: 1, limit: input.profile === "series3" ? 3 : 1, wins: {}}});
        if (input.action === "search") s.queue[uid] = {id: code, expiresAt: time + 30000};
      } else {
        room.guest = uid; room.names[uid] = name; room.status = "ready"; room.revision++;
        room.presence = {[uid]: time, [room.host]: time};
      }
      s.rooms[room.id] = room; s.active[uid] = room.id; s.requests[key] = {id: room.id, fingerprint};
      if (room.guest) {
        s.active[room.host] = room.id; s.active[room.guest] = room.id;
      }
    });
    const r = E.hydrate(s.rooms[s.requests[uid + "__" + input.actionId].id]);
    return {room: E.view(await pinned(r.dataRevision), r, uid, now())};
  }
  async function act(uid, input) {
    check(input);
    if (!await isLinked(uid)) fail("permission-denied", "Kalıcı hesap gerekli.");
    if (!/^[A-F0-9]{8}$/.test(input.roomId || "")) fail("invalid-argument", "Geçersiz oda.");
    const before = E.hydrate((await db.ref(`pvpV1/${input.mode}/rooms/${input.roomId}`).get()).val());
    if (!before || ![before.host, before.guest].includes(uid)) {
      fail("permission-denied",
          "Bu maçın katılımcısı değilsin.");
    }
    if (before.schemaVersion !== 1 || before.ruleVersion !== E.RULE) {
      fail("failed-precondition", "Maç kural sürümü desteklenmiyor; kayıt korunuyor.");
    }
    let c;
    try {
      c = await pinned(before.dataRevision);
    } catch (error) {
      if (E.terminal(before)) throw error;
      const state = await change(input.mode, (s, time) => {
        const room = E.hydrate(s.rooms[before.id]);
        if (!E.terminal(room)) {
          E.finish(room, "cancelled", "Sunucu veri sürümünü doğrulayamadı. Maç tarafsız iptal edildi.", time, null);
          room.revision++;
          room.settlement = Object.fromEntries([room.host, room.guest].filter(Boolean).map((u) =>
            [u, {status: "none", coins: 0, xp: 0, eloDelta: 0}]));
          s.rooms[room.id] = room;
        }
      });
      return {room: E.view(catalog, E.hydrate(state.rooms[before.id]), uid, now()), receipt: null};
    }
    const p = await policy(input.mode);
    const event = input.action !== "poll";
    if (event && !validId(input.actionId)) fail("invalid-argument", "Hamle kimliği gerekli.");
    const allowed = new Set(["mode", "schemaVersion", "ruleVersion", "dataRevision", "roomId",
      "actionId", "action", "revision",
      "playerId", "targetId", "criterionId", "round", "playerIds", "formation", "tactics", "choice",
      "clientVersion", "platform"]);
    if (Object.keys(input).some((k) => !allowed.has(k))) {
      fail("invalid-argument",
          "İstemci skor veya kanıt gönderemez.");
    }
    const fp = hash(Object.fromEntries(Object.entries(input).sort(([a], [b]) => a.localeCompare(b))));
    const seed = random(); let receipt;
    const s = await change(input.mode, (s, time) => {
      const r = E.hydrate(s.rooms[input.roomId]);
      if (!r || ![r.host, r.guest].includes(uid)) fail("permission-denied", "Maç yetkisi değişti.");
      const key = uid + "__" + input.actionId;
      if (event && r.receipts[key]) {
        if (r.receipts[key].fingerprint !== fp) fail("invalid-argument", "Aynı hamle kimliği değiştirilemez.");
        receipt = r.receipts[key].result; return;
      }
      const was = hash([r.status, r.turnUid, r.turnDeadline, r.scores]); E.advance(r, time);
      if (was !== hash([r.status, r.turnUid, r.turnDeadline, r.scores])) r.revision++;
      if (r.playKind === "ranked" && r.status === "waiting" && time >= r.createdAt + 30000) {
        E.finish(r, "expired", "Bu modda rakip bulunamadı. Yeniden arayabilirsin.", time, null); delete s.queue[uid];
      }
      if (event && !E.terminal(r)) {
        if (Object.keys(r.audit).length >= 600) fail("resource-exhausted", "Maç hamle sınırı doldu.");
        if (input.action === "leave") {
          E.finish(r, r.status === "playing" ? "forfeit" : "cancelled", "Oyuncu maçtan ayrıldı.", time,
              r.status === "playing" ? uid === r.host ? r.guest : r.host : null); delete s.queue[uid];
          receipt = {accepted: true};
        } else if (input.action === "choose" && r.status === "ready" && r.playKind === "friend" &&
          ["club_club", "club_country"].includes(r.mode)) {
          const side = uid === r.host ? "left" : "right";
          const options = r.mode === "club_country" && side === "right" ? c.countryOptions : c.clubOptions;
          if (!options.includes(input.choice)) fail("invalid-argument", "Geçersiz seçim.");
          r.choices[side] = input.choice; r.ready = {}; receipt = {accepted: true};
        } else if (input.action === "ready" && r.status === "ready") {
          if (r.playKind === "friend" && ["club_club", "club_country"].includes(r.mode) &&
            (!r.choices.left || !r.choices.right)) fail("failed-precondition", "İki oyuncu da seçimini tamamlamalı.");
          r.ready[uid] = true;
          if (r.ready[r.host] && r.ready[r.guest]) E.start(r, c, time);
          receipt = {accepted: true};
        } else {
          if (!["answer", "squad"].includes(input.action)) fail("invalid-argument", "Bu aşamada geçersiz işlem.");
          // Simultaneous races validate current target/round atomically; stale turn claims do not consume a new turn.
          if (["grid_classic", "grid_reverse", "cinko"].includes(r.mode) && input.revision !== r.revision) {
            fail("aborted", "Sıra değişti; güncel maçı yenile.");
          }
          receipt = E.move(c, r, uid, input, time);
        }
        r.revision++;
        r.audit[r.revision] = {uid, at: time, input: structuredClone(input), result: receipt};
      } else if (event && input.action === "rematch" && r.playKind === "friend" && ["finished",
        "forfeit"].includes(r.status)) {
        if (!p.friendEnabled) fail("failed-precondition", "Yeni maçlar geçici olarak kapalı.");
        if (r.dataRevision !== catalog.version) fail("failed-precondition", "Yeni sürümle yeni bir oda aç.");
        r.rematch[uid] = true; receipt = {accepted: true};
        if (r.rematch[r.host] && r.rematch[r.guest] && !r.nextRoom) {
          const id = hash([seed, r.id]).slice(0, 8).toUpperCase();
          if (s.rooms[id]) fail("already-exists", "Rövanşı tekrar dene.");
          const series = structuredClone(r.series); series.wins ||= {};
          if (series.game >= series.limit) {
            series.id = id; series.game = 1; series.wins = {}; series.draws = 0;
          } else series.game++;
          const next = E.hydrate({id, mode: r.mode, playKind: "friend", host: r.guest, guest: r.host,
            names: r.names, status: "ready", revision: 0, createdAt: time, seed, schemaVersion: 1,
            ruleVersion: E.RULE, dataRevision: c.version, profile: r.profile, series, rankedEligible: false,
            rewardPolicy: {rewardsEnabled: false, eloEnabled: false}});
          s.rooms[id] = next; s.active[r.host] = id; s.active[r.guest] = id; r.nextRoom = id;
        }
      } else if (event && !["leave"].includes(input.action)) {
        fail("failed-precondition", "Maç sona erdi.");
      }
      if (!E.terminal(r)) r.presence[uid] = time;
      if (event) r.receipts[key] = {fingerprint: fp, result: receipt || {accepted: false}};
      s.rooms[r.id] = r;
    });
    let r = E.hydrate(s.rooms[input.roomId]);
    if (E.terminal(r) && !r.settlement && r.playKind === "ranked") {
      const result = await settle(r, p);
      await change(input.mode, (s) => {
        s.rooms[r.id].settlement = result;
      });
      r = E.hydrate((await db.ref(`pvpV1/${input.mode}/rooms/${r.id}`).get()).val());
    }
    return {room: E.view(c, r, uid, now()), receipt: receipt || null};
  }
  async function search(uid, input) {
    check(input); if (!await isLinked(uid)) fail("permission-denied", "Kalıcı hesap gerekli.");
    const q = norm(input.query).slice(0, 80); if (q.length < 2) return {players: []};
    // Full allowed snapshot, never the question's answer set or relevance to its criteria.
    let c = catalog;
    if (input.roomId) {
      const r = (await db.ref(`pvpV1/${input.mode}/rooms/${input.roomId}`).get()).val();
      if (!r || ![r.host, r.guest].includes(uid)) fail("permission-denied", "Maç yetkisi yok.");
      c = await pinned(r.dataRevision);
    }
    return {players: Object.values(c.players).filter((p) => [p.name, ...p.aliases].some((x) => norm(x).includes(q)))
        .sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id)).slice(0, 24).map((p) => E.player(c, p.id))};
  }
  async function sweep() {
    for (const mode of E.MODES) {
      const s = await change(mode, (s, time) => {
        for (const [id, raw] of Object.entries(s.rooms)) {
          const r = E.hydrate(raw); const was = hash([r.status, r.turnUid, r.turnDeadline, r.scores]);
          E.advance(r, time);
          if (r.status === "waiting" && r.playKind === "ranked" && time >= r.createdAt + 30000) {
            E.finish(r, "expired", "Rakip bulunamadı.", time, null);
          }
          if (was !== hash([r.status, r.turnUid, r.turnDeadline, r.scores])) r.revision++;
          s.rooms[id] = r;
        }
        for (const [u, q] of Object.entries(s.queue)) {
          if (time >= q.expiresAt || E.terminal(
              s.rooms[q.id])) delete s.queue[u];
        }
      });
      // Durable reward outbox is retried even if neither app returns to the result page.
      const p = await policy(mode);
      for (const raw of Object.values(s?.rooms || {})) {
        const r = E.hydrate(raw);
        if (E.terminal(r) && r.playKind === "ranked" && !r.settlement) {
          const result = await settle(r, p);
          await change(mode, (state) => {
            state.rooms[r.id].settlement = result;
          });
        }
      }
    }
  }
  return {status, enter, act, search, sweep};
}
module.exports = {createService, defaults};
