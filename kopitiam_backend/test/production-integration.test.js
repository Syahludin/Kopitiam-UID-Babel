"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");
const idempotent = fs.readFileSync(path.join(root, "IdempotentUpload.js"), "utf8");

test("production POST router consumes action quota before dispatch", () => {
  assert.match(code, /function doPost\(e\)/);
  assert.match(code, /consumeActionQuota_\(a, runtimeIdentity_\(b\)\)/);
  assert.match(code, /runtimeIdentity_\(body\)/);
});

test("device handler fails closed before issuing a fresh session", () => {
  assert.match(code, /function cekPerangkat_\(t\)/);
  assert.match(code, /validateDeviceRecord_\(rec, Date\.now\(\)\)/);
  assert.match(code, /accountStatus_\(rec\.username\)/);
  assert.match(code, /p\.deleteProperty\(key\)/);
  assert.match(code, /ACCOUNT_INACTIVE/);
});

test("every cached session is bound to a live device record", () => {
  assert.match(code, /verifySessionDeviceBinding_\(t, sesi\)/);
  assert.match(code, /session\.deviceToken/);
  assert.match(code, /device_.*deviceToken/);
  assert.match(code, /validateDeviceRecord_\(record, Date\.now\(\)\)/);
  assert.match(code, /SESSION_DEVICE_MISMATCH/);
  assert.match(code, /SESSION_BINDING_INVALID/);
});

test("password changes revoke both the session and bound device", () => {
  assert.match(code, /passwordSignature_/);
  assert.match(code, /record\.passwordSignature/);
  assert.match(code, /constantTimeEqual_/);
  assert.match(code, /revokeBoundSession_\(sessionToken, deviceToken\)/);
  assert.match(code, /DEVICE_REVOKED/);
});

test("account status is checked on every successful cached session request", () => {
  assert.match(code, /accountStatus_\(session\.username\)/);
  assert.match(code, /ACCOUNT_INACTIVE/);
  assert.match(code, /function cekSesi_\(t\)/);
  assert.match(code, /verifySessionDeviceBinding_\(t, sesi\)/);
});

test("master validation runs before idempotent Temuan transaction", () => {
  assert.match(idempotent, /function syncTemuanInspeksiIdempotent_/);
  const fnStart = idempotent.indexOf("function syncTemuanInspeksiIdempotent_");
  const next = idempotent.indexOf("\nfunction ", fnStart + 1);
  const fnBody = idempotent.slice(fnStart, next < 0 ? undefined : next);
  assert.match(fnBody, /validateFindingMaster_/);
  assert.match(fnBody, /incoming\["Jenis Object"\]/);
  assert.match(fnBody, /incoming(?:\["Prioritas"\]|\.Prioritas)/);
  const masterIdx = fnBody.indexOf("validateFindingMaster_");
  const syncIdx = fnBody.indexOf("woContext_");
  assert.ok(masterIdx < syncIdx, "master validation must run before woContext_");
});
