"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "ZZ_MasterDataFiltered.js"), "utf8");

function load() {
  const sandbox = {
    normalize_: (value) => String(value || "").trim().toLowerCase(),
    headerIndex_: (headers) => Object.fromEntries(headers.map((value, index) => [String(value).trim().toLowerCase(), index])),
    CONFIG: { USERS_SHEET: "User_App_Mobile" },
    USER_COL: { username: 0 },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: "ZZ_MasterDataFiltered.js" });
  return sandbox;
}

function masterSheet() {
  return {
    getDataRange: () => ({
      getDisplayValues: () => [
        ["Objek Inspeksi", "Tier", "Temuan"],
        ["Inspeksi Jaringan", "Tier 1", "Kabel Geser"],
        ["Jaringan", "Tier 2", "Andongan Rendah"],
        ["Inspeksi Gardu", "Tier 1", "Trafo Bocor"],
        ["Gardu Distribusi", "Tier 2", "Bushing Rusak"],
      ],
    }),
  };
}

function findings(api, subTim) {
  const target = api.masterObjectForSession_({ subTim });
  return Array.from(
    api.masterRows_(masterSheet(), "Master_Temuan", { username: "petugas", subTim }, target),
    (row) => row.Temuan,
  );
}

test("Inspeksi Jaringan receives only Jaringan findings", () => {
  const api = load();
  assert.deepEqual(findings(api, "Inspeksi Jaringan"), ["Kabel Geser", "Andongan Rendah"]);
});

test("Inspeksi Gardu receives only Gardu findings", () => {
  const api = load();
  assert.deepEqual(findings(api, "Inspeksi Gardu"), ["Trafo Bocor", "Bushing Rusak"]);
});

test("other sub-teams receive both categories for explicit mobile selection", () => {
  const api = load();
  assert.equal(api.masterObjectForSession_({ subTim: "Har Jaringan" }), "");
  assert.deepEqual(findings(api, "Har Jaringan"), [
    "Kabel Geser",
    "Andongan Rendah",
    "Trafo Bocor",
    "Bushing Rusak",
  ]);
});

test("object aliases normalize to the mobile categories", () => {
  const api = load();
  assert.equal(api.masterObjectCategory_("INSJAR"), "jaringan");
  assert.equal(api.masterObjectCategory_("JTM / JTR"), "jaringan");
  assert.equal(api.masterObjectCategory_("Inspeksi Gardu"), "gardu");
  assert.equal(api.masterObjectCategory_("Gardu Distribusi"), "gardu");
});
