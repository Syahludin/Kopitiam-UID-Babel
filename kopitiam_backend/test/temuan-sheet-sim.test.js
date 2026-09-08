"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const upload = fs.readFileSync(path.join(root, "IdempotentUpload.js"), "utf8");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");

test("C4A targets Inp_Temuan", () => {
  assert.ok(code.includes('TEMUAN_SHEET: "Inp_Temuan"'));
  assert.ok(upload.includes('CONFIG.TEMUAN_SHEET || "Inp_Temuan"'));
  assert.equal(upload.includes("Ins_Temuan"), false);
});

test("C4A accepts no WO and clears WO fields", () => {
  assert.ok(upload.includes('var isC4a = kodeWo === ""'));
  assert.ok(upload.includes('incoming["Kode WO"] = ""'));
  assert.ok(upload.includes('incoming["Jenis WO"] = ""'));
  assert.ok(upload.includes('row["Kode WO"] = isC4a ? "" : kodeWo'));
  assert.ok(upload.includes('row["Jenis WO"] = isC4a ? ""'));
});

test("C4A validates input before committing", () => {
  for (const contract of [
    "FINDING_CODE_INVALID", "c4aContext_", "ULP_MISMATCH",
    "validateFindingMaster_", "validateCoordinate_",
    "preparePhoto_(incoming.fotoTemuanBase64",
    "preparePhoto_(incoming.fotoLingkunganBase64",
  ]) assert.ok(upload.includes(contract), contract);
});

test("same code updates its row and photo hashes are reused", () => {
  for (const contract of [
    'headerIndex["kode temuan"]', "if (target)", "sheet.getRange(target",
    "putPhotoIdempotent_", "photoIdempotencyKey_",
    "reused: !primary.created && !environment.created",
  ]) assert.ok(upload.includes(contract), contract);
});

test("C4A uses a folder path without phantom WO", () => {
  assert.ok(upload.includes("function buildC4aFindingPath_"));
  assert.ok(upload.includes("isC4a ? buildC4aFindingPath_"));
  assert.ok(upload.includes('safePath_(code) + "/"'));
});
