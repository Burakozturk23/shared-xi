"use strict";
// Old games stay playable on the catalog they started with, so each catalog version is
// stored once. Checking one small field keeps a game start from downloading the whole
// catalog: a transaction on it spiked memory past 256 MiB on the 3 MB Arcade catalog.
async function pinCatalog(db, path, value, marker = "version") {
  if ((await db.ref(`${path}/${marker}`).get()).val() != null) return;
  await db.ref(path).transaction((raw) => raw || value);
}
module.exports = {pinCatalog};
