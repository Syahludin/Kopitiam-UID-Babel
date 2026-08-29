"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");
const setup = fs.readFileSync(path.join(root, "Setup.js"), "utf8");

test("production router exposes getWoRow and syncWoRow", () => {
  assert.match(code, /if \(a === "getWoRow"\) return json_\(getWoRow_\(b\.token\)\)/);
  assert.match(code, /if \(a === "syncWoRow"\) return json_\(syncWoRow_\(b\.token, b\.rows\)\)/);
});

test("ROW sheet is configured and validated by setup", () => {
  assert.match(code, /WO_ROW_SHEET: "WO_ROW"/);
  assert.match(setup, /CONFIG\.WO_ROW_SHEET/);
  assert.match(setup, /"Tim Eksekusi",/);
});

test("woRowAccess_ gates on ROW sub-team and ULP", () => {
  assert.match(code, /function woRowAccess_\(s\)/);
  assert.match(code, /sub\.indexOf\("row"\) < 0/);
  assert.match(code, /ROW_ACCESS_DENIED/);
  assert.match(code, /function woRowContext_\(s, k, editable\)/);
  assert.match(code, /WO_TEAM_DENIED/);
});

test("syncWoRow_ validates ROW statuses and mutates only ROW headers", () => {
  assert.match(code, /var WO_ROW_MUTABLE_HEADERS = \[/);
  assert.match(code, /"penugasan tim", "progress pekerjaan", "selesai"/);
  assert.match(code, /WO_ROW_MUTABLE_HEADERS\.indexOf\(n\) < 0/);
  assert.match(code, /function getWoRow_\(t\)/);
  assert.match(code, /timEksekusiFilter: ac\.subTim/);
  assert.match(code, /"foto sesudah base64"/);
  assert.match(code, /preparePhoto_\(fotoB64, "Foto Sesudah"\)/);
  assert.match(code, /putPhotoIdempotent_\(/);
});

test("syncWoRow_ accepts the mobile camelCase photo key", () => {
  assert.match(
    code,
    /normPayload\["foto sesudah base64"\] \|\| normPayload\["fotosesudahbase64"\]/,
  );
  assert.match(code, /fp\.replace\(\/\\\/\+\$\/, ""\) \+ "\/" \+ stored\.name/);
});

test("jenis tebangan mengikuti formula IFS diameter batang", () => {
  const sandbox = { console };
  vm.createContext(sandbox);
  vm.runInContext(code, sandbox, { filename: "Code.js" });
  assert.equal(sandbox.jenisTebanganFromDiameter_(0), "Rabas / Pangkas");
  assert.equal(sandbox.jenisTebanganFromDiameter_("0"), "Rabas / Pangkas");
  assert.equal(sandbox.jenisTebanganFromDiameter_(1), "Tebang Sedang");
  assert.equal(sandbox.jenisTebanganFromDiameter_(25), "Tebang Sedang");
  assert.equal(sandbox.jenisTebanganFromDiameter_(50), "Tebang Sedang");
  assert.equal(sandbox.jenisTebanganFromDiameter_(51), "Tebang Besar");
  assert.equal(sandbox.jenisTebanganFromDiameter_(200), "Tebang Besar");
  assert.equal(sandbox.jenisTebanganFromDiameter_(""), "");
  assert.equal(sandbox.jenisTebanganFromDiameter_(null), "");
});
