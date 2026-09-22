"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const configModule = require("../../economy_config");
const clone = (v) => v == null ? null : JSON.parse(JSON.stringify(v));
const auth = {uid: "alice", token: {firebase: {identities: {"google.com": ["alice-google"]}}}};

// Runs the actual index.js exports. Only Firebase transport and the clock are
// substituted. Transactions serialize conflicting calls and retry a cold null
// callback against server data; projections remain separate writes.
function harness(initial = {}) {
  const tree = clone(initial);
  let time = Date.parse("2026-09-20T10:00:00Z");
  let remote = clone(configModule.defaults);
  let queue = Promise.resolve();
  let failPath = null;
  const snap = (value) => ({val: () => clone(value), exists: () => value != null});
  function get(key = "") {
    return key.split("/").filter(Boolean).reduce((v, p) => v && v[p], tree) ?? null;
  }
  function set(key, value) {
    const parts = key.split("/").filter(Boolean);
    let node = tree;
    for (const p of parts.slice(0, -1)) node = node[p] ||= {};
    if (value == null) delete node[parts.at(-1)];
    else node[parts.at(-1)] = clone(value);
  }
  function maybeFail(key) {
    if (key === failPath) {
      failPath = null;
      throw new Error("Simulated interrupted write: " + key);
    }
  }
  const db = {ref: (key = "") => ({
    get: async () => snap(get(key)),
    set: async (v) => {
      maybeFail(key);
      set(key, v);
    },
    update: async (entries) => {
      maybeFail(key);
      for (const [p, v] of Object.entries(entries)) set(key ? key + "/" + p : p, v);
    },
    transaction: (update) => {
      const pending = queue.then(() => {
        maybeFail(key);
        const cold = update(null);
        if (cold === undefined) return {committed: false, snapshot: snap(null)};
        const next = update(clone(get(key)));
        if (next === undefined) return {committed: false, snapshot: snap(get(key))};
        set(key, next);
        return {committed: true, snapshot: snap(get(key))};
      });
      queue = pending.catch(() => {});
      return pending;
    },
  })};
  class Clock extends Date {
    static now() {
      return time;
    }
  }
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  const registration = (opts, fn) => fn;
  const modules = {
    "firebase-functions": {setGlobalOptions: () => {}},
    "firebase-functions/v2/scheduler": {onSchedule: registration},
    "firebase-functions/params": {defineSecret: () => ({value: () => "unused"})},
    "firebase-functions/logger": {warn: () => {}, info: () => {}, error: () => {}},
    "firebase-functions/v2/https": {HttpsError, onCall: registration, onRequest: registration},
    "firebase-functions/v2/database": {onValueWritten: registration},
    "firebase-admin": {initializeApp: () => {}, database: () => db,
      auth: () => ({getUser: async () => ({providerData: [{providerId: "google.com"}]})})},
    "firebase-admin/remote-config": {getRemoteConfig: () => ({getServerTemplate: async () => ({
      evaluate: () => ({getString: () => JSON.stringify(remote)}),
    })})},
    "./economy_config": {...configModule,
      createProvider: (opts) => configModule.createProvider({...opts, now: () => time})},
    "google-auth-library": {GoogleAuth: class {}},
  };
  const context = vm.createContext({
    exports: {}, Date: Clock, Intl, Buffer, console,
    require: (name) => modules[name] || require(name.startsWith(".") ? "../../" + name.slice(2) : name),
  });
  vm.runInContext(fs.readFileSync(path.join(__dirname, "../../index.js"), "utf8"), context);
  return {
    call: (name, data = {}, identity = auth) => context.exports[name]({auth: identity, data}),
    read: (key) => clone(get(key)),
    seed: set,
    db, context,
    failNext: (key) => failPath = key,
    setTime: (v) => time = typeof v === "string" ? Date.parse(v) : v,
    get now() {
      return time;
    },
    setConfig: (edit) => {
      remote = clone(configModule.defaults);
      edit(remote);
      time += 300001;
    },
  };
}
module.exports = {harness, clone};
