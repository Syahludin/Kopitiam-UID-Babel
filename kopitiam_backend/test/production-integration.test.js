"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const integration = fs.readFileSync(
  path.join(root, "ZZ_RuntimeIntegration.js"),
  "utf8",
);

function expectBefore(first, second, source = integration) {
  const left = source.indexOf(first);
  const right = source.indexOf(second);
  assert.ok(left >= 0, `${first} tidak ditemukan`);
  assert.ok(right >= 0, `${second} tidak ditemukan`);
  assert.ok(left < right, `${first} harus dijalankan sebelum ${second}`);
}

function functionBlock(name, nextName) {
  const start = integration.indexOf(name);
  const end = integration.indexOf(nextName, start + name.length);
  assert.ok(start >= 0, `${name} tidak ditemukan`);
  assert.ok(end > start, `${nextName} tidak ditemukan setelah ${name}`);
  return integration.slice(start, end);
}

test("production POST router consumes action quota before dispatch", () => {
  assert.match(integration, /doPost = function\(e\)/);
  expectBefore("consumeActionQuota_", "_unguardedDoPost_(e)");
  assert.match(integration, /runtimeIdentity_\(body\)/);
});

test("device handler fails closed before issuing a fresh session", () => {
  assert.match(integration, /cekPerangkat_ = function\(token\)/);
  expectBefore("validateDeviceRecord_", "_unguardedCekPerangkat_(token)");
  expectBefore("accountStatus_", "_unguardedCekPerangkat_(token)");
  assert.match(integration, /props\.deleteProperty\(key\)/);
  assert.match(integration, /ACCOUNT_INACTIVE/);
});

test("every cached session is bound to a live device record", () => {
  assert.match(
    integration,
    /verifySessionDeviceBinding_\(token, result\.sesi\)/,
  );
  assert.match(integration, /session\.deviceToken/);
  assert.match(integration, /device_.*deviceToken/);
  assert.match(integration, /validateDeviceRecord_\(record, Date\.now\(\)\)/);
  assert.match(integration, /SESSION_DEVICE_MISMATCH/);
  assert.match(integration, /SESSION_BINDING_INVALID/);
});

test("password changes revoke both the session and bound device", () => {
  assert.match(integration, /passwordSignature_/);
  assert.match(integration, /record\.passwordSignature/);
  assert.match(integration, /constantTimeEqual_/);
  assert.match(integration, /revokeBoundSession_\(sessionToken, deviceToken\)/);
  assert.match(integration, /DEVICE_REVOKED/);
});

test("account status is checked on every successful cached session request", () => {
  assert.match(integration, /accountStatus_\(session\.username\)/);
  assert.match(integration, /ACCOUNT_INACTIVE/);
  const cekSesi = functionBlock(
    "cekSesi_ = function(token)",
    "syncTemuanInspeksiIdempotent_ = function",
  );
  expectBefore(
    "verifySessionDeviceBinding_(token, result.sesi)",
    "return result;",
    cekSesi,
  );
});

test("master validation runs before idempotent Temuan transaction", () => {
  assert.match(integration, /syncTemuanInspeksiIdempotent_ = function/);
  expectBefore(
    "validateFindingMaster_",
    "_unguardedSyncTemuan_(token, incoming)",
  );
  assert.match(integration, /incoming\['Jenis Object'\]/);
  assert.match(integration, /incoming\['Prioritas'\]/);
});
