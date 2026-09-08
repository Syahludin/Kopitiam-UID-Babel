"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const upload = fs.readFileSync(path.join(root, "IdempotentUpload.js"), "utf8");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");

test("C4A targets the production Inp_Temuan sheet", () => {
  assert.match(code, /TEMUAN_SHEET:\s*["']Inp_Temuan["']/);
  assert.match(upload, /CONFIG\.TEMUAN_SHEET\s*\|\|\s*["']Inp_Temuan["']/);
  assert.doesNotMatch(upload, /Ins_Temuan/);
});

test("C4A accepts a finding without WO but clears both WO fields", () => {
  assert.match(upload, /var isC4a = kodeWo === ""/);
  assert.match(upload, /incoming\["Kode WO"\]\s*=\s*""/);
  assert.match(upload, /incoming\["Jenis WO"\]\s*=\s*""/);
  assert.match(upload, /row\["Kode WO"\]\s*=\s*isC4a\s*\?\s*""/);
  assert.match(upload, /row\["Jenis WO"\]\s*=\s*isC4a\s*\?\s*""/);
});

test("C4A validates code, unit, master, coordinate and JPEGs", () => {
  assert.match(upload, /FINDING_CODE_INVALID/);
  assert.match(upload, /function c4aContext_/);
  assert.match(upload, /ULP_MISMATCH/);
  assert.match(upload, /validateFindingMaster_/);
  assert.match(upload, /validateCoordinate_/);
  assert.match(upload, /preparePhoto_\(incoming\.fotoTemuanBase64/);
  assert.match(upload, /preparePhoto_\(incoming\.fotoLingkunganBase64/);
});

test("same Kode Temuan updates the existing row and reuses photo hashes", () => {
  assert.match(upload, /headerIndex\["kode temuan"\]/);
  assert.match(upload, /if \(target\)/);
  assert.match(upload, /sheet\.getRange\(target/);
  assert.match(upload, /putPhotoIdempotent_/);
  assert.match(upload, /photoIdempotencyKey_/);
  assert.match(upload, /reused:\s*!primary\.created && !environment\.created/);
});

test("C4A folder omits a phantom WO segment", () => {
  assert.match(upload, /function buildC4aFindingPath_/);
  assert.match(upload, /safePath_\(code\) \+ "\/"/);
  assert.match(upload, /isC4a \? buildC4aFindingPath_/);
});
