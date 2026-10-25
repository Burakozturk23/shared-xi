"use strict";
// Migrate a private game document into the user's wallet transaction. Keep the
// legacy private path as an ordered compatibility mirror for existing triggers.
function create({db, normalize, project, collection, shouldMigrate = async () => true, now = Date.now}) {
  return (uid) => {
    const canonical = db.ref(`economyState/${uid}/storyStates/${collection}`);
    const mirror = db.ref(`${collection}/${uid}`);
    const get = async () => {
      const stored = await canonical.get();
      if (stored.val()?._walletDocumentVersion !== 1) return mirror.get();
      const value = stored.val(); const projected = (await mirror.get()).val();
      if ((projected?._projectionRevision || 0) < value._projectionRevision) {
        await mirror.transaction((old) => (old?._projectionRevision || 0) > value._projectionRevision ? old : value);
      }
      return stored;
    };
    const transaction = async (update) => {
      const legacy = (await get()).val();
      if (legacy?._walletDocumentVersion !== 1 && !await shouldMigrate(uid)) return mirror.transaction(update);
      const wallet = db.ref("economyState/" + uid);
      // RTDB may invoke a cold callback before downloading this parent. Seed
      // from the read; the server retries with its current value on conflict.
      const base = (await wallet.get()).val();
      const result = await wallet.transaction((raw) => {
        const e = normalize(structuredClone(raw ?? base)); e.storyStates ||= {};
        const current = e.storyStates[collection]?._walletDocumentVersion === 1 ?
          e.storyStates[collection] : structuredClone(legacy);
        const next = update(current, e, now());
        if (next == null) return undefined;
        if (!next || typeof next !== "object") throw Error("Game document must remain an object");
        next._walletDocumentVersion = 1;
        next._projectionRevision = (current?._projectionRevision || 0) + 1;
        e.storyStates[collection] = next;
        return e;
      });
      if (!result.committed) return {committed: false, snapshot: await get()};
      const e = result.snapshot.val(); const value = e.storyStates[collection];
      await mirror.transaction((old) => (old?._projectionRevision || 0) > value._projectionRevision ? old : value);
      await project(db, uid, normalize(e));
      return {committed: true, snapshot: {val: () => structuredClone(value)}};
    };
    return {get, transaction};
  };
}
module.exports = {create};
