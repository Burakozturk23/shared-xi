"use strict";
// A callable whose answer holds NaN or Infinity fails to encode ("Data cannot be
// encoded in JSON: NaN"): the move is already saved, but every reply to that room
// fails and the client shows "Oyunla bağlantı kurulamadı" until the match ends.
// Live-game replies pass through here: such a number becomes null (the client
// treats it as missing) and the path is logged once, so the bug is visible without
// stopping the match.
function finiteResponse(value, label) {
  const bad = [];
  const walk = (v, path) => {
    if (typeof v === "number") {
      if (Number.isFinite(v)) return v;
      bad.push(path); return null;
    }
    if (Array.isArray(v)) return v.map((x, i) => walk(x, path + "." + i));
    if (v && typeof v === "object" && Object.getPrototypeOf(v) === Object.prototype) {
      const out = {};
      for (const [k, x] of Object.entries(v)) out[k] = walk(x, path + "." + k);
      return out;
    }
    return v;
  };
  const out = walk(value, "");
  if (bad.length) console.error(`${label}: non-finite numbers replaced with null`, bad.slice(0, 10));
  return bad.length ? out : value;
}
module.exports = {finiteResponse};
