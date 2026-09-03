"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const code = read("Code.js");
const core = read("WorkOrderCore.js");
const setup = read("Setup.js");
const production = code + "\n" + core;

function jenisTebanganFromDiameter(value) {
  if (value === "" || value === null || value === undefined) return "";
  const diameter = Number(value);
  if (!Number.isFinite(diameter)) return "";
  if (diameter <= 0) return "Rabas / Pangkas";
  return diameter <= 50 ? "Tebang Sedang" : "Tebang Besar";
}

test("production router exposes getWoRow and syncWoRow", () => {
  assert.match(code, /getWoRow_\(b\.token\)/);
  assert.match(code, /syncWoRow_\(b\.token, b\.rows\)/);
});

test("ROW sheet is configured and validated by setup", () => {
  assert.match(code, /WO_ROW_SHEET: "WO_ROW"/);
  assert.match(setup, /CONFIG\.WO_ROW_SHEET/);
  assert.match(setup, /"Tim Eksekusi"/);
});

test("ROW access gates on ROW sub-team and ULP", () => {
  assert.match(production, /function woCoreAccess_\(session, mode\)/);
  assert.match(production, /mode === 'row'/);
  assert.match(production, /ROW_ACCESS_DENIED/);
  assert.match(production, /normalizeCode_\(session\.kodeUlp/);
});

test("ROW sync validates batch and mutates only approved ROW headers", () => {
  assert.match(core, /var WO_CORE_MUTABLE = \{/);
  assert.match(core, /row: \[/);
  assert.match(core, /function getWoRow_\(token\)/);
  assert.match(core, /function syncWoRow_\(token, rows\)/);
  assert.match(core, /WO_CORE_MUTABLE\[mode\]/);
  assert.match(core, /safeCell_\(normalized\[header\]\)/);
});

test("jenis tebangan mengikuti formula IFS diameter batang", () => {
  assert.equal(jenisTebanganFromDiameter(0), "Rabas / Pangkas");
  assert.equal(jenisTebanganFromDiameter("0"), "Rabas / Pangkas");
  assert.equal(jenisTebanganFromDiameter(1), "Tebang Sedang");
  assert.equal(jenisTebanganFromDiameter(25), "Tebang Sedang");
  assert.equal(jenisTebanganFromDiameter(50), "Tebang Sedang");
  assert.equal(jenisTebanganFromDiameter(51), "Tebang Besar");
  assert.equal(jenisTebanganFromDiameter(200), "Tebang Besar");
  assert.equal(jenisTebanganFromDiameter(""), "");
  assert.equal(jenisTebanganFromDiameter(null), "");
});
