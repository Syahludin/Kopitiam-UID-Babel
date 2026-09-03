"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

function iterator(values) { let index = 0; return { hasNext: () => index < values.length, next: () => values[index++] }; }
function fakeSheet(headers) {
  const data = [headers.slice()];
  return {
    data,
    getDataRange() { return { getValues: () => data.map((row) => row.slice()) }; },
    getLastColumn() { return data[0].length; },
    getLastRow() { return data.length; },
    getRange(row, col, numRows, numCols) {
      return {
        getDisplayValues() { return Array.from({ length: numRows }, (_, r) => Array.from({ length: numCols }, (_, c) => data[row - 1 + r][col - 1 + c])); },
        setValues(values) { for (let r = 0; r < values.length; r++) for (let c = 0; c < values[r].length; c++) data[row - 1 + r][col - 1 + c] = values[r][c]; },
      };
    },
    appendRow(values) { data.push(values.slice()); },
    setFrozenRows() {},
  };
}
function driveTree() {
  function folder(name) { const children = new Map(); const files = []; return {
    getFoldersByName(n) { return iterator(children.has(n) ? [children.get(n)] : []); },
    createFolder(n) { if (!children.has(n)) children.set(n, folder(n)); return children.get(n); },
    getFilesByName(n) { return iterator(files.filter((f) => f.name === n && !f.trashed)); },
    getFiles() { return iterator(files.filter((f) => !f.trashed)); },
    getFolders() { return iterator([...children.values()]); },
    createFile(blob) { const file = { name: blob.name, trashed: false, getName() { return this.name; }, getUrl() { return "https://drive.example/" + encodeURIComponent(this.name); }, setTrashed(value) { this.trashed = value; } }; files.push(file); return file; },
  }; }
  return folder();
}
function jpegBytes() { const body = Buffer.alloc(1092, 0x42); return Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0x21, 0x01]), body, Buffer.from([0xff, 0xd9])]); }
function makeBackend(headers, opts = {}) {
  const sheet = fakeSheet(headers), driveRoot = driveTree(); let createdSheet = null;
  const openSheet = { getSheetByName: (name) => name === "Inp_Temuan" ? (opts.missingSheet ? null : sheet) : null, insertSheet: (name) => { if (name !== "Inp_Temuan") throw new Error("insertSheet unexpected: " + name); createdSheet = fakeSheet([]); return createdSheet; } };
  const sandbox = { console, Date, String, Number, Math, Utilities: { DigestAlgorithm: { SHA_256: "sha256" }, Charset: { UTF_8: "utf-8" }, base64Decode: (value) => Buffer.from(String(value), "base64"), computeDigest: (algorithm, value, charset) => [...crypto_findHash(algorithm, value, charset)].map((b) => (b > 127 ? b - 256 : b)), newBlob: (bytes, mime, name) => ({ bytes, mime, name }), getUuid: () => "uu-id-" + Math.random().toString(16).slice(2), formatDate: (date, tz, pattern) => formatDate(date, pattern) }, Session: { getScriptTimeZone: () => "Asia/Jakarta" }, LockService: { getScriptLock: () => ({ waitLock: () => {}, releaseLock: () => {} }) }, SpreadsheetApp: { openById: () => openSheet, flush: () => {} }, CacheService: { getScriptCache: () => ({ get: () => null, put: () => {}, remove: () => {} }) }, PropertiesService: { getScriptProperties: () => ({ getProperty: () => null, setProperty: () => {}, deleteProperty: () => {}, getProperties: () => ({}) }) }, DriveApp: { getRootFolder: () => driveRoot }, ContentService: { createTextOutput: () => ({ setMimeType() { return this; } }) } };
  vm.createContext(sandbox);
  vm.runInContext(read("SecurityValidation.js"), sandbox);
  vm.runInContext(read("Code.js"), sandbox);
  vm.runInContext(read("IdempotentUpload.js"), sandbox);
  vm.runInContext(read("TemuanSheetHelpers.js"), sandbox);
  vm.runInContext(["cekSesi_ = function() { return { success: true, sesi: { username: 'petugas', subTim: 'Inspeksi Jaringan', kodeUiw: 'UIW001', kodeUp3: 'UP3001', kodeUlp: 'PLG', ulp: 'ULP Babel' } }; };", "validateFindingMaster_ = function() { return { success: true }; };", "woContext_ = function(s, k, editable) { return { success: true, index: { 'kode uiw': 0, 'kode up3': 1, 'ulp': 2, 'penyulang': 3, 'section awal': 4, 'section akhir': 5, 'section': 6 }, row: ['UIW001', 'UP3001', 'ULP Babel', 'PLG', 'A-04', 'A-05', '04-05', 'PLG-2026-001'], headers: ['Kode UIW','Kode UP3','ULP','Penyulang','Section Awal','Section Akhir','Section','Kode WO'], rowNumber: 2, status: 'dalam pengerjaan', kodeUlp: 'PLG' }; };"].join("\n"), sandbox);
  return { sandbox, sheet, driveRoot, get createdSheet() { return createdSheet; } };
}
function crypto_findHash(algorithm, value, charset) { const crypto = require("node:crypto"); const input = typeof value === "string" ? Buffer.from(String(value), charset || "utf8") : Buffer.from(value); return crypto.createHash("sha256").update(input).digest(); }
function formatDate(date, pattern) { const months = ["Januari","Februari","Maret","April","Mei","Juni","Juli","Agustus","September","Oktober","November","Desember"]; const p2 = (n) => String(n).padStart(2, "0"); return pattern.replace("MMMM", months[date.getMonth()]).replace("yyyy", String(date.getFullYear())).replace("MM", p2(date.getMonth() + 1)).replace("dd", p2(date.getDate())).replace("HH", p2(date.getHours())).replace("mm", p2(date.getMinutes())).replace("ss", p2(date.getSeconds())); }
function payload(codes) { const b64 = jpegBytes().toString("base64"); return { "Kode WO": codes.wo, "Kode Temuan": codes.finding, "Segmen": "A-04/A-05", "Jenis Object": "Jaringan", "Tier": "Tier 1", "Temuan": "Rabas / Pangkas", "Jarak Terhadap Jaringan": 2.5, "Jenis Pohon": "Sengon", "Tinggi Pohon": 6, "Prioritas": "Mayor", "Koordinat Temuan": "-6.12345, 106.23456", fotoTemuanBase64: b64, fotoLingkunganBase64: b64 }; }
function cellByHeader(sheet, rowIndex, header) { const headers = sheet.data[0]; const col = headers.indexOf(header); return col < 0 ? undefined : sheet.data[rowIndex][col]; }
const DEFAULT_HEADERS = ["Kode WO","Kode Temuan","Kode ULP","Jenis Object","Tier","Temuan","Koordinat Temuan","Foto Temuan","Link Foto","Foto Lingkungan Sekitaran Tiang","Link Foto Sekitaran Tiang","Segmen","Jarak Terhadap Jaringan","Jenis Pohon","Tinggi Pohon","Prioritas","User Input","Folder Path","Kode UIW"];
test("temuan input values fill a brand-new row in Inp_Temuan", () => { const { sandbox, sheet } = makeBackend(DEFAULT_HEADERS); const result = sandbox.syncTemuanInspeksiIdempotent_("tok", payload({ wo: "PLG-2026-001", finding: "PLG-2026-001.TO-001" })); assert.equal(result.success, true); assert.equal(sheet.data.length, 2); assert.equal(cellByHeader(sheet, 1, "Kode WO"), "PLG-2026-001"); assert.equal(cellByHeader(sheet, 1, "Kode Temuan"), "PLG-2026-001.TO-001"); assert.equal(cellByHeader(sheet, 1, "Temuan"), "Rabas / Pangkas"); assert.equal(cellByHeader(sheet, 1, "Segmen"), "A-04/A-05"); assert.equal(cellByHeader(sheet, 1, "Tier"), "Tier 1"); assert.equal(cellByHeader(sheet, 1, "Jenis Object"), "Jaringan"); assert.equal(cellByHeader(sheet, 1, "Prioritas"), "Mayor"); assert.equal(cellByHeader(sheet, 1, "Jenis Pohon"), "Sengon"); assert.equal(cellByHeader(sheet, 1, "Jarak Terhadap Jaringan"), "2.5"); assert.equal(cellByHeader(sheet, 1, "Tinggi Pohon"), "6"); assert.equal(cellByHeader(sheet, 1, "Kode UIW"), "UIW001"); assert.equal(cellByHeader(sheet, 1, "User Input"), "petugas"); assert.match(String(cellByHeader(sheet, 1, "Koordinat Temuan")), /106\.23456/); assert.match(String(cellByHeader(sheet, 1, "Foto Temuan")), /^PLG-2026-001\.TO-001\.Foto Temuan\./); assert.match(String(cellByHeader(sheet, 1, "Link Foto")), /^https:\/\/drive\.example\//); assert.match(String(cellByHeader(sheet, 1, "Foto Lingkungan Sekitaran Tiang")), /^PLG-2026-001\.TO-001\.Foto Lingkungan\./); assert.match(String(cellByHeader(sheet, 1, "Folder Path")), /Kopitiam\/Rekap Temuan Inspeksi/); });
test("header case-insensitive and leading No column still gets values", () => { const headers = ["No","kode wo","Kode Temuan","Temuan","tier","Segmen","Koordinat Temuan","Foto Temuan","Link Foto"]; const { sandbox, sheet } = makeBackend(headers); const result = sandbox.syncTemuanInspeksiIdempotent_("tok", payload({ wo: "PLG-2026-002", finding: "PLG-2026-002.TO-001" })); assert.equal(result.success, true); assert.equal(sheet.data.length, 2); assert.equal(cellByHeader(sheet, 1, "No"), 1); assert.equal(cellByHeader(sheet, 1, "kode wo"), "PLG-2026-002"); assert.equal(cellByHeader(sheet, 1, "Kode Temuan"), "PLG-2026-002.TO-001"); assert.equal(cellByHeader(sheet, 1, "Temuan"), "Rabas / Pangkas"); assert.equal(cellByHeader(sheet, 1, "tier"), "Tier 1"); });
test("retrying the same finding updates the same row instead of duplicating", () => { const { sandbox, sheet } = makeBackend(DEFAULT_HEADERS); const body = payload({ wo: "PLG-2026-003", finding: "PLG-2026-003.TO-001" }); const first = sandbox.syncTemuanInspeksiIdempotent_("tok", body); const retry = sandbox.syncTemuanInspeksiIdempotent_("tok", body); assert.equal(first.success, true); assert.equal(retry.success, true); assert.equal(retry.reused, true); assert.equal(sheet.data.length, 2); assert.equal(cellByHeader(sheet, 1, "Kode Temuan"), "PLG-2026-003.TO-001"); });
test("auto-creates Inp_Temuan with headers when the sheet is missing", () => { const backend = makeBackend([], { missingSheet: true }); const result = backend.sandbox.syncTemuanInspeksiIdempotent_("tok", payload({ wo: "PLG-2026-004", finding: "PLG-2026-004.TO-001" })); assert.equal(result.success, true); const createdSheet = backend.createdSheet; assert.ok(createdSheet); assert.ok(createdSheet.data[0].includes("Kode Temuan")); assert.ok(createdSheet.data[0].includes("Kode WO")); assert.ok(createdSheet.data[0].includes("Folder Path")); assert.equal(cellByHeader(createdSheet, 1, "Kode Temuan"), "PLG-2026-004.TO-001"); });
test("invalid headers fail before any Drive photo is created", () => { const { sandbox, sheet, driveRoot } = makeBackend(["Kode WO", "Temuan"]); const result = sandbox.syncTemuanInspeksiIdempotent_("tok", payload({ wo: "PLG-2026-005", finding: "PLG-2026-005.TO-001" })); assert.equal(result.success, false); assert.equal(result.kode, "SHEET_HEADERS_INVALID"); assert.equal(sheet.data.length, 1); const files = []; (function collect(folder) { for (const it = folder.getFiles(); it.hasNext();) files.push(it.next()); for (const it = folder.getFolders(); it.hasNext();) collect(it.next()); })(driveRoot); assert.equal(files.length, 0); });
