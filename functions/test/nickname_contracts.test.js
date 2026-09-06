"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "..");
const indexPath = path.join(root, "functions", "index.js");
const rulesPath = path.join(root, "database.rules.json");
const nicknameServicePath = path.join(
    root,
    "lib",
    "services",
    "nickname_service.dart",
);
const authServicePath = path.join(
    root,
    "lib",
    "services",
    "auth_service.dart",
);
const profileServicePath = path.join(
    root,
    "lib",
    "services",
    "profile_service.dart",
);
const auditServicePath = path.join(
    root,
    "lib",
    "services",
    "profile_runtime_audit_service.dart",
);

const indexSource = fs.readFileSync(indexPath, "utf8");
const rules = JSON.parse(
    fs.readFileSync(rulesPath, "utf8"),
).rules;
const nicknameService = fs.readFileSync(
    nicknameServicePath,
    "utf8",
);
const authService = fs.readFileSync(
    authServicePath,
    "utf8",
);
const profileService = fs.readFileSync(
    profileServicePath,
    "utf8",
);
const auditService = fs.readFileSync(
    auditServicePath,
    "utf8",
);

test("nickname authority exports are present", () => {
  for (const name of [
    "checkNicknameAvailability",
    "syncMyNickname",
    "setMyNickname",
  ]) {
    assert.ok(
        indexSource.includes("exports." + name + " ="),
        name,
    );
  }
});

test("nickname policy is server-defined", () => {
  assert.ok(
      indexSource.includes(
          "LB_NICKNAME_CHANGE_COOLDOWN_MS = 24 * 60 * 60 * 1000",
      ),
  );
  assert.ok(indexSource.includes("LB_NICKNAME_BLOCKED_EXACT"));
  assert.ok(indexSource.includes("LB_NICKNAME_BLOCKED_PARTS"));
  assert.ok(indexSource.includes("lbNicknameSafetyKey("));
  assert.ok(indexSource.includes("\"inappropriate\""));
  assert.ok(indexSource.includes("\"reserved\""));
});

test("nickname registry is server-private", () => {
  assert.equal(rules.usernames[".read"], false);
  assert.equal(
      rules.usernames["$normalized"][".write"],
      false,
  );
});

test("client nickname service uses callables only", () => {
  assert.ok(
      nicknameService.includes(
          "package:cloud_functions/cloud_functions.dart",
      ),
  );
  assert.ok(
      nicknameService.includes(
          "_functions.httpsCallable('setMyNickname')",
      ),
  );
  assert.ok(
      nicknameService.includes(
          "_functions.httpsCallable('syncMyNickname')",
      ),
  );
  assert.ok(
      nicknameService.includes(
          "'checkNicknameAvailability'",
      ),
  );
  assert.equal(
      nicknameService.includes("FirebaseDatabase"),
      false,
  );
  assert.equal(
      nicknameService.includes("usernames/"),
      false,
  );
});

test("profile audit no longer reads private username registry", () => {
  assert.equal(auditService.includes("usernames/"), false);
  assert.ok(
      auditService.includes("normalized_name_invalid"),
  );
});

test("profile service delegates nickname repair to backend", () => {
  assert.equal(
      profileService.includes("data['displayName'] ="),
      false,
  );
  assert.ok(
      profileService.includes(
          "NicknameService.ensureCurrentNicknameIndex()",
      ),
  );
});

test("new guest profile starts from generated safe nickname", () => {
  assert.ok(
      authService.includes(
          "final generatedName = _generatedNickname(user.uid);",
      ),
  );
  assert.ok(
      authService.includes(
          "NicknameService.ensureCurrentNicknameIndex()",
      ),
  );
});

test("unsafe social names cannot build public profiles", () => {
  const buildStart = indexSource.indexOf(
      "async function lbSocialBuildPublicProfile",
  );
  const buildEnd = indexSource.indexOf(
      "async function lbSocialSyncPublicProfile",
  );

  assert.ok(buildStart >= 0);
  assert.ok(buildEnd > buildStart);

  const block = indexSource.slice(buildStart, buildEnd);
  assert.ok(block.includes("lbNicknameValidateDisplay("));
  assert.ok(block.includes("storedNormalized !== normalizedName"));
});

test("account deletion clears nickname safety state", () => {
  assert.ok(
      indexSource.includes(
          "\"safetyState/nicknameChanges/\" + uid",
      ),
  );
  assert.ok(
      indexSource.includes(
          "\"safetyState/nicknameLocks/\" + uid",
      ),
  );
});
